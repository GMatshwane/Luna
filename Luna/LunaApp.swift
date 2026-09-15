import SwiftUI
import SwiftData
import UserNotifications

@main
struct LunaApp: App {
    @State private var scheduler = NotificationScheduler()
    @State private var settings = LunaSettings()
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer

    init() {
        LunaTypography.registerIfNeeded()
        container = LunaPersistence.makeContainer()
        UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scheduler)
                .environment(settings)
                .environment(\.font, LunaTypography.font(.body))
                .modelContainer(container)
                .lunaScreen()
                .preferredColorScheme(settings.appearance.preferredColorScheme)
                .task {
                    await scheduler.refreshStatus()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await scheduler.refreshStatus() }
            }
        }
    }
}
