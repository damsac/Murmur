import SwiftUI
import SwiftData
import MurmurCore

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NotificationPreferences.self) private var notifPrefs
    @Query(
        filter: #Predicate<Entry> { $0.statusRawValue == "archived" || $0.statusRawValue == "completed" },
        sort: \Entry.updatedAt,
        order: .reverse
    ) private var archivedEntries: [Entry]
    let onBack: () -> Void

    @State private var searchText = ""

    private static let categoryDisplayOrder: [EntryCategory] = [
        .todo, .reminder, .habit, .idea, .list, .note, .question
    ]

    private var filteredEntries: [Entry] {
        guard !searchText.isEmpty else { return archivedEntries }
        let q = searchText.lowercased()
        return archivedEntries.filter { $0.summary.lowercased().contains(q) }
    }

    private var entriesByCategory: [(category: EntryCategory, entries: [Entry])] {
        let grouped = Dictionary(grouping: filteredEntries) { $0.category }
        return Self.categoryDisplayOrder.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category: category, entries: items)
        }
    }

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
                    searchBar
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.top, 12)
                        .padding(.bottom, 4)

                    ScrollView {
                        VStack(spacing: 0) {
                            if filteredEntries.isEmpty {
                                noResultsState
                            } else if searchText.isEmpty {
                                ForEach(entriesByCategory, id: \.category) { group in
                                    ArchiveSectionView(
                                        category: group.category,
                                        entries: group.entries,
                                        onRestore: { entry in
                                            entry.perform(.unarchive, in: modelContext, preferences: notifPrefs)
                                        },
                                        onDelete: { entry in
                                            modelContext.delete(entry)
                                        }
                                    )
                                }
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredEntries) { entry in
                                        ArchiveRow(entry: entry, onRestore: {
                                            entry.perform(.unarchive, in: modelContext, preferences: notifPrefs)
                                        }, onDelete: {
                                            modelContext.delete(entry)
                                        })
                                    }
                                }
                                .padding(.horizontal, Theme.Spacing.screenPadding)
                                .padding(.top, 10)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.textTertiary)

            TextField("Search archive", text: $searchText)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.Colors.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
        )
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

    @ViewBuilder
    private var noResultsState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Colors.textTertiary)
            Text("No results for \"\(searchText)\"")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
            Spacer(minLength: 60)
        }
    }
}

// MARK: - Archive Section

private struct ArchiveSectionView: View {
    let category: EntryCategory
    let entries: [Entry]
    let onRestore: (Entry) -> Void
    let onDelete: (Entry) -> Void

    @AppStorage private var isCollapsed: Bool

    init(category: EntryCategory, entries: [Entry], onRestore: @escaping (Entry) -> Void, onDelete: @escaping (Entry) -> Void) {
        self.category = category
        self.entries = entries
        self.onRestore = onRestore
        self.onDelete = onDelete
        self._isCollapsed = AppStorage(wrappedValue: false, "archive_section_\(category.rawValue)_collapsed")
    }

    private var color: Color { Theme.categoryColor(category) }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isCollapsed.toggle()
                }
            } label: {
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                            .shadow(color: color.opacity(0.6), radius: 3)

                        Text(category.displayName.uppercased())
                            .font(Theme.Typography.badge)
                            .foregroundStyle(color)
                            .tracking(0.8)

                        Rectangle()
                            .fill(color.opacity(0.2))
                            .frame(height: 1)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Text("\(entries.count)")
                            .font(Theme.Typography.badge)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Theme.Colors.bgCard)
                                    .overlay(Capsule().stroke(Theme.Colors.borderSubtle, lineWidth: 1))
                            )

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isCollapsed)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, isCollapsed ? 8 : 12)

            if !isCollapsed {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        ArchiveRow(entry: entry, onRestore: {
                            onRestore(entry)
                        }, onDelete: {
                            onDelete(entry)
                        })
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Archive Row

private struct ArchiveRow: View {
    let entry: Entry
    let onRestore: () -> Void
    let onDelete: () -> Void

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

            HStack(spacing: 12) {
                Button(action: onRestore) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Colors.accentPurple)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restore entry")

                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete entry")
            }
        }
        .cardStyle()
    }
}
