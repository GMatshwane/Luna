import SwiftUI

struct EmptyDayView: View {
    let isToday: Bool
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: "moon.stars.fill")
                .font(.system(size: 42))
                .foregroundStyle(LunaTheme.secondary)
                .accessibilityHidden(true)

            Text(isToday ? "A quiet evening." : "Nothing planned for this day.")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(LunaTheme.highlight)
                .multilineTextAlignment(.center)

            Text(isToday ? "Add a task when you’re ready." : "Set a reminder for this date.")
                .font(.subheadline)
                .foregroundStyle(LunaTheme.secondary)
                .multilineTextAlignment(.center)

            Button(action: onAdd) {
                Text("Add a task")
                    .font(.headline)
                    .foregroundStyle(LunaTheme.background)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(LunaTheme.highlight, in: Capsule())
            }
            .padding(.top, 6)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}
