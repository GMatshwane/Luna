import SwiftUI
import SwiftData
import UIKit

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationScheduler.self) private var scheduler

    let task: TaskItem?
    let defaultDueDate: Date

    @State private var title: String
    @State private var notes: String
    @State private var dueDate: Date
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var repeatEnabled: Bool
    @State private var repeatDays: Int
    @State private var showingDeleteConfirm = false

    init(task: TaskItem?, defaultDueDate: Date) {
        self.task = task
        self.defaultDueDate = defaultDueDate
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _dueDate = State(initialValue: CalendarDay.startOfDay(task?.dueDate ?? defaultDueDate))
        _reminderEnabled = State(initialValue: task?.reminderAt != nil)
        _reminderTime = State(initialValue: task?.reminderAt ?? CalendarDay.combining(day: task?.dueDate ?? defaultDueDate, time: Self.defaultReminderTime))
        let interval = RepeatPolicy.normalizedInterval(task?.repeatIntervalDays)
        _repeatEnabled = State(initialValue: interval != nil)
        _repeatDays = State(initialValue: interval ?? 1)
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
        }
        .preferredColorScheme(.dark)
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
            .accessibilityHint("Repeat this task every N days after you complete it.")

            if repeatEnabled {
                Stepper(value: $repeatDays, in: RepeatPolicy.minimumIntervalDays...RepeatPolicy.maximumIntervalDays) {
                    Text(RepeatPolicy.summaryLabel(intervalDays: repeatDays))
                        .foregroundStyle(LunaTheme.highlight)
                }
                .accessibilityLabel(RepeatPolicy.summaryLabel(intervalDays: repeatDays))

                Text("When you complete this task, Luna keeps it here and adds the next copy \(repeatDays == 1 ? "tomorrow" : "in \(repeatDays) days").")
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
        let interval = repeatEnabled ? repeatDays : nil
        _ = await TaskService(context: modelContext, scheduler: scheduler).save(
            existing: task,
            title: title,
            notes: notes,
            dueDate: dueDate,
            reminderAt: reminderAt,
            repeatIntervalDays: interval
        )
        dismiss()
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
