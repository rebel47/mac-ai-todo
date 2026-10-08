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
        #expect(todayTask.formattedDueDate == "Today")
        #expect(tomorrowTask.formattedDueDate == "Tomorrow")
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

    @Test("AI Task Parser extracts dates when provided and leaves nil when missing or unclear")
    func testAITaskParserDates() {
        let tags = TagItem.defaultTags
        let parser = AITaskParser.shared

        // Test with explicit timing
        let textWithDate = "Finalize the quarterly presentation by tomorrow at 3pm urgent"
        let tasksWithDate = parser.parseTasks(from: textWithDate, availableTags: tags)
        #expect(tasksWithDate.count == 1)
        #expect(tasksWithDate.first?.dueDate != nil)
        #expect(tasksWithDate.first?.priority == .high)

        // Test WITHOUT timing - should leave dueDate strictly nil
        let textWithoutDate = "Buy milk and bread from the grocery store"
        let tasksWithoutDate = parser.parseTasks(from: textWithoutDate, availableTags: tags)
        #expect(tasksWithoutDate.count >= 1)
        #expect(tasksWithoutDate.first?.dueDate == nil)
        #expect(tasksWithoutDate.first?.priority == .none)
    }

    @Test("AI Task Parser extracts multiple tasks from paragraphs or meeting notes")
    func testAITaskParserMultipleTasks() {
        let tags = TagItem.defaultTags
        let parser = AITaskParser.shared

        let meetingSummary = """
        1. Review landing page mockups by tomorrow
        2. Fix database query latency (urgent)
        3. Brainstorm new app features when possible
        """

        let tasks = parser.parseTasks(from: meetingSummary, availableTags: tags)
        #expect(tasks.count == 3)
        #expect(tasks[0].dueDate != nil)
        #expect(tasks[1].priority == .high)
        #expect(tasks[2].dueDate == nil) // Unclear/missing date -> left empty
    }
}
