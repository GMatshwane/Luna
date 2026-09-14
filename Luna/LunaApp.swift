import SwiftUI
import SwiftData
import UserNotifications

@main
struct LunaApp: App {
    @State private var scheduler = NotificationScheduler()
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer

    init() {
        container = LunaPersistence.makeContainer()
        UNUserNotificationCenter.current().delegate = NotificationPresentationDelegate.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scheduler)
                .modelContainer(container)
                .lunaScreen()
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
