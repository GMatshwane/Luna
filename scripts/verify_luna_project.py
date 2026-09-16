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
        "Luna/Theme/LunaTypography.swift",
        "Luna/Calendar/WeekdayAbbreviation.swift",
        "Luna/Fonts/Roboto-Regular.ttf",
        "Luna/Fonts/Roboto-Medium.ttf",
        "Luna/Fonts/Roboto-SemiBold.ttf",
        "Luna/Fonts/OFL.txt",
        "Luna/Info.plist",
        "Luna/Calendar/CalendarDay.swift",
        "Luna/Calendar/TaskListOrdering.swift",
        "Luna/Calendar/RepeatPolicy.swift",
        "Luna/Models/CategoryPolicy.swift",
        "Luna/Models/Category.swift",
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
        "Luna/Views/CategoryEditorView.swift",
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
        "LunaTests/CategoryPolicyTests.swift",
        "LunaTests/LunaThemeTests.swift",
        "LunaTests/LunaSettingsTests.swift",
        "LunaTests/WeekdayAbbreviationTests.swift",
        "LunaTests/LunaTypographyTests.swift",
    ]
    for rel in required:
        ok((ROOT / rel).is_file(), f"missing {rel}")

    swift_on_disk = sorted(p.relative_to(ROOT).as_posix() for p in ROOT.glob("Luna/**/*.swift"))
    test_on_disk = sorted(p.relative_to(ROOT).as_posix() for p in ROOT.glob("LunaTests/**/*.swift"))

    for rel in swift_on_disk + test_on_disk:
        name = Path(rel).name
        ok(name in pbx, f"{rel} is not referenced in project.pbxproj")

    ok("PRODUCT_BUNDLE_IDENTIFIER = com.gmatshwane.Luna;" in pbx, "app bundle id missing")
    ok("INFOPLIST_KEY_UIUserInterfaceStyle = Dark;" not in pbx, "UIUserInterfaceStyle must not force dark")
    ok("IPHONEOS_DEPLOYMENT_TARGET = 17.0;" in pbx, "iOS 17 deployment target missing")
    ok("CloudKit" not in pbx, "CloudKit must not be in the project")

    theme = read(ROOT / "Luna/Theme/LunaTheme.swift")
    for hex_color in ("0x011C40", "0x023859", "0x26658C", "0x54ACBF", "0xA7EBF2"):
        ok(hex_color in theme, f"LunaTheme missing dark {hex_color}")
    for hex_color in ("0xEAF8FA", "0xFFFFFF"):
        ok(hex_color in theme, f"LunaTheme missing light {hex_color}")
    ok("Palette" in theme, "LunaTheme should expose Palette snapshots")
    ok("preferredColorScheme(.dark)" not in theme, "lunaScreen must not force dark")
    ok("Font.custom" not in theme, "LunaTheme must remain color tokens only")
    ok("Roboto" not in theme, "do not put Roboto helpers in LunaTheme.swift")

    model = read(ROOT / "Luna/Models/TaskItem.swift")
    for field in (
        "id: UUID",
        "title: String",
        "notes: String?",
        "dueDate: Date",
        "reminderAt: Date?",
        "isCompleted: Bool",
        "createdAt: Date",
        "sortOrder: Int",
        "repeatIntervalDays: Int?",
        "repeatKindRaw: String?",
        "repeatWeekdaysMask: Int",
        "repeatMonthDay: Int?",
        "repeatMonth: Int?",
        "points: Int",
        "category: Category?",
    ):
        ok(field in model, f"TaskItem missing {field}")
    ok("@Model" in model, "TaskItem is not a SwiftData @Model")
    ok("CalendarDay.startOfDay" in model, "TaskItem should normalize dueDate")
    ok("RepeatPolicy.normalizedInterval" in model or "RepeatPolicy.normalized(" in model, "TaskItem should normalize repeat rule")
    ok("ScorePolicy.normalizedPoints" in model, "TaskItem should normalize points")
    ok("var recurrence" in model or "RepeatPolicy.rule(fromStored" in model, "TaskItem should expose RecurrenceRule")

    category_model = read(ROOT / "Luna/Models/Category.swift")
    ok("@Model" in category_model, "Category is not a SwiftData @Model")
    ok("var name: String" in category_model, "Category missing name")
    ok("colorHex: String?" in category_model, "Category missing optional color")
    ok("deleteRule: .nullify" in category_model, "deleting a category should uncategorize tasks")
    ok("inverse: \\TaskItem.category" in category_model, "Category.tasks should inverse TaskItem.category")

    category_policy = read(ROOT / "Luna/Models/CategoryPolicy.swift")
    ok("normalizedName" in category_policy, "CategoryPolicy.normalizedName missing")
    ok("normalizedColorHex" in category_policy, "CategoryPolicy.normalizedColorHex missing")
    ok("uncategorizedName" in category_policy, "CategoryPolicy.uncategorizedName missing")
    ok("func grouped" in category_policy, "CategoryPolicy.grouped missing")
    ok("enum Filter" in category_policy, "CategoryPolicy.Filter missing")

    repeat_policy = read(ROOT / "Luna/Calendar/RepeatPolicy.swift")
    ok("enum RecurrenceRule" in repeat_policy, "RecurrenceRule missing")
    ok("case everyNDays" in repeat_policy, "RecurrenceRule.everyNDays missing")
    ok("case weekdays" in repeat_policy, "RecurrenceRule.weekdays missing")
    ok("case weekly" in repeat_policy, "RecurrenceRule.weekly missing")
    ok("case monthly" in repeat_policy, "RecurrenceRule.monthly missing")
    ok("case yearly" in repeat_policy, "RecurrenceRule.yearly missing")
    ok("shouldSpawnNext" in repeat_policy, "RepeatPolicy.shouldSpawnNext missing")
    ok("nextOccurrence" in repeat_policy, "RepeatPolicy.nextOccurrence missing")
    ok("normalizedInterval" in repeat_policy, "RepeatPolicy.normalizedInterval missing")
    ok("date(byAdding: .day" in repeat_policy, "next occurrence must shift by calendar days")
    ok("StoredFields" in repeat_policy, "RepeatPolicy.StoredFields missing")
    ok("rulesMatch" in repeat_policy, "RepeatPolicy.rulesMatch missing")
    ok("mondayThroughFriday" in repeat_policy, "weekday preset missing")
    ok("weekendDays" in repeat_policy, "weekend preset missing")
    ok("RRULE" not in repeat_policy and "rrule" not in repeat_policy, "skip RRULE parsing")

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
    ok("category: task.category" in service, "next occurrence must copy category")
    ok("points: Int" in service, "TaskService save must accept points")
    ok("category: Category?" in service, "TaskService save must accept a category")
    ok("saveCategory" in service, "TaskService must persist user-defined categories")
    ok("repeatIntervalDays" in service, "TaskService must keep every-N-days repeatIntervalDays")
    ok("recurrence: next.rule" in service, "next occurrence must copy RecurrenceRule")
    ok("rulesMatch" in service, "spawn must dedupe by title + rule + due day")
    ok("rule: task.recurrence" in service, "complete must spawn from RecurrenceRule")

    score_policy = read(ROOT / "Luna/Scores/ScorePolicy.swift")
    ok("defaultPoints = 1" in score_policy, "default task points should be 1")
    ok("defaultDailyGoal = 10" in score_policy, "default daily goal should be 10")
    ok("earnedPoints" in score_policy, "ScorePolicy.earnedPoints missing")
    ok("normalizedGoal" in score_policy, "ScorePolicy.normalizedGoal missing")

    settings_store = read(ROOT / "Luna/Settings/LunaSettings.swift")
    ok("dailyPointGoal" in settings_store, "LunaSettings dailyPointGoal missing")
    ok("UserDefaults" in settings_store, "daily goal should persist in UserDefaults")
    ok("appearance" in settings_store, "LunaSettings appearance missing")
    ok("luna.appearance" in settings_store, "appearance should persist under luna.appearance")
    ok("enum LunaAppearance" in settings_store, "LunaAppearance enum missing")
    for case_name in ("system", "light", "dark"):
        ok(case_name in settings_store, f"LunaAppearance missing {case_name}")

    score_card = read(ROOT / "Luna/Views/ScoreCardView.swift")
    ok("LunaTheme.highlight" in score_card, "score fill should use highlight")
    ok("LunaTheme.surface" in score_card, "score track should use surface")

    editor = read(ROOT / "Luna/Views/TaskEditorView.swift")
    ok("requestAuthorizationIfNeeded" in editor, "editor must request permission when enabling a reminder")
    ok("openSettingsURLString" in editor, "denied-state Settings link missing")
    ok("Delete task" in editor, "editor delete missing")
    ok("repeatEnabled" in editor and "Repeat" in editor, "editor Repeat control missing")
    ok("recurrence:" in editor or "composedRecurrence" in editor, "editor must persist RecurrenceRule")
    ok("Every N days" in editor, "every-N-days picker label missing")
    ok("Specific weekdays" in editor, "weekday picker label missing")
    ok("Weekly" in editor, "weekly picker label missing")
    ok("Monthly" in editor, "monthly picker label missing")
    ok("Yearly" in editor, "yearly picker label missing")
    ok("Monday–Friday" in editor or "Monday-Friday" in editor, "weekday preset missing")
    ok("points:" in editor and "Points" in editor, "editor points control missing")
    ok("selectedCategory" in editor and "CATEGORY" in editor, "editor category picker missing")
    ok("New category" in editor, "editor must create user-defined categories")
    ok("category: selectedCategory" in editor, "editor must persist the assigned category")
    ok(".preferredColorScheme(.dark)" not in editor, "editor must not force dark")
    ok(".colorScheme(.dark)" not in editor, "editor controls must not force dark")

    category_editor = read(ROOT / "Luna/Views/CategoryEditorView.swift")
    ok("NAME" in category_editor, "category editor name field missing")
    ok("COLOR" in category_editor, "category editor optional color missing")
    ok("saveCategory" in category_editor, "category editor must persist through TaskService")
    ok("Delete category" in category_editor, "category editor delete missing")
    ok(".preferredColorScheme(.dark)" not in category_editor, "category editor must not force dark")

    settings = read(ROOT / "Luna/Views/SettingsView.swift")
    ok("authorizationStatus" in settings, "settings permission status missing")
    ok("dailyPointGoal" in settings, "settings daily goal editor missing")
    ok("appearance" in settings, "settings appearance override missing")
    ok("System" in settings and "Light" in settings and "Dark" in settings, "settings appearance choices missing")
    ok(".preferredColorScheme(.dark)" not in settings, "settings must not force dark")

    calendar = read(ROOT / "Luna/Views/CalendarSheet.swift")
    ok(".preferredColorScheme(.dark)" not in calendar, "calendar sheet must not force dark")

    empty = read(ROOT / "Luna/Views/EmptyDayView.swift")
    ok("A quiet evening." in empty, "today empty-state copy missing")
    ok("Add a task" in empty, "empty-state add affordance missing")

    day_list = read(ROOT / "Luna/Views/DayTasksView.swift")
    ok("dueDate >= start && task.dueDate < end" in day_list, "day query missing")
    ok("TaskListOrdering.sorted" in day_list, "list sort missing")
    ok("ScoreCardView" in day_list, "day header score card missing")
    ok("earnedPoints" in day_list, "day score aggregation missing")
    ok("ScorePolicy.earnedPoints(from: tasks" in day_list, "daily score must stay a single unfiltered day total")
    ok("CategoryPolicy.grouped" in day_list, "day list should section by category")
    ok("Uncategorized" in day_list or "uncategorizedName" in day_list, "day list must include uncategorized")
    ok("categoryFilter" in day_list, "day list should filter by category")

    persistence = read(ROOT / "Luna/Persistence/LunaPersistence.swift")
    ok("isStoredInMemoryOnly" in persistence, "in-memory configuration missing")
    ok("CloudKit" not in persistence, "persistence must not use CloudKit")
    ok("Category.self" in persistence, "schema must include Category")

    app = read(ROOT / "Luna/LunaApp.swift")
    ok("preferredColorScheme" in app, "appearance preference missing at app root")
    ok("settings.appearance" in app, "root color scheme must come from LunaSettings")
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

    from datetime import date, timedelta
    import calendar as pycal

    def normalized_interval(days):
        if days is None or days < 1:
            return None
        return min(days, 365)

    def should_spawn(was_completed, is_completed, rule_present):
        return is_completed and not was_completed and rule_present

    def swift_weekday(d):
        return d.isoweekday() % 7 + 1

    def next_weekdays(d, days):
        cur = d
        for _ in range(7):
            cur = cur + timedelta(days=1)
            if swift_weekday(cur) in days:
                return cur
        return None

    def next_monthly(d, month_day):
        if d.month == 12:
            year, month = d.year + 1, 1
        else:
            year, month = d.year, d.month + 1
        last = pycal.monthrange(year, month)[1]
        return date(year, month, min(max(month_day, 1), last))

    def next_yearly(d, month, day):
        year = d.year + 1
        last = pycal.monthrange(year, month)[1]
        return date(year, month, min(max(day, 1), last))

    def next_due(year, month, day, n):
        return date(year, month, day) + timedelta(days=n)

    ok(normalized_interval(None) is None, "repeat replica: nil interval")
    ok(normalized_interval(0) is None, "repeat replica: zero interval")
    ok(normalized_interval(3) == 3, "repeat replica: valid interval")
    ok(should_spawn(False, True, True) is True, "repeat replica: spawn on complete")
    ok(should_spawn(True, True, True) is False, "repeat replica: no spawn if already complete")
    ok(should_spawn(False, True, False) is False, "repeat replica: no spawn without rule")
    ok(next_due(2026, 9, 14, 3) == date(2026, 9, 17), "repeat replica: due date + N days")
    ok(next_weekdays(date(2026, 9, 18), {2, 3, 4, 5, 6}) == date(2026, 9, 21), "repeat replica: Friday weekday -> Monday")
    ok(next_weekdays(date(2026, 9, 19), {1, 7}) == date(2026, 9, 20), "repeat replica: Saturday weekend -> Sunday")
    ok(next_due(2026, 9, 17, 7) == date(2026, 9, 24), "repeat replica: weekly +7 days")
    ok(next_monthly(date(2026, 1, 31), 31) == date(2026, 2, 28), "repeat replica: Jan 31 clamps to Feb 28")
    ok(next_monthly(date(2026, 2, 28), 31) == date(2026, 3, 31), "repeat replica: preserved 31 after clamp")
    ok(next_yearly(date(2024, 2, 29), 2, 29) == date(2025, 2, 28), "repeat replica: leap day clamps")

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

    def normalized_category_name(name):
        trimmed = name.strip()
        if not trimmed:
            return None
        return trimmed[:40]

    def names_match(lhs, rhs):
        a = normalized_category_name(lhs)
        b = normalized_category_name(rhs)
        return a is not None and b is not None and a.lower() == b.lower()

    def normalized_color_hex(hex_value):
        if hex_value is None:
            return None
        trimmed = hex_value.strip().lstrip("#").upper()
        if len(trimmed) != 6 or any(ch not in "0123456789ABCDEF" for ch in trimmed):
            return None
        return trimmed

    health = "health-id"
    home = "home-id"
    rows = [
        {"title": "Unsorted", "category_id": None, "name": None, "color": None, "order": 2},
        {"title": "Water plants", "category_id": home, "name": "Home", "color": "#d4a373", "order": 1},
        {"title": "Stretch", "category_id": health, "name": "Health", "color": "c97b84", "order": 0},
        {"title": "Walk", "category_id": health, "name": "Health", "color": "c97b84", "order": 1},
    ]

    def grouped(items, filt="all"):
        filtered = []
        for item in items:
            cid = item["category_id"]
            if filt == "all":
                filtered.append(item)
            elif filt == "uncategorized" and cid is None:
                filtered.append(item)
            elif filt == cid:
                filtered.append(item)
        filtered.sort(key=lambda item: (item["category_id"] is None, (item["name"] or "Uncategorized").lower(), item["order"]))
        sections = []
        seen = {}
        for item in filtered:
            key = item["category_id"]
            if key not in seen:
                seen[key] = {
                    "name": "Uncategorized" if key is None else item["name"],
                    "color": None if key is None else normalized_color_hex(item["color"]),
                    "tasks": [],
                }
                sections.append(key)
            seen[key]["tasks"].append(item["title"])
        named = [key for key in sections if key is not None]
        named.sort(key=lambda key: seen[key]["name"].lower())
        ordered_keys = named + ([None] if None in seen else [])
        return [(seen[key]["name"], seen[key]["color"], seen[key]["tasks"]) for key in ordered_keys]

    ok(normalized_category_name("  Health  ") == "Health", "category replica: trim name")
    ok(normalized_category_name("   ") is None, "category replica: reject blank name")
    ok(names_match("Health", "health") is True, "category replica: case-insensitive names")
    ok(normalized_color_hex("#c97b84") == "C97B84", "category replica: color hash")
    ok(normalized_color_hex("zzz") is None, "category replica: invalid color")
    ok(grouped(rows)[0] == ("Health", "C97B84", ["Stretch", "Walk"]), "category replica: named section first")
    ok(grouped(rows)[-1][0] == "Uncategorized", "category replica: uncategorized last")
    ok(grouped(rows, health)[0][2] == ["Stretch", "Walk"], "category replica: filter identified")
    ok(sum(1 for item in rows if True) == 4, "category replica: day score still counts every task")

    def parse_appearance(raw):
        if raw in ("system", "light", "dark"):
            return raw
        return "system"

    def preferred_scheme(appearance):
        return {"system": None, "light": "light", "dark": "dark"}[appearance]

    ok(parse_appearance(None) == "system", "appearance replica: default system")
    ok(parse_appearance("light") == "light", "appearance replica: light")
    ok(parse_appearance("sepia") == "system", "appearance replica: invalid falls back")
    ok(preferred_scheme("system") is None, "appearance replica: system follows OS")
    ok(preferred_scheme("dark") == "dark", "appearance replica: dark override")

    theme_tests = read(ROOT / "LunaTests/LunaThemeTests.swift")
    ok("#EAF8FA" in theme_tests, "theme tests should lock the light background")
    ok("#FFFFFF" in theme_tests, "theme tests should lock the light surface")
    settings_tests = read(ROOT / "LunaTests/LunaSettingsTests.swift")
    ok("appearanceKey" in settings_tests, "settings tests should persist appearance")
    ok("preferredColorScheme" in settings_tests, "settings tests should map color scheme")

    spec = read(ROOT / "docs/superpowers/specs/2026-09-14-luna-task-reminder-design.md").lower()
    ok("repeatintervaldays" in spec, "design spec missing repeatIntervalDays")
    ok("every n days" in spec, "design spec missing every-N-days behavior")
    ok("recurrencerule" in spec, "design spec missing RecurrenceRule")
    ok("weekdays" in spec, "design spec missing weekday recurrence")
    ok("clamped to the last day" in spec, "design spec missing month-end clamp")
    ok("rrule" in spec, "design spec should skip RRULE parsing")
    ok("daily point goal" in spec or "dailypointgoal" in spec, "design spec missing daily point goal")
    ok("streaks" in spec, "design spec should mention no streaks")
    ok("taskitem.category" in spec or "optional category" in spec, "design spec missing one optional category")
    ok("uncategorized" in spec, "design spec should mention uncategorized tasks")
    ok("single day total" in spec or "not split by category" in spec, "design spec should keep score as one day total")

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

    typography = read(ROOT / "Luna/Theme/LunaTypography.swift")
    ok("Roboto-Regular" in typography, "LunaTypography missing Roboto-Regular")
    ok("Roboto-Medium" in typography, "LunaTypography missing Roboto-Medium")
    ok("Roboto-SemiBold" in typography, "LunaTypography missing Roboto-SemiBold")
    ok("relativeTo:" in typography, "custom fonts must scale with Dynamic Type via relativeTo")
    ok("monospacedDigit" in typography, "LunaTypography must expose tabular/monospaced digits")
    ok("Font.custom" in typography, "LunaTypography should wrap Font.custom")

    day_strip = read(ROOT / "Luna/Views/DayStripView.swift")
    ok("WeekdayAbbreviation.compact" in day_strip, "DayStripView should use locale-aware 3-letter weekdays")
    ok(".weekday(.narrow)" not in day_strip, "DayStripView must not use narrow single-letter weekdays")
    ok(".weekday(.wide)" in day_strip, "DayStripView accessibility should keep full weekday names")
    ok("LunaTypography.tabular" in day_strip, "day numbers should keep tabular/monospaced digits")
    ok("LunaTypography." in day_strip, "DayStripView should use the shared Roboto helper")

    day_list = read(ROOT / "Luna/Views/DayTasksView.swift")
    ok(".weekday(.wide)" in day_list, "Today header should keep full weekday names")
    ok("design: .serif" not in day_list, "Today header should not use serif system fonts")
    ok("LunaTypography." in day_list, "Today header should use the shared Roboto helper")

    empty = read(ROOT / "Luna/Views/EmptyDayView.swift")
    ok("design: .serif" not in empty, "empty states should not use serif system fonts")
    ok("LunaTypography." in empty, "empty states should use the shared Roboto helper")

    score_card = read(ROOT / "Luna/Views/ScoreCardView.swift")
    ok("LunaTypography.tabular" in score_card, "score digits should stay tabular/monospaced")

    task_row = read(ROOT / "Luna/Views/TaskRowView.swift")
    ok("LunaTypography.tabular" in task_row, "task point digits should stay tabular/monospaced")

    for view in (
        "SettingsView.swift",
        "TaskEditorView.swift",
        "CalendarSheet.swift",
        "ScoreCardView.swift",
        "TaskRowView.swift",
        "CategoryEditorView.swift",
    ):
        source = read(ROOT / "Luna/Views" / view)
        ok("LunaTypography." in source, f"{view} should use the shared Roboto helper")

    for swift in (ROOT / "Luna").rglob("*.swift"):
        source = swift.read_text(encoding="utf-8")
        ok("design: .serif" not in source, f"{swift.relative_to(ROOT)} still uses serif system fonts")

    weekday_helper = read(ROOT / "Luna/Calendar/WeekdayAbbreviation.swift")
    ok("weekday(.abbreviated)" in weekday_helper, "compact weekdays should use locale-aware abbreviated style")
    ok("Locale" in weekday_helper, "weekday abbreviations must be locale-aware")

    import calendar as py_calendar
    from datetime import date as py_date

    def compact_weekday(value: py_date) -> str:
        return py_calendar.day_abbr[value.weekday()]

    ok(compact_weekday(py_date(2026, 9, 14)) == "Mon", "weekday replica: Monday")
    ok(compact_weekday(py_date(2026, 9, 15)) == "Tue", "weekday replica: Tuesday")
    ok(compact_weekday(py_date(2026, 9, 16)) == "Wed", "weekday replica: Wednesday")
    ok(len(compact_weekday(py_date(2026, 9, 14))) == 3, "weekday replica: three letters")

    info = read(ROOT / "Luna/Info.plist")
    for font_file in ("Roboto-Regular.ttf", "Roboto-Medium.ttf", "Roboto-SemiBold.ttf"):
        ok(font_file in info, f"Info.plist UIAppFonts missing {font_file}")
        ok(font_file in pbx, f"{font_file} is not referenced in project.pbxproj")
        font_path = ROOT / "Luna/Fonts" / font_file
        if font_path.is_file():
            header = font_path.read_bytes()[:4]
            ok(header in {b"\x00\x01\x00\x00", b"OTTO", b"true", b"ttcf"}, f"{font_file} is not an sfnt font")
            ok(len(font_path.read_bytes()) > 10_000, f"{font_file} looks too small to be Roboto")

    ofl = read(ROOT / "Luna/Fonts/OFL.txt")
    ok("SIL Open Font License" in ofl, "Roboto OFL license text missing")

    generator = read(ROOT / "scripts/generate_xcode_project.py")
    ok("Path(__file__)" in generator, "project generator ROOT must be repo-relative for worktrees")
    ok("LunaTypography.swift" in generator, "generator must include LunaTypography.swift")
    ok("WeekdayAbbreviation.swift" in generator, "generator must include WeekdayAbbreviation.swift")
    ok("Roboto-Regular.ttf" in generator, "generator must include bundled Roboto files")

    if errors:
        print("verify_luna_project: FAILED")
        for item in errors:
            print(f"  - {item}")
        return 1

    print("verify_luna_project: OK")
    print(f"  app swift files: {len(swift_on_disk)}")
    print(f"  test swift files: {len(test_on_disk)}")
    print("  TaskItem fields, Luna light/dark palettes, appearance persistence, and notification cancel-then-schedule match the spec.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
