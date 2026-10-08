import SwiftUI

struct TaskRowView: View {
    @ObservedObject var store: TodoStore
    let task: TaskItem
    var onEdit: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button {
                store.toggleTask(id: task.id)
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(
                            task.isCompleted ? Color.accentColor :
                                (task.priority == .high ? Color.red.opacity(0.7) : Color.primary.opacity(0.25)),
                            lineWidth: 1.5
                        )
                        .background(
                            Circle()
                                .fill(task.isCompleted ? Color.accentColor : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
                        )
                        .frame(width: 18, height: 18)

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            // Content
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .center, spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 14, weight: task.isCompleted ? .regular : .medium))
                        .strikethrough(task.isCompleted, color: .secondary.opacity(0.6))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .animation(.easeInOut(duration: 0.15), value: task.isCompleted)

                    Spacer()

                    // Hover Actions
                    if isHovered {
                        HStack(spacing: 6) {
                            Button {
                                onEdit()
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, height: 22)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .help("Edit task")

                            Button {
                                store.deleteTask(id: task.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.red.opacity(0.85))
                                    .frame(width: 22, height: 22)
                                    .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                            .help("Delete task")
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                    }
                }

                // Notes preview
                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Metadata Badges (Due Date, Tag, Priority)
                if hasMetadata {
                    HStack(spacing: 6) {
                        // Due date badge
                        if task.dueDate != nil {
                            HStack(spacing: 4) {
                                Image(systemName: task.isOverdue ? "exclamationmark.circle.fill" : "calendar")
                                    .font(.system(size: 9))
                                Text(task.formattedDueDate)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                task.isOverdue ? Color.red.opacity(0.12) :
                                    (task.isToday ? Color.orange.opacity(0.12) : Color.primary.opacity(0.06)),
                                in: Capsule()
                            )
                            .foregroundStyle(
                                task.isOverdue ? Color.red :
                                    (task.isToday ? Color.orange : Color.secondary)
                            )
                        }

                        // Tag badge
                        if let tag = store.tag(for: task.tagId) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 6, height: 6)
                                Text(tag.name)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag.color.opacity(0.12), in: Capsule())
                            .foregroundStyle(tag.color)
                        }

                        // Priority badge
                        if task.priority != .none {
                            HStack(spacing: 3) {
                                Image(systemName: task.priority.iconName)
                                    .font(.system(size: 9))
                                Text(task.priority.rawValue)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(task.priority.color.opacity(0.12), in: Capsule())
                            .foregroundStyle(task.priority.color)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.primary.opacity(0.035) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button {
                store.toggleTask(id: task.id)
            } label: {
                Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                      systemImage: task.isCompleted ? "circle" : "checkmark.circle")
            }

            Divider()

            Menu("Priority") {
                ForEach(Priority.allCases) { priority in
                    Button {
                        var updated = task
                        updated.priority = priority
                        store.updateTask(updated)
                    } label: {
                        HStack {
                            Text(priority.rawValue)
                            if task.priority == priority {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Menu("Tag") {
                Button("None") {
                    var updated = task
                    updated.tagId = nil
                    store.updateTask(updated)
                }
                ForEach(store.tags) { tag in
                    Button(tag.name) {
                        var updated = task
                        updated.tagId = tag.id
                        store.updateTask(updated)
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                store.deleteTask(id: task.id)
            } label: {
                Label("Delete Task", systemImage: "trash")
            }
        }
    }

    private var hasMetadata: Bool {
        task.dueDate != nil || task.tagId != nil || task.priority != .none
    }
}
