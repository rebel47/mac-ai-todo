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

class AITaskParser {

    static let shared = AITaskParser()

    // MARK: - Main Extraction Entry Point

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

        // Split by newlines first
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let lineTrimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lineTrimmed.isEmpty else { continue }

            // Strip bullet points or numbering (e.g., "1. ", "- ", "* ", "• ")
            let cleanedLine = lineTrimmed
                .replacingOccurrences(of: "^([0-9]+[\\.\\)]|[-*•])\\s+", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)

            // If a line contains multiple sentences or conjunctions like "and also", "then"
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
        // Look for strong separators like semicolons, "also,", "and then,"
        let pattern = "(;|\\.\\s+(?=[A-Z])|\\b(?:also|and then)\\s+)"
        let parts = line.components(separatedBy: try! NSRegularExpression(pattern: pattern, options: .caseInsensitive))
        if parts.count > 1 {
            return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
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
            let time = extractTimeOfDay(from: text) ?? (17, 0) // default 5pm if unspecified
            let finalDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate)
            return (finalDate, cleaned)
        }

        if lower.contains("tomorrow") {
            let cleaned = removePhrase(text, matches: ["tomorrow", "tmrw"])
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
                let time = extractTimeOfDay(from: text) ?? (9, 0) // default 9am
                let finalDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: tomorrow)
                return (finalDate, cleaned)
            }
        }

        // Relative days of week (e.g. "by friday", "on monday", "next tuesday")
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

        // Use NSDataDetector for standard dates (e.g. "Oct 15", "October 20th", "12/25/2026")
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

        // If no timing/date information is found or unclear, leave empty as requested!
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

        // 1. Check exact tag names
        for tag in availableTags {
            let tagNameLower = tag.name.lowercased()
            if lower.contains(tagNameLower) {
                let cleaned = removePhrase(text, matches: [
                    "[\(tag.name)]", "(for \(tagNameLower))", "for \(tagNameLower)", "\(tagNameLower):", tagNameLower
                ])
                return (tag.id, cleaned)
            }
        }

        // 2. Keyword heuristic matching to default tag types
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

        // Leave empty if missing or unclear
        return (nil, text)
    }

    // MARK: - Title and Notes Extraction

    private func extractTitleAndNotes(from text: String) -> (String, String) {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common imperative filler prefixes
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

        // Clean trailing punctuation and spaces
        clean = clean.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:-"))

        // Capitalize first letter
        if let first = clean.first {
            clean = String(first).uppercased() + clean.dropFirst()
        }

        // If title is excessively long (> 75 chars), split into title and notes
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
        // Clean multiple spaces
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
