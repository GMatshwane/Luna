# Luna

Dark, on-device task reminder for iOS. Today is home; a calendar of days is for planning. Tasks live only in Luna (no Apple Reminders or Calendar sync). Each task can have one local notification.

Design: [docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md](docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md)

## Requirements

- A Mac with **Xcode 15.4+** (SwiftUI + SwiftData)
- iOS **17.0+** Simulator or device
- No third-party packages

## Open and run

1. Clone this repository.
2. Open **`Luna.xcodeproj`** in Xcode (double-click it, or `open Luna.xcodeproj` in Terminal).
3. Select the **Luna** scheme and an iPhone simulator (or your device).
4. Press **Run** (⌘R).

The first time you enable a reminder on a task, iOS asks for notification permission. If you decline, Settings in Luna links to system Settings so you can turn notifications on later.

To run tests: **Product → Test** (⌘U), or:

```bash
xcodebuild test -scheme Luna -destination 'platform=iOS Simulator,name=iPhone 16'
```

(Simulator name may differ on your machine.)

## What v1 includes

- Today list, horizontal day strip, and a calendar sheet to jump dates
- Add / edit / complete / delete tasks
- Optional per-task reminder time with local notifications
- Dark-only Luna palette (`#011C40`, `#023859`, `#26658C`, `#54ACBF`, `#A7EBF2`)

## Out of scope

Reminders/Calendar sync, iCloud, widgets, Siri, recurring tasks, priorities, folders, light mode, and auto-rolling unfinished tasks to tomorrow.

## Project layout

```
Luna.xcodeproj          Xcode project (open this)
Luna/                   App sources, assets, SwiftData model
LunaTests/              Calendar, sort, and reminder-policy tests
docs/superpowers/specs  Product design
scripts/                Project generator and Linux verifier
```

On this cloud environment, Xcode is not available. `python3 scripts/verify_luna_project.py` checks that the project file list, `TaskItem` fields, palette, and notification wiring match the spec.
