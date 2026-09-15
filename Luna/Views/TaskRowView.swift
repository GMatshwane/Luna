import SwiftUI

struct TaskRowView: View {
    let task: TaskItem
    var onToggle: () -> Void
    var onOpen: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? LunaTheme.secondary : LunaTheme.highlight)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Mark \(task.title) incomplete" : "Mark \(task.title) complete")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if task.category?.colorHex != nil {
                        CategoryColorDot(hex: task.category?.colorHex)
                    }
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(task.isCompleted ? LunaTheme.secondary : LunaTheme.highlight)
                        .strikethrough(task.isCompleted, color: LunaTheme.secondary)
                }

                if let reminderAt = task.reminderAt {
                    Label(reminderAt.formatted(date: .omitted, time: .shortened), systemImage: "bell")
                        .font(.caption)
                        .foregroundStyle(LunaTheme.secondary)
                }

                if let rule = task.recurrence {
                    Label(RepeatPolicy.summaryLabel(rule), systemImage: "repeat")
                        .font(.caption)
                        .foregroundStyle(LunaTheme.secondary)
                } else if task.reminderAt == nil, let notes = task.notes {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(LunaTheme.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Text("\(ScorePolicy.normalizedPoints(task.points))")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(task.isCompleted ? LunaTheme.secondary : LunaTheme.highlight)
                .accessibilityLabel("\(ScorePolicy.normalizedPoints(task.points)) points")
        }
        .padding(16)
        .background(LunaTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(LunaTheme.border.opacity(0.45), lineWidth: 1)
        }
        .opacity(task.isCompleted ? 0.62 : 1)
        .accessibilityElement(children: .contain)
    }
}
