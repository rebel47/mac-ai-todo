import SwiftUI
import AppKit

@main
struct TodoApp: App {
    @StateObject private var store = TodoStore()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, columnVisibility: $columnVisibility)
                .frame(minWidth: 680, minHeight: 460)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .focusNewTaskField, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Today") {
                    store.selectedFilter = .today
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Upcoming") {
                    store.selectedFilter = .upcoming
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("All Tasks") {
                    store.selectedFilter = .all
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("High Priority") {
                    store.selectedFilter = .highPriority
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Completed") {
                    store.selectedFilter = .completed
                }
                .keyboardShortcut("5", modifiers: .command)

                Divider()

                Button("Clear Completed Tasks") {
                    store.clearCompletedTasks()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: TodoStore
    @Binding var columnVisibility: NavigationSplitViewVisibility

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(store: store)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            TaskListView(store: store)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation {
                        if columnVisibility == .detailOnly {
                            columnVisibility = .all
                        } else {
                            columnVisibility = .detailOnly
                        }
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 13))
                }
                .help("Toggle Sidebar (⌘S)")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    NotificationCenter.default.post(name: .focusNewTaskField, object: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                }
                .help("New Task (⌘N)")
            }
        }
    }
}
