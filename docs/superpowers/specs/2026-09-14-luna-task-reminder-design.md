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
- Optional **RecurrenceRule** repeat (every N days, weekdays, weekly, monthly, yearly) that spawns the next occurrence on complete.
- Daily **Scores**: custom points per task, a daily point goal, and live progress on each day.
- Optional **category** per task (user-defined name + optional color) so a day list can be scanned by kind of work.
- Dark UI using the Luna five-blue palette.

### Out of scope (v1)

- Apple Reminders / EventKit / Calendar sync
- CloudKit / iCloud / any network backend
- Widgets, Siri, App Intents
- RRULE parsing, priorities, multi-tags
- Repeatable plans
- Streaks, leaderboards, or cross-day score history
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
| `LunaPersistence` | Builds the `ModelContainer` / store | SwiftData schema (`TaskItem`, `Category`) |
| `TaskItem` | Persisted task fields | SwiftData |
| `Category` | User-defined name + optional color; one optional category per task | SwiftData |
| `CategoryPolicy` | Name/color normalize, day-list grouping and filter | `TaskListOrdering` |
| `CalendarDay` | Start-of-day, day range, combine day+time | Foundation `Calendar` |
| `RepeatPolicy` | `RecurrenceRule` normalize, next due/reminder, spawn-on-complete | `CalendarDay` |
| `ScorePolicy` | Point/goal normalization and day-score aggregation | Foundation |
| `LunaSettings` | Persists `dailyPointGoal` in UserDefaults | `ScorePolicy` |
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
| `repeatIntervalDays` | `Int?` | Every-N-days interval (`1...365`); unused for other kinds |
| `repeatKindRaw` | `String?` | `everyNDays` / `weekdays` / `weekly` / `monthly` / `yearly`; `nil` + interval is legacy every-N-days |
| `repeatWeekdaysMask` | `Int` | Bits 1…7 = Calendar weekday numbers for `weekdays` |
| `repeatMonthDay` | `Int?` | Intended day of month (1…31) for monthly/yearly |
| `repeatMonth` | `Int?` | Intended month (1…12) for yearly |
| `points` | `Int` | Default **1**, minimum 1 (clamped by `ScorePolicy`) |
| `category` | `Category?` | Optional; **one** category per task (not multi-tags) |

SwiftData `@Model` class **`Category`**:

| Field | Type | Notes |
|---|---|---|
| `id` | `UUID` | Stable identity |
| `name` | `String` | Required after trim; clamped by `CategoryPolicy` |
| `colorHex` | `String?` | Optional 6-digit hex; `nil` means no color |
| `createdAt` | `Date` | Set on insert |
| `sortOrder` | `Int` | Creation order |
| `tasks` | `[TaskItem]` | Inverse of `TaskItem.category`; delete **nullifies** (tasks become uncategorized) |

`TaskItem.recurrence` maps those fields to `RecurrenceRule`. `RepeatPolicy.normalizedInterval` still treats `nil`, 0, and negatives as “no repeat”, and clamps N into `1...365`. Empty weekday sets do not repeat.

### Scores

Each task has a custom point value (default 1). Completing a task earns those points toward the **selected day’s** score. Uncompleting subtracts them (the day score is always the live sum of `points` where `isCompleted == true` for that `dueDate`).

Daily goal is app settings, not per-day:

- Stored in `UserDefaults` as `luna.dailyPointGoal` via `LunaSettings`
- Default **10**, minimum 1
- The same goal applies to Today and every other browsed day

```
earned = sum(points of completed tasks on selected day)
display = "earned / dailyPointGoal"   // overflow allowed, e.g. 12 / 10
bar     = min(1, earned / dailyPointGoal)
```

Repeating tasks copy `points` and `category` onto the next occurrence, same as title and notes. No streaks in this version. The daily score stays a **single day total** (not split by category).

### Repeats (`RecurrenceRule`)

Repeats are **optional per task**. Completing a repeating task does **not** move it; the completed copy stays on that day (muted + strikethrough). Luna then inserts a **new incomplete** `TaskItem` (new `id`) for the next occurrence.

`RecurrenceRule` cases (reusable later for multi-task plans; no RRULE parsing):

| Kind | Next due |
|---|---|
| `everyNDays(N)` | N calendar days later (`N` in 1…365) |
| `weekdays(set)` | Next day whose Calendar weekday is in the set (Mon–Fri, weekends, or custom) |
| `weekly` | Same weekday, 7 calendar days later |
| `monthly(dayOfMonth)` | Next month on `dayOfMonth`, **clamped to the last day** of that month |
| `yearly(month, day)` | Next year on that month/day, clamped to the last valid day (leap day → Feb 28) |

Monthly and yearly store the *intended* day (and month) on the spawned copy, so 31 January → 28 February still carries `dayOfMonth = 31` and the following occurrence is 31 March.

```
nextDue      = RepeatPolicy.nextOccurrence(dueDate, rule)
nextReminder = reminderAt == nil ? nil : Calendar.date(byAdding: .day, value: dayDelta, to: reminderAt)
```

`dayDelta` is the calendar-day difference between the old and new start-of-day due dates so clock time is preserved across DST.

The next row copies `title`, `notes`, `points`, `category`, and the same `RecurrenceRule`. `sortOrder` is the next value on that future day.

Then:

1. Cancel the completed occurrence’s notification (same as any complete).
2. Schedule the new occurrence if its `reminderAt` is in the future and the task is incomplete.

