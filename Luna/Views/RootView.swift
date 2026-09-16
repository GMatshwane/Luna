import SwiftUI
import SwiftData

private struct EditorSession: Identifiable {
    let id = UUID()
    let task: TaskItem?
}

struct RootView: View {
    @Environment(LunaSettings.self) private var settings
    @State private var selectedDate = Date()
    @State private var editorSession: EditorSession?
    @State private var showingCalendar = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            DayTasksView(
                selectedDate: $selectedDate,
                onAdd: { editorSession = EditorSession(task: nil) },
                onSelect: { editorSession = EditorSession(task: $0) }
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .foregroundStyle(LunaTheme.highlight)
                            .accessibilityLabel("Jump to date")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(LunaTheme.highlight)
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .toolbarBackground(LunaTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .sheet(item: $editorSession) { session in
                TaskEditorView(
                    task: session.task,
                    defaultDueDate: selectedDate
                )
                .preferredColorScheme(settings.appearance.preferredColorScheme)
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarSheet(selectedDate: $selectedDate)
                    .preferredColorScheme(settings.appearance.preferredColorScheme)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .preferredColorScheme(settings.appearance.preferredColorScheme)
            }
        }
    }
}

#Preview {
    let container = LunaPersistence.makeContainer(inMemory: true)
    return RootView()
        .environment(NotificationScheduler())
        .environment(LunaSettings())
        .modelContainer(container)
        .lunaScreen()
}
