import SwiftUI
import MurmurCore

struct ZonedFocusHomeView: View {
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
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            }
            Spacer()
            Spacer()
        }
    }

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            pulseScale1 = 1.05; pulseOpacity1 = 0.8
        }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(0.5)) {
            pulseScale2 = 1.05; pulseOpacity2 = 0.5
        }
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true).delay(1.0)) {
            pulseScale3 = 1.05; pulseOpacity3 = 0.3
        }
    }

    // MARK: - Populated State

    @ViewBuilder
    private var populatedState: some View {
        TabView(selection: Binding(
            get: { appState.selectedTab },
            set: { appState.selectedTab = $0 }
        )) {
            ZonedFocusTabView(
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
            .tag(AppState.Tab.focus)

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
            .tag(AppState.Tab.all)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .mask(
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 110)
            }
        )
    }

    // MARK: - Swipe Actions

    private func swipeActions(for entry: Entry) -> [CardSwipeAction] {
        [
            CardSwipeAction(icon: "checkmark.circle.fill", label: "Done", color: Theme.Colors.accentGreen) {
                onAction(entry, .complete)
            },
            CardSwipeAction(icon: "moon.zzz.fill", label: "Snooze", color: Theme.Colors.accentYellow) {
                onAction(entry, .snooze(until: nil))
            }
        ]
    }
}

// MARK: - Shared data types (file-private)

private struct ZonedFocusItem {
    let entry: Entry
    let reason: String
    let globalIndex: Int
}

private struct ZonedItems {
    let hero: ZonedFocusItem?
    let standard: [ZonedFocusItem]
    let habits: [Entry]
}

// MARK: - Zoned Focus Tab

private struct ZonedFocusTabView: View {
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

    private static let maxFocusItems = 7

    private func urgencyScore(_ entry: Entry) -> Int {
        var score = 0
        if let due = entry.dueDate, due < Date(), entry.status == .active { score += 100 }
        if let p = entry.priority { score += p == 1 ? 60 : p == 2 ? 40 : 0 }
        if let due = entry.dueDate, Calendar.current.isDateInToday(due) { score += 25 }
        return score
    }

