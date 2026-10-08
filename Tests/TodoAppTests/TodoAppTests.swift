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
}
