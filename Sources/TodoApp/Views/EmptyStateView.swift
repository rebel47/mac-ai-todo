import SwiftUI

struct EmptyStateView: View {
    let filter: NavigationFilter
    let searchQuery: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: iconName)
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(iconColor)
                .padding(.bottom, 4)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            if searchQuery.isEmpty {
                Button {
                    NotificationCenter.default.post(name: .focusNewTaskField, object: nil)
                } label: {
                    Label("Add Task", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var iconName: String {
        if !searchQuery.isEmpty {
            return "magnifyingglass"
        }
        switch filter {
        case .today:
            return "sun.max"
        case .upcoming:
            return "calendar.badge.clock"
        case .all:
            return "checklist"
        case .highPriority:
            return "sparkles"
        case .completed:
            return "checkmark.circle"
        case .tag:
            return "tag"
        }
    }

    private var iconColor: Color {
        if !searchQuery.isEmpty {
            return .secondary
        }
        switch filter {
        case .today:
            return .orange
        case .upcoming:
            return .indigo
        case .all:
            return .blue
        case .highPriority:
            return .yellow
        case .completed:
            return .green
        case .tag:
            return .pastelLavender
        }
    }

    private var title: String {
        if !searchQuery.isEmpty {
            return "No Results Found"
        }
        switch filter {
        case .today:
            return "All Done for Today!"
        case .upcoming:
            return "No Upcoming Tasks"
        case .all:
            return "No Tasks Yet"
        case .highPriority:
            return "Clear Skies"
        case .completed:
            return "No Completed Tasks"
        case .tag:
            return "Empty Tag"
        }
    }

    private var subtitle: String {
        if !searchQuery.isEmpty {
            return "No tasks matched your search query \"\(searchQuery)\"."
        }
        switch filter {
        case .today:
            return "You have no pending tasks for today. Relax or get a head start on tomorrow."
        case .upcoming:
            return "Schedule tasks for the future to keep your goals organized."
        case .all:
            return "Your todo list is currently empty. Add your first task to get started."
        case .highPriority:
            return "No urgent items requiring immediate attention."
        case .completed:
            return "Tasks you check off will appear here for your reference."
        case .tag:
            return "There are no tasks assigned to this tag."
        }
    }
}
