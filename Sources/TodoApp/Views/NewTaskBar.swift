import SwiftUI

struct NewTaskBar: View {
    @ObservedObject var store: TodoStore
    @State private var isFieldFocused: Bool = false

    // OpenAI API Key storage
    @AppStorage("openai_api_key") private var openaiApiKey: String = ""

    // Voice dictation state
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var isMicPulsing: Bool = false

    // Input state
    @State private var taskTitle: String = ""
    @State private var selectedPriority: Priority = .none
    @State private var selectedTagId: UUID? = nil
    @State private var selectedDueDate: Date? = nil

    // Auto-expanding input height, reported by the editor
    @State private var inputHeight: CGFloat = 26

    private static let minInputHeight: CGFloat = 26
    private static let maxInputHeight: CGFloat = 120

    // UI Feedback state
    @State private var isShowingKeyPopover: Bool = false
    @State private var isProcessingAI: Bool = false
    @State private var statusToast: String? = nil

    var body: some View {
        VStack(spacing: 6) {
            // Main Input Container (grows downward as text wraps)
            HStack(alignment: .top, spacing: 8) {
                // Leading Icon / Status Spinner
                leadingStatusIcon
                    .padding(.top, 2)

                // Main Text Input (type, paste or dictate — expands smoothly)
                ZStack(alignment: .topLeading) {
                    if taskTitle.isEmpty {
                        Text(inputPlaceholder)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .allowsHitTesting(false)
                    }

                    GrowingTextEditor(
                        text: $taskTitle,
                        minHeight: Self.minInputHeight,
                        maxHeight: Self.maxInputHeight,
                        focusRequest: isFieldFocused,
                        onSubmit: { submitWithAI() },
                        onHeightChange: { measuredHeight in
                            guard abs(measuredHeight - inputHeight) > 0.5 else { return }
                            inputHeight = measuredHeight
                        },
                        onFocusChange: { isFieldFocused = $0 }
                    )
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: inputHeight)

                // Controls Row
                HStack(spacing: 6) {
                    // 1. Microphone Dictation Button
                    micButton

                    // 2. OpenAI API Key Configuration Popover
                    apiKeyButton

                    // 3. Quick Attributes (Due Date, Priority, Tag)
                    quickAttributesMenu

                    // 4. Submit / AI Extract Button
                    if !taskTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        submitButton
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isProcessingAI ? Color.purple.opacity(0.7) :
                            (isFieldFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.08)),
                        lineWidth: isProcessingAI ? 1.5 : 1
                    )
            )

            // Status feedback banner
            if let status = statusToast {
                HStack(spacing: 6) {
                    Image(systemName: status.contains("⚠️") ? "exclamationmark.triangle" : "sparkles")
                        .font(.system(size: 11))
                        .foregroundStyle(status.contains("⚠️") ? Color.orange : Color.purple)
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(status.contains("⚠️") ? Color.orange : Color.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            presetBasedOnCurrentFilter()
        }
        .onChange(of: store.selectedFilter) {
            presetBasedOnCurrentFilter()
        }
        .onChange(of: speechRecognizer.transcript) {
            if speechRecognizer.isRecording && !speechRecognizer.transcript.isEmpty {
                taskTitle = speechRecognizer.transcript
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusNewTaskField)) { _ in
            isFieldFocused = true
        }
    }

    private var inputPlaceholder: String {
        if speechRecognizer.isRecording {
            return "Listening to your voice... Speak now"
        }
        if hasOpenAIKey {
            return "Add task or paste summary... (GPT-5.4 Mini enabled)"
        }
        return "Add task or paste summary... (press Return to add)"
    }

    // MARK: - Leading Icon

    private var leadingStatusIcon: some View {
        Group {
            if isProcessingAI {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else if speechRecognizer.isRecording {
                Circle()
                    .fill(Color.red)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isMicPulsing ? 1.3 : 0.9)
                    .animation(.easeInOut(duration: 0.6).repeatForever(), value: isMicPulsing)
            } else {
                Image(systemName: "plus.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Voice Dictation

    private var micButton: some View {
        Button {
            toggleVoiceRecording()
        } label: {
            ZStack {
                if speechRecognizer.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 26, height: 26)
                }

                Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(speechRecognizer.isRecording ? Color.red : Color.secondary)
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(speechRecognizer.isRecording ? "Stop dictation" : "Speak to dictate task or summary")
    }

    private func toggleVoiceRecording() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            isMicPulsing = false
            if !taskTitle.isEmpty {
                submitWithAI()
            }
        } else {
            taskTitle = ""
            speechRecognizer.startRecording()
            isMicPulsing = true
            isFieldFocused = true
        }
    }

    // MARK: - API Key Popover Button

    private var apiKeyButton: some View {
        Button {
            isShowingKeyPopover.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: hasOpenAIKey ? "key.fill" : "key")
                    .font(.system(size: 11))
                    .foregroundStyle(hasOpenAIKey ? Color.green : Color.secondary)

                if hasOpenAIKey {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("OpenAI API Key Settings")
        .popover(isPresented: $isShowingKeyPopover) {
            apiKeyPopoverView
        }
    }

    private var hasOpenAIKey: Bool {
        !openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var apiKeyPopoverView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.purple)
                Text("OpenAI API Key")
                    .font(.system(size: 13, weight: .semibold))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("API Key:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("Paste your OpenAI API key (sk-...)", text: $openaiApiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 280)
            }

            if hasOpenAIKey {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                        .font(.system(size: 12))
                    Text("GPT-5.4 Mini Active")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.green)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.shield")
                        .foregroundStyle(Color.secondary)
                        .font(.system(size: 12))
                    Text("No API key — tasks are added directly")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Get a key at platform.openai.com/api-keys")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                if hasOpenAIKey {
                    Button("Remove Key") {
                        openaiApiKey = ""
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }

                Spacer()

                Button("Done") {
                    isShowingKeyPopover = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 310)
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            submitWithAI()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
        .disabled(isProcessingAI)
        .help("Submit and parse with AI")
    }

    // MARK: - Quick Attributes (Date, Priority, Tag)

    private var quickAttributesMenu: some View {
        HStack(spacing: 4) {
            // Due Date
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
                Image(systemName: "calendar")
                    .font(.system(size: 11))
                    .foregroundStyle(selectedDueDate != nil ? Color.orange : Color.secondary)
                    .padding(4)
                    .background(selectedDueDate != nil ? Color.orange.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Set Due Date")

            // Priority
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
                Image(systemName: selectedPriority.iconName)
                    .font(.system(size: 11))
                    .foregroundStyle(selectedPriority != .none ? selectedPriority.color : Color.secondary)
                    .padding(4)
                    .background(selectedPriority != .none ? selectedPriority.color.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Set Priority")

            // Tag
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
                Image(systemName: "tag")
                    .font(.system(size: 11))
                    .foregroundStyle(selectedTagId != nil ? Color.accentColor : Color.secondary)
                    .padding(4)
                    .background(selectedTagId != nil ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Set Tag")
        }
    }

    // MARK: - Unified AI Submission Action

    private func submitWithAI() {
        let text = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            isMicPulsing = false
        }

        isProcessingAI = true
        let key = openaiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let manualDueDate = selectedDueDate
        let manualPriority = selectedPriority
        let manualTagId = selectedTagId

        Task {
            let result = await AITaskParser.shared.extractTasks(
                from: text,
                apiKey: key,
                availableTags: store.tags
            )

            await MainActor.run {
                if !result.tasks.isEmpty {
                    for item in result.tasks {
                        // Apply manual selections if the AI did not identify one
                        let finalDueDate = item.dueDate ?? manualDueDate
                        let finalPriority = item.priority != .none ? item.priority : manualPriority
                        let finalTagId = item.tagId ?? manualTagId

                        store.addTask(
                            title: item.title,
                            notes: item.notes,
                            dueDate: finalDueDate,
                            priority: finalPriority,
                            tagId: finalTagId
                        )
                    }
                    NSSound(named: "Glass")?.play()

                    showToast("✨ Added \(result.tasks.count) \(result.tasks.count == 1 ? "task" : "tasks") via \(result.engineName)")
                } else {
                    // No API key, or the OpenAI call failed: add the raw input as a plain task
                    store.addTask(
                        title: text,
                        notes: "",
                        dueDate: manualDueDate,
                        priority: manualPriority,
                        tagId: manualTagId
                    )
                    if let err = result.errorDescription {
                        showToast("⚠️ \(err) · Added as plain task")
                    } else {
                        showToast("Added task")
                    }
                }

                taskTitle = ""
                presetBasedOnCurrentFilter()
                isProcessingAI = false
                isFieldFocused = true
            }
        }
    }

    private func showToast(_ message: String) {
        withAnimation {
            statusToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
                if self.statusToast == message {
                    self.statusToast = nil
                }
            }
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
}

extension Notification.Name {
    static let focusNewTaskField = Notification.Name("focusNewTaskField")
}
