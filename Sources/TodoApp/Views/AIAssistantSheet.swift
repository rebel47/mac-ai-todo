import SwiftUI

enum AIInputMode: String, CaseIterable, Identifiable {
    case speech = "Voice Dictation"
    case text = "Type or Paste"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .speech: return "mic.fill"
        case .text: return "doc.text.fill"
        }
    }
}

struct AIAssistantSheet: View {
    @ObservedObject var store: TodoStore
    var onDismiss: () -> Void

    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var inputMode: AIInputMode = .text
    @State private var inputText: String = ""
    @State private var extractedTasks: [ParsedTaskItem] = []
    @State private var isProcessing: Bool = false
    @State private var showPreview: Bool = false

    // Pulsing animation state for microphone
    @State private var isPulsing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()

            // Content Area
            if showPreview && !extractedTasks.isEmpty {
                extractedTasksPreviewView
            } else {
                inputEntryView
            }
        }
        .frame(width: 580, height: 600)
        .onDisappear {
            speechRecognizer.stopRecording()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("AI Task Creator")
                    .font(.system(size: 15, weight: .semibold))
            }

            Spacer()

            if !showPreview {
                Picker("Input Mode", selection: $inputMode) {
                    ForEach(AIInputMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
            }

            Spacer()

            Button {
                speechRecognizer.stopRecording()
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Input View

    private var inputEntryView: some View {
        VStack(spacing: 16) {
            if inputMode == .speech {
                speechInputView
            } else {
                textInputView
            }

            Spacer()

            // Bottom Actions Bar
            HStack {
                Text("Dates & timing will only be set if explicitly mentioned.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    speechRecognizer.stopRecording()
                    onDismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    processInput()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Extract Tasks")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentTextToProcess.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            }
            .padding(.top, 6)
        }
        .padding(20)
    }

    private var currentTextToProcess: String {
        inputMode == .speech ? speechRecognizer.transcript : inputText
    }

    // MARK: - Voice Input View

    private var speechInputView: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated Mic Button
            ZStack {
                if speechRecognizer.isRecording {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 3)
                        .frame(width: 110, height: 110)
                        .scaleEffect(isPulsing ? 1.25 : 1.0)
                        .opacity(isPulsing ? 0.0 : 0.8)
                        .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: false), value: isPulsing)

                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 90, height: 90)
                }

                Button {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                        isPulsing = false
                    } else {
                        speechRecognizer.startRecording()
                        isPulsing = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(speechRecognizer.isRecording ? Color.red : Color.accentColor)
                            .frame(width: 72, height: 72)
                            .shadow(color: (speechRecognizer.isRecording ? Color.red : Color.accentColor).opacity(0.3), radius: 10, x: 0, y: 4)

                        Image(systemName: speechRecognizer.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 4) {
                Text(speechRecognizer.isRecording ? "Listening to your voice..." : "Click microphone to start speaking")
                    .font(.system(size: 14, weight: .medium))

                Text(speechRecognizer.isRecording ? "Speak naturally: mention tasks, deadlines, priorities or tags." : "Dictate your meeting notes, brain dump, or list of todos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Live Transcript Box
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("LIVE TRANSCRIPT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    if !speechRecognizer.transcript.isEmpty {
                        Button("Clear") {
                            speechRecognizer.transcript = ""
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                ScrollView {
                    Text(speechRecognizer.transcript.isEmpty ? "Spoken words will appear here in real-time..." : speechRecognizer.transcript)
                        .font(.system(size: 13))
                        .foregroundStyle(speechRecognizer.transcript.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 120)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            }

            if let error = speechRecognizer.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
    }

    // MARK: - Text / Paste View

    private var textInputView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste or type notes, email summaries, or daily thoughts:")
                .font(.system(size: 13, weight: .medium))

            // Multiline Text Editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .font(.system(size: 13))
                    .frame(height: 220)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )

                if inputText.isEmpty {
                    Text("e.g.,\n• Sync with team: review launch slides by tomorrow 3pm (urgent)\n• Email client proposal this Friday\n• Pick up groceries and call the plumber\n• Brainstorm app icons when free")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }

            // Quick Samples
            VStack(alignment: .leading, spacing: 6) {
                Text("Try an example:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    sampleButton(title: "📅 Meeting Notes", text: "Team meeting recap: Need to finalize the Q3 budget presentation by tomorrow at 2pm (high priority for Work). Also email the frontend team new assets on Friday. Schedule retrospective next Monday.")
                    sampleButton(title: "☕ Daily Errands", text: "Quick errands today: Pick up fresh coffee beans and milk. Remember to call dentist at 4pm for checkup. Fix kitchen faucet this weekend.")
                    sampleButton(title: "🚀 Project Tasks", text: "Deploy version 1.2 to staging by tonight. Review user feedback tickets (Work). Explore ideas for generative UI widgets.")
                }
            }
        }
    }

    private func sampleButton(title: String, text: String) -> some View {
        Button {
            inputText = text
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Extracted Tasks Preview View

    private var extractedTasksPreviewView: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Extracted \(extractedTasks.count) Tasks")
                        .font(.system(size: 16, weight: .bold))

                    Text("Review, edit, or deselect items before adding to your list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    let allSelected = extractedTasks.allSatisfy { $0.isSelected }
                    for i in 0..<extractedTasks.count {
                        extractedTasks[i].isSelected = !allSelected
                    }
                } label: {
                    Text(extractedTasks.allSatisfy { $0.isSelected } ? "Deselect All" : "Select All")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Divider()

            ScrollView {
                VStack(spacing: 10) {
                    ForEach($extractedTasks) { $item in
                        parsedTaskRow(for: $item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }

            Divider()

            // Import Actions
            HStack {
                Button("Back to Edit") {
                    showPreview = false
                }
                .buttonStyle(.bordered)

                Spacer()

                let selectedCount = extractedTasks.filter { $0.isSelected }.count
                Button {
                    importSelectedTasks()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \(selectedCount) \(selectedCount == 1 ? "Task" : "Tasks") to List")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func parsedTaskRow(for item: Binding<ParsedTaskItem>) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle("", isOn: item.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Task Title", text: item.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))

                if !item.notes.wrappedValue.isEmpty {
                    TextField("Notes", text: item.notes)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    // Due Date
                    if let dueDate = item.dueDate.wrappedValue {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(formatDate(dueDate))
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                        .foregroundStyle(Color.orange)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.minus")
                                .font(.system(size: 9))
                            Text("No date")
                                .font(.system(size: 10))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.04), in: Capsule())
                        .foregroundStyle(.secondary)
                    }

                    // Priority
                    if item.priority.wrappedValue != .none {
                        HStack(spacing: 3) {
                            Image(systemName: item.priority.wrappedValue.iconName)
                                .font(.system(size: 9))
                            Text(item.priority.wrappedValue.rawValue)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.priority.wrappedValue.color.opacity(0.12), in: Capsule())
                        .foregroundStyle(item.priority.wrappedValue.color)
                    }

                    // Tag
                    if let tagId = item.tagId.wrappedValue, let tag = store.tag(for: tagId) {
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
                }
            }

            Spacer()

            Button {
                extractedTasks.removeAll { $0.id == item.wrappedValue.id }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(item.isSelected.wrappedValue ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func processInput() {
        speechRecognizer.stopRecording()
        isPulsing = false
        isProcessing = true

        let text = currentTextToProcess
        let parsed = AITaskParser.shared.parseTasks(from: text, availableTags: store.tags)

        withAnimation(.easeInOut) {
            extractedTasks = parsed
            isProcessing = false
            showPreview = true
        }
    }

    private func importSelectedTasks() {
        let selected = extractedTasks.filter { $0.isSelected }
        for task in selected {
            store.addTask(
                title: task.title,
                notes: task.notes,
                dueDate: task.dueDate,
                priority: task.priority,
                tagId: task.tagId
            )
        }
        NSSound(named: "Glass")?.play()
        onDismiss()
    }

    private func formatDate(_ date: Date) -> String {
        let cal = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let timeStr = timeFormatter.string(from: date)

        if cal.isDateInToday(date) {
            return "Today at \(timeStr)"
        } else if cal.isDateInTomorrow(date) {
            return "Tomorrow at \(timeStr)"
        } else {
            let df = DateFormatter()
            df.dateFormat = "MMM d"
            return "\(df.string(from: date)) at \(timeStr)"
        }
    }
}
