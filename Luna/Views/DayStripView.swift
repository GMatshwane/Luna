import SwiftUI

struct DayStripView: View {
    @Binding var selectedDate: Date

    private var days: [Date] {
        let aroundToday = CalendarDay.nearbyDays(around: Date(), before: 14, after: 28)
        if aroundToday.contains(where: { CalendarDay.isSameDay($0, selectedDate) }) {
            return aroundToday
        }
        return CalendarDay.nearbyDays(around: selectedDate, before: 14, after: 14)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(days, id: \.self) { day in
                        DayChip(
                            day: day,
                            isSelected: CalendarDay.isSameDay(day, selectedDate),
                            isToday: CalendarDay.isSameDay(day, Date())
                        )
                        .id(day)
                        .onTapGesture {
                            selectedDate = day
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                proxy.scrollTo(CalendarDay.startOfDay(selectedDate), anchor: .center)
            }
            .onChange(of: selectedDate) { _, newValue in
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(CalendarDay.startOfDay(newValue), anchor: .center)
                }
            }
        }
    }
}

private struct DayChip: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(day.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? LunaTheme.background : LunaTheme.secondary)

            Text(day.formatted(.dateTime.day()))
                .font(.headline.monospacedDigit())
                .foregroundStyle(isSelected ? LunaTheme.background : LunaTheme.highlight)
        }
        .frame(width: 48, height: 64)
        .background(isSelected ? LunaTheme.highlight : LunaTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isToday && !isSelected ? LunaTheme.border : Color.clear, lineWidth: 1)
        }
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var accessibilityText: String {
        day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}
