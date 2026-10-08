import Foundation
import NaturalLanguage

struct ParsedTaskItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var dueDate: Date? = nil
    var priority: Priority = .none
    var tagId: UUID? = nil
    var isSelected: Bool = true
}

struct AIExtractionResult {
    var tasks: [ParsedTaskItem]
    var engineName: String
    var errorDescription: String?
}

class AITaskParser {

    static let shared = AITaskParser()

    private let commonActionVerbs = [
        "call", "buy", "email", "send", "finish", "review", "fix", "prepare",
        "schedule", "write", "pick up", "clean", "deploy", "check", "meet", "cancel",
        "order", "read", "update", "create", "submit", "pay", "work on", "brush up",
        "talk to", "contact", "set up", "organize", "plan", "research", "test", "inspect"
    ]

    // MARK: - Smart Extraction (Gemini 3 Flash or Local NLP Fallback)

    func extractTasks(
        from text: String,
        apiKey: String,
        availableTags: [TagItem]
    ) async -> AIExtractionResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. If user provided an API key, attempt Gemini
        if !trimmedKey.isEmpty {
            let (geminiTasks, usedModel, err) = await callGeminiWithFallbacks(
                text: text,
                apiKey: trimmedKey,
                availableTags: availableTags
            )

            if let tasks = geminiTasks, !tasks.isEmpty {
                return AIExtractionResult(tasks: tasks, engineName: usedModel ?? "Gemini 3 Flash", errorDescription: nil)
            } else if let error = err {
                // Gemini call returned an error, fall back to local parser and report error
                let localTasks = parseTasksLocal(from: text, availableTags: availableTags)
                return AIExtractionResult(
                    tasks: localTasks,
                    engineName: "On-Device NLP",
                    errorDescription: error
                )
            }
        }

