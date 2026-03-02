import SwiftUI
import MurmurCore

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    let entries: [Entry]
    let onMicTap: () -> Void
    let onSubmit: () -> Void
    let onEntryTap: (Entry) -> Void
    let onSettingsTap: () -> Void
    let onAction: (Entry, EntryAction) -> Void

    // Empty state pulse animations
    @State private var pulseScale1: CGFloat = 1.0
    @State private var pulseScale2: CGFloat = 1.0
    @State private var pulseScale3: CGFloat = 1.0
    @State private var pulseOpacity1: Double = 1.0
    @State private var pulseOpacity2: Double = 0.7
    @State private var pulseOpacity3: Double = 0.5
    @State private var activeSwipeEntryID: UUID?

    var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            populatedState
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.accentPurple.opacity(0.05), lineWidth: 1)
                        .frame(width: 136, height: 136)
                        .scaleEffect(pulseScale3)
                        .opacity(pulseOpacity3)

                    Circle()
                        .stroke(Theme.Colors.accentPurple.opacity(0.1), lineWidth: 1)
                        .frame(width: 112, height: 112)
                        .scaleEffect(pulseScale2)
                        .opacity(pulseOpacity2)

                    Circle()
                        .stroke(Theme.Colors.accentPurple.opacity(0.3), lineWidth: 2)
                        .frame(width: 88, height: 88)
                        .scaleEffect(pulseScale1)
                        .opacity(pulseOpacity1)

                    Button(action: onMicTap) {
                        Image(systemName: "mic")
                            .font(.largeTitle)
                            .foregroundStyle(Theme.Colors.accentPurple.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Record your first voice note")
                }
                .onAppear { startPulseAnimation() }

                VStack(spacing: 10) {
                    Text("Say or type anything.")
                        .font(Theme.Typography.title)
                        .tracking(-0.5)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("Murmur remembers so you don't have to.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .lineSpacing(2)
                        .devModeActivator()
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            }

            Spacer()
            Spacer()
        }
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale1 = 1.05
            pulseOpacity1 = 0.8
        }

        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
            .delay(0.5)
        ) {
            pulseScale2 = 1.05
            pulseOpacity2 = 0.5
        }

        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
            .delay(1.0)
        ) {
            pulseScale3 = 1.05
            pulseOpacity3 = 0.3
        }
    }

    // MARK: - Populated State

    @ViewBuilder
    private var populatedState: some View {
        VStack(spacing: 0) {
            // Scrollable content: focus strip + category sections
            ScrollView {
                VStack(spacing: 0) {
                    // Focus strip: LLM-composed or loading shimmer
                    if appState.isFocusLoading && appState.dailyFocus == nil {
                        FocusShimmerView()
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                            .transition(.opacity.animation(.easeOut(duration: 0.4)))
                    } else if let focus = appState.dailyFocus, !focus.items.isEmpty {
                        FocusStripView(
                            dailyFocus: focus,
                            allEntries: entries,
                            activeSwipeEntryID: $activeSwipeEntryID,
                            onEntryTap: onEntryTap,
                            swipeActionsProvider: swipeActions(for:),
                            onAction: onAction
                        )
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                            .transition(.opacity.animation(.easeIn(duration: 0.3)))
                    }

                    // Category sections
                    LazyVStack(spacing: 0) {
                        ForEach(entriesByCategory, id: \.category) { group in
                            CategorySectionView(
                                category: group.category,
                                entries: group.entries,
                                activeSwipeEntryID: $activeSwipeEntryID,
                                onEntryTap: onEntryTap,
                                swipeActionsProvider: swipeActions(for:),
                                onAction: onAction
                            )
                        }
                    }
                    // Extra padding so last card clears the floating mic
                    .padding(.bottom, 80)
                }
            }
            .scrollIndicators(.hidden)
            .mask(
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
            )
        }
    }

    // MARK: - Category Section Data

    private static let categoryDisplayOrder: [EntryCategory] = [
        .todo, .reminder, .habit, .idea, .list, .note, .question
    ]

    /// Entries grouped by category, in fixed display order, only non-empty categories.
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

    // MARK: - Swipe Actions

    private func swipeActions(for entry: Entry) -> [CardSwipeAction] {
        let isCompletable = entry.category == .todo
            || entry.category == .reminder
            || entry.category == .habit

        var actions: [CardSwipeAction] = []

        if isCompletable {
            actions.append(CardSwipeAction(
                icon: "checkmark.circle.fill", label: "Done",
                color: Theme.Colors.accentGreen
            ) { onAction(entry, .complete) })
        } else {
            actions.append(CardSwipeAction(
                icon: "archivebox.fill", label: "Archive",
                color: Theme.Colors.accentBlue
            ) { onAction(entry, .archive) })
        }

        actions.append(CardSwipeAction(
            icon: "moon.zzz.fill", label: "Snooze",
            color: Theme.Colors.accentYellow
        ) { onAction(entry, .snooze(until: nil)) })

        return actions
    }
}

