import SwiftUI

struct ScoreCardView: View {
    let earned: Int
    let goal: Int

    private var score: ScorePolicy.DayScore {
        ScorePolicy.score(earned: earned, goal: goal)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("SCORE")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(LunaTheme.secondary)
                Spacer()
                Text(score.label)
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(LunaTheme.highlight)
                    .accessibilityLabel("\(score.earned) of \(score.goal) points")
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LunaTheme.surface)
                    Capsule()
                        .fill(LunaTheme.highlight)
                        .frame(width: geometry.size.width * score.progress)
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}
