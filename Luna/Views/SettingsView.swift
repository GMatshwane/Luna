import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationScheduler.self) private var scheduler

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTIFICATIONS")
                        .font(.caption.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(LunaTheme.secondary)

                    Text(statusTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LunaTheme.highlight)

                    Text(statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(LunaTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if scheduler.isDenied {
                        Button("Open Settings") {
                            openSystemSettings()
                        }
                        .font(.headline)
                        .foregroundStyle(LunaTheme.background)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(LunaTheme.highlight, in: Capsule())
                        .padding(.top, 4)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
                }

                Text("Luna keeps tasks and reminders on this device. There is no iCloud or Apple Reminders sync.")
                    .font(.footnote)
                    .foregroundStyle(LunaTheme.secondary)

                Spacer()
            }
            .padding(20)
            .lunaScreen()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LunaTheme.highlight)
                }
            }
            .toolbarBackground(LunaTheme.background, for: .navigationBar)
            .task {
                await scheduler.refreshStatus()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var statusTitle: String {
        switch scheduler.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are on"
        case .denied:
            return "Notifications are off"
        case .notDetermined:
            return "Not requested yet"
        @unknown default:
            return "Unknown status"
        }
    }

    private var statusDetail: String {
        switch scheduler.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Luna can send a local alert at each task’s reminder time."
        case .denied:
            return "Enable notifications in iOS Settings to receive reminder alerts."
        case .notDetermined:
            return "Luna will ask the first time you enable a reminder on a task."
        @unknown default:
            return "Check iOS Settings if reminders are not arriving."
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
