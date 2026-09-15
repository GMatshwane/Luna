import SwiftUI
import SwiftData
import UIKit

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationScheduler.self) private var scheduler
    @Query(sort: \Category.name) private var categories: [Category]

    let task: TaskItem?
    let defaultDueDate: Date

    @State private var title: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var repeatEnabled: Bool
    @State private var repeatKind: EditorRepeatKind
    @State private var repeatDays: Int
    @State private var weekdayPreset: WeekdayPreset
    @State private var customWeekdays: Set<Int>
    @State private var points: Int
    @State private var selectedCategory: Category?
    @State private var showingDeleteConfirm = false
    @State private var categoryEditor: CategoryEditorSession?

    init(task: TaskItem?, defaultDueDate: Date) {
        self.task = task
        self.defaultDueDate = defaultDueDate
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _dueDate = State(initialValue: CalendarDay.startOfDay(task?.dueDate ?? defaultDueDate))
        _reminderEnabled = State(initialValue: task?.reminderAt != nil)
        _reminderTime = State(initialValue: task?.reminderAt ?? CalendarDay.combining(day: task?.dueDate ?? defaultDueDate, time: Self.defaultReminderTime))
        let rule = task?.recurrence
        _repeatEnabled = State(initialValue: rule != nil)
        _repeatKind = State(initialValue: EditorRepeatKind(rule: rule))
        _repeatDays = State(initialValue: {
            if case .everyNDays(let days) = rule { return days }
            return RepeatPolicy.normalizedInterval(task?.repeatIntervalDays) ?? 1
        }())
        let preset = WeekdayPreset(rule: rule)
        _weekdayPreset = State(initialValue: preset)
        _customWeekdays = State(initialValue: {
            if case .weekdays(let days) = rule, preset == .custom { return days }
            return [Calendar.current.component(.weekday, from: task?.dueDate ?? defaultDueDate)]
        }())
        _points = State(initialValue: ScorePolicy.normalizedPoints(task?.points ?? ScorePolicy.defaultPoints))
        _selectedCategory = State(initialValue: task?.category)
    }

    private var canSave: Bool {
        !TaskItem.normalizedTitle(title).isEmpty
    }

    private var composedReminder: Date {
        CalendarDay.combining(day: dueDate, time: reminderTime)
    }

    private var reminderIsPast: Bool {
        reminderEnabled && composedReminder <= Date()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    editorField(title: "Title") {
                        TextField("What needs doing?", text: $title, axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                    }

                    editorField(title: "Notes") {
                        TextField("Optional details", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    editorField(title: "Due date") {
                        DatePicker(
                            "Due date",
                            selection: $dueDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .tint(LunaTheme.highlight)
                        .colorScheme(.dark)
                    }

                    editorField(title: "Points") {
                        Stepper(value: $points, in: ScorePolicy.minimumPoints...ScorePolicy.maximumPoints) {
                            Text(points == 1 ? "1 point" : "\(points) points")
                                .foregroundStyle(LunaTheme.highlight)
                        }
                        .accessibilityLabel(points == 1 ? "1 point" : "\(points) points")
                    }

                    categorySection

                    reminderSection

                    repeatSection

                    if task != nil {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Text("Delete task")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .foregroundStyle(LunaTheme.highlight)
                                .background(LunaTheme.surface, in: Capsule())
                                .overlay {
                                    Capsule().stroke(LunaTheme.border, lineWidth: 1)
                                }
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .lunaScreen()
            .navigationTitle(task == nil ? "New task" : "Edit task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LunaTheme.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                    .foregroundStyle(canSave ? LunaTheme.highlight : LunaTheme.border)
                    .fontWeight(.semibold)
                }
            }
            .toolbarBackground(LunaTheme.background, for: .navigationBar)
            .confirmationDialog("Delete this task?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    Task { await deleteTask() }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                await scheduler.refreshStatus()
            }
            .sheet(item: $categoryEditor) { session in
                CategoryEditorView(category: session.category) { saved in
                    selectedCategory = saved
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var orderedCategories: [Category] {
        categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY")
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(LunaTheme.secondary)

            categoryChoiceRow(title: "None", hex: nil, isSelected: selectedCategory == nil) {
                selectedCategory = nil
            }

            ForEach(orderedCategories, id: \.id) { category in
                categoryChoiceRow(
                    title: category.name,
                    hex: category.colorHex,
                    isSelected: selectedCategory?.id == category.id
                ) {
                    selectedCategory = category
                }
            }

            HStack(spacing: 12) {
                Button {
                    categoryEditor = CategoryEditorSession(category: nil)
                } label: {
                    Text("New category")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LunaTheme.highlight)
                }

                if selectedCategory != nil {
                    Button {
                        categoryEditor = CategoryEditorSession(category: selectedCategory)
                    } label: {
                        Text("Edit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LunaTheme.secondary)
                    }
                    .accessibilityLabel("Edit category")
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
        }
        .onChange(of: categories.map(\.id)) { _, ids in
            if let selectedCategory, !ids.contains(selectedCategory.id) {
                self.selectedCategory = nil
            }
        }
    }

    private func categoryChoiceRow(title: String, hex: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if hex != nil {
                    CategoryColorDot(hex: hex)
                } else {
                    Circle()
                        .stroke(LunaTheme.border, lineWidth: 1)
                        .frame(width: 10, height: 10)
                }
                Text(title)
                    .foregroundStyle(LunaTheme.highlight)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(LunaTheme.highlight)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $reminderEnabled) {
                Text("Reminder")
                    .foregroundStyle(LunaTheme.highlight)
            }
            .tint(LunaTheme.secondary)
            .onChange(of: reminderEnabled) { _, enabled in
                if enabled {
                    Task { await scheduler.requestAuthorizationIfNeeded() }
                }
            }

            if reminderEnabled {
                DatePicker(
                    "Reminder time",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .tint(LunaTheme.highlight)
                .colorScheme(.dark)

                if reminderIsPast {
                    Text("This time is in the past, so Luna will not send an alert.")
                        .font(.footnote)
                        .foregroundStyle(LunaTheme.secondary)
                }
            }

            if reminderEnabled && scheduler.isDenied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notifications are off, so this reminder will not fire. Enable them in Settings.")
                        .font(.footnote)
                        .foregroundStyle(LunaTheme.secondary)
                    Button("Open Settings") {
                        openSystemSettings()
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(LunaTheme.highlight)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LunaTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $repeatEnabled) {
                Text("Repeat")
                    .foregroundStyle(LunaTheme.highlight)
            }
            .tint(LunaTheme.secondary)
            .accessibilityHint("Repeat this task after you complete it.")

            if repeatEnabled {
                Picker("Repeat type", selection: $repeatKind) {
                    ForEach(EditorRepeatKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .tint(LunaTheme.highlight)
                .accessibilityLabel("Repeat type")

                repeatKindControls

                Text(repeatKind.footnote(repeatDays: repeatDays))
                    .font(.footnote)
                    .foregroundStyle(LunaTheme.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var repeatKindControls: some View {
        switch repeatKind {
        case .everyNDays:
            Stepper(value: $repeatDays, in: RepeatPolicy.minimumIntervalDays...RepeatPolicy.maximumIntervalDays) {
                Text(RepeatPolicy.summaryLabel(intervalDays: repeatDays))
                    .foregroundStyle(LunaTheme.highlight)
            }
            .accessibilityLabel(RepeatPolicy.summaryLabel(intervalDays: repeatDays))
        case .weekdays:
            Picker("Weekdays", selection: $weekdayPreset) {
                Text("Monday–Friday").tag(WeekdayPreset.weekdays)
                Text("Weekends").tag(WeekdayPreset.weekends)
                Text("Custom").tag(WeekdayPreset.custom)
            }
            .pickerStyle(.menu)
            .tint(LunaTheme.highlight)
            .accessibilityLabel("Weekday pattern")

            if weekdayPreset == .custom {
                weekdaySelector
            }
        case .weekly, .monthly, .yearly:
            EmptyView()
        }
    }

    private var weekdaySelector: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                let selected = customWeekdays.contains(weekday)
                Button {
                    if selected {
                        customWeekdays.remove(weekday)
                    } else {
                        customWeekdays.insert(weekday)
                    }
                } label: {
                    Text(shortWeekdaySymbol(weekday))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? LunaTheme.background : LunaTheme.highlight)
                        .background(selected ? LunaTheme.highlight : LunaTheme.background.opacity(0.4), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(weekdayAccessibilityName(weekday))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Custom weekdays")
    }

    private func editorField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(LunaTheme.secondary)
            content()
                .foregroundStyle(LunaTheme.highlight)
                .tint(LunaTheme.highlight)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
        }
    }

    private func save() async {
        let reminderAt = reminderEnabled ? composedReminder : nil
        _ = await TaskService(context: modelContext, scheduler: scheduler).save(
            existing: task,
            title: title,
            notes: notes,
            dueDate: dueDate,
            reminderAt: reminderAt,
            recurrence: composedRecurrence(),
            points: points,
            category: selectedCategory
        )
        dismiss()
    }

    private func composedRecurrence() -> RecurrenceRule? {
        guard repeatEnabled else { return nil }
        switch repeatKind {
        case .everyNDays:
            return .everyNDays(repeatDays)
        case .weekdays:
            return .weekdays(selectedWeekdays)
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly(dayOfMonth: preservedMonthDay)
        case .yearly:
            return .yearly(month: preservedYearMonth.month, day: preservedYearMonth.day)
        }
    }

    private var selectedWeekdays: Set<Int> {
        switch weekdayPreset {
        case .weekdays:
            return RepeatPolicy.mondayThroughFriday
        case .weekends:
            return RepeatPolicy.weekendDays
        case .custom:
            if customWeekdays.isEmpty {
                return [Calendar.current.component(.weekday, from: dueDate)]
            }
            return customWeekdays
        }
    }

    private var preservedMonthDay: Int {
        if let existing = task?.recurrence,
           case .monthly(let stored) = existing,
           CalendarDay.isSameDay(dueDate, task?.dueDate ?? dueDate) {
            return stored
        }
        return Calendar.current.component(.day, from: dueDate)
    }

    private var preservedYearMonth: (month: Int, day: Int) {
        if let existing = task?.recurrence,
           case .yearly(let month, let day) = existing,
           CalendarDay.isSameDay(dueDate, task?.dueDate ?? dueDate) {
            return (month, day)
        }
        let parts = Calendar.current.dateComponents([.month, .day], from: dueDate)
        return (parts.month ?? 1, parts.day ?? 1)
    }

    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private func shortWeekdaySymbol(_ weekday: Int) -> String {
        let symbols = ["", "S", "M", "T", "W", "T", "F", "S"]
        return (1...7).contains(weekday) ? symbols[weekday] : ""
    }

    private func weekdayAccessibilityName(_ weekday: Int) -> String {
        var calendar = Calendar.current
        calendar.locale = .current
        let symbols = calendar.weekdaySymbols
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return "Weekday" }
        return symbols[index]
    }

    private func deleteTask() async {
        guard let task else { return }
        await TaskService(context: modelContext, scheduler: scheduler).delete(task)
        dismiss()
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private static var defaultReminderTime: Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

private struct CategoryEditorSession: Identifiable {
    let id = UUID()
    let category: Category?
}

private enum EditorRepeatKind: String, CaseIterable, Identifiable {
    case everyNDays
    case weekdays
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everyNDays: return "Every N days"
        case .weekdays: return "Specific weekdays"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }

    init(rule: RecurrenceRule?) {
        switch rule {
        case .weekdays:
            self = .weekdays
        case .weekly:
            self = .weekly
        case .monthly:
            self = .monthly
        case .yearly:
            self = .yearly
        default:
            self = .everyNDays
        }
    }

    func footnote(repeatDays: Int) -> String {
        let spawn = "When you complete this task, Luna keeps it here and adds the next copy"
        switch self {
        case .everyNDays:
            let when = repeatDays == 1 ? "tomorrow" : "in \(repeatDays) days"
            return "\(spawn) \(when)."
        case .weekdays:
            return "\(spawn) on the next selected weekday."
        case .weekly:
            return "\(spawn) next week on the same weekday."
        case .monthly:
            return "\(spawn) next month on the same day, or the last day of that month."
        case .yearly:
            return "\(spawn) next year on the same date."
        }
    }
}

private enum WeekdayPreset: String, CaseIterable, Identifiable {
    case weekdays
    case weekends
    case custom

    var id: String { rawValue }

    init(rule: RecurrenceRule?) {
        guard case .weekdays(let days) = rule else {
            self = .weekdays
            return
        }
        if days == RepeatPolicy.mondayThroughFriday {
            self = .weekdays
        } else if days == RepeatPolicy.weekendDays {
            self = .weekends
        } else {
            self = .custom
        }
    }
}