// MARK: - Focus Strip

private struct FocusStripView: View {
    let dailyFocus: DailyFocus
    let allEntries: [Entry]
    @Binding var activeSwipeEntryID: UUID?
    let onEntryTap: (Entry) -> Void
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void

    @State private var messageVisible: Bool = false
    @State private var visibleCardCount: Int = 0

    private var resolvedItems: [(entry: Entry, reason: String)] {
        dailyFocus.items.compactMap { item in
            guard let entry = Entry.resolve(shortID: item.id, in: allEntries) else { return nil }
            return (entry, item.reason)
        }
    }

    var body: some View {
        let items = resolvedItems
        if !items.isEmpty {
            VStack(spacing: 12) {
                // Briefing message from LLM
                Text(dailyFocus.message)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(messageVisible ? 1 : 0)
                    .offset(y: messageVisible ? 0 : 6)

                // Focus cards — stagger in one at a time
                VStack(spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.entry.id) { index, item in
                        if index < visibleCardCount {
                            FocusCardView(
                                entry: item.entry,
                                reason: item.reason,
                                activeSwipeEntryID: $activeSwipeEntryID,
                                swipeActionsProvider: swipeActionsProvider,
                                onAction: onAction,
                                onTap: { onEntryTap(item.entry) }
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .opacity
                                        .combined(with: .offset(y: 8))
                                        .combined(with: .scale(scale: 0.97, anchor: .top)),
                                    removal: .opacity
                                )
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .onAppear { staggerIn(count: items.count) }
        }
    }

    private func staggerIn(count: Int) {
        // Message fades in first
        withAnimation(.easeOut(duration: 0.4)) {
            messageVisible = true
        }
        // Cards appear one at a time
        for i in 0..<count {
            let delay = 0.2 + Double(i) * 0.25
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    visibleCardCount = i + 1
                }
            }
        }
    }
}

// MARK: - Focus Shimmer (Loading State)

private struct FocusShimmerView: View {
    @State private var glowPhases: [Bool] = [false, false, false]

    var body: some View {
        VStack(spacing: 12) {
            // Message placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Theme.Colors.bgCard)
                .frame(width: 200, height: 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(glowPhases[0] ? 0.45 : 0.8)

            // 3 placeholder cards with staggered breathing
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.bgCard)
                                .frame(width: 50, height: 14)
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Theme.Colors.bgCard)
                                .frame(width: 40, height: 14)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.bgCard)
                            .frame(height: 16)
                            .frame(maxWidth: .infinity)
                    }
                    .cardStyle()
                    .opacity(glowPhases[index] ? 0.45 : 1.0)
                    .shadow(
                        color: Theme.Colors.textTertiary.opacity(glowPhases[index] ? 0.15 : 0),
                        radius: 12, y: 0
                    )
                }
            }

            Text("Thinking about your day...")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(glowPhases[2] ? 0.4 : 0.7)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .onAppear { startRipple() }
    }

    private func startRipple() {
        for index in 0..<3 {
            let delay = Double(index) * 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    glowPhases[index] = true
                }
            }
        }
    }
}

// MARK: - Focus Card

private struct FocusCardView: View {
    let entry: Entry
    let reason: String
    @Binding var activeSwipeEntryID: UUID?
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void
    let onTap: () -> Void

    @State private var glowIntensity: Double = 1.0

    private var accentColor: Color { Theme.categoryColor(entry.category) }

