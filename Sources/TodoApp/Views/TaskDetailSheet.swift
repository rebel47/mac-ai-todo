import SwiftUI

struct TaskDetailSheet: View {
    @ObservedObject var store: TodoStore
    @Binding var task: TaskItem?
    var onDismiss: () -> Void

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var priority: Priority = .none
    @State private var tagId: UUID? = nil
    @State private var isCompleted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Task")
                    .font(.system(size: 15, weight: .semibold))

                Spacer()

                Button {
                    saveAndClose()
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task Title")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Title", text: $title)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14))
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes & Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $notes)
                            .font(.system(size: 13))
                            .frame(minHeight: 90)
                            .padding(4)
                            .background(Color(nsColor: .textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                    }

                    // Priority & Tag Row
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Priority")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("", selection: $priority) {
                                ForEach(Priority.allCases) { p in
                                    HStack {
                                        Image(systemName: p.iconName)
                                        Text(p.title)
                                    }
                                    .tag(p)
                                }
                            }
                            .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tag")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Picker("", selection: $tagId) {
                                Text("No Tag").tag(Optional<UUID>(nil))
                                ForEach(store.tags) { tag in
                                    Text(tag.name).tag(Optional<UUID>(tag.id))
                                }
                            }
                            .labelsHidden()
                        }
                    }

                    Divider()

                    // Due Date
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $hasDueDate) {
                            Text("Due Date")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .toggleStyle(.checkbox)

                        if hasDueDate {
                            DatePicker(
                                "Date",
                                selection: $dueDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                            .padding(8)
                            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    Divider()

                    // Status & Timestamps
                    HStack {
                        Toggle(isOn: $isCompleted) {
                            Text(isCompleted ? "Completed" : "Mark as completed")
                                .font(.system(size: 13))
                        }
                        .toggleStyle(.checkbox)

                        Spacer()

                        if let original = task {
                            Text("Created \(original.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Divider()

                    // Destructive Delete Button
                    HStack {
                        Spacer()
                        Button(role: .destructive) {
                            if let original = task {
                                store.deleteTask(id: original.id)
                            }
                            task = nil
                            onDismiss()
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                                .foregroundStyle(Color.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 440, height: 520)
        .onAppear {
            if let t = task {
                title = t.title
                notes = t.notes
                priority = t.priority
                tagId = t.tagId
                isCompleted = t.isCompleted
                if let d = t.dueDate {
                    hasDueDate = true
                    dueDate = d
                } else {
                    hasDueDate = false
                    dueDate = Date()
                }
            }
        }
    }

    private func saveAndClose() {
        guard var updated = task else {
            onDismiss()
            return
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.title = cleanTitle.isEmpty ? updated.title : cleanTitle
        updated.notes = notes
        updated.priority = priority
        updated.tagId = tagId
        updated.dueDate = hasDueDate ? dueDate : nil
        if updated.isCompleted != isCompleted {
            updated.isCompleted = isCompleted
            updated.completedAt = isCompleted ? Date() : nil
        }
        store.updateTask(updated)
        task = nil
        onDismiss()
    }
}
