import Foundation
import NaturalLanguage

enum AIProvider: String, CaseIterable, Identifiable {
    case onDevice = "On-Device (Apple Intelligence / Free)"
    case openAI = "OpenAI (GPT-4o-mini)"
    case gemini = "Google Gemini (1.5 Flash)"
    case ollama = "Local Ollama"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .onDevice: return "On-Device (Free)"
        case .openAI: return "OpenAI"
        case .gemini: return "Gemini"
        case .ollama: return "Ollama"
        }
    }
}

struct ParsedTaskItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var dueDate: Date? = nil
    var priority: Priority = .none
    var tagId: UUID? = nil
    var isSelected: Bool = true
}

class AITaskParser {

    static let shared = AITaskParser()

    // MARK: - Async Parse (Supports On-Device or Cloud/Local LLMs)

    func parseTasksAsync(
        from text: String,
        availableTags: [TagItem],
        provider: AIProvider = .onDevice,
        apiKey: String = "",
        ollamaEndpoint: String = "http://localhost:11434"
    ) async -> [ParsedTaskItem] {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        switch provider {
        case .openAI:
            if !trimmedKey.isEmpty {
                if let tasks = await callOpenAI(text: text, apiKey: trimmedKey, availableTags: availableTags) {
                    return tasks
                }
            }
        case .gemini:
            if !trimmedKey.isEmpty {
                if let tasks = await callGemini(text: text, apiKey: trimmedKey, availableTags: availableTags) {
                    return tasks
                }
            }
        case .ollama:
            if let tasks = await callOllama(text: text, endpoint: ollamaEndpoint, availableTags: availableTags) {
                return tasks
            }
        case .onDevice:
            break
        }

        // Default or Fallback: Built-in On-Device NLP
        return parseTasks(from: text, availableTags: availableTags)
    }

    // MARK: - Cloud LLM Calls

    private func callOpenAI(text: String, apiKey: String, availableTags: [TagItem]) async -> [ParsedTaskItem]? {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }

