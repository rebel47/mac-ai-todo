import SwiftUI

struct NewTaskBar: View {
    @ObservedObject var store: TodoStore
    @FocusState private var isFieldFocused: Bool

    @State private var taskTitle: String = ""
    @State private var selectedPriority: Priority = .none
    @State private var selectedTagId: UUID? = nil
    @State private var selectedDueDate: Date? = nil
    @State private var isShowingDatePicker: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)

                TextField("Add a task... (Press Return to add)", text: $taskTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isFieldFocused)
                    .onSubmit {
                        submitTask()
                    }

                // Quick Action Controls
                HStack(spacing: 6) {
                    // Due Date Button
                    Menu {
                        Button("No Date") { selectedDueDate = nil }
                        Button("Today") { selectedDueDate = Date() }
                        Button("Tomorrow") {
                            selectedDueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                        }
                        Button("Next Week") {
                            selectedDueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                            if let date = selectedDueDate {
                                Text(formatQuickDate(date))
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            selectedDueDate != nil ? Color.orange.opacity(0.12) : Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(selectedDueDate != nil ? Color.orange : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Set Due Date")

                    // Priority Selector
                    Menu {
                        ForEach(Priority.allCases) { priority in
                            Button {
                                selectedPriority = priority
                            } label: {
                                HStack {
                                    Text(priority.title)
                                    if selectedPriority == priority {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectedPriority.iconName)
                                .font(.system(size: 11))
                            if selectedPriority != .none {
                                Text(selectedPriority.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            selectedPriority != .none ? selectedPriority.color.opacity(0.12) : Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(selectedPriority != .none ? selectedPriority.color : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Set Priority")

                    // Tag Selector
                    Menu {
                        Button("No Tag") { selectedTagId = nil }
                        ForEach(store.tags) { tag in
                            Button {
                                selectedTagId = tag.id
                            } label: {
                                HStack {
                                    Text(tag.name)
                                    if selectedTagId == tag.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "tag")
                                .font(.system(size: 11))
                            if let tagId = selectedTagId, let tag = store.tag(for: tagId) {
                                Text(tag.name)
                                    .font(.system(size: 11, weight: .medium))
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            selectedTagId != nil ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(selectedTagId != nil ? Color.accentColor : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Set Tag")

                    // Submit button
                    if !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button {
                            submitTask()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isFieldFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .onAppear {
            presetBasedOnCurrentFilter()
        }
        .onChange(of: store.selectedFilter) {
            presetBasedOnCurrentFilter()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNewTaskField)) { _ in
            isFieldFocused = true
        }
    }

    private func presetBasedOnCurrentFilter() {
        switch store.selectedFilter {
        case .today:
            selectedDueDate = Date()
            selectedTagId = nil
        case .upcoming:
            selectedDueDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            selectedTagId = nil
        case .highPriority:
            selectedPriority = .high
            selectedTagId = nil
        case .tag(let id):
            selectedTagId = id
            selectedDueDate = nil
        default:
            selectedDueDate = nil
            selectedPriority = .none
            selectedTagId = nil
        }
    }

    private func submitTask() {
        let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        store.addTask(
            title: trimmed,
            notes: "",
            dueDate: selectedDueDate,
            priority: selectedPriority,
            tagId: selectedTagId
        )

        taskTitle = ""
        presetBasedOnCurrentFilter()
        isFieldFocused = true
    }

    private func formatQuickDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            return df.string(from: date)
        }
    }
}

extension Notification.Name {
    static let focusNewTaskField = Notification.Name("focusNewTaskField")
}