Editing the repeat rule on an **incomplete** task only changes that instance; it is used the next time *that* instance is completed. Past completed copies are not rewritten.

Non-repeating tasks (`recurrence == nil`) are unchanged.

Uncompleting a repeating task does not delete an already-spawned next occurrence. Completing the same instance again will not create a second next row if an incomplete copy with the same title, rule, and next due day already exists.

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

If any task on the day has a category, the list is **sectioned** by category name (A–Z) with **Uncategorized** last. Filter chips can show All, each category, or Uncategorized. Filtering does **not** change the day’s score.

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
- Compact **score card**: `earned / goal` and a progress bar (`#A7EBF2` fill on `#023859` track). Empty day shows `0 / goal`. Updates live on complete/uncomplete. One total for the day, not per category.
- If `selectedDate` is today: title **Today**, subtitle weekday + month day.
- Otherwise: weekday title, full date subtitle (Yesterday / Tomorrow labels when applicable).
- Toolbar: calendar (jump date), settings.
- Horizontal **day strip** of nearby days (centered on selection).
- Task cards for the selected day, sorted as in §4, **grouped/sectioned by category** when any task is categorized, plus Uncategorized. Optional filter chips for All / a category / Uncategorized.
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
- Repeat toggle; when on, a labeled type picker (Every N days, Specific weekdays, Weekly, Monthly, Yearly). Every N days keeps the stepper; weekdays offer Monday–Friday, weekends, or a custom set.
- Points stepper (default 1, minimum 1)
- Category picker: None, existing user-defined categories, New category (name + optional color)
- Save / Cancel
- Delete (existing tasks only), with confirmation

**Permission:** the first time the user turns the reminder toggle on, request notification authorization. If status is `.denied` (or `.notDetermined` after a failed request), show an inline tip with a button/link that opens the system Settings app (`UIApplication.openSettingsURLString`). The user may still save a `reminderAt`; delivery requires authorization.

Save is disabled while title is blank.

### 5.4 Settings (minimal sheet)

- Editable **Daily goal** (points), default 10
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
| Complete (non-repeating) | yes | no (completed) |
| Complete (repeating) | yes on completed copy | yes on **new** next occurrence if its reminder is future |
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
- Completing a repeating task also creates the next incomplete occurrence from `RecurrenceRule`, with reminder shifted by `Calendar.date(byAdding: .day)` and **points, category, and rule copied**.
- Completing/uncompleting updates that day’s score (sum of completed task points).
- Daily point goal is edited in Settings and shared across days. The score is **not split by category**.
- No `reminderAt` → still listed, no alert.
- Changing `dueDate` moves the task and reschedules.
- Changing repeat interval on an incomplete task does not rewrite past completed copies.
- Unfinished tasks do **not** auto-roll to tomorrow.
- Empty day shows the prompt + add control.

## 9. Project structure

```
Luna.xcodeproj
Luna/
  LunaApp.swift
  Persistence/LunaPersistence.swift
  Models/TaskItem.swift
  Models/Category.swift
  Models/CategoryPolicy.swift
  Calendar/CalendarDay.swift
  Calendar/TaskListOrdering.swift
  Calendar/RepeatPolicy.swift
  Scores/ScorePolicy.swift
  Settings/LunaSettings.swift
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
  Views/CategoryEditorView.swift
  Views/SettingsView.swift
  Views/ScoreCardView.swift
  Assets.xcassets
LunaTests/
  CalendarDayTests.swift
  TaskListOrderingTests.swift
  ReminderPolicyTests.swift
  RepeatPolicyTests.swift
  ScorePolicyTests.swift
  CategoryPolicyTests.swift
docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md
```

Bundle ID: `com.gmatshwane.Luna`  
Display name: Luna

## 10. Testing

XCTest (logic only; no UI tests in v1):

- `CalendarDay` start-of-day, exclusive end, combine day+time
- `TaskListOrdering` timed-before-untimed
- `ReminderPolicy` skip nil / completed / past; schedule future incomplete; identifier + payload
- `RepeatPolicy` / `RecurrenceRule` N-day, weekday, weekly, monthly (month-end clamp), yearly, reminder offset, spawn only on complete transition
- `ScorePolicy` defaults (1 point, goal 10), completed-only sum, overflow label with capped bar
- `CategoryPolicy` name/color normalize, section named categories then Uncategorized, filter All / identified / uncategorized

On this cloud VM, Xcode/Simulator are unavailable. A `scripts/verify_luna_project.py` check asserts project references, required types/fields, palette hexes, and notification wiring so the tree stays consistent without `xcodebuild`.

Open `Luna.xcodeproj` on a Mac to build and run.

## 11. Decisions locked

1. Today and day browser share one list view + `selectedDate`.
2. Reminder time lives on the due day (clock time); moving the due day moves the reminder.
3. Completed tasks keep sort position; they are not bucketed to the bottom.
4. Permission is requested on first reminder enable, not at launch.
5. No EventKit, no CloudKit, no third-party packages.
6. Repeats use `RecurrenceRule` (every N days, weekdays, weekly, monthly, yearly). Next occurrence is created on complete, not at save. No RRULE parsing.
7. Day score is a live sum of completed task points; the daily goal is a single UserDefaults setting, not per-day history. No streaks. Score is a single day total, not split by category.
8. One optional category per task. Categories are user-defined (name + optional color), assigned in the task editor, copied onto spawned occurrences, and used to section/filter the day list including Uncategorized.
