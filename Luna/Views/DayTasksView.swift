import SwiftUI
import SwiftData

struct DayTasksView: View {
    @Binding var selectedDate: Date
    var onAdd: () -> Void
    var onSelect: (TaskItem) -> Void

    var body: some View {
        DayTaskList(
            dayStart: CalendarDay.startOfDay(selectedDate),
            selectedDate: $selectedDate,
            onAdd: onAdd,
            onSelect: onSelect
        )
        .id(CalendarDay.startOfDay(selectedDate).timeIntervalSince1970)
    }
}

private struct DayTaskList: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(LunaSettings.self) private var settings

    let dayStart: Date
    @Binding var selectedDate: Date
    var onAdd: () -> Void
    var onSelect: (TaskItem) -> Void

    @Query private var tasks: [TaskItem]

    init(
        dayStart: Date,
        selectedDate: Binding<Date>,
        onAdd: @escaping () -> Void,
        onSelect: @escaping (TaskItem) -> Void
    ) {
        self.dayStart = dayStart
        self._selectedDate = selectedDate
        self.onAdd = onAdd
        self.onSelect = onSelect

        let start = dayStart
        let end = CalendarDay.endOfDay(dayStart)
        _tasks = Query(
            filter: #Predicate<TaskItem> { task in
                task.dueDate >= start && task.dueDate < end
            }
        )
    }

    private var orderedTasks: [TaskItem] {
        TaskListOrdering.sorted(tasks) { $0.sortKey }
    }

    private var earnedPoints: Int {
        ScorePolicy.earnedPoints(from: tasks, points: { $0.points }, isCompleted: { $0.isCompleted })
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                DayStripView(selectedDate: $selectedDate)
                    .padding(.top, 18)
                    .padding(.bottom, 8)

                if orderedTasks.isEmpty {
                    EmptyDayView(isToday: CalendarDay.isSameDay(selectedDate, Date()), onAdd: onAdd)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(orderedTasks, id: \.id) { task in
                                TaskRowView(
                                    task: task,
                                    onToggle: {
                                        Task { await TaskService(context: modelContext, scheduler: scheduler).toggleCompleted(task) }
                                    },
                                    onOpen: { onSelect(task) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 96)
                    }
                    .scrollIndicators(.hidden)
                }
            }

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(LunaTheme.background)
                    .frame(width: 56, height: 56)
                    .background(LunaTheme.highlight, in: Circle())
                    .shadow(color: LunaTheme.highlight.opacity(0.25), radius: 12, y: 4)
            }
            .accessibilityLabel("Add task")
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .background(LunaTheme.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LUNA")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .tracking(6)
                .foregroundStyle(LunaTheme.secondary)

            Text(titleText)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(LunaTheme.highlight)

            Text(subtitleText)
                .font(.subheadline)
                .foregroundStyle(LunaTheme.secondary)

            ScoreCardView(earned: earnedPoints, goal: settings.dailyPointGoal)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titleText: String {
        if CalendarDay.isSameDay(selectedDate, Date()) {
            return "Today"
        }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()),
           CalendarDay.isSameDay(selectedDate, yesterday) {
            return "Yesterday"
        }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
           CalendarDay.isSameDay(selectedDate, tomorrow) {
            return "Tomorrow"
        }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var subtitleText: String {
        selectedDate.formatted(.dateTime.month(.wide).day().year())
    }
}
