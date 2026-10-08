import Foundation

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

final class AITaskParser: Sendable {

    static let shared = AITaskParser()

    // MARK: - Configuration (single OpenAI model, no fallback chain)

    private static let openAIModelId = "gpt-5.4-mini-2026-03-17"
    private static let openAIModelDisplayName = "GPT-5.4 Mini"
    private static let endpoint = "https://api.openai.com/v1/chat/completions"

    // MARK: - Smart Extraction (OpenAI only)

    func extractTasks(
        from text: String,
        apiKey: String,
        availableTags: [TagItem]
    ) async -> AIExtractionResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        // No API key: return no tasks so the caller adds the raw input as a plain task.
        guard !trimmedKey.isEmpty else {
            return AIExtractionResult(tasks: [], engineName: "", errorDescription: nil)
        }

        let (tasks, error) = await callOpenAI(
            text: text,
            apiKey: trimmedKey,
            availableTags: availableTags
        )

        if let tasks = tasks, !tasks.isEmpty {
            return AIExtractionResult(
                tasks: tasks,
                engineName: Self.openAIModelDisplayName,
                errorDescription: nil
            )
        }

        return AIExtractionResult(
            tasks: [],
            engineName: Self.openAIModelDisplayName,
            errorDescription: error
        )
    }

    // MARK: - OpenAI API Call

    private func callOpenAI(
        text: String,
        apiKey: String,
        availableTags: [TagItem]
    ) async -> ([ParsedTaskItem]?, String?) {
        guard let url = URL(string: Self.endpoint) else {
            return (nil, "Invalid OpenAI endpoint URL")
        }

        let systemPrompt = makeSystemPrompt(availableTags: availableTags)

        let body: [String: Any] = [
            "model": Self.openAIModelId,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "response_format": ["type": "json_object"]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            return (nil, "JSON serialization error")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (nil, "No HTTP response")
            }

            guard httpResponse.statusCode == 200 else {
                let message = Self.apiErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
                return (nil, "OpenAI: \(message)")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String,
                  let tasks = parseLLMJSONResponse(content, availableTags: availableTags) else {
                return (nil, "OpenAI returned an unreadable response")
            }

            return (tasks, nil)
        } catch {
            return (nil, "Network error: \(error.localizedDescription)")
        }
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    private func makeSystemPrompt(availableTags: [TagItem]) -> String {
        let tagNames = availableTags.map { $0.name }.joined(separator: ", ")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm ZZZZ"
        let nowString = formatter.string(from: Date())

        return """
        You are a smart, accurate task extraction engine for a macOS Todo application. Current date and time (with timezone offset) is \(nowString). Use it to resolve every relative expression.
        Analyze the user's input text (or transcript or meeting notes) and extract distinct actionable to-do tasks into a JSON object with a "tasks" array.

        Strict Rules:
        1. "title": Clean, concise, imperative task title (e.g. "Review Q3 budget deck", "Email Sarah about mockups"). NEVER duplicate dates, times or deadlines in the title — they belong in dueDate.
        2. "notes": Any additional context, description, or secondary notes (empty string "" if none).
        3. "dueDate" — the task's DEADLINE. Capture ANY timing information the user gives, in any form:
           - explicit dates: "Oct 15", "15/10", "2026-11-03"
           - weekdays: "by Friday", "before Wednesday", "next monday"
           - relative: "today", "tonight", "tomorrow", "tmrw", "in 3 days", "in 2 hours", "next week", "next month", "end of the week"
           - clock times: "at 3pm", "at 09:30", "3 o'clock", "by 5pm", "before noon". If only a time is given, combine it with today's date (or the nearest mentioned day).
           - deadline wording: "deadline Friday", "due tomorrow", "by EOD", "by end of day", "before the 15th", "ship by launch"
           Format: ISO-8601 in UTC with a "Z" suffix (e.g. "2026-10-09T15:00:00Z"). Convert from the current local time shown above.
           IMPORTANT: If the input contains NO timing information at all, or the timing is genuinely unclear, "dueDate" MUST be null. Never invent a deadline.
        4. "priority": One of "High", "Medium", "Low", "None". Set "High" only for urgent/critical/asap items or hard deadlines that are today/tomorrow, "Medium" for clearly important ones, otherwise "None".
        5. "tag": One of [\(tagNames)] if relevant, otherwise null. Match by meaning (e.g. "groceries" → Personal, "sprint" → Work).

        Output ONLY valid JSON:
        {"tasks": [{"title": "...", "notes": "", "dueDate": null, "priority": "None", "tag": null}]}
        """
    }

    func parseLLMJSONResponse(_ jsonString: String, availableTags: [TagItem]) -> [ParsedTaskItem]? {
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let taskList = root["tasks"] as? [[String: Any]] else {
            return nil
        }

        var results: [ParsedTaskItem] = []
        let isoFormatter = ISO8601DateFormatter()
        let isoFormatterFractional = ISO8601DateFormatter()
        isoFormatterFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for dict in taskList {
            guard let title = dict["title"] as? String, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }

            let notes = dict["notes"] as? String ?? ""

            var dueDate: Date? = nil
            if let dateStr = dict["dueDate"] as? String {
                dueDate = isoFormatter.date(from: dateStr) ?? isoFormatterFractional.date(from: dateStr)
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
}
