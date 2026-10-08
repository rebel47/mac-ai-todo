import SwiftUI

struct TaskListView: View {
    @ObservedObject var store: TodoStore
    @FocusState private var isSearchFocused: Bool
    @State private var isCompletedSectionExpanded: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Top Header Bar
            headerBar
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

            Divider()

            // Main scrollable area
            ScrollView {
                VStack(spacing: 16) {
                    // Quick Add Bar
                    NewTaskBar(store: store)
                        .padding(.top, 14)

                    // Content
                    if store.filteredTasks.isEmpty {
                        EmptyStateView(
                            filter: store.selectedFilter,
                            searchQuery: store.searchText
                        )
                        .frame(minHeight: 280)
                    } else {
                        // Active Tasks
                        if !store.activeFilteredTasks.isEmpty {
                            VStack(spacing: 2) {
                                ForEach(store.activeFilteredTasks) { task in
                                    TaskRowView(store: store, task: task) {
                                        store.editingTask = task
                                    }
                                }
                            }
                        }

                        // Completed Tasks Section
                        if !store.completedFilteredTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isCompletedSectionExpanded.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: isCompletedSectionExpanded ? "chevron.down" : "chevron.right")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 12)

                                        Text("Completed")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.secondary)

                                        Text("(\(store.completedFilteredTasks.count))")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.tertiary)

                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                .buttonStyle(.plain)

                                if isCompletedSectionExpanded {
                                    VStack(spacing: 2) {
                                        ForEach(store.completedFilteredTasks) { task in
                                            TaskRowView(store: store, task: task) {
                                                store.editingTask = task
                                            }
                                        }
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $store.editingTask) { task in
            TaskDetailSheet(
                store: store,
                task: Binding(
                    get: { store.editingTask },
                    set: { store.editingTask = $0 }
                ),
                onDismiss: {
                    store.editingTask = nil
                }
            )
        }
    }

    private var headerBar: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: store.selectedFilter.iconName)
                            .foregroundStyle(store.selectedFilter.iconColor)
                            .font(.system(size: 18, weight: .medium))

                        Text(currentTitle)
                            .font(.system(size: 22, weight: .bold))
                    }

                    Text(formattedSubtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Minimal Search Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    TextField("Search tasks...", text: $store.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .focused($isSearchFocused)

                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(width: 190)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSearchFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.08), lineWidth: 1)
                )
            }
        }
    }

    private var currentTitle: String {
        switch store.selectedFilter {
        case .all: return "All Tasks"
        case .today: return "Today"
        case .upcoming: return "Upcoming"
        case .highPriority: return "High Priority"
        case .completed: return "Completed"
        case .tag(let id):
            return store.tag(for: id)?.name ?? "Tag"
        }
    }

    private var formattedSubtitle: String {
        let activeCount = store.activeFilteredTasks.count
        let countText = activeCount == 1 ? "1 task remaining" : "\(activeCount) tasks remaining"

        if store.selectedFilter == .today {
            let df = DateFormatter()
            df.dateFormat = "EEEE, MMMM d"
            return "\(df.string(from: Date())) · \(countText)"
        }
        return countText
    }
}