        // 2. Default to On-Device Smart Parser
        let localTasks = parseTasksLocal(from: text, availableTags: availableTags)
        return AIExtractionResult(tasks: localTasks, engineName: "On-Device Smart AI", errorDescription: nil)
    }

    // MARK: - Google Gemini API Calls

    private func callGeminiWithFallbacks(
        text: String,
        apiKey: String,
        availableTags: [TagItem]
    ) async -> ([ParsedTaskItem]?, String?, String?) {
        // Try gemini-3-flash first as requested, then gemini-2.5-flash, gemini-2.0-flash, gemini-1.5-flash
        let modelsToTry = [
            ("gemini-3-flash", "Gemini 3 Flash"),
            ("gemini-2.5-flash", "Gemini 2.5 Flash"),
            ("gemini-2.0-flash", "Gemini 2.0 Flash"),
            ("gemini-1.5-flash", "Gemini 1.5 Flash")
        ]

        var lastError: String? = nil

        for (modelId, displayName) in modelsToTry {
            let (tasks, error) = await executeGeminiRequest(modelId: modelId, text: text, apiKey: apiKey, availableTags: availableTags)
            if let tasks = tasks, !tasks.isEmpty {
                return (tasks, displayName, nil)
            }
            if let error = error {
                lastError = error
            }
        }

        return (nil, nil, lastError)
    }

    private func executeGeminiRequest(
        modelId: String,
        text: String,
        apiKey: String,
        availableTags: [TagItem]
    ) async -> ([ParsedTaskItem]?, String?) {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            return (nil, "Invalid Gemini endpoint URL")
        }

        let systemPrompt = makeSystemPrompt(availableTags: availableTags)
        let promptText = "\(systemPrompt)\n\nUser Input to extract into todo items:\n\(text)"

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.1
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return (nil, "JSON serialization error")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 12

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (nil, "No HTTP response")
            }

            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let firstPart = parts.first,
                   let textResponse = firstPart["text"] as? String,
                   let tasks = parseLLMJSONResponse(textResponse, availableTags: availableTags) {
                    return (tasks, nil)
                }
            } else {
                return (nil, "Gemini \(modelId): HTTP \(httpResponse.statusCode)")
            }
        } catch {
            return (nil, "Network error: \(error.localizedDescription)")
        }

        return (nil, nil)
    }

    private func makeSystemPrompt(availableTags: [TagItem]) -> String {
        let tagNames = availableTags.map { $0.name }.joined(separator: ", ")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let nowString = formatter.string(from: Date())

        return """
        You are a smart, accurate task extraction engine for a macOS Todo application. Current date and time is \(nowString).
        Analyze the user's input text (or transcript or meeting notes) and extract distinct actionable to-do tasks into a JSON object with a "tasks" array.

        Strict Rules:
        1. "title": Clean, concise, imperative task title (e.g. "Review Q3 budget deck", "Email Sarah about mockups"). NEVER duplicate the timing or dates in the title if extracted into dueDate.
        2. "notes": Any additional context, description, or secondary notes (empty string "" if none).
        3. "dueDate": ISO-8601 formatted string (e.g. "2026-10-09T15:00:00Z") ONLY if a date or time is explicitly mentioned (e.g., "tomorrow at 3pm", "by Friday", "tonight", "Oct 15").
           IMPORTANT: If no date/timing information is provided or if unclear, "dueDate" MUST be null.
        4. "priority": One of "High", "Medium", "Low", "None". Set "High" only for urgent/critical/asap items, otherwise "None".
        5. "tag": One of [\(tagNames)] if relevant, otherwise null.

        Output ONLY valid JSON:
        {"tasks": [{"title": "...", "notes": "", "dueDate": null, "priority": "None", "tag": null}]}
        """
    }

    private func parseLLMJSONResponse(_ jsonString: String, availableTags: [TagItem]) -> [ParsedTaskItem]? {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskList = root["tasks"] as? [[String: Any]] else {
            return nil
        }

        var results: [ParsedTaskItem] = []
        let isoFormatter = ISO8601DateFormatter()

        for dict in taskList {
            guard let title = dict["title"] as? String, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }

            let notes = dict["notes"] as? String ?? ""

            var dueDate: Date? = nil
            if let dateStr = dict["dueDate"] as? String {
                dueDate = isoFormatter.date(from: dateStr)
            }

            var priority: Priority = .none
            if let prioStr = dict["priority"] as? String {
                switch prioStr.lowercased() {
                case "high": priority = .high
                case "medium": priority = .medium
                case "low": priority = .low
                default: priority = .none
                }
            }

            var tagId: UUID? = nil
            if let tagName = dict["tag"] as? String {
                tagId = availableTags.first { $0.name.lowercased() == tagName.lowercased() }?.id
            }

            results.append(ParsedTaskItem(
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                tagId: tagId,
                isSelected: true
            ))
        }

        return results.isEmpty ? nil : results
    }

    // MARK: - On-Device Local NLP Parser (Robust Splitting & Extraction)

    func parseTasksLocal(from text: String, availableTags: [TagItem]) -> [ParsedTaskItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Split text into candidate distinct task items
        let segments = splitIntoTaskSegments(text: trimmed)
        var tasks: [ParsedTaskItem] = []

        for segment in segments {
            if let task = parseIndividualSegment(segment, availableTags: availableTags) {
                tasks.append(task)
            }
        }

        if tasks.isEmpty {
            if let single = parseIndividualSegment(trimmed, availableTags: availableTags) {
                tasks.append(single)
            }
        }

        return tasks
    }

    private func splitIntoTaskSegments(text: String) -> [String] {
        var raw = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Convert bullet lists, dashes, and numbers (1., 2., etc.) into newlines
        raw = raw.replacingOccurrences(of: "(?m)^([0-9]+[\\.\\)]|[-*•])\\s+", with: "\n", options: .regularExpression)

        // 2. Semicolons into newlines
        raw = raw.replacingOccurrences(of: ";", with: "\n")

        // 3. Sentence end periods (avoiding abbreviations like Prof., Dr., Mr., etc.)
        let sentencePattern = "(?<!Prof|Dr|Mr|Mrs|Ms|vs|e\\.g|i\\.e)\\.\\s+(?=[A-Z0-9])"
        raw = raw.replacingOccurrences(of: sentencePattern, with: "\n", options: .regularExpression)

        // 4. Split on ", and " or ", also " or ", then "
        raw = raw.replacingOccurrences(of: ",\\s*(?:and|also|then)\\s+", with: "\n", options: [.regularExpression, .caseInsensitive])

        // 5. Split on " and then " or " then "
        raw = raw.replacingOccurrences(of: "\\s+(?:and then|then)\\s+", with: "\n", options: [.regularExpression, .caseInsensitive])

        // 6. Split on ", <verb> " or " and <verb> "
        for verb in commonActionVerbs {
            let patternAnd = "\\s+and\\s+(\(verb)\\b)"
            raw = raw.replacingOccurrences(of: patternAnd, with: "\n$1", options: [.regularExpression, .caseInsensitive])

            let patternComma = ",\\s*(\(verb)\\b)"
            raw = raw.replacingOccurrences(of: patternComma, with: "\n$1", options: [.regularExpression, .caseInsensitive])
        }

        // 7. Split on "need to" or "remember to" or "don't forget to"
        raw = raw.replacingOccurrences(of: "\\s+(?:and\\s+)?(?:also\\s+)?(?:i need to|we need to|need to|remember to|make sure to|don't forget to)\\s+", with: "\n", options: [.regularExpression, .caseInsensitive])

        return raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }
    }

    private func parseIndividualSegment(_ rawText: String, availableTags: [TagItem]) -> ParsedTaskItem? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return nil }

        // 1. Extract Due Date & time (and strip the date/time phrase from title text!)
        let (extractedDate, textWithoutDate) = extractDueDateAndCleanText(from: text)

        // 2. Extract Priority
        let (priority, textWithoutPriority) = extractPriority(from: textWithoutDate)

        // 3. Extract Tag
        let (tagId, textWithoutTag) = extractTag(from: textWithoutPriority, availableTags: availableTags)

        // 4. Clean Title and Notes
        let (title, notes) = extractTitleAndNotes(from: textWithoutTag)

        guard !title.isEmpty else { return nil }

        return ParsedTaskItem(
            title: title,
            notes: notes,
            dueDate: extractedDate,
            priority: priority,
            tagId: tagId,
            isSelected: true
        )
    }

    // MARK: - Date Extraction & Title Cleaning

    private func extractDueDateAndCleanText(from text: String) -> (Date?, String) {
        let calendar = Calendar.current
        let now = Date()
        let lower = text.lowercased()
        var workingText = text
        var extractedDate: Date? = nil

        let (timeOfDay, timeMatchedStr) = extractTimeOfDay(from: workingText)
        if let timeStr = timeMatchedStr {
            workingText = workingText.replacingOccurrences(of: timeStr, with: " ", options: .caseInsensitive)
        }

        if lower.contains("today") || lower.contains("tonight") || lower.contains("this evening") {
            workingText = removeDatePrepositions(workingText, keyword: "today")
            workingText = removeDatePrepositions(workingText, keyword: "tonight")
            workingText = removeDatePrepositions(workingText, keyword: "this evening")
            let start = calendar.startOfDay(for: now)
            let hour = timeOfDay?.hour ?? (lower.contains("tonight") ? 20 : 17)
            let minute = timeOfDay?.minute ?? 0
            extractedDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)
        } else if lower.contains("tomorrow") || lower.contains("tmrw") {
            workingText = removeDatePrepositions(workingText, keyword: "tomorrow")
            workingText = removeDatePrepositions(workingText, keyword: "tmrw")
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                let hour = timeOfDay?.hour ?? 9
                let minute = timeOfDay?.minute ?? 0
                extractedDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow)
            }
        } else {
            let weekDays = [
                "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                "thursday": 5, "friday": 6, "saturday": 7
            ]

            var foundWeekday = false
            for (dayName, targetWeekday) in weekDays {
                if lower.contains(dayName) {
                    workingText = removeDatePrepositions(workingText, keyword: dayName)
                    var dateComponents = DateComponents()
                    dateComponents.weekday = targetWeekday
                    if let nextDate = calendar.nextDate(after: now, matching: dateComponents, matchingPolicy: .nextTime) {
                        let hour = timeOfDay?.hour ?? 17
                        let minute = timeOfDay?.minute ?? 0
                        extractedDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: nextDate)
                        foundWeekday = true
                        break
                    }
                }
            }

            if !foundWeekday {
                // Use NSDataDetector for calendar dates
                if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
                    let range = NSRange(location: 0, length: (text as NSString).length)
                    let matches = detector.matches(in: text, options: [], range: range)
                    for match in matches {
                        if let date = match.date {
                            let matchedStr = (text as NSString).substring(with: match.range)
                            workingText = workingText.replacingOccurrences(of: matchedStr, with: "")
                            extractedDate = date
                            break
                        }
                    }
                }
            }
        }

        // Clean extra whitespace
        workingText = workingText.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)

        return (extractedDate, workingText)
    }

    private func removeDatePrepositions(_ text: String, keyword: String) -> String {
        let pattern = "\\b(?:by\\s+|on\\s+|at\\s+|before\\s+|due\\s+|for\\s+|this\\s+|next\\s+)?\(NSRegularExpression.escapedPattern(for: keyword))\\b"
        return text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
    }

    private func extractTimeOfDay(from text: String) -> ((hour: Int, minute: Int)?, String?) {
        let pattern = "\\b(?:at\\s+|by\\s+)?([0-1]?[0-9]|2[0-3])(?::([0-5][0-9]))?\\s*(am|pm)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return (nil, nil) }
        let range = NSRange(location: 0, length: (text as NSString).length)

        if let match = regex.firstMatch(in: text, options: [], range: range) {
            let fullMatch = (text as NSString).substring(with: match.range)
            let hourStr = (text as NSString).substring(with: match.range(at: 1))
            var hour = Int(hourStr) ?? 9

            var minute = 0
            if match.range(at: 2).location != NSNotFound {
                let minStr = (text as NSString).substring(with: match.range(at: 2))
                minute = Int(minStr) ?? 0
            }

            if match.range(at: 3).location != NSNotFound {
                let ampm = (text as NSString).substring(with: match.range(at: 3)).lowercased()
                if ampm == "pm" && hour < 12 {
                    hour += 12
                } else if ampm == "am" && hour == 12 {
                    hour = 0
                }
            }
            return ((hour, minute), fullMatch)
        }
        return (nil, nil)
    }

    // MARK: - Priority Extraction

    private func extractPriority(from text: String) -> (Priority, String) {
        var clean = text
        let lower = text.lowercased()

        let highKeywords = ["urgent", "asap", "critical", "immediately", "high priority", "vital", "top priority"]
        for kw in highKeywords {
            if lower.contains(kw) {
                clean = clean.replacingOccurrences(of: "\\b\(kw)\\b", with: "", options: [.caseInsensitive, .regularExpression])
                return (.high, clean)
            }
        }

        let mediumKeywords = ["medium priority", "important", "needed"]
        for kw in mediumKeywords {
            if lower.contains(kw) {
                clean = clean.replacingOccurrences(of: "\\b\(kw)\\b", with: "", options: [.caseInsensitive, .regularExpression])
                return (.medium, clean)
            }
        }

        let lowKeywords = ["low priority", "optional", "when free", "eventually"]
        for kw in lowKeywords {
            if lower.contains(kw) {
                clean = clean.replacingOccurrences(of: "\\b\(kw)\\b", with: "", options: [.caseInsensitive, .regularExpression])
                return (.low, clean)
            }
        }

        return (.none, clean)
    }

    // MARK: - Tag Extraction

    private func extractTag(from text: String, availableTags: [TagItem]) -> (UUID?, String) {
        var clean = text
        let lower = text.lowercased()

        for tag in availableTags {
            let tagNameLower = tag.name.lowercased()
            if lower.contains(tagNameLower) {
                clean = clean.replacingOccurrences(of: "[\(tag.name)]", with: "", options: .caseInsensitive)
                clean = clean.replacingOccurrences(of: "\\bfor \(tagNameLower)\\b", with: "", options: .caseInsensitive)
                clean = clean.replacingOccurrences(of: "\\b\(tagNameLower):\\b", with: "", options: .caseInsensitive)
                return (tag.id, clean)
            }
        }

        let workKeywords = ["client", "meeting", "presentation", "report", "sprint", "code", "deploy", "boss", "colleague", "email", "proposal", "budget", "invoice"]
        let personalKeywords = ["grocery", "groceries", "home", "dentist", "doctor", "pharmacy", "workout", "gym", "coffee", "dinner", "family", "car"]
        let ideasKeywords = ["idea", "brainstorm", "concept", "explore", "research", "prototype"]

        for tag in availableTags {
            let name = tag.name.lowercased()
            if name == "work" && workKeywords.contains(where: { lower.contains($0) }) {
                return (tag.id, clean)
            } else if name == "personal" && personalKeywords.contains(where: { lower.contains($0) }) {
                return (tag.id, clean)
            } else if name == "ideas" && ideasKeywords.contains(where: { lower.contains($0) }) {
                return (tag.id, clean)
            }
        }

        return (nil, clean)
    }

    // MARK: - Title and Notes Extraction

    private func extractTitleAndNotes(from text: String) -> (String, String) {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        let fillerPrefixes = [
            "^i need to\\s+",
            "^we need to\\s+",
            "^need to\\s+",
            "^make sure to\\s+",
            "^don't forget to\\s+",
            "^dont forget to\\s+",
            "^remember to\\s+",
            "^i should\\s+",
            "^we should\\s+",
            "^have to\\s+",
            "^please\\s+",
            "^action item:?\\s*",
            "^todo:?\\s*",
            "^task:?\\s*"
        ]

        for pattern in fillerPrefixes {
            clean = clean.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }

        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-"))

        if let first = clean.first {
            clean = String(first).uppercased() + clean.dropFirst()
        }

        if clean.count > 75 {
            if let commaIndex = clean.firstIndex(of: ",") {
                let title = String(clean[..<commaIndex]).trimmingCharacters(in: .whitespaces)
                let notes = String(clean[clean.index(after: commaIndex)...]).trimmingCharacters(in: .whitespaces)
                return (title, notes)
            } else {
                return (clean, "")
            }
        }

        return (clean, "")
    }
}
