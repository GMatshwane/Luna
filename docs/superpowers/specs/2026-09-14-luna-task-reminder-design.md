# Luna Task Reminder — Design Spec

**Date:** 2026-09-14  
**Status:** Approved for v1 implementation  
**Stack:** SwiftUI + SwiftData + UserNotifications  
**Platform:** iOS 17+, iPhone first (iPad supported as scaled)

## 1. Product

Luna is a dark, on-device task reminder. **Today is home.** A full calendar of days supports planning. Tasks are created only inside Luna (no Apple Reminders or Calendar sync). Each task may have one local notification time.

v1 is single-device, local-only, dark-only.

## 2. Goals and non-goals

### Goals

- Add, edit, complete, and delete tasks for today and any other calendar day.
- Query and display tasks for a selected local calendar day.
- Schedule and cancel per-task local notifications.
- Dark UI using the Luna five-blue palette.

### Out of scope (v1)

- Apple Reminders / EventKit / Calendar sync
- CloudKit / iCloud / any network backend
- Widgets, Siri, App Intents
- Recurring tasks, priorities, folders, tags
- Light mode
- Auto-rolling unfinished tasks to tomorrow
- Third-party dependencies

## 3. Architecture

Three isolated layers. Views never talk to `UNUserNotificationCenter` or construct the `ModelContainer`.

```
Views (SwiftUI, @Query)
    ↓ calls
TaskService (save / complete / delete)
    ↓            ↓
SwiftData        NotificationScheduler
ModelContainer   (authorize, schedule, cancel)
```

| Unit | Responsibility | Depends on |
|---|---|---|
| `LunaPersistence` | Builds the `ModelContainer` / store | SwiftData schema (`TaskItem`) |
| `TaskItem` | Persisted task fields | SwiftData |
| `CalendarDay` | Start-of-day, day range, combine day+time | Foundation `Calendar` |
| `ReminderPolicy` | Pure rules: should a reminder fire; notification id + payload | Foundation |
| `NotificationScheduler` | Permission + schedule/cancel via UserNotifications | `ReminderPolicy` |
| `TaskService` | Persist mutations, then sync notifications | `ModelContext`, `NotificationScheduler` |
| Views | Observe queries; present editor/settings; call `TaskService` | Environment objects |

`NotificationScheduler` is an `@Observable @MainActor` type injected with `.environment`. Persistence is injected with `.modelContainer`.

### Data flow

1. Home/`DayTasksView` holds `selectedDate` (default: now). A child view keyed by start-of-day owns the SwiftData `@Query` for that day.
2. Completing a row or saving/deleting in the editor calls `TaskService`.
3. `TaskService` writes SwiftData first, then asks `NotificationScheduler.syncReminder(...)`.
4. Scheduler **always cancels** the prior request for that task id, then schedules only if policy allows.

## 4. Data model

SwiftData `@Model` class **`TaskItem`**:

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Stable identity; used as notification identifier key |
| `title` | `String` | Required (non-empty after trim to save) |
| `notes` | `String?` | Optional; empty string stored as `nil` |
| `dueDate` | `Date` | **Always normalized to start-of-day in the local calendar** |
| `reminderAt` | `Date?` | Absolute local datetime; `nil` means listed, no alert |
| `isCompleted` | `Bool` | Default `false` |
| `createdAt` | `Date` | Set on insert |
| `sortOrder` | `Int` | Tie-breaker after reminder time |

### Day query

For selected date `D`:

```
start = startOfDay(D)
end   = start + 1 day
filter: dueDate >= start && dueDate < end
```

Do not compare formatted strings. Do not use `inSameDayAs` inside `#Predicate` (not supported). Normalization of `dueDate` makes the range query exact.

### Sort (display)

1. Timed tasks (`reminderAt != nil`) first, ascending by `reminderAt`
2. Untimed tasks after timed
3. Tie-break: `sortOrder` ascending, then `createdAt` ascending

Completed items **remain on that day** in this same order (not auto-hidden, not moved to another day). They render muted with strikethrough.

### Due date vs reminder time

The editor exposes a **date** (due day) and an optional **time of day** (reminder). On save:

```
dueDate    = startOfDay(pickedDate)
reminderAt = reminderEnabled ? combining(dueDate, reminderTime) : nil
```

Changing `dueDate` moves the task to that day. If a reminder is enabled, `reminderAt` is rebuilt on the new day at the same clock time, then rescheduled.

## 5. Screens

One primary navigation stack. Today and the day browser share the same list UI; the selected day changes.

### 5.1 Today / day list (home)

- Wordmark **LUNA** (serif) and a dated header.
- If `selectedDate` is today: title **Today**, subtitle weekday + month day.
- Otherwise: weekday title, full date subtitle (Yesterday / Tomorrow labels when applicable).
- Toolbar: calendar (jump date), settings.
- Horizontal **day strip** of nearby days (centered on selection).
- Task cards for the selected day, sorted as in §4.
- Checkbox completes/incompletes in place.
- Tap card → editor.
- Prominent add control (toolbar and empty state).

### 5.2 Day browser