    var body: some View {
        SwipeableCard(
            actions: swipeActionsProvider(entry),
            activeSwipeID: $activeSwipeEntryID,
            entryID: entry.id,
            onTap: onTap
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    CategoryBadge(category: entry.category, size: .small)
                    Spacer()
                    if !reason.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption2)
                            Text(reason)
                                .font(Theme.Typography.badge)
                        }
                        .foregroundStyle(Theme.Colors.accentRed)
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    Text(entry.summary)
                        .font(Theme.Typography.body)
                        .foregroundStyle(entry.isDoneForPeriod || entry.isCompletedToday ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                    .stroke(accentColor.opacity(0.55 * glowIntensity), lineWidth: 1.5)
            )
            .shadow(color: accentColor.opacity(0.30 * glowIntensity), radius: 18, y: 0)
            .opacity(entry.isDoneForPeriod || entry.isCompletedToday ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
        }
        .onAppear {
            // Start glowing immediately — card arrives with glow, then fades out
            withAnimation(.easeOut(duration: 1.8)) {
                glowIntensity = 0
            }
        }
    }
}

// MARK: - Category Section

private struct CategorySectionView: View {
    let category: EntryCategory
    let entries: [Entry]
    @Binding var activeSwipeEntryID: UUID?
    let onEntryTap: (Entry) -> Void
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void

    @AppStorage private var isCollapsed: Bool

    init(
        category: EntryCategory,
        entries: [Entry],
        activeSwipeEntryID: Binding<UUID?>,
        onEntryTap: @escaping (Entry) -> Void,
        swipeActionsProvider: @escaping (Entry) -> [CardSwipeAction],
        onAction: @escaping (Entry, EntryAction) -> Void
    ) {
        self.category = category
        self.entries = entries
        self._activeSwipeEntryID = activeSwipeEntryID
        self.onEntryTap = onEntryTap
        self.swipeActionsProvider = swipeActionsProvider
        self.onAction = onAction
        self._isCollapsed = AppStorage(wrappedValue: false, "section_\(category.rawValue)_collapsed")
    }

    private var color: Color { Theme.categoryColor(category) }
    private var hasOverdue: Bool { entries.contains { $0.dueDate.map { $0 < Date() } ?? false } }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(Animations.smoothSlide) { isCollapsed.toggle() }
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
            .padding(.bottom, isCollapsed ? 8 : 12)

