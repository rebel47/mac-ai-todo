# Todo Mac 📋✨

A sleek, modern, and minimalist native macOS Todo desktop application built with pure **Swift** and **SwiftUI**.

Designed specifically for macOS Sonoma and Sequoia, adhering strictly to Apple's Human Interface Guidelines with clean typography, smooth animations, native frosted materials, and zero Electron bloat.

---

## ✨ Features

- **Minimalist & Modern UI**: Clean SF Pro typography, uncluttered layout, native sidebar, and subtle translucent materials.
- **Instant Quick Add (`⌘N`)**: Floating task input bar with inline due-date, priority, and tag selectors. Press Return to add tasks seamlessly without leaving your keyboard.
- **Smart Views & Sidebar Filters**:
  - ☀️ **Today**: Focus only on tasks due today (`⌘1`)
  - 📅 **Upcoming**: Scheduled future tasks (`⌘2`)
  - 📋 **All Tasks**: Complete overview of active items (`⌘3`)
  - ⭐ **High Priority**: Urgent items (`⌘4`)
  - ✅ **Completed**: Archive of finished tasks (`⌘5`)
- **Projects & Tags**: Create custom colored tags (Work, Personal, Urgent, Ideas, etc.) with custom color palettes.
- **Interactive Checkboxes**: Smooth spring animations with subtle completion sound.
- **Task Inspector / Details**: Double-click or click edit on any task to add multi-line notes, adjust dates, or change priority flags.
- **Instant Search (`⌘F`)**: Live fuzzy filtering across task titles, notes, and tags.
- **Progress Tracking**: Minimal progress bar and completion fraction in sidebar.
- **Native Persistence**: Automatically persists tasks and tags locally to JSON storage (`~/Library/Application Support/TodoMacApp/todos_data.json`).
- **Retina App Icon**: Custom high-resolution vector squircle icon with standard macOS icon resolutions.

---

## 🚀 How to Run

### Option 1: Open the Built macOS Application
You can open the app directly from your terminal or double-click `Todo.app` in Finder:
```bash
open Todo.app
```
*(Or drag `Todo.app` into your `/Applications` folder to have it always in Spotlight and Launchpad!)*

### Option 2: Rebuild with the Build Script
If you make any changes to the Swift code, simply run:
```bash
./build.sh
```
This compiles the Swift sources with `-O` release optimization, reassembles the `Todo.app` bundle, attaches `AppIcon.icns`, and signs it for macOS.

### Option 3: Open in Xcode
Open the project directory in Xcode:
```bash
open Package.swift
```

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘ N` | Focus Quick Add task bar |
| `⌘ F` | Focus Search field |
| `⌘ 1` | Switch to **Today** view |
| `⌘ 2` | Switch to **Upcoming** view |
| `⌘ 3` | Switch to **All Tasks** view |
| `⌘ 4` | Switch to **High Priority** view |
| `⌘ 5` | Switch to **Completed** view |
| `⌘ S` | Toggle Sidebar visibility |
| `⌘ ⇧ K` | Clear completed tasks |
| `Return` | Submit new task in Quick Add |
| `Double Click` | Open task detail & notes editor |

---

## 📁 Project Structure

```
Todo Mac/
├── Todo.app/                     # Packaged native macOS Application Bundle
│   └── Contents/
│       ├── MacOS/TodoApp         # Compiled binary
│       ├── Resources/AppIcon.icns# Retina App Icon
│       └── Info.plist            # Application bundle metadata
├── Sources/
│   └── TodoApp/
│       ├── TodoApp.swift         # Main App entrypoint & AppKit Window Scene
│       ├── Models/
│       │   ├── TaskItem.swift    # Task data model & date helpers
│       │   ├── Priority.swift    # Priority enum (High, Medium, Low, None)
│       │   ├── TagItem.swift     # Custom colored tags model
│       │   └── FilterType.swift  # Navigation & filter options
│       ├── Store/
│       │   └── TodoStore.swift   # Observable state & JSON persistence
│       └── Views/
│           ├── SidebarView.swift # Navigation sidebar with counts & progress
│           ├── TaskListView.swift# Main view with header, search & sections
│           ├── TaskRowView.swift # Task card with animated checkbox & hover actions
│           ├── NewTaskBar.swift  # Quick add floating input bar
│           ├── TaskDetailSheet.swift # Detailed task editor modal
│           └── EmptyStateView.swift  # Minimalist empty state graphic & copy
├── Tests/
│   └── TodoAppTests/             # Automated test suite
├── Package.swift                 # Swift Package Manager manifest
├── build.sh                      # Automated build & bundle script
└── Info.plist                    # Bundle metadata template
```
