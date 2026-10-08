# Todo Mac 📋✨

A sleek, modern, and minimalist native macOS Todo desktop application built with pure **Swift** and **SwiftUI**, powered by **OpenAI GPT-5.4 Mini** directly from the main input section.

Designed specifically for macOS Sonoma and Sequoia, adhering strictly to Apple's Human Interface Guidelines with clean typography, smooth animations, native frosted materials, and zero Electron bloat.

---

## ✨ Features

- **⚡ Unified Direct AI Input (No bloated modal dialogs)**:
  - **Type or Paste Directly**: Paste multi-task summaries, emails, meeting notes, or unstructured brain dumps right into the main input bar — the bar **expands smoothly downward** as the text grows, up to six lines, then scrolls. `Shift+Return` inserts a line break, `Return` submits.
  - **🎙️ Voice Dictation**: Click the microphone icon directly in the input bar to speak. Apple Speech Recognition transcribes your words into the input bar in real time, growing with the transcript.
  - **✨ One-Click AI Extraction**: Click the **✨ AI** button or press Return—tasks are automatically extracted and added directly to your list.
- **💎 Powered by OpenAI GPT-5.4 Mini**:
  - Uses a single model — **GPT-5.4 Mini** (`gpt-5.4-mini-2026-03-17`) — for fast, high-quality reasoning. No fallback chain, no on-device parser.
  - **🔑 Quick API Key Button**: Click the subtle key icon in the input bar to paste your OpenAI API key (`sk-...`).
  - **No key? No problem**: Without an API key, whatever you type is added directly as a plain task.
- **🧠 Strict Timing & Deadline Handling**:
  - Captures **every** form of timing as the task's deadline: explicit dates (*"Oct 15"*), weekdays (*"by Friday"*), relative expressions (*"tomorrow"*, *"in 3 days"*, *"next week"*, *"end of the week"*), clock times (*"at 3pm"*, *"by 5pm"*, *"before noon"*) and deadline wording (*"deadline Friday"*, *"due tomorrow"*, *"by EOD"*).
  - Captured times are surfaced on the task badge (e.g. **Today, 3:00 PM**); pure dates stay clean (e.g. **Tomorrow**).
  - **If date or timing information is not provided, missing, or unclear, the due date field is left completely empty (`nil`)**.
- **Priority & Tag Detection**: Automatically identifies urgency (*urgent*, *asap*, *critical*) and matches tags (*Work*, *Personal*, *Ideas*, *Urgent*).
- **Minimalist & Modern UI**: Clean SF Pro typography, uncluttered layout, native sidebar, and subtle translucent materials.
- **Smart Views & Sidebar Filters**:
  - ☀️ **Today**: Focus only on tasks due today (`⌘1`)
  - 📅 **Upcoming**: Scheduled future tasks (`⌘2`)
  - 📋 **All Tasks**: Complete overview of active items (`⌘3`)
  - ⭐ **High Priority**: Urgent items (`⌘4`)
  - ✅ **Completed**: Archive of finished tasks (`⌘5`)
- **Projects & Tags**: Create custom colored tags with custom color palettes.
- **Interactive Checkboxes**: Smooth spring animations with subtle completion sound.
- **Task Inspector / Details**: Double-click or click edit on any task to add multi-line notes, adjust dates, or change priority flags.
- **Instant Search (`⌘F`)**: Live fuzzy filtering across task titles, notes, and tags.
- **Guaranteed Local Persistence**: Automatically persists tasks locally to JSON storage (`~/Library/Application Support/TodoMacApp/todos_data.json`) across app restarts and upon application exit.

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

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `⌘ N` | Focus main input bar |
| `⌘ F` | Focus Search field |
| `⌘ 1` | Switch to **Today** view |
| `⌘ 2` | Switch to **Upcoming** view |
| `⌘ 3` | Switch to **All Tasks** view |
| `⌘ 4` | Switch to **High Priority** view |
| `⌘ 5` | Switch to **Completed** view |
| `⌘ S` | Toggle Sidebar visibility |
| `⌘ ⇧ K` | Clear completed tasks |
| `Return` | Submit new task or extract with AI |
| `⇧ Return` | Insert a line break in the input bar |
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
│       ├── Services/
│       │   ├── SpeechRecognizer.swift # Speech-to-text dictation service
│       │   └── AITaskParser.swift     # OpenAI GPT-5.4 Mini task extractor
│       ├── Store/
│       │   └── TodoStore.swift   # Observable state & JSON persistence
│       └── Views/
│           ├── SidebarView.swift # Navigation sidebar with counts & progress
│           ├── TaskListView.swift# Main view with header, search & sections
│           ├── TaskRowView.swift # Task card with animated checkbox & hover actions
│           ├── NewTaskBar.swift  # Unified main input bar with mic, key & AI
│           ├── TaskDetailSheet.swift # Detailed task editor modal
│           └── EmptyStateView.swift  # Minimalist empty state graphic & copy
├── Tests/
│   └── TodoAppTests/             # Automated test suite
├── Package.swift                 # Swift Package Manager manifest
├── build.sh                      # Automated build & bundle script
└── Info.plist                    # Bundle metadata template
```
