import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationPreferences.self) private var notifPrefs
    @Query(
        filter: #Predicate<Entry> { $0.statusRawValue == "archived" },
        sort: \Entry.updatedAt,
        order: .reverse
    ) private var archivedEntries: [Entry]
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                NavHeader(
                    title: "Archive",
                    showBackButton: true,
                    backAction: onBack
                )

                if archivedEntries.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(archivedEntries) { entry in
                                ArchiveRow(entry: entry) {
                                    entry.perform(.unarchive, in: modelContext, preferences: notifPrefs)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 40))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No archived entries")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Archive Row

private struct ArchiveRow: View {
    let entry: Entry
    let onRestore: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                CategoryBadge(category: entry.category, size: .small)

                Text(entry.summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onRestore) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.Colors.accentPurple)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Restore entry")
        }
        .cardStyle()
    }
}
