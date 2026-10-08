import SwiftUI

enum NavigationFilter: Hashable, Identifiable {
    case all
    case today
    case upcoming
    case highPriority
    case completed
    case tag(UUID)

    var id: String {
        switch self {
        case .all: return "all"
        case .today: return "today"
        case .upcoming: return "upcoming"
        case .highPriority: return "highPriority"
        case .completed: return "completed"
        case .tag(let id): return "tag-\(id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .all: return "All Tasks"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .highPriority: return "High Priority"
        case .completed: return "Completed"
        case .tag: return "Tag"
        }
    }

    var iconName: String {
        switch self {
        case .all: return "tray"
        case .today: return "sun.max"
        case .upcoming: return "calendar"
        case .highPriority: return "exclamationmark.circle"
        case .completed: return "checkmark.circle"
        case .tag: return "tag"
        }
    }

    var iconColor: Color {
        switch self {
        case .all: return .blue
        case .today: return .orange
        case .upcoming: return .indigo
        case .highPriority: return .red
        case .completed: return .green
        case .tag: return .secondary
        }
    }
}
