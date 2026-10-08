import Testing
import Foundation
@testable import TodoApp

@Suite("TodoApp Core Tests")
struct TodoAppCoreTests {

    @Test("Task creation initializes with default properties")
    func testTaskCreation() {
        let task = TaskItem(title: "Complete presentation")
        #expect(task.title == "Complete presentation")
        #expect(task.isCompleted == false)
        #expect(task.completedAt == nil)
        #expect(task.priority == .none)
    }

    @Test("Due date helpers correctly identify Today and Upcoming")
    func testDueDateHelpers() {
        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let todayTask = TaskItem(title: "Today task", dueDate: today)
        let tomorrowTask = TaskItem(title: "Tomorrow task", dueDate: tomorrow)
        let yesterdayTask = TaskItem(title: "Overdue task", dueDate: yesterday)

        #expect(todayTask.isToday == true)
        #expect(tomorrowTask.isUpcoming == true)
        #expect(yesterdayTask.isOverdue == true)
        #expect(todayTask.formattedDueDate.hasPrefix("Today"))
        #expect(tomorrowTask.formattedDueDate.hasPrefix("Tomorrow"))
    }

    @Test("Deadline times are surfaced while pure dates stay clean")
    func testFormattedDueDateIncludesTime() {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        let atThreePM = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: midnight)!

        let pureDate = TaskItem(title: "Pure date", dueDate: midnight)
        let deadline = TaskItem(title: "Deadline", dueDate: atThreePM)

        #expect(pureDate.formattedDueDate == "Today")
        #expect(deadline.formattedDueDate.hasPrefix("Today, "))
    }

    @Test("Priority ordering behaves hierarchically")
    func testPriorityOrdering() {
        #expect(Priority.high.order > Priority.medium.order)
        #expect(Priority.medium.order > Priority.low.order)
        #expect(Priority.low.order > Priority.none.order)
    }

    @Test("TodoStore mutations add, toggle, and delete tasks")
    @MainActor
    func testStoreMutations() {
        let store = TodoStore()
        let initialCount = store.tasks.count

        let task = store.addTask(title: "Write documentation", priority: .high)
        #expect(store.tasks.count == initialCount + 1)
        #expect(store.tasks.first?.title == "Write documentation")

        store.toggleTask(id: task.id)
        #expect(store.tasks.first?.isCompleted == true)
        #expect(store.tasks.first?.completedAt != nil)

        store.deleteTask(id: task.id)
        #expect(store.tasks.count == initialCount)
    }

    @Test("Extraction is skipped when no OpenAI API key is configured")
    func testNoAPIKeySkipsExtraction() async {
        let tags = TagItem.defaultTags
        let result = await AITaskParser.shared.extractTasks(
            from: "Finalize the quarterly presentation by tomorrow at 3pm urgent",
            apiKey: "",
            availableTags: tags
        )

        #expect(result.tasks.isEmpty)
        #expect(result.errorDescription == nil)
    }

    @Test("Extraction is skipped for whitespace-only API keys")
    func testWhitespaceAPIKeySkipsExtraction() async {
        let result = await AITaskParser.shared.extractTasks(
            from: "Buy milk from the grocery store",
            apiKey: "   \n  ",
            availableTags: TagItem.defaultTags
        )

        #expect(result.tasks.isEmpty)
        #expect(result.errorDescription == nil)
    }

    @Test("LLM response parsing decodes dates, priorities and tags")
    func testLLMResponseParsing() {
        let tags = TagItem.defaultTags
        let workTagId = tags.first { $0.name == "Work" }?.id

        let json = """
        {"tasks": [
            {"title": "Finalize the quarterly presentation", "notes": "Slide deck v3",
             "dueDate": "2026-10-09T15:00:00Z", "priority": "High", "tag": "Work"},
            {"title": "Brainstorm new app features", "notes": "",
             "dueDate": null, "priority": "None", "tag": null}
        ]}
        """

        let tasks = AITaskParser.shared.parseLLMJSONResponse(json, availableTags: tags)
        #expect(tasks?.count == 2)
        #expect(tasks?.first?.title == "Finalize the quarterly presentation")
        #expect(tasks?.first?.notes == "Slide deck v3")
        #expect(tasks?.first?.dueDate != nil)
        #expect(tasks?.first?.priority == .high)
        #expect(tasks?.first?.tagId == workTagId)
        #expect(tasks?.last?.dueDate == nil) // Unclear/missing date -> left empty
        #expect(tasks?.last?.priority == Priority.none)
        #expect(tasks?.last?.tagId == nil)
    }

    @Test("LLM response parsing leaves dueDate nil when missing and rejects invalid JSON")
    func testLLMResponseParsingEdgeCases() {
        let tags = TagItem.defaultTags

        let noDateJSON = """
        {"tasks": [{"title": "Buy milk from the grocery store", "notes": "",
                    "dueDate": null, "priority": "None", "tag": null}]}
        """
        let tasks = AITaskParser.shared.parseLLMJSONResponse(noDateJSON, availableTags: tags)
        #expect(tasks?.count == 1)
        #expect(tasks?.first?.dueDate == nil)
        #expect(tasks?.first?.priority == Priority.none)

        #expect(AITaskParser.shared.parseLLMJSONResponse("not json at all", availableTags: tags) == nil)
        #expect(AITaskParser.shared.parseLLMJSONResponse("{}", availableTags: tags) == nil)
        #expect(AITaskParser.shared.parseLLMJSONResponse(#"{"tasks": []}"#, availableTags: tags) == nil)
    }
}
