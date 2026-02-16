import SwiftUI

struct HomeSparseView: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    let entries: [Entry]
    let onMicTap: () -> Void
    let onSubmit: () -> Void
    let onEntryTap: (Entry) -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 2) {
                Text("Murmur")
                    .font(Theme.Typography.navTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(greeting)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text("You have \(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Token balance
            HStack {
                Spacer()
                TokenBalanceLabel(
                    balance: appState.creditBalance,
                    showWarning: appState.creditBalance < 100
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.bottom, 16)

            // Entries
            ScrollView {
                VStack(spacing: Theme.Spacing.cardGap) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        EntryCard(entry: entry)
                            .onTapGesture {
                                onEntryTap(entry)
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.1),
                                value: appeared
                            )
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 16)
            }
        }
        .onAppear {
            appeared = true
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        case 17..<22:
            return "Good evening"
        default:
            return "Good night"
        }
    }
}

#Preview("Home Sparse - Few Entries") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    HomeSparseView(
        inputText: $inputText,
        entries: [
            Entry(
                summary: "Review the new design system and provide feedback to the team by end of week",
                category: .todo,
                priority: 2,
                aiGenerated: true
            ),
            Entry(
                summary: "Doctor appointment tomorrow at 2pm - bring insurance card",
                category: .reminder,
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                aiGenerated: true
            ),
            Entry(
                summary: "Build a browser extension for quick voice notes",
                category: .idea,
                priority: 1,
                aiGenerated: true
            )
        ],
        onMicTap: { print("Mic tapped") },
        onSubmit: { print("Submit:", inputText) },
        onEntryTap: { print("Entry tapped:", $0.summary) }
    )
    .environment(appState)
}

#Preview("Home Sparse - Single Entry") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    HomeSparseView(
        inputText: $inputText,
        entries: [
            Entry(
                summary: "The best interfaces are invisible - they get out of the way",
                category: .insight,
                aiGenerated: true
            )
        ],
        onMicTap: { print("Mic tapped") },
        onSubmit: { print("Submit:", inputText) },
        onEntryTap: { print("Entry tapped:", $0.summary) }
    )
    .environment(appState)
}
