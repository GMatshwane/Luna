import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NotificationScheduler.self) private var scheduler
    @Environment(LunaSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("APPEARANCE")
                        .font(LunaTypography.font(.caption, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(LunaTheme.secondary)

                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(LunaAppearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(LunaTheme.highlight)
                    .accessibilityLabel("Appearance")

                    Text("System follows this iPhone. Light and Dark stay until you change them.")
                        .font(LunaTypography.font(.subheadline))
                        .foregroundStyle(LunaTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("DAILY GOAL")
                        .font(LunaTypography.font(.caption, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(LunaTheme.secondary)

                    Stepper(value: $settings.dailyPointGoal, in: ScorePolicy.minimumDailyGoal...ScorePolicy.maximumDailyGoal) {
                        Text("\(settings.dailyPointGoal) points")
                            .font(LunaTypography.font(.title3, weight: .semibold))
                            .foregroundStyle(LunaTheme.highlight)
                    }
                    .accessibilityLabel("Daily goal \(settings.dailyPointGoal) points")

                    Text("Completing tasks adds their points toward this day’s goal.")
                        .font(LunaTypography.font(.subheadline))
                        .foregroundStyle(LunaTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTIFICATIONS")
                        .font(LunaTypography.font(.caption, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(LunaTheme.secondary)

                    Text(statusTitle)
                        .font(LunaTypography.font(.title3, weight: .semibold))
                        .foregroundStyle(LunaTheme.highlight)

                    Text(statusDetail)
                        .font(LunaTypography.font(.subheadline))
                        .foregroundStyle(LunaTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if scheduler.isDenied {
                        Button("Open Settings") {
                            openSystemSettings()
                        }
                        .font(LunaTypography.font(.headline, weight: .semibold))
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
                    .font(LunaTypography.font(.footnote))
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
