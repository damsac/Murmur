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
            // Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(greeting)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Text(formattedDate)
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Daily brief
            if !dailyBrief.isEmpty {
                Text(dailyBrief)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.bottom, 4)
            }

            // Scrollable content: focus strip + category sections
            ScrollView {
                VStack(spacing: 0) {
                    // Focus strip (always pinned at top)
                    FocusStripView(entries: focusEntries, onEntryTap: onEntryTap)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

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

    private var greeting: String { Greeting.current }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private var formattedDate: String {
        Self.dateFormatter.string(from: Date())
    }

    private var dailyBrief: String {
        let now = Date()
        let calendar = Calendar.current

        let overdue = entries.filter { ($0.dueDate ?? .distantFuture) < now }.count
        let dueToday = entries.filter { guard let d = $0.dueDate else { return false }; return d >= now && calendar.isDateInToday(d) }.count
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)) ?? now
        let dueThisWeek = entries.filter { guard let d = $0.dueDate else { return false }; return d > now && !calendar.isDateInToday(d) && d <= endOfWeek }.count

        var parts: [String] = []
        if overdue > 0 { parts.append("\(overdue) overdue") }
        if dueToday > 0 { parts.append("\(dueToday) due today") }
        if dueThisWeek > 0 { parts.append("\(dueThisWeek) due this week") }

        let total = entries.count
        if parts.isEmpty {
            return total == 1 ? "1 entry" : "\(total) entries"
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Focus Strip Data

    /// Entries qualifying for the focus strip: overdue (dueDate < now) or P1/P2.
    private var focusEntries: [Entry] {
        let now = Date()
        return entries
            .filter { entry in
                let isOverdue = entry.dueDate.map { $0 < now } ?? false
                let isHighPriority = (entry.priority ?? Int.max) <= 2
                return isOverdue || isHighPriority
            }
            .sorted { lhs, rhs in
                let now = Date()
                let lo = lhs.dueDate.map { $0 < now } ?? false
                let ro = rhs.dueDate.map { $0 < now } ?? false
                if lo != ro { return lo }
                let pa = lhs.priority ?? Int.max
                let pb = rhs.priority ?? Int.max
                if pa != pb { return pa < pb }
                return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
            }
    }

    // MARK: - Category Section Data

    private static let categoryDisplayOrder: [EntryCategory] = [
        .todo, .reminder, .habit, .idea, .list, .note, .question, .thought
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
    let entries: [Entry]
    let onEntryTap: (Entry) -> Void

    private let maxVisible = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.Colors.accentRed)
                Text("NEEDS ATTENTION")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            if entries.isEmpty {
                Text("All clear")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(entries.prefix(maxVisible))) { entry in
                            FocusChipView(entry: entry) { onEntryTap(entry) }
                        }

                        if entries.count > maxVisible {
                            Text("+\(entries.count - maxVisible) more →")
                                .font(Theme.Typography.badge)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Theme.Colors.bgCard)
                                        .overlay(Capsule().stroke(Theme.Colors.borderSubtle, lineWidth: 1))
                                )
                        }
                    }
                    .padding(.bottom, 1) // prevents shadow clipping
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.Colors.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(entries.isEmpty
                            ? Theme.Colors.borderSubtle
                            : Theme.Colors.accentRed.opacity(0.20),
                            lineWidth: 1)
                )
                .shadow(color: entries.isEmpty
                    ? Color.clear
                    : Theme.Colors.accentRed.opacity(0.06),
                    radius: 12, x: 0, y: 2)
        )
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }
}

// MARK: - Focus Chip

private struct FocusChipView: View {
    let entry: Entry
    let onTap: () -> Void

    private var color: Color { Theme.categoryColor(entry.category) }
    private var isOverdue: Bool { entry.dueDate.map { $0 < Date() } ?? false }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .shadow(color: color.opacity(0.5), radius: 3)

                Text(entry.summary)
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: 130)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isOverdue ? Theme.Colors.accentRed.opacity(0.12) : color.opacity(0.10))
                    .overlay(
                        Capsule().stroke(
                            isOverdue ? Theme.Colors.accentRed.opacity(0.35) : color.opacity(0.25),
                            lineWidth: 1
                        )
                    )
            )
        }
        .buttonStyle(.plain)
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

                    if hasOverdue {
                        Circle()
                            .fill(Theme.Colors.accentRed)
                            .frame(width: 5, height: 5)
                            .padding(.leading, 6)
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

    private var cardAccent: Color? {
        isOverdue ? Theme.Colors.accentRed : nil
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
                    .foregroundStyle(entry.isDoneForPeriod ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if entry.category == .habit {
                    Button {
                        onAction(entry, .checkOffHabit)
                    } label: {
                        Image(systemName: entry.isDoneForPeriod ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                entry.isDoneForPeriod
                                    ? Theme.categoryColor(entry.category)
                                    : Theme.Colors.textTertiary
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: entry.isDoneForPeriod)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardStyle(accent: cardAccent, intensity: isOverdue ? 1.2 : 1.0)
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
                .offset(x: dragOffset)
                .onTapGesture {
                    guard Date().timeIntervalSince(lastDragEndTime) > 0.15 else { return }
                    if revealed {
                        snap(reveal: false)
                    } else {
                        onTap()
                    }
                }
                .overlay(
                    HorizontalPanGestureView(
                        onChanged: { dx in
                            guard !actions.isEmpty else { return }
                            activeSwipeID = entryID
                            let base: CGFloat = revealed ? -totalWidth : 0
                            dragOffset = min(0, max(-totalWidth, base + dx))
                        },
                        onEnded: { _ in
                            guard !actions.isEmpty else { return }
                            snap(reveal: -dragOffset > totalWidth * 0.35)
                            lastDragEndTime = Date()
                        }
                    )
                    .allowsHitTesting(actions.isEmpty ? false : true)
                )
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

// MARK: - Horizontal Pan Gesture (UIKit)

/// A UIKit-based horizontal pan gesture recognizer that coexists with UIScrollView.
/// Only begins recognition for horizontal drags, letting vertical scrolls pass through.
private struct HorizontalPanGestureView: UIViewRepresentable {
    var onChanged: (CGFloat) -> Void
    var onEnded: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = HorizontalPanHostView()
        view.backgroundColor = .clear

        let pan = DirectionalPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan)
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping (CGFloat) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            switch gesture.state {
            case .changed:
                onChanged(translation.x)
            case .ended, .cancelled:
                onEnded(translation.x)
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

/// Pan gesture recognizer that only begins for horizontal drags.
private class DirectionalPanGestureRecognizer: UIPanGestureRecognizer {
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        // Only decide direction once, at the beginning of the gesture
        guard state == .began else { return }
        let velocity = self.velocity(in: view)
        if abs(velocity.y) > abs(velocity.x) {
            state = .cancelled
        }
    }
}

/// Host view for horizontal pan gesture overlay.
private class HorizontalPanHostView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit == self ? self : hit
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
