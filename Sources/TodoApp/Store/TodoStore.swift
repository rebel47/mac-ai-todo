import SwiftUI
import AppKit
import Combine

class TodoStore: ObservableObject {
    @Published var tasks: [TaskItem] = [] {
        didSet {
            scheduleSave()
        }
    }
    @Published var tags: [TagItem] = [] {
        didSet {
            scheduleSave()
        }
    }
    @Published var selectedFilter: NavigationFilter = .all
    @Published var searchText: String = ""
    @Published var selectedTaskId: UUID? = nil
    @Published var editingTask: TaskItem? = nil
    @Published var isShowingNewTagSheet: Bool = false

    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<Void, Never>()

    init() {
        loadData()
        saveCancellable = saveSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.persistNow()
            }

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.persistNow()
        }
    }

    private func scheduleSave() {
        saveSubject.send(())
    }

    // MARK: - Filtering & Search

    var filteredTasks: [TaskItem] {
        var result = tasks

        // Apply sidebar filter
        switch selectedFilter {
        case .all:
            break
        case .today:
            result = result.filter { $0.isToday }
        case .upcoming:
            result = result.filter { $0.isUpcoming }
        case .highPriority:
            result = result.filter { $0.priority == .high }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .tag(let tagId):
            result = result.filter { $0.tagId == tagId }
        }

        // Apply search query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter { task in
                task.title.lowercased().contains(query) ||
                task.notes.lowercased().contains(query) ||
                (self.tag(for: task.tagId)?.name.lowercased().contains(query) ?? false)
            }
        }

        return result
    }

    var activeFilteredTasks: [TaskItem] {
        filteredTasks.filter { !$0.isCompleted }
    }

    var completedFilteredTasks: [TaskItem] {
        filteredTasks.filter { $0.isCompleted }
    }

    // MARK: - Counts

    var activeTotalCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var totalCompletedCount: Int {
        tasks.filter { $0.isCompleted }.count
    }

    var completionPercentage: Double {
        let total = tasks.count
        guard total > 0 else { return 0.0 }
        return Double(totalCompletedCount) / Double(total)
    }

    func count(for filter: NavigationFilter) -> Int {
        switch filter {
        case .all:
            return tasks.filter { !$0.isCompleted }.count
        case .today:
            return tasks.filter { !$0.isCompleted && $0.isToday }.count
        case .upcoming:
            return tasks.filter { !$0.isCompleted && $0.isUpcoming }.count
        case .highPriority:
            return tasks.filter { !$0.isCompleted && $0.priority == .high }.count
        case .completed:
            return tasks.filter { $0.isCompleted }.count
        case .tag(let tagId):
            return tasks.filter { !$0.isCompleted && $0.tagId == tagId }.count
        }
    }

    // MARK: - Task Mutations

    @discardableResult
    func addTask(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        priority: Priority = .none,
        tagId: UUID? = nil
    ) -> TaskItem {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualTitle = trimmedTitle.isEmpty ? "New Task" : trimmedTitle

        let newTask = TaskItem(
            title: actualTitle,
            notes: notes,
            isCompleted: false,
            dueDate: dueDate,
            priority: priority,
            tagId: tagId
        )

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            tasks.insert(newTask, at: 0)
        }
        return newTask
    }

    func toggleTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            tasks[index].isCompleted.toggle()
            if tasks[index].isCompleted {
                tasks[index].completedAt = Date()
                NSSound(named: "Pop")?.play()
            } else {
                tasks[index].completedAt = nil
            }
        }
    }

    func updateTask(_ task: TaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            tasks[index] = task
        }
    }

    func deleteTask(id: UUID) {
        withAnimation(.easeOut(duration: 0.25)) {
            tasks.removeAll { $0.id == id }
            if selectedTaskId == id {
                selectedTaskId = nil
            }
            if editingTask?.id == id {
                editingTask = nil
            }
        }
    }

    func clearCompletedTasks() {
        withAnimation(.easeOut(duration: 0.3)) {
            tasks.removeAll { $0.isCompleted }
        }
    }

    // MARK: - Tag Management

    func tag(for id: UUID?) -> TagItem? {
        guard let id = id else { return nil }
        return tags.first { $0.id == id }
    }

    func addTag(name: String, colorHex: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newTag = TagItem(name: trimmed, colorHex: colorHex)
        withAnimation {
            tags.append(newTag)
        }
    }

    func deleteTag(id: UUID) {
        withAnimation {
            tags.removeAll { $0.id == id }
            for i in 0..<tasks.count {
                if tasks[i].tagId == id {
                    tasks[i].tagId = nil
                }
            }
            if case .tag(let selectedId) = selectedFilter, selectedId == id {
                selectedFilter = .all
            }
        }
    }

    // MARK: - Persistence

    private struct StorageData: Codable {
        var tasks: [TaskItem]
        var tags: [TagItem]
    }

    private var storageURL: URL {
        let fileManager = FileManager.default
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let appFolder = appSupport.appendingPathComponent("TodoMacApp", isDirectory: true)
            try? fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true)
            return appFolder.appendingPathComponent("todos_data.json")
        }
        return URL(fileURLWithPath: "./todos_data.json")
    }

    private func persistNow() {
        let data = StorageData(tasks: tasks, tags: tags)
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    private func loadData() {
        let url = storageURL
        if FileManager.default.fileExists(atPath: url.path),
           let rawData = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(StorageData.self, from: rawData) {
            self.tasks = decoded.tasks
            self.tags = decoded.tags.isEmpty ? TagItem.defaultTags : decoded.tags
            return
        }

        // Initialize with elegant sample data
        self.tags = TagItem.defaultTags
        let workTag = self.tags.first { $0.name == "Work" }?.id
        let personalTag = self.tags.first { $0.name == "Personal" }?.id
        let urgentTag = self.tags.first { $0.name == "Urgent" }?.id
        let ideasTag = self.tags.first { $0.name == "Ideas" }?.id

        let today = Date()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)

        self.tasks = [
            TaskItem(
                title: "Launch Todo Mac desktop app",
                notes: "Enjoy the clean, modern and minimalist design with instant keyboard shortcuts.",
                isCompleted: false,
                dueDate: today,
                priority: .high,
                tagId: urgentTag
            ),
            TaskItem(
                title: "Try pressing ⌘N to quick-add a new task",
                notes: "You can assign tags, priority flags, and due dates effortlessly.",
                isCompleted: false,
                dueDate: today,
                priority: .medium,
                tagId: workTag
            ),
            TaskItem(
                title: "Double-click or click edit on any task",
                notes: "Inspect details, add multi-line notes, adjust due dates or change tags.",
                isCompleted: false,
                dueDate: tomorrow,
                priority: .low,
                tagId: ideasTag
            ),
            TaskItem(
                title: "Organize tasks by Projects & Tags",
                notes: "Create custom colored tags in the sidebar to organize your life and projects.",
                isCompleted: false,
                dueDate: tomorrow,
                priority: .none,
                tagId: personalTag
            ),
            TaskItem(
                title: "Install and run native macOS application",
                notes: "Built with pure native SwiftUI for lightning fast speed and zero battery drain.",
                isCompleted: true,
                completedAt: Date(),
                dueDate: today,
                priority: .medium,
                tagId: workTag
            )
        ]
    }
}
