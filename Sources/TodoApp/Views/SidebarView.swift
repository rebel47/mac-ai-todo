import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: TodoStore
    @State private var showingAddTagPopover: Bool = false
    @State private var newTagName: String = ""
    @State private var newTagColorHex: String = "#3B82F6"

    private let presetColors = [
        "#3B82F6", // Blue
        "#8B5CF6", // Purple
        "#EC4899", // Pink
        "#EF4444", // Red
        "#F59E0B", // Amber
        "#10B981", // Emerald
        "#06B6D4", // Cyan
        "#6B7280"  // Gray
    ]

    var body: some View {
        List(selection: $store.selectedFilter) {
            Section("Filters") {
                filterRow(for: .today)
                filterRow(for: .upcoming)
                filterRow(for: .all)
                filterRow(for: .highPriority)
                filterRow(for: .completed)
            }

            Section {
                ForEach(store.tags) { tag in
                    NavigationLink(value: NavigationFilter.tag(tag.id)) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(tag.color)
                                .frame(width: 8, height: 8)
                            Text(tag.name)
                                .font(.system(size: 13, weight: .regular))
                            Spacer()
                            let count = store.count(for: .tag(tag.id))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.06), in: Capsule())
                            }
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            store.deleteTag(id: tag.id)
                        } label: {
                            Label("Delete Tag", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Tags")
                    Spacer()
                    Button {
                        showingAddTagPopover = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingAddTagPopover) {
                        addTagPopover
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    private func filterRow(for filter: NavigationFilter) -> some View {
        NavigationLink(value: filter) {
            HStack(spacing: 10) {
                Image(systemName: filter.iconName)
                    .foregroundStyle(filter.iconColor)
                    .frame(width: 16)
                    .font(.system(size: 13, weight: .medium))

                Text(filter.title)
                    .font(.system(size: 13, weight: .regular))

                Spacer()

                let count = store.count(for: filter)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(filter == .completed ? .secondary : (filter == .today ? Color.orange : .secondary))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.horizontal, 12)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.totalCompletedCount) of \(store.tasks.count) done")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 4)

                            Capsule()
                                .fill(LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(width: max(0, geo.size.width * CGFloat(store.completionPercentage)), height: 4)
                        }
                    }
                    .frame(height: 4)
                }

                Spacer()

                if store.totalCompletedCount > 0 {
                    Button {
                        store.clearCompletedTasks()
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear Completed Tasks")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var addTagPopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create New Tag")
                .font(.system(size: 13, weight: .semibold))

            TextField("Tag name", text: $newTagName)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Color")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(presetColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: newTagColorHex == hex ? 2 : 0)
                            )
                            .onTapGesture {
                                newTagColorHex = hex
                            }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    showingAddTagPopover = false
                    newTagName = ""
                }
                .buttonStyle(.bordered)

                Button("Add Tag") {
                    if !newTagName.trimmingCharacters(in: .whitespaces).isEmpty {
                        store.addTag(name: newTagName, colorHex: newTagColorHex)
                        newTagName = ""
                        showingAddTagPopover = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}