            // Section body
            if !isCollapsed {
                LazyVStack(spacing: 12) {
                    ForEach(entries) { entry in
                        SwipeableCard(
                            actions: swipeActionsProvider(entry),
                            activeSwipeID: $activeSwipeEntryID,
                            entryID: entry.id,
                            onTap: { onEntryTap(entry) }
                        ) {
                            SmartListRow(entry: entry, onAction: onAction)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Smart List Row

private struct SmartListRow: View {
    let entry: Entry
    let onAction: (Entry, EntryAction) -> Void

    private var isOverdue: Bool {
        guard let dueDate = entry.dueDate else { return false }
        return dueDate < Date()
    }

    private var dueText: String? {
        guard let dueDate = entry.dueDate else { return nil }
        let calendar = Calendar.current
        if isOverdue { return "Overdue" }
        if calendar.isDateInToday(dueDate) { return "Due today" }
        if calendar.isDateInTomorrow(dueDate) { return "Due tomorrow" }
        let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
        return "Due in \(days)d"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category + metadata row
            HStack(spacing: 6) {
                CategoryBadge(category: entry.category, size: .small)

                Spacer()

                if let priority = entry.priority, priority <= 2 {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                        Text("P\(priority)")
                            .font(Theme.Typography.badge)
                    }
                    .foregroundStyle(Theme.Colors.accentRed)
                }

                if let dueText {
                    HStack(spacing: 3) {
                        Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "calendar")
                            .font(.caption2)
                        Text(dueText)
                            .font(Theme.Typography.badge)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(isOverdue ? Theme.Colors.accentRed : Theme.Colors.accentYellow)
                }
            }

            // Summary + habit check-off
            HStack(alignment: .center, spacing: 12) {
                Text(entry.summary)
                    .font(Theme.Typography.body)
                    .foregroundStyle(entry.isDoneForPeriod || entry.isCompletedToday ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle()
        .opacity(entry.isDoneForPeriod || entry.isCompletedToday ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.category.displayName): \(entry.summary)")
    }
}

// MARK: - Card Swipe Actions

struct CardSwipeAction: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let color: Color
    let handler: () -> Void
}

struct SwipeableCard<Content: View>: View {
    let actions: [CardSwipeAction]
    @Binding var activeSwipeID: UUID?
    let entryID: UUID
    var onHeightChange: ((CGFloat) -> Void)?
    let onTap: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0
    @State private var revealed = false
    @State private var lastDragEndTime: Date = .distantPast
    @State private var cardHeight: CGFloat = 0
    @State private var isDraggingHorizontally = false

    private let actionWidth: CGFloat = 74
    private let swipeVisibilityThreshold: CGFloat = -1
    private var totalWidth: CGFloat { actionWidth * CGFloat(actions.count) }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Action buttons revealed behind the card
            HStack(spacing: 0) {
                ForEach(actions) { action in
                    Button {
                        action.handler()
                        snap(reveal: false)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: action.icon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(action.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.white)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(action.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: cardHeight > 0 ? cardHeight : nil)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
            .opacity(revealed || dragOffset < swipeVisibilityThreshold ? 1 : 0)
            .zIndex(revealed ? 1 : 0)

            // Card content slides left to reveal actions
            content()
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear {
                                cardHeight = geo.size.height
                                onHeightChange?(geo.size.height)
                            }
                            .onChange(of: geo.size.height) { _, height in
                                cardHeight = height
                                onHeightChange?(height)
                            }
                    }
                    .allowsHitTesting(false)
                )
                .contentShape(Rectangle())
                .offset(x: dragOffset)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            guard !actions.isEmpty else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > abs(dy) else { return }
                            isDraggingHorizontally = true
                            activeSwipeID = entryID
                            let base: CGFloat = revealed ? -totalWidth : 0
                            dragOffset = min(0, max(-totalWidth, base + dx))
                        }
                        .onEnded { _ in
                            guard isDraggingHorizontally else { return }
                            isDraggingHorizontally = false
                            snap(reveal: -dragOffset > totalWidth * 0.35)
                            lastDragEndTime = Date()
                        }
                )
        }
        .onTapGesture {
            guard Date().timeIntervalSince(lastDragEndTime) > 0.15 else { return }
            if revealed {
                snap(reveal: false)
            } else {
                onTap()
            }
        }
        .onChange(of: activeSwipeID) { _, newID in
            if newID != entryID && revealed {
                snap(reveal: false)
            }
        }
    }

    private func snap(reveal: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            revealed = reveal
            dragOffset = reveal ? -totalWidth : 0
        }
    }
}

#Preview("Home - Category Sections") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    HomeView(
        inputText: $inputText,
        entries: [
            Entry(
                transcript: "",
                content: "DMV appointment Thursday",
                category: .reminder,
                sourceText: "",
                summary: "DMV appointment Thursday",
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
            ),
            Entry(
                transcript: "",
                content: "Review design system and provide feedback",
                category: .todo,
                sourceText: "",
                summary: "Review design system and provide feedback",
                priority: 1,
                dueDate: Date()
            ),
            Entry(
                transcript: "",
                content: "Call dentist about appointment",
                category: .todo,
                sourceText: "",
                summary: "Call dentist about appointment",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Meditate for 10 minutes",
                category: .habit,
                sourceText: "",
                summary: "Meditate for 10 minutes"
            ),
            Entry(
                transcript: "",
                content: "Voice-controlled home garden watering system",
                category: .idea,
                sourceText: "",
                summary: "Voice-controlled home garden watering system"
            ),
            Entry(
                transcript: "",
                content: "App that turns grocery receipts into meal plans",
                category: .idea,
                sourceText: "",
                summary: "App that turns grocery receipts into meal plans"
            )
        ],
        onMicTap: { print("Mic tapped") },
        onSubmit: { print("Submit:", inputText) },
        onEntryTap: { print("Entry tapped:", $0.summary) },
        onSettingsTap: { print("Settings tapped") },
        onAction: { entry, action in print("Action:", action, entry.summary) }
    )
    .environment(appState)
    .background(Theme.Colors.bgDeep)
}
