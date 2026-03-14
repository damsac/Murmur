import SwiftUI
import MurmurCore

// MARK: - All Entries View (category sections browser, shared by both home variants)

struct AllEntriesView: View {
    let entries: [Entry]
    let isProcessing: Bool
    let arrivedEntryIDs: Set<UUID>
    @Binding var activeSwipeEntryID: UUID?
    let onEntryTap: (Entry) -> Void
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void
    let onGlowComplete: (UUID) -> Void

    private static let categoryDisplayOrder: [EntryCategory] = [
        .todo, .reminder, .habit, .idea, .list, .note, .question
    ]

    private var entriesByCategory: [(category: EntryCategory, entries: [Entry])] {
        let grouped = Dictionary(grouping: entries) { $0.category }
        return Self.categoryDisplayOrder.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            let sorted = items.sorted { lhs, rhs in
                let pa = lhs.priority ?? Int.max
                let pb = rhs.priority ?? Int.max
                if pa != pb { return pa < pb }
                let da = lhs.dueDate ?? Date.distantFuture
                let db = rhs.dueDate ?? Date.distantFuture
                if da != db { return da < db }
                return lhs.createdAt > rhs.createdAt
            }
            return (category: category, entries: sorted)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isProcessing {
                    SharedProcessingDotsView()
                        .transition(.opacity)
                }

                VStack(spacing: 0) {
                    ForEach(entriesByCategory, id: \.category) { group in
                        CategorySectionView(
                            category: group.category,
                            entries: group.entries,
                            arrivedEntryIDs: arrivedEntryIDs,
                            activeSwipeEntryID: $activeSwipeEntryID,
                            onEntryTap: onEntryTap,
                            swipeActionsProvider: swipeActionsProvider,
                            onAction: onAction,
                            onGlowComplete: onGlowComplete
                        )
                    }
                }
                .animation(Animations.smoothSlide, value: entries.map(\.id))

                Color.clear.frame(height: 160)
            }
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Category Section

struct CategorySectionView: View {
    let category: EntryCategory
    let entries: [Entry]
    let arrivedEntryIDs: Set<UUID>
    @Binding var activeSwipeEntryID: UUID?
    let onEntryTap: (Entry) -> Void
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void
    let onGlowComplete: (UUID) -> Void

    @AppStorage private var isCollapsed: Bool

    // MARK: - Peek State (collapsed section arrival preview)
    @State private var peekEntry: Entry?
    @State private var peekCount: Int = 0
    @State private var peekVisible: Bool = false
    @State private var peekTask: Task<Void, Never>?
    @State private var headerGlowIntensity: Double = 0

    init(
        category: EntryCategory,
        entries: [Entry],
        arrivedEntryIDs: Set<UUID>,
        activeSwipeEntryID: Binding<UUID?>,
        onEntryTap: @escaping (Entry) -> Void,
        swipeActionsProvider: @escaping (Entry) -> [CardSwipeAction],
        onAction: @escaping (Entry, EntryAction) -> Void,
        onGlowComplete: @escaping (UUID) -> Void
    ) {
        self.category = category
        self.entries = entries
        self.arrivedEntryIDs = arrivedEntryIDs
        self._activeSwipeEntryID = activeSwipeEntryID
        self.onEntryTap = onEntryTap
        self.swipeActionsProvider = swipeActionsProvider
        self.onAction = onAction
        self.onGlowComplete = onGlowComplete
        self._isCollapsed = AppStorage(wrappedValue: true, "section_\(category.rawValue)_collapsed")
    }

    private var color: Color { Theme.categoryColor(category) }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(Animations.smoothSlide) {
                    isCollapsed.toggle()
                    // Clear peek when expanding
                    if !isCollapsed {
                        peekTask?.cancel()
                        peekVisible = false
                        peekEntry = nil
                        peekCount = 0
                    }
                }
            } label: {
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .shadow(color: color.opacity(0.6), radius: 4)

                        Text(category.displayName.uppercased())
                            .font(Theme.Typography.badge)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .tracking(0.8)
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        // Arrival count badge
                        if peekCount > 0 {
                            Text("+\(peekCount)")
                                .font(Theme.Typography.badge)
                                .foregroundStyle(color)
                                .transition(.scale.combined(with: .opacity))
                        }

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
                            .animation(Animations.smoothSlide, value: isCollapsed)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, isCollapsed && !peekVisible ? 8 : 12)
            .shadow(color: color.opacity(0.3 * headerGlowIntensity), radius: 8)

            // Peek slot (collapsed section arrival preview)
            if isCollapsed && peekVisible, let peekEntry {
                SmartListRow(
                    entry: peekEntry,
                    onAction: onAction,
                    glowAccent: color,
                    glowIntensity: 1.0
                )
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .onTapGesture {
                    // Expand section, cancel retract
                    peekTask?.cancel()
                    withAnimation(Animations.smoothSlide) {
                        isCollapsed = false
                        peekVisible = false
                        self.peekEntry = nil
                        peekCount = 0
                    }
                }
            }

