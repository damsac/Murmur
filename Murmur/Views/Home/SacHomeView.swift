import SwiftUI
import MurmurCore

struct SacHomeView: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    let entries: [Entry]
    let onMicTap: () -> Void
    let onSubmit: () -> Void
    let onEntryTap: (Entry) -> Void
    let onKeyboardTap: () -> Void
    let onSettingsTap: () -> Void
    let onCalendarTap: () -> Void
    let onAction: (Entry, EntryAction) -> Void
    // Empty state pulse animations
    @State private var pulseScale1: CGFloat = 1.0
    @State private var pulseScale2: CGFloat = 1.0
    @State private var pulseScale3: CGFloat = 1.0
    @State private var pulseOpacity1: Double = 1.0
    @State private var pulseOpacity2: Double = 0.7
    @State private var pulseOpacity3: Double = 0.5
    @State private var activeSwipeEntryID: UUID?
    @State private var focusMessageVisible: Bool = false
    @State private var focusVisibleCardCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .background(Theme.Colors.bgDeep)
            if entries.isEmpty {
                emptyState
            } else {
                populatedState
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onCalendarTap) {
                Image(systemName: "calendar")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Calendar")
            .padding(.leading, Theme.Spacing.screenPadding - 10)

            Spacer()

            Button(action: onSettingsTap) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
            .padding(.trailing, Theme.Spacing.screenPadding - 10)
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

    // MARK: - Populated State (tab switcher)

    @ViewBuilder
    private var populatedState: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let tabIndex: CGFloat = appState.selectedTab == .focus ? 0 : 1

            HStack(spacing: 0) {
                FocusTabView(
                    isLoading: appState.isHomeCompositionLoading,
                    composition: appState.homeComposition,
                    isProcessing: appState.conversation.isProcessing,
                    allEntries: entries,
                    activeSwipeEntryID: $activeSwipeEntryID,
                    messageVisible: $focusMessageVisible,
                    visibleCardCount: $focusVisibleCardCount,
                    onEntryTap: onEntryTap,
                    swipeActionsProvider: swipeActions(for:),
                    onAction: onAction
                )
                .frame(width: width)

                AllEntriesView(
                    entries: entries,
                    isProcessing: appState.conversation.isProcessing,
                    arrivedEntryIDs: appState.conversation.arrivedEntryIDs,
                    activeSwipeEntryID: $activeSwipeEntryID,
                    onEntryTap: onEntryTap,
                    swipeActionsProvider: swipeActions(for:),
                    onAction: onAction,
                    onGlowComplete: { id in appState.conversation.arrivedEntryIDs.remove(id) }
                )
                .frame(width: width)
            }
            .frame(width: width, alignment: .leading)
            .offset(x: -(tabIndex * width))
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appState.selectedTab)
            .clipped()
        }
    }

    // MARK: - Swipe Actions

    private func swipeActions(for entry: Entry) -> [CardSwipeAction] {
        [
            CardSwipeAction(
                icon: "checkmark.circle.fill", label: "Done",
                color: Theme.Colors.accentGreen
            ) { onAction(entry, .complete) },
            CardSwipeAction(
                icon: "moon.zzz.fill", label: "Snooze",
                color: Theme.Colors.accentYellow
            ) { onAction(entry, .snooze(until: nil)) }
        ]
    }
}

// MARK: - Focus Tab (full-page focus dashboard)

private struct FocusTabView: View {
    let isLoading: Bool
    let composition: HomeComposition?
    let isProcessing: Bool
    let allEntries: [Entry]
    @Binding var activeSwipeEntryID: UUID?
    @Binding var messageVisible: Bool
    @Binding var visibleCardCount: Int
    let onEntryTap: (Entry) -> Void
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void

    private struct FocusItemResolved {
        let entry: Entry
        let reason: String
        let globalIndex: Int
    }

    private struct ResolvedCluster {
        let items: [FocusItemResolved]

        var dominantCategory: EntryCategory {
            items.first?.entry.category ?? .todo
        }
    }

    private static let maxFocusItems = 7