    private func zoneItems(composition: HomeComposition) -> ZonedItems {
        var tasks: [(entry: Entry, badge: String?)] = []
        var habits: [Entry] = []
        var total = 0

        for section in composition.sections {
            for item in section.items {
                guard total < Self.maxFocusItems,
                      case .entry(let composed) = item,
                      let entry = Entry.resolve(shortID: composed.id, in: allEntries) else { continue }
                if entry.category == .habit {
                    habits.append(entry)
                } else {
                    tasks.append((entry, composed.badge))
                }
                total += 1
            }
        }

        let sorted = tasks.sorted { urgencyScore($0.entry) > urgencyScore($1.entry) }
        var globalIndex = 0
        let items: [ZonedFocusItem] = sorted.map { pair in
            defer { globalIndex += 1 }
            return ZonedFocusItem(entry: pair.entry, reason: pair.badge ?? "", globalIndex: globalIndex)
        }

        return ZonedItems(
            hero: items.first,
            standard: items.count > 1 ? Array(items.dropFirst()) : [],
            habits: habits.filter { $0.appliesToday }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isLoading && composition == nil {
                    FocusLoadingView()
                        .transition(.opacity)
                } else if let composition {
                    // Greeting + briefing
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Greeting.current + ".")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        if let briefing = composition.briefing {
                            Text(briefing)
                                .font(.subheadline)
                                .foregroundStyle(Theme.Colors.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(messageVisible ? 1 : 0)
                    .offset(y: messageVisible ? 0 : 6)
                    .padding(.bottom, 20)

                    let zones = zoneItems(composition: composition)

                    // Zone 1 — Hero card
                    if let hero = zones.hero, 0 < visibleCardCount {
                        HeroCardView(
                            item: hero,
                            activeSwipeEntryID: $activeSwipeEntryID,
                            swipeActionsProvider: swipeActionsProvider,
                            onAction: onAction,
                            onTap: { onEntryTap(hero.entry) }
                        )
                        .transition(cardTransition)
                        .padding(.bottom, 10)
                    }

                    // Zone 2 — Standard cards
                    if !zones.standard.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(zones.standard, id: \.entry.id) { item in
                                if item.globalIndex < visibleCardCount {
                                    StandardFocusCard(
                                        entry: item.entry,
                                        reason: item.reason,
                                        activeSwipeEntryID: $activeSwipeEntryID,
                                        swipeActionsProvider: swipeActionsProvider,
                                        onAction: onAction,
                                        onTap: { onEntryTap(item.entry) }
                                    )
                                    .transition(cardTransition)
                                }
                            }
                        }
                        .padding(.bottom, zones.habits.isEmpty ? 0 : 20)
                    }

                    // Zone 3 — Habits strip
                    if !zones.habits.isEmpty {
                        HabitsStripView(habits: zones.habits, onAction: onAction)
                            .opacity(messageVisible ? 1 : 0)
                            .offset(y: messageVisible ? 0 : 6)
                    }
                }

                if isProcessing {
                    SharedProcessingDotsView()
                        .transition(.opacity)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 160)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            guard visibleCardCount == 0, let composition else { return }
            staggerIn(composition: composition)
        }
        .onChange(of: composition?.composedAt) { _, _ in
            guard let composition else { return }
            messageVisible = false
            visibleCardCount = 0
            staggerIn(composition: composition)
        }
    }

    private var cardTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity
                .combined(with: .offset(y: 8))
                .combined(with: .scale(scale: 0.97, anchor: .top)),
            removal: .opacity
        )
    }

    private func staggerIn(composition: HomeComposition) {
        let zones = zoneItems(composition: composition)
        let count = (zones.hero != nil ? 1 : 0) + zones.standard.count
        withAnimation(.easeOut(duration: 0.4)) {
            messageVisible = true
        }
        for i in 0..<count {
            let delay = 0.2 + Double(i) * 0.22
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    visibleCardCount = i + 1
                }
            }
        }
    }
}

// MARK: - Hero Card

private struct HeroCardView: View {
    let item: ZonedFocusItem
    @Binding var activeSwipeEntryID: UUID?
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void
    let onTap: () -> Void

    private var accent: Color { Theme.categoryColor(item.entry.category) }

    private var isOverdue: Bool { item.entry.isOverdue }

    private var isDueToday: Bool {
        guard let due = item.entry.dueDate, !isOverdue else { return false }
        return Calendar.current.isDateInToday(due)
    }

    var body: some View {
        SwipeableCard(
            actions: swipeActionsProvider(item.entry),
            activeSwipeID: $activeSwipeEntryID,
            entryID: item.entry.id,
            onTap: onTap
        ) {
            HStack(spacing: 0) {
                // Left accent stripe
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 3)
                    .padding(.vertical, 6)
                    .padding(.leading, 14)

                VStack(alignment: .leading, spacing: 8) {
                    // Top row: category + urgency chip
                    HStack(spacing: 0) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(accent)
                                .frame(width: 7, height: 7)
                            Text(item.entry.category.displayName.uppercased())
                                .font(Theme.Typography.badge)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .tracking(0.8)
                        }
                        Spacer()
                        if isOverdue {
                            Text("Overdue")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.accentRed)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.accentRed.opacity(0.12), in: Capsule())
                        } else if isDueToday {
                            Text("Due today")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.Colors.accentYellow)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.Colors.accentYellow.opacity(0.12), in: Capsule())
                        } else if let p = item.entry.priority, p <= 2 {
                            Text("P\(p)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(accent.opacity(0.12), in: Capsule())
                        }
                    }

                    // Summary — 3 lines, slightly heavier
                    Text(item.entry.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            item.entry.isDone
                                ? Theme.Colors.textTertiary
                                : Theme.Colors.textPrimary
                        )
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Reason sentence from LLM
                    if !item.reason.isEmpty {
                        Text(item.reason)
                            .font(.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
            .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            )
            .opacity(item.entry.isDone ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: item.entry.isCompletedToday)
        }
    }
}