- The strip is the primary jump control.
- Calendar **sheet** with a graphical `DatePicker` to jump to any day.
- Same list UI as Today. No second list implementation.

### 5.3 Task editor (sheet)

- Title (required)
- Notes (optional, multiline)
- Due date (date picker)
- Reminder toggle; when on, hour-and-minute picker
- Save / Cancel
- Delete (existing tasks only), with confirmation

**Permission:** the first time the user turns the reminder toggle on, request notification authorization. If status is `.denied` (or `.notDetermined` after a failed request), show an inline tip with a button/link that opens the system Settings app (`UIApplication.openSettingsURLString`). The user may still save a `reminderAt`; delivery requires authorization.

Save is disabled while title is blank.

### 5.4 Settings (minimal sheet)

- Notification permission status (authorized / denied / not requested)
- Open system Settings when denied
- Short note that reminders are on-device only

### 5.5 Empty day

Short Luna-styled prompt plus add affordance, not a blank screen.

- Today: “A quiet evening. Add a task when you’re ready.”
- Other days: “Nothing planned for this day.”

## 6. Reminders (UserNotifications)

Identifier: `luna.task.<uuid>`  
UserInfo: `taskID` → `task.id.uuidString`  
Title: task title  
Body: notes if present, otherwise `Luna reminder`  
Trigger: non-repeating `UNCalendarNotificationTrigger` on local `reminderAt` components (year, month, day, hour, minute)  
Sound: default  
Foreground presentation: banner + sound (app sets `UNUserNotificationCenter` delegate)

### Policy (`ReminderPolicy.shouldSchedule`)

Schedule **only** when all of:

- `reminderAt != nil`
- `isCompleted == false`
- `reminderAt > now`

Otherwise cancel and do not reschedule.

### Lifecycle

| Event | Cancel prior | Reschedule if policy allows |
|---|---|---|
| Save (create or edit) | yes | yes |
| Complete | yes | no (completed) |
| Uncomplete | yes | yes if still future |
| Delete | yes | no |
| Due date change | yes | yes (new datetime) |

Do not request permission at cold launch. Request when the user first enables a reminder.

If permission is later granted in system Settings, refresh status on `scenePhase == .active` and reschedule pending incomplete future reminders when the editor saves or when the scheduler is asked to sync.

## 7. Theme

Dark-only. `preferredColorScheme(.dark)`. Centralize in `LunaTheme`.

| Token | Hex | Role |
|---|---|---|
| `background` | `#011C40` | Screen background |
| `surface` | `#023859` | Cards, chips, editor fields |
| `border` | `#26658C` | Strokes, icons, dividers |
| `secondary` | `#54ACBF` | Subtitles, timestamps, muted completed |
| `highlight` | `#A7EBF2` | Primary text, wordmark, selected/accent |

Do not use system grouped list backgrounds. Custom scroll + cards so the five-blue palette is intact.

Completed rows: secondary color, reduced opacity, strikethrough title.

## 8. Behaviors (acceptance)

- Completing cancels the notification; the item stays on that day until deleted.
- No `reminderAt` → still listed, no alert.
- Changing `dueDate` moves the task and reschedules.
- Unfinished tasks do **not** auto-roll to tomorrow.
- Empty day shows the prompt + add control.

## 9. Project structure

```
Luna.xcodeproj
Luna/
  LunaApp.swift
  Persistence/LunaPersistence.swift
  Models/TaskItem.swift
  Calendar/CalendarDay.swift
  Calendar/TaskListOrdering.swift
  Notifications/ReminderPolicy.swift
  Notifications/NotificationScheduler.swift
  Services/TaskService.swift
  Theme/LunaTheme.swift
  Views/RootView.swift
  Views/DayTasksView.swift
  Views/DayStripView.swift
  Views/CalendarSheet.swift
  Views/TaskRowView.swift
  Views/EmptyDayView.swift
  Views/TaskEditorView.swift
  Views/SettingsView.swift
  Assets.xcassets
LunaTests/
  CalendarDayTests.swift
  TaskListOrderingTests.swift
  ReminderPolicyTests.swift
docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md
```

Bundle ID: `com.gmatshwane.Luna`  
Display name: Luna

## 10. Testing

XCTest (logic only; no UI tests in v1):

- `CalendarDay` start-of-day, exclusive end, combine day+time
- `TaskListOrdering` timed-before-untimed
- `ReminderPolicy` skip nil / completed / past; schedule future incomplete; identifier + payload

On this cloud VM, Xcode/Simulator are unavailable. A `scripts/verify_luna_project.py` check asserts project references, required types/fields, palette hexes, and notification wiring so the tree stays consistent without `xcodebuild`.

Open `Luna.xcodeproj` on a Mac to build and run.

## 11. Decisions locked

1. Today and day browser share one list view + `selectedDate`.
2. Reminder time lives on the due day (clock time); moving the due day moves the reminder.
3. Completed tasks keep sort position; they are not bucketed to the bottom.
4. Permission is requested on first reminder enable, not at launch.
5. No EventKit, no CloudKit, no third-party packages.
