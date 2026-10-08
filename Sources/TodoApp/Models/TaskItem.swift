import Foundation

struct TaskItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var notes: String = ""
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var createdAt: Date = Date()
    var dueDate: Date? = nil
    var priority: Priority = .none
    var tagId: UUID? = nil

    var isOverdue: Bool {
        guard let dueDate = dueDate, !isCompleted else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var isToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isUpcoming: Bool {
        guard let dueDate = dueDate else { return false }
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return dueDate >= startOfTomorrow
    }

    var formattedDueDate: String {
        guard let dueDate = dueDate else { return "" }
        let calendar = Calendar.current

        let dayPart: String
        if calendar.isDateInToday(dueDate) {
            dayPart = "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            dayPart = "Tomorrow"
        } else if calendar.isDateInYesterday(dueDate) {
            dayPart = "Yesterday"
        } else {
            let formatter = DateFormatter()
            if calendar.isDate(dueDate, equalTo: Date(), toGranularity: .year) {
                formatter.dateFormat = "MMM d"
            } else {
                formatter.dateFormat = "MMM d, yyyy"
            }
            dayPart = formatter.string(from: dueDate)
        }

        // Surface the deadline time whenever one was captured
        let hasTime = calendar.component(.hour, from: dueDate) != 0
            || calendar.component(.minute, from: dueDate) != 0
        guard hasTime else { return dayPart }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        return "\(dayPart), \(timeFormatter.string(from: dueDate))"
    }
}
