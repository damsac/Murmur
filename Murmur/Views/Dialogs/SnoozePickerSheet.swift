import SwiftUI

struct SnoozePickerSheet: View {
    @State private var date: Date = Date().addingTimeInterval(3600)
    let onSave: (Date) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                DatePicker(
                    "",
                    selection: $date,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, Theme.Spacing.screenPadding)

                Spacer()
            }
            .background(Theme.Colors.bgDeep)
            .navigationTitle("Snooze until")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Snooze") { onSave(date) }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
        }
        .background(Theme.Colors.bgDeep)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