// MARK: - Standard Focus Card

private struct StandardFocusCard: View {
    let entry: Entry
    let reason: String
    @Binding var activeSwipeEntryID: UUID?
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void
    let onTap: () -> Void

    private var accentColor: Color { Theme.categoryColor(entry.category) }

    private var isOverdue: Bool { entry.isOverdue }

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
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.summary)
                        .font(.subheadline)
                        .foregroundStyle(entry.isDone ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
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

                if entry.category == .habit && entry.appliesToday {
                    Button {
                        onAction(entry, .checkOffHabit)
                    } label: {
                        Image(systemName: entry.isCompletedToday ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                entry.isCompletedToday ? accentColor : Theme.Colors.textTertiary
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: entry.isCompletedToday)
                            .frame(width: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .cardStyle()
            .opacity(entry.isDone ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
        }
    }
}

// MARK: - Habits Strip

private struct HabitsStripView: View {
    let habits: [Entry]
    let onAction: (Entry, EntryAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S HABITS")
                .font(Theme.Typography.badge)
                .foregroundStyle(Theme.Colors.textTertiary)
                .tracking(0.8)

            VStack(spacing: 8) {
                ForEach(habits) { habit in
                    HabitRowView(habit: habit, onAction: onAction)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HabitRowView: View {
    let habit: Entry
    let onAction: (Entry, EntryAction) -> Void

    private var accent: Color { Theme.categoryColor(habit.category) }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                onAction(habit, .checkOffHabit)
            } label: {
                Image(systemName: habit.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(habit.isCompletedToday ? accent : Theme.Colors.textTertiary)
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: habit.isCompletedToday)
                    .frame(width: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.summary)
                    .font(.subheadline)
                    .foregroundStyle(habit.isCompletedToday ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .lineLimit(1)
                if let cadence = habit.cadence {
                    Text(cadence.displayName)
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .background(Theme.Colors.bgCard, in: RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
        )
        .opacity(habit.isDoneForPeriod ? 0.45 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: habit.isCompletedToday)
    }
}

// FocusLoadingView is defined in AllEntriesView.swift (shared by all home variants)

// MARK: - Preview

#Preview("Zoned Focus — With Data") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    ZonedFocusHomeView(
        inputText: $inputText,
        entries: [
            Entry(
                transcript: "",
                content: "Submit quarterly report to finance team",
                category: .todo,
                sourceText: "",
                summary: "Submit quarterly report to finance team",
                priority: 1,
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
            ),
            Entry(
                transcript: "",
                content: "Review design system and provide feedback",
                category: .todo,
                sourceText: "",
                summary: "Review design system and provide feedback",
                priority: 2,
                dueDate: Date()
            ),
            Entry(
                transcript: "",
                content: "Call dentist about appointment",
                category: .reminder,
                sourceText: "",
                summary: "Call dentist about appointment",
                priority: 3
            ),
            Entry(
                transcript: "",
                content: "Meditate for 10 minutes",
                category: .habit,
                sourceText: "",
                summary: "Meditate for 10 minutes",
                cadenceRawValue: "daily"
            ),
            Entry(
                transcript: "",
                content: "Exercise",
                category: .habit,
                sourceText: "",
                summary: "Exercise 30 min",
                cadenceRawValue: "daily"
            )
        ],
        onMicTap: { print("Mic") },
        onSubmit: {},
        onEntryTap: { print("Tap:", $0.summary) },
        onKeyboardTap: { print("Keyboard") },
        onSettingsTap: { print("Settings") },
        onCalendarTap: { print("Calendar") },
        onAction: { e, a in print("Action:", a, e.summary) }
    )
    .environment(appState)
    .background(Theme.Colors.bgDeep)
}
