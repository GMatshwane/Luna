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
    @Query(sort: \Category.name) private var categories: [Category]
    @State private var categoryFilter: CategoryPolicy.Filter = .all

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

    private var orderedCategories: [Category] {
        categories.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var visibleSections: [CategoryPolicy.Section<TaskItem>] {
        CategoryPolicy.grouped(
            tasks,
            filter: categoryFilter,
            categoryID: { $0.category?.id },
            categoryName: { $0.category?.name },
            colorHex: { $0.category?.colorHex },
            sortKey: { $0.sortKey }
        )
    }

    private var showsCategorySections: Bool {
        CategoryPolicy.shouldShowSections(tasks, categoryID: { $0.category?.id })
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
                    VStack(spacing: 0) {
                        if !categories.isEmpty {
                            categoryFilterBar
                                .padding(.bottom, 8)
                        }

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                if visibleSections.isEmpty {
                                    emptyFilterMessage
                                } else if showsCategorySections || categoryFilter != .all {
                                    ForEach(visibleSections, id: \.categoryID) { section in
                                        sectionHeader(section)
                                        ForEach(section.tasks, id: \.id) { task in
                                            taskRow(task)
                                        }
                                    }
                                } else {
                                    ForEach(orderedTasks, id: \.id) { task in
                                        taskRow(task)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 96)
                        }
                        .scrollIndicators(.hidden)
                    }
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
        .onChange(of: categories.map(\.id)) { _, ids in
            if case .identified(let id) = categoryFilter, !ids.contains(id) {
                categoryFilter = .all
            }
        }
    }

    private func taskRow(_ task: TaskItem) -> some View {
        TaskRowView(
            task: task,
            onToggle: {
                Task { await TaskService(context: modelContext, scheduler: scheduler).toggleCompleted(task) }
            },
            onOpen: { onSelect(task) }
        )
    }

    private func sectionHeader(_ section: CategoryPolicy.Section<TaskItem>) -> some View {
        HStack(spacing: 8) {
            if section.colorHex != nil {
                CategoryColorDot(hex: section.colorHex)
            }
            Text(section.name.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(LunaTheme.secondary)
            Spacer()
        }
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }

    private var emptyFilterMessage: some View {
        Text("No tasks in this category.")
            .font(.subheadline)
            .foregroundStyle(LunaTheme.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", hex: nil, isSelected: categoryFilter == .all) {
                    categoryFilter = .all
                }
                ForEach(orderedCategories, id: \.id) { category in
                    filterChip(
                        title: category.name,
                        hex: category.colorHex,
                        isSelected: {
                            if case .identified(let id) = categoryFilter { return id == category.id }
                            return false
                        }()
                    ) {
                        categoryFilter = .identified(category.id)
                    }
                }
                filterChip(
                    title: CategoryPolicy.uncategorizedName,
                    hex: nil,
                    isSelected: categoryFilter == .uncategorized
                ) {
                    categoryFilter = .uncategorized
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterChip(title: String, hex: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if hex != nil {
                    CategoryColorDot(hex: hex, size: 8)
                }
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? LunaTheme.background : LunaTheme.highlight)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? LunaTheme.highlight : LunaTheme.surface, in: Capsule())
            .overlay {
                Capsule().stroke(LunaTheme.border.opacity(isSelected ? 0 : 0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