            // Section body (expanded)
            if !isCollapsed {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        SwipeableCard(
                            actions: swipeActionsProvider(entry),
                            activeSwipeID: $activeSwipeEntryID,
                            entryID: entry.id,
                            onTap: { onEntryTap(entry) }
                        ) {
                            GlowingEntryRow(
                                entry: entry,
                                isArrived: arrivedEntryIDs.contains(entry.id),
                                category: category,
                                onAction: onAction,
                                onGlowComplete: { onGlowComplete(entry.id) }
                            )
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.97)).combined(with: .offset(y: 8)),
                            removal: .opacity.combined(with: .scale(scale: 0.95))
                        ))
                    }
                }
                .padding(.horizontal, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(Animations.cardAppear, value: entries.map(\.id))
            }
        }
        .onAppear {
            guard isCollapsed, !arrivedEntryIDs.isEmpty else { return }
            let newInSection = entries.filter { arrivedEntryIDs.contains($0.id) }
            guard let latest = newInSection.first else { return }

            peekEntry = latest
            peekCount += newInSection.count
            showPeek()
        }
        .onChange(of: arrivedEntryIDs) { oldIDs, newIDs in
            guard isCollapsed else { return }
            let added = newIDs.subtracting(oldIDs)
            let newInSection = entries.filter { added.contains($0.id) }
            guard let latest = newInSection.first else { return }

            peekEntry = latest
            peekCount += newInSection.count
            showPeek()
        }
    }

    // MARK: - Peek Helpers

    private func showPeek() {
        headerGlowIntensity = 1.0
        withAnimation(.easeOut(duration: 1.0)) {
            headerGlowIntensity = 0
        }

        withAnimation(Animations.cardAppear) {
            peekVisible = true
        }

        peekTask?.cancel()
        peekTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(Animations.smoothSlide) {
                    peekVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    peekEntry = nil
                    peekCount = 0
                }
            }
        }
    }
}

// MARK: - Glowing Entry Row

private struct GlowingEntryRow: View {
    let entry: Entry
    let isArrived: Bool
    let category: EntryCategory
    let onAction: (Entry, EntryAction) -> Void
    let onGlowComplete: () -> Void

    @State private var glowIntensity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SmartListRow(
            entry: entry,
            onAction: onAction,
            glowAccent: glowIntensity > 0 ? Theme.categoryColor(category) : nil,
            glowIntensity: glowIntensity
        )
        .onChange(of: isArrived) { _, newValue in
            if newValue { triggerGlow() }
        }
        .onAppear {
            if isArrived && glowIntensity == 0 { triggerGlow() }
        }
    }

    private func triggerGlow() {
        if reduceMotion {
            onGlowComplete()
            return
        }
        glowIntensity = 1.0
        withAnimation(.easeOut(duration: 3.5)) {
            glowIntensity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            onGlowComplete()
        }
    }
}

// MARK: - Smart List Row

struct SmartListRow: View {
    let entry: Entry
    let onAction: (Entry, EntryAction) -> Void
    var glowAccent: Color?
    var glowIntensity: Double = 0

    private var isOverdue: Bool {
        guard let dueDate = entry.dueDate else { return false }
        return dueDate < Date()
    }

    private var listItems: [String] {
        guard entry.category == .list else { return [] }
        return entry.content
            .components(separatedBy: "\n")
            .map { line -> String in
                var s = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if s.hasPrefix("- ") { s = String(s.dropFirst(2)) } else if s.hasPrefix("• ") { s = String(s.dropFirst(2)) } else if s.hasPrefix("* ") { s = String(s.dropFirst(2)) }
                return s
            }
            .filter { !$0.isEmpty }
    }

    private var dueText: String? {
        guard entry.category == .todo || entry.category == .reminder else { return nil }
        guard let dueDate = entry.dueDate else { return nil }
        let calendar = Calendar.current
        if isOverdue { return "Overdue" }
        if calendar.isDateInToday(dueDate) { return "Due today" }
        if calendar.isDateInTomorrow(dueDate) { return "Due tomorrow" }
        let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return "Due in \(days)d"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if entry.category == .habit && entry.appliesToday {
                Button {
                    onAction(entry, .checkOffHabit)
                } label: {
                    Image(systemName: entry.isCompletedToday ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            entry.isCompletedToday
                                ? Theme.categoryColor(entry.category)
                                : Theme.Colors.textTertiary
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: entry.isCompletedToday)
                        .frame(width: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(entry.isDoneForPeriod || entry.isCompletedToday ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .lineLimit(2)

                if entry.category == .habit, let cadence = entry.cadence {
                    Text(cadence.displayName)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                } else if let dueText {
                    Text(dueText)
                        .font(.caption)
                        .foregroundStyle(isOverdue ? Theme.Colors.accentRed : Theme.Colors.textTertiary)
                }

                if !listItems.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        let displayItems = Array(listItems.prefix(3))
                        let remaining = listItems.count - displayItems.count
                        ForEach(displayItems, id: \.self) { item in
                            HStack(alignment: .center, spacing: 5) {
                                Circle()
                                    .fill(Theme.Colors.textMuted)
                                    .frame(width: 3, height: 3)
                                Text(item)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        if remaining > 0 {
                            Text("+\(remaining) more")
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .padding(.leading, 8)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        }
        .cardStyle(accent: glowAccent, intensity: glowIntensity)
        .opacity(entry.isDoneForPeriod || entry.isCompletedToday ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.category.displayName): \(entry.summary)")
    }
}

// MARK: - Processing Dots (inline streaming indicator)

struct SharedProcessingDotsView: View {
    @State private var phase: Int = 0

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Theme.Colors.accentPurple)
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1.5 : 0.7)
                    .opacity(phase == i ? 1.0 : 0.25)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .accessibilityLabel("Processing")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeInOut(duration: 0.25)) {
                    phase = (phase + 1) % 3
                }
            }
        }
    }
}
