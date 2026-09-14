import SwiftUI

struct CalendarSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                DatePicker(
                    "Jump to date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(LunaTheme.highlight)
                .padding(.horizontal, 8)
                .accessibilityHidden(false)

                Button {
                    selectedDate = Date()
                    dismiss()
                } label: {
                    Text("Jump to today")
                        .font(.headline)
                        .foregroundStyle(LunaTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LunaTheme.highlight, in: Capsule())
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 8)
            .lunaScreen()
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(LunaTheme.highlight)
                }
            }
            .toolbarBackground(LunaTheme.background, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }
}
