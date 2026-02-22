import SwiftUI
import MurmurCore

struct ArchiveView: View {
    let entries: [Entry]
    let onEntryTap: (Entry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Archive")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)

            if entries.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(Theme.Colors.textTertiary)
                    Text("Nothing archived yet")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Text("Archive entries from their detail view to keep things tidy.")
                        .font(Theme.Typography.label)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.screenPadding * 2)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: Theme.Spacing.cardGap) {
                        ForEach(entries) { entry in
                            ArchiveEntryRow(entry: entry)
                                .onTapGesture { onEntryTap(entry) }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Archive Entry Row

private struct ArchiveEntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: categoryIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(categoryColor)
                .frame(width: 20, height: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.summary)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)

                Text(entry.category.displayName)
                    .font(Theme.Typography.label)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.Colors.textTertiary)
                .padding(.top, 4)
        }
        .padding(Theme.Spacing.cardPadding)
        .background(Theme.Colors.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private var categoryIcon: String {
        switch entry.category {
        case .todo: return "checklist"
        case .reminder: return "bell.fill"
        case .idea: return "lightbulb.fill"
        case .habit: return "flame.fill"
        case .note: return "note.text"
        case .list: return "list.bullet"
        case .question: return "questionmark.circle.fill"
        case .thought: return "bubble.left.fill"
        }
    }

    private var categoryColor: Color {
        switch entry.category {
        case .todo: return Theme.Colors.accentPurple
        case .reminder: return Theme.Colors.accentYellow
        case .idea: return Theme.Colors.accentYellow
        case .habit: return Theme.Colors.accentGreen
        default: return Theme.Colors.textSecondary
        }
    }
}

#Preview("Archive — Empty") {
    ArchiveView(entries: [], onEntryTap: { _ in })
        .background(Theme.Colors.bgDeep)
}

#Preview("Archive — With Entries") {
    ArchiveView(
        entries: [
            Entry(
                transcript: "",
                content: "Old todo I no longer need",
                category: .todo,
                sourceText: "",
                summary: "Old todo I no longer need",
                status: .archived
            ),
            Entry(
                transcript: "",
                content: "Dentist appointment April 2024",
                category: .reminder,
                sourceText: "",
                summary: "Dentist appointment April 2024",
                status: .archived
            ),
            Entry(
                transcript: "",
                content: "App that converts receipts to meal plans",
                category: .idea,
                sourceText: "",
                summary: "App that converts receipts to meal plans",
                status: .archived
            ),
        ],
        onEntryTap: { print("Tapped: \($0.summary)") }
    )
    .background(Theme.Colors.bgDeep)
}
