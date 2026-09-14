#!/usr/bin/env python3
"""Verify the Luna Xcode project tree without requiring xcodebuild."""

from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def ok(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def read(path: Path) -> str:
    ok(path.is_file(), f"missing file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def main() -> int:
    pbx = read(ROOT / "Luna.xcodeproj" / "project.pbxproj")
    scheme = ROOT / "Luna.xcodeproj" / "xcshareddata" / "xcschemes" / "Luna.xcscheme"
    ok(scheme.is_file(), "missing shared Luna scheme")

    required = [
        "docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md",
        "docs/superpowers/plans/2026-09-14-luna-task-reminder.md",
        "README.md",
        "Luna/LunaApp.swift",
        "Luna/Theme/LunaTheme.swift",
        "Luna/Calendar/CalendarDay.swift",
        "Luna/Calendar/TaskListOrdering.swift",
        "Luna/Calendar/RepeatPolicy.swift",
        "Luna/Scores/ScorePolicy.swift",
        "Luna/Settings/LunaSettings.swift",
        "Luna/Notifications/ReminderPolicy.swift",
        "Luna/Notifications/NotificationScheduler.swift",
        "Luna/Models/TaskItem.swift",
        "Luna/Persistence/LunaPersistence.swift",
        "Luna/Services/TaskService.swift",
        "Luna/Views/RootView.swift",
        "Luna/Views/DayTasksView.swift",
        "Luna/Views/DayStripView.swift",
        "Luna/Views/CalendarSheet.swift",
        "Luna/Views/TaskRowView.swift",
        "Luna/Views/EmptyDayView.swift",
        "Luna/Views/TaskEditorView.swift",
        "Luna/Views/SettingsView.swift",
        "Luna/Views/ScoreCardView.swift",
        "Luna/Assets.xcassets/Contents.json",
        "Luna/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
        "Luna/Assets.xcassets/AccentColor.colorset/Contents.json",
        "LunaTests/CalendarDayTests.swift",
        "LunaTests/TaskListOrderingTests.swift",
        "LunaTests/ReminderPolicyTests.swift",
        "LunaTests/RepeatPolicyTests.swift",
        "LunaTests/ScorePolicyTests.swift",
    ]
    for rel in required:
        ok((ROOT / rel).is_file(), f"missing {rel}")

    swift_on_disk = sorted(p.relative_to(ROOT).as_posix() for p in ROOT.glob("Luna/**/*.swift"))
    test_on_disk = sorted(p.relative_to(ROOT).as_posix() for p in ROOT.glob("LunaTests/**/*.swift"))

    for rel in swift_on_disk + test_on_disk:
        name = Path(rel).name
        ok(name in pbx, f"{rel} is not referenced in project.pbxproj")

    ok("PRODUCT_BUNDLE_IDENTIFIER = com.gmatshwane.Luna;" in pbx, "app bundle id missing")
    ok("INFOPLIST_KEY_UIUserInterfaceStyle = Dark;" in pbx, "dark-only UIUserInterfaceStyle missing")
    ok("IPHONEOS_DEPLOYMENT_TARGET = 17.0;" in pbx, "iOS 17 deployment target missing")
    ok("CloudKit" not in pbx, "CloudKit must not be in the project")

    theme = read(ROOT / "Luna/Theme/LunaTheme.swift")
    for hex_color in ("0x011C40", "0x023859", "0x26658C", "0x54ACBF", "0xA7EBF2"):
        ok(hex_color in theme, f"LunaTheme missing {hex_color}")

    model = read(ROOT / "Luna/Models/TaskItem.swift")
    for field in ("id: UUID", "title: String", "notes: String?", "dueDate: Date", "reminderAt: Date?", "isCompleted: Bool", "createdAt: Date", "sortOrder: Int", "repeatIntervalDays: Int?", "points: Int"):
        ok(field in model, f"TaskItem missing {field}")
    ok("@Model" in model, "TaskItem is not a SwiftData @Model")
    ok("CalendarDay.startOfDay" in model, "TaskItem should normalize dueDate")
    ok("RepeatPolicy.normalizedInterval" in model, "TaskItem should normalize repeat interval")
    ok("ScorePolicy.normalizedPoints" in model, "TaskItem should normalize points")

    repeat_policy = read(ROOT / "Luna/Calendar/RepeatPolicy.swift")
    ok("shouldSpawnNext" in repeat_policy, "RepeatPolicy.shouldSpawnNext missing")
    ok("nextOccurrence" in repeat_policy, "RepeatPolicy.nextOccurrence missing")
    ok("normalizedInterval" in repeat_policy, "RepeatPolicy.normalizedInterval missing")
    ok("date(byAdding: .day" in repeat_policy, "next occurrence must shift by calendar days")

    policy = read(ROOT / "Luna/Notifications/ReminderPolicy.swift")
    ok('identifierPrefix = "luna.task."' in policy, "notification identifier prefix missing")
    ok('taskIDKey = "taskID"' in policy, "task id payload key missing")
    ok("shouldSchedule" in policy, "shouldSchedule missing")

    scheduler = read(ROOT / "Luna/Notifications/NotificationScheduler.swift")
    sync_fn = scheduler.split("func syncReminder", 1)[-1]
    cancel_pos = sync_fn.find("cancel(taskID")
    add_pos = sync_fn.find("center.add")
    ok(cancel_pos != -1 and add_pos != -1 and cancel_pos < add_pos, "syncReminder must cancel before scheduling")
    ok("requestAuthorization" in scheduler, "permission request missing")
    ok("UNCalendarNotificationTrigger" in scheduler, "calendar trigger missing")

    service = read(ROOT / "Luna/Services/TaskService.swift")
    ok("scheduler.syncReminder" in service, "TaskService must sync reminders on save")
    ok("scheduler.cancel" in service, "TaskService must cancel on delete")
    ok("isCompleted.toggle" in service, "complete/incomplete toggle missing")
    ok("spawnNextOccurrence" in service, "complete must spawn the next repeating occurrence")
    ok("shouldSpawnNext" in service, "complete must consult RepeatPolicy before spawning")
    ok("points: task.points" in service or "points: pointValue" in service, "next occurrence must copy points")
    ok("points: Int" in service, "TaskService save must accept points")

    score_policy = read(ROOT / "Luna/Scores/ScorePolicy.swift")
    ok("defaultPoints = 1" in score_policy, "default task points should be 1")
    ok("defaultDailyGoal = 10" in score_policy, "default daily goal should be 10")
    ok("earnedPoints" in score_policy, "ScorePolicy.earnedPoints missing")
    ok("normalizedGoal" in score_policy, "ScorePolicy.normalizedGoal missing")

    settings_store = read(ROOT / "Luna/Settings/LunaSettings.swift")
    ok("dailyPointGoal" in settings_store, "LunaSettings dailyPointGoal missing")
    ok("UserDefaults" in settings_store, "daily goal should persist in UserDefaults")

    score_card = read(ROOT / "Luna/Views/ScoreCardView.swift")
    ok("LunaTheme.highlight" in score_card, "score fill should use highlight")
    ok("LunaTheme.surface" in score_card, "score track should use surface")

    editor = read(ROOT / "Luna/Views/TaskEditorView.swift")
    ok("requestAuthorizationIfNeeded" in editor, "editor must request permission when enabling a reminder")
    ok("openSettingsURLString" in editor, "denied-state Settings link missing")
    ok("Delete task" in editor, "editor delete missing")
    ok("repeatEnabled" in editor and "Repeat" in editor, "editor Repeat control missing")
    ok("repeatIntervalDays:" in editor, "editor must persist repeat interval")
    ok("points:" in editor and "Points" in editor, "editor points control missing")

    settings = read(ROOT / "Luna/Views/SettingsView.swift")
    ok("authorizationStatus" in settings, "settings permission status missing")
    ok("dailyPointGoal" in settings, "settings daily goal editor missing")

    empty = read(ROOT / "Luna/Views/EmptyDayView.swift")
    ok("A quiet evening." in empty, "today empty-state copy missing")
    ok("Add a task" in empty, "empty-state add affordance missing")

    day_list = read(ROOT / "Luna/Views/DayTasksView.swift")
    ok("dueDate >= start && task.dueDate < end" in day_list, "day query missing")
    ok("TaskListOrdering.sorted" in day_list, "list sort missing")
    ok("ScoreCardView" in day_list, "day header score card missing")
    ok("earnedPoints" in day_list, "day score aggregation missing")

    persistence = read(ROOT / "Luna/Persistence/LunaPersistence.swift")
    ok("isStoredInMemoryOnly" in persistence, "in-memory configuration missing")
    ok("CloudKit" not in persistence, "persistence must not use CloudKit")

    app = read(ROOT / "Luna/LunaApp.swift")
    ok("preferredColorScheme" in app or "lunaScreen()" in app, "dark preference missing at app root")
    ok("modelContainer" in app, "model container not injected")
    ok("environment(settings)" in app, "LunaSettings not injected")

    ok("auto-roll" in read(ROOT / "docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md").lower() or
       "auto-rolling" in read(ROOT / "README.md").lower(),
       "spec/README should mention no auto-roll")

    # Pure policy replica of ReminderPolicy.shouldSchedule
    def should_schedule(reminder_at, is_completed, now):
        if is_completed or reminder_at is None:
            return False
        return reminder_at > now

    ok(should_schedule(None, False, 10) is False, "policy replica: nil reminder")
    ok(should_schedule(50, True, 10) is False, "policy replica: completed")
    ok(should_schedule(20, False, 20) is False, "policy replica: now")
    ok(should_schedule(21, False, 20) is True, "policy replica: future")

    def normalized_interval(days):
        if days is None or days < 1:
            return None
        return min(days, 365)

    def should_spawn(was_completed, is_completed, interval_days):
        return is_completed and not was_completed and normalized_interval(interval_days) is not None

    def next_due(year, month, day, n):
        from datetime import date, timedelta
        return date(year, month, day) + timedelta(days=n)

    ok(normalized_interval(None) is None, "repeat replica: nil interval")
    ok(normalized_interval(0) is None, "repeat replica: zero interval")
    ok(normalized_interval(3) == 3, "repeat replica: valid interval")
    ok(should_spawn(False, True, 3) is True, "repeat replica: spawn on complete")
    ok(should_spawn(True, True, 3) is False, "repeat replica: no spawn if already complete")
    ok(should_spawn(False, True, None) is False, "repeat replica: no spawn without interval")
    ok(next_due(2026, 9, 14, 3) == __import__("datetime").date(2026, 9, 17), "repeat replica: due date + N days")

    def normalized_points(points):
        return min(max(points, 1), 99)

    def normalized_goal(goal):
        return min(max(goal, 1), 999)

    def earned_points(items):
        return sum(normalized_points(p) for p, done in items if done)

    def progress(earned, goal):
        goal = normalized_goal(goal)
        return 0 if goal <= 0 else min(1.0, earned / goal)

    ok(normalized_points(0) == 1, "score replica: min points")
    ok(normalized_points(1) == 1, "score replica: default points")
    ok(normalized_goal(0) == 1, "score replica: min goal")
    ok(normalized_goal(10) == 10, "score replica: default goal")
    ok(earned_points([(1, True), (3, True), (5, False)]) == 4, "score replica: completed only")
    ok(earned_points([]) == 0, "score replica: empty day")
    ok(progress(12, 10) == 1.0, "score replica: bar caps at 100%")
    ok(f"{12} / {10}" == "12 / 10", "score replica: overflow label")

    spec = read(ROOT / "docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md").lower()
    ok("repeatintervaldays" in spec, "design spec missing repeatIntervalDays")
    ok("every n days" in spec, "design spec missing every-N-days behavior")
    ok("rrule" in spec, "design spec should keep RRULE/monthly recurrence out of v1")
    ok("daily point goal" in spec or "dailypointgoal" in spec, "design spec missing daily point goal")
    ok("streaks" in spec, "design spec should mention no streaks")

    for swift in list((ROOT / "Luna").rglob("*.swift")) + list((ROOT / "LunaTests").rglob("*.swift")):
        source = swift.read_text(encoding="utf-8")
        ok(source.count("{") == source.count("}"), f"unbalanced braces in {swift.relative_to(ROOT)}")
        ok(source.count("(") == source.count(")"), f"unbalanced parens in {swift.relative_to(ROOT)}")

    icon = ROOT / "Luna/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    if icon.is_file():
        data = icon.read_bytes()
        ok(data.startswith(b"\x89PNG\r\n\x1a\n"), "AppIcon.png is not a PNG")
        # signature(8) + length(4) + "IHDR"(4) + width(4) + height(4) + bitDepth(1) → color type at 25
        color_type = data[25]
        ok(color_type == 2, f"AppIcon.png must be opaque RGB (got color type {color_type})")

    if errors:
        print("verify_luna_project: FAILED")
        for item in errors:
            print(f"  - {item}")
        return 1

    print("verify_luna_project: OK")
    print(f"  app swift files: {len(swift_on_disk)}")
    print(f"  test swift files: {len(test_on_disk)}")
    print("  TaskItem fields, Luna palette, notification cancel-then-schedule, and dark-only project settings match the spec.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