        let systemPrompt = makeSystemPrompt(availableTags: availableTags)
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.2
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return parseLLMJSONResponse(content, availableTags: availableTags)
            }
        } catch {
            print("OpenAI call failed, falling back to on-device: \(error)")
        }

        return nil
    }

    private func callGemini(text: String, apiKey: String, availableTags: [TagItem]) async -> [ParsedTaskItem]? {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)") else { return nil }

        let systemPrompt = makeSystemPrompt(availableTags: availableTags)
        let promptText = "\(systemPrompt)\n\nUser Input:\n\(text)"

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json"
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let first = candidates.first,
               let content = first["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let textResponse = firstPart["text"] as? String {
                return parseLLMJSONResponse(textResponse, availableTags: availableTags)
            }
        } catch {
            print("Gemini call failed, falling back to on-device: \(error)")
        }

        return nil
    }

    private func callOllama(text: String, endpoint: String, availableTags: [TagItem]) async -> [ParsedTaskItem]? {
        let cleanEndpoint = endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(cleanEndpoint)/api/generate") else { return nil }

        let systemPrompt = makeSystemPrompt(availableTags: availableTags)
        let prompt = "\(systemPrompt)\n\nUser Input:\n\(text)"

        let body: [String: Any] = [
            "model": "llama3.2",
            "prompt": prompt,
            "format": "json",
            "stream": false
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseStr = json["response"] as? String {
                return parseLLMJSONResponse(responseStr, availableTags: availableTags)
            }
        } catch {
            print("Ollama call failed, falling back to on-device: \(error)")
        }

        return nil
    }

    private func makeSystemPrompt(availableTags: [TagItem]) -> String {
        let tagNames = availableTags.map { $0.name }.joined(separator: ", ")
        let todayStr = ISO8601DateFormatter().string(from: Date())

        return """
        You are a task extractor for a macOS Todo application. Today is \(todayStr).
        Analyze the user's input text (or transcript) and extract actionable todo tasks into a JSON object with a "tasks" array.
        Each task must have:
        - "title": Concise, imperative action title (e.g. "Prepare presentation slides")
        - "notes": Secondary context or description (empty string if none)
        - "dueDate": ISO-8601 formatted string if a date or time is explicitly mentioned (e.g. "2026-10-09T15:00:00Z"). CRITICAL: If no date/timing information is provided or if unclear, dueDate MUST BE null.
        - "priority": One of "High", "Medium", "Low", "None". Set "High" only for urgent/critical items.
        - "tag": One of [\(tagNames)] if relevant, otherwise null.

        Output only valid JSON:
        {"tasks": [{"title": "...", "notes": "...", "dueDate": null, "priority": "None", "tag": null}]}
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

    // MARK: - On-Device NLP & Heuristic Extraction (Zero API Key, 100% Private)

    func parseTasks(from text: String, availableTags: [TagItem]) -> [ParsedTaskItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Step 1: Split into distinct candidate task segments
        let segments = extractCandidateSegments(from: trimmed)

        // Step 2: Parse each segment into a structured task
        var tasks: [ParsedTaskItem] = []
        for segment in segments {
            if let task = parseIndividualSegment(segment, availableTags: availableTags) {
                tasks.append(task)
            }
        }

        // If no tasks could be parsed via segmented breakdown, attempt whole-text single task
        if tasks.isEmpty {
            if let single = parseIndividualSegment(trimmed, availableTags: availableTags) {
                tasks.append(single)
            }
        }

        return tasks
    }

    // MARK: - Segmentation

    private func extractCandidateSegments(from text: String) -> [String] {
        var results: [String] = []

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lineTrimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lineTrimmed.isEmpty else { continue }

            let cleanedLine = lineTrimmed
                .replacingOccurrences(of: "^([0-9]+[\\.\\)]|[-*•])\\s+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            let subSentences = splitCompoundSentences(cleanedLine)
            for sub in subSentences {
                let trimmedSub = sub.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedSub.count >= 3 {
                    results.append(trimmedSub)
                }
            }
        }

        return results
    }

    private func splitCompoundSentences(_ line: String) -> [String] {
        let pattern = "(;|\\.\\s+(?=[A-Z])|\\b(?:also|and then)\\s+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let parts = line.components(separatedBy: regex)
            if parts.count > 1 {
                return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            }
        }
        return [line]
    }

    // MARK: - Segment Parsing

    private func parseIndividualSegment(_ rawText: String, availableTags: [TagItem]) -> ParsedTaskItem? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > 2 else { return nil }

        // 1. Extract Due Date (or nil if missing/unclear)
        let (extractedDate, textWithoutDate) = extractDueDate(from: text)

        // 2. Extract Priority (or .none if not specified)
        let (priority, textWithoutPriority) = extractPriority(from: textWithoutDate)

        // 3. Extract Tag (or nil if unclear)
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

    // MARK: - Date Extraction

    private func extractDueDate(from text: String) -> (Date?, String) {
        let calendar = Calendar.current
        let now = Date()
        let lower = text.lowercased()

        // Check explicit natural keywords first
        if lower.contains("today") || lower.contains("tonight") || lower.contains("this evening") {
            let cleaned = removePhrase(text, matches: ["today", "tonight", "this evening"])
            let targetDate = calendar.startOfDay(for: now)
            let time = extractTimeOfDay(from: text) ?? (17, 0)
            let finalDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate)
            return (finalDate, cleaned)
        }

        if lower.contains("tomorrow") {
            let cleaned = removePhrase(text, matches: ["tomorrow", "tmrw"])
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                let time = extractTimeOfDay(from: text) ?? (9, 0)
                let finalDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: tomorrow)
                return (finalDate, cleaned)
            }
        }

        let weekDays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]

        for (dayName, targetWeekday) in weekDays {
            if lower.contains(dayName) {
                let cleaned = removePhrase(text, matches: ["by \(dayName)", "on \(dayName)", "this \(dayName)", "next \(dayName)", dayName])
                var dateComponents = DateComponents()
                dateComponents.weekday = targetWeekday
                if let nextDate = calendar.nextDate(after: now, matching: dateComponents, matchingPolicy: .nextTime) {
                    let time = extractTimeOfDay(from: text) ?? (17, 0)
                    let finalDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: nextDate)
                    return (finalDate, cleaned)
                }
            }
        }

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(location: 0, length: (text as NSString).length)
            let matches = detector.matches(in: text, options: [], range: range)

            for match in matches {
                if let date = match.date {
                    let matchedString = (text as NSString).substring(with: match.range)
                    let cleaned = text.replacingOccurrences(of: matchedString, with: "")
                    return (date, cleaned)
                }
            }
        }

        // Leave empty if timing information is missing or unclear
        return (nil, text)
    }

    private func extractTimeOfDay(from text: String) -> (hour: Int, minute: Int)? {
        let pattern = "\\b(?:at\\s+)?([0-1]?[0-9]|2[0-3])(?::([0-5][0-9]))?\\s*(am|pm)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(location: 0, length: (text as NSString).length)

        if let match = regex.firstMatch(in: text, options: [], range: range) {
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
            return (hour, minute)
        }
        return nil
    }

    // MARK: - Priority Extraction

    private func extractPriority(from text: String) -> (Priority, String) {
        let lower = text.lowercased()

        let highKeywords = ["urgent", "asap", "critical", "immediately", "high priority", "vital", "top priority"]
        for kw in highKeywords {
            if lower.contains(kw) {
                return (.high, removePhrase(text, matches: [kw]))
            }
        }

        let mediumKeywords = ["medium priority", "important", "soon", "needed"]
        for kw in mediumKeywords {
            if lower.contains(kw) {
                return (.medium, removePhrase(text, matches: [kw]))
            }
        }

        let lowKeywords = ["low priority", "optional", "when possible", "eventually"]
        for kw in lowKeywords {
            if lower.contains(kw) {
                return (.low, removePhrase(text, matches: [kw]))
            }
        }

        return (.none, text)
    }

    // MARK: - Tag Extraction

    private func extractTag(from text: String, availableTags: [TagItem]) -> (UUID?, String) {
        let lower = text.lowercased()

        for tag in availableTags {
            let tagNameLower = tag.name.lowercased()
            if lower.contains(tagNameLower) {
                let cleaned = removePhrase(text, matches: [
                    "[\(tag.name)]", "(for \(tagNameLower))", "for \(tagNameLower)", "\(tagNameLower):", tagNameLower
                ])
                return (tag.id, cleaned)
            }
        }

        let workKeywords = ["client", "meeting", "presentation", "report", "sprint", "code", "deploy", "boss", "colleague", "email", "proposal", "budget", "invoice", "q3", "q4"]
        let personalKeywords = ["grocery", "groceries", "home", "dentist", "doctor", "pharmacy", "workout", "gym", "coffee", "dinner", "family", "car", "clean apartment"]
        let ideasKeywords = ["idea", "brainstorm", "concept", "explore", "research", "prototype"]

        for tag in availableTags {
            let name = tag.name.lowercased()
            if name == "work" && workKeywords.contains(where: { lower.contains($0) }) {
                return (tag.id, text)
            } else if name == "personal" && personalKeywords.contains(where: { lower.contains($0) }) {
                return (tag.id, text)
            } else if name == "ideas" && ideasKeywords.contains(where: { lower.contains($0) }) {
                return (tag.id, text)
            }
        }

        return (nil, text)
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

    private func removePhrase(_ text: String, matches: [String]) -> String {
        var result = text
        for m in matches {
            result = result.replacingOccurrences(of: "\\b\(NSRegularExpression.escapedPattern(for: m))\\b", with: "", options: [.regularExpression, .caseInsensitive])
        }
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespaces)
    }
}

private extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        let range = NSRange(location: 0, length: (self as NSString).length)
        let matches = regex.matches(in: self, options: [], range: range)
        var results: [String] = []
        var lastIndex = 0

        for match in matches {
            let part = (self as NSString).substring(with: NSRange(location: lastIndex, length: match.range.location - lastIndex))
            results.append(part)
            lastIndex = match.range.location + match.range.length
        }
        if lastIndex < (self as NSString).length {
            let part = (self as NSString).substring(with: NSRange(location: lastIndex, length: (self as NSString).length - lastIndex))
            results.append(part)
        }
        return results
    }
}