    /// Flatten composition items and re-group by entry category client-side.
    private func resolvedClusters(composition: HomeComposition) -> [ResolvedCluster] {
        var byCategory: [EntryCategory: [(entry: Entry, badge: String?)]] = [:]
        var total = 0
        for section in composition.sections {
            for item in section.items {
                guard total < Self.maxFocusItems,
                      case .entry(let composed) = item,
                      let entry = Entry.resolve(shortID: composed.id, in: allEntries) else { continue }
                byCategory[entry.category, default: []].append((entry, composed.badge))
                total += 1
            }
        }
        let order: [EntryCategory] = [.todo, .reminder, .habit, .idea, .list, .note, .question]
        var globalIndex = 0
        var result: [ResolvedCluster] = []
        for category in order {
            guard let pairs = byCategory[category], !pairs.isEmpty else { continue }
            let items = pairs.map { pair -> FocusItemResolved in
                let item = FocusItemResolved(
                    entry: pair.entry,
                    reason: pair.badge ?? "",
                    globalIndex: globalIndex
                )
                globalIndex += 1
                return item
            }
            result.append(ResolvedCluster(items: items))
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading && composition == nil {
                    FocusLoadingView()
                        .transition(.opacity)
                } else if let composition {
                    // Greeting + briefing header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Greeting.current + ".")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)

                        if let briefing = composition.briefing {
                            Text(briefing)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(messageVisible ? 1 : 0)
                    .offset(y: messageVisible ? 0 : 6)

                    // Focus clusters
                    let clusters = resolvedClusters(composition: composition)
                    if !clusters.isEmpty {
                        VStack(spacing: 24) {
                            ForEach(clusters.indices, id: \.self) { i in
                                let cluster = clusters[i]
                                VStack(alignment: .leading, spacing: 12) {
                                    let dominantCat = cluster.dominantCategory
                                    let accentColor = Theme.categoryColor(dominantCat)
                                    HStack(spacing: 0) {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(accentColor)
                                                .frame(width: 8, height: 8)
                                                .shadow(color: accentColor.opacity(0.6), radius: 4)
                                            Text(dominantCat.displayName.uppercased())
                                                .font(Theme.Typography.badge)
                                                .foregroundStyle(Theme.Colors.textSecondary)
                                                .tracking(0.8)
                                        }
                                        Spacer()
                                        Text("\(cluster.items.count)")
                                            .font(Theme.Typography.badge)
                                            .foregroundStyle(Theme.Colors.textTertiary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(
                                                Capsule()
                                                    .fill(Theme.Colors.bgCard)
                                                    .overlay(Capsule().stroke(Theme.Colors.borderSubtle, lineWidth: 1))
                                            )
                                    }
                                    VStack(spacing: 10) {
                                        ForEach(cluster.items, id: \.entry.id) { item in
                                            if item.globalIndex < visibleCardCount {
                                                FocusCardExpandedView(
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
                            }
                        }
                    }

                    // Processing indicator below focus cards
                    if isProcessing {
                        SharedProcessingDotsView()
                            .transition(.opacity)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 160)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            guard visibleCardCount == 0, let composition else { return }
            let count = resolvedClusters(composition: composition).reduce(0) { $0 + $1.items.count }
            staggerIn(count: count)
        }
        .onChange(of: composition?.composedAt) { _, _ in
            guard let composition else { return }
            messageVisible = false
            visibleCardCount = 0
            let count = resolvedClusters(composition: composition).reduce(0) { $0 + $1.items.count }
            staggerIn(count: count)
        }
    }

    private func staggerIn(count: Int) {
        withAnimation(.easeOut(duration: 0.4)) {
            messageVisible = true
        }
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

// MARK: - Focus Card (compact — matches SmartListRow dimensions)

private struct FocusCardExpandedView: View {
    let entry: Entry
    let reason: String
    @Binding var activeSwipeEntryID: UUID?
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void
    let onTap: () -> Void

    @State private var glowIntensity: Double = 1.0

    private var accentColor: Color { Theme.categoryColor(entry.category) }

    private var isOverdue: Bool {
        guard let dueDate = entry.dueDate else { return false }
        return dueDate < Date() && entry.status == .active
    }

    private var detailText: String? {
        if entry.category == .habit, let cadence = entry.cadence {
            return cadence.displayName
        }
        guard let dueDate = entry.dueDate else { return nil }
        let priorityPrefix = (entry.priority ?? Int.max) <= 2 ? "P\(entry.priority!) · " : ""
        if isOverdue { return priorityPrefix + "Overdue" }
        if Calendar.current.isDateInToday(dueDate) { return priorityPrefix + "Due today" }
        if Calendar.current.isDateInTomorrow(dueDate) { return priorityPrefix + "Due tomorrow" }
        return nil
    }

    private var detailColor: Color {
        isOverdue ? Theme.Colors.accentRed : Theme.Colors.textTertiary
    }

    var body: some View {
        SwipeableCard(
            actions: swipeActionsProvider(entry),
            activeSwipeID: $activeSwipeEntryID,
            entryID: entry.id,
            onTap: onTap
        ) {
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

                    if let detail = detailText {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(detailColor)
                    } else if !reason.isEmpty {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            }
            .cardStyle()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                    .stroke(accentColor.opacity(0.45 * glowIntensity), lineWidth: 1.5)
            )
            .shadow(color: accentColor.opacity(0.25 * glowIntensity), radius: 14, y: 0)
            .opacity(entry.isDoneForPeriod || entry.isCompletedToday ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.8)) {
                glowIntensity = 0
            }
        }
    }
}

// AllTabView, CategorySectionView, SmartListRow, ProcessingDotsView
// extracted to AllEntriesView.swift (shared by both home variants)

// MARK: - Focus Loading State

private struct FocusLoadingView: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Greeting.current + ".")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary.opacity(0.35))
            Text("Murmur is selecting your focus…")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .opacity(isPulsing ? 0.45 : 0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

// CategorySectionView, GlowingEntryRow, SmartListRow, ProcessingDotsView
// are defined in AllEntriesView.swift (shared by both home variants)

#Preview("Home - Category Sections") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    SacHomeView(
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
        onKeyboardTap: { print("Keyboard tapped") },
        onSettingsTap: { print("Settings tapped") },
        onCalendarTap: { print("Calendar tapped") },
        onAction: { entry, action in print("Action:", action, entry.summary) }
    )
    .environment(appState)
    .background(Theme.Colors.bgDeep)
}
