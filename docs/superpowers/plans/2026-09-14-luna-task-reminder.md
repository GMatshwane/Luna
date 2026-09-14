# Luna Task Reminder Implementation Plan

> **For agentic workers:** Implement against `docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md`. This plan is the file map and verification path for a from-scratch Xcode project. Cloud VMs may lack `xcodebuild`; still produce a valid project and run `python3 scripts/verify_luna_project.py`.

**Goal:** Ship a complete SwiftUI + SwiftData + UserNotifications iOS app named Luna: per-day tasks, local reminders, dark Luna palette.

**Architecture:** Views observe SwiftData queries and call `TaskService`. Persistence (`LunaPersistence` / `TaskItem`) is isolated from `NotificationScheduler`. Pure calendar/sort/policy types are unit-tested.

**Tech Stack:** SwiftUI, SwiftData, UserNotifications, XCTest. iOS 17+. No third-party packages.

## Global Constraints

- Dark-only UI; colors only from `LunaTheme` (`#011C40`, `#023859`, `#26658C`, `#54ACBF`, `#A7EBF2`)
- Model type name is `TaskItem` with the spec fields
- `dueDate` always start-of-day local
- No CloudKit, EventKit, widgets, Siri, RRULE/monthly recurrence, auto-roll, light mode
- Notification id `luna.task.<uuid>`; payload includes `taskID`
- Request notification permission when the user first enables a reminder

---

### File map

Create:

- `Luna.xcodeproj/project.pbxproj`
- `Luna.xcodeproj/xcshareddata/xcschemes/Luna.xcscheme`
- All Swift sources under `Luna/` and `LunaTests/` listed in the spec
- `Luna/Assets.xcassets/**`
- `.gitignore`, `README.md`
- `scripts/verify_luna_project.py`

### Task 1: Xcode project + theme + calendar/policy types + tests

**Files:** project, `LunaTheme`, `CalendarDay`, `TaskListOrdering`, `ReminderPolicy`, matching XCTest files, app icon assets.

- [x] Tests encode start-of-day, sort order, schedule policy
- [x] Implementation matches tests and spec
- [x] `verify_luna_project.py` covers file list, `TaskItem` fields, hex colors, scheduler cancel-then-schedule

### Task 2: Persistence + notifications + task service

**Files:** `TaskItem`, `LunaPersistence`, `NotificationScheduler`, `TaskService`, `LunaApp`

- [x] Save/complete/delete always cancel prior request
- [x] Reschedule only if incomplete and `reminderAt` is future
- [x] Permission requested from editor enable path, not launch

### Task 3: Screens

**Files:** `RootView`, `DayTasksView`, `DayStripView`, `CalendarSheet`, `TaskRowView`, `EmptyDayView`, `TaskEditorView`, `SettingsView`

- [x] Today is default selected day
- [x] Shared list UI for any day
- [x] Editor: title required, notes, due date, reminder toggle + time, delete
- [x] Denied permission inline tip + Settings link
- [x] Empty day Luna prompt + add

### Task 4: README + verify + PR

- [x] README: open `Luna.xcodeproj` in Xcode 15+ on a Mac, iOS 17 simulator or device, grant notifications when enabling a reminder
- [x] Run `python3 scripts/verify_luna_project.py`
