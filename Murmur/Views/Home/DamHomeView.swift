import SwiftUI
import MurmurCore

struct DamHomeView: View {
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

    @Namespace private var layoutNamespace
    @State private var revealedEntryIDs: Set<String> = []
    @State private var hasAnimatedInitialLoad: Bool = false
    @State private var activeSwipeEntryID: UUID?

    var body: some View {
        if entries.isEmpty {
            emptyState
        } else {
            composedContent
        }
    }

    // MARK: - Composed Content

    @ViewBuilder
    private var composedContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Settings gear
                HStack {
                    Spacer()
                    Button(action: onSettingsTap) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.top, 4)

                // Recent inserts — entries/messages created since last composition
                if !appState.recentInserts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(appState.recentInserts) { insert in
                            switch insert {
                            case .entry(let id):
                                if let entry = entries.first(where: { $0.id == id }) {
                                    ComposedEntryView(
                                        entry: entry,
                                        emphasis: .standard,
                                        badge: nil,
                                        activeSwipeEntryID: $activeSwipeEntryID,
                                        swipeActionsProvider: swipeActions(for:),
                                        onTap: { onEntryTap(entry) },
                                        onAction: { onAction(entry, $0) }
                                    )
                                }
                            case .message(let text, _):
                                ComposedMessageView(text: text)
                            }
                        }
                    }
                    .padding(.bottom, 16)
                }

                if appState.isHomeCompositionLoading && appState.homeComposition == nil {
                    CompositionShimmerView()
                }

                if let composition = appState.homeComposition {
                    ForEach(composition.sections) { section in
                        ComposedSectionView(
                            section: section,
                            entries: entries,
                            activeSwipeEntryID: $activeSwipeEntryID,
                            layoutNamespace: layoutNamespace,
                            isEntryRevealed: isEntryRevealed,
                            onEntryTap: onEntryTap,
                            swipeActionsProvider: swipeActions(for:),
                            onAction: onAction
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    .animation(Animations.layoutSpring, value: composition.sections.map(\.id))
                }
            }
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            Task {
                await appState.requestHomeComposition(entries: entries, variant: .scanner)
            }
        }
        .onChange(of: appState.homeComposition?.composedAt) { _, newValue in
            if newValue != nil && !hasAnimatedInitialLoad {
                staggerRevealEntries()
            }
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onSettingsTap) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.top, 4)

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

    // MARK: - Pulse Animation

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

    // MARK: - Layout Reveal

    private func isEntryRevealed(_ id: String) -> Bool {
        hasAnimatedInitialLoad || revealedEntryIDs.contains(id)
    }

    private func staggerRevealEntries() {
        guard let composition = appState.homeComposition else { return }
        let allEntryIDs = composition.sections.flatMap { section in
            section.items.compactMap { item in
                if case .entry(let e) = item { return e.id }
                return nil
            }
        }

        guard !allEntryIDs.isEmpty else {
            hasAnimatedInitialLoad = true
            return
        }

        for (index, id) in allEntryIDs.enumerated() {
            let delay = Double(index) * 0.06
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(Animations.layoutSpring) {
                    revealedEntryIDs.insert(id)
                }
            }
        }

        // Mark initial load complete after all entries revealed
        let totalDelay = Double(allEntryIDs.count) * 0.06 + 0.3
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(totalDelay))
            hasAnimatedInitialLoad = true
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

// MARK: - Composed Section View

private struct ComposedSectionView: View {
    let section: ComposedSection
    let entries: [Entry]
    @Binding var activeSwipeEntryID: UUID?
    var layoutNamespace: Namespace.ID
    var isEntryRevealed: (String) -> Bool
    let onEntryTap: (Entry) -> Void
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onAction: (Entry, EntryAction) -> Void

    private var sectionSpacing: CGFloat {
        section.density == .compact ? 8 : 16
    }

    private var itemSpacing: CGFloat {
        section.density == .compact ? 4 : 8
    }

    /// Resolve composed items against real entries, dropping unresolvable ones.
    private var resolvedItems: [ResolvedItem] {
        section.items.compactMap { item in
            switch item {
            case .entry(let composed):
                guard let entry = Entry.resolve(shortID: composed.id, in: entries) else {
                    return nil
                }
                return .entry(entry, composed)
            case .message(let text):
                return .message(text)
            }
        }
    }

    var body: some View {
        let items = resolvedItems
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                if let title = section.title {
                    Text(title.uppercased())
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .tracking(0.8)
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                        .padding(.top, 20)
                        .padding(.bottom, 4)
                }

                if section.density == .compact {
                    FlowLayout(spacing: 6) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                            switch item {
                            case .entry(let entry, let composed):
                                ComposedEntryView(
                                    entry: entry,
                                    emphasis: .compact,
                                    badge: composed.badge,
                                    activeSwipeEntryID: $activeSwipeEntryID,
                                    swipeActionsProvider: swipeActionsProvider,
                                    onTap: { onEntryTap(entry) },
                                    onAction: { onAction(entry, $0) }
                                )
                                .matchedGeometryEffect(id: "entry-\(composed.id)", in: layoutNamespace)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .opacity(isEntryRevealed(composed.id) ? 1 : 0)
                                .scaleEffect(isEntryRevealed(composed.id) ? 1 : 0.95)
                            case .message(let text):
                                ComposedMessageView(text: text)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                } else {
                    VStack(alignment: .leading, spacing: itemSpacing) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { _, item in
                            switch item {
                            case .entry(let entry, let composed):
                                ComposedEntryView(
                                    entry: entry,
                                    emphasis: composed.emphasis,
                                    badge: composed.badge,
                                    activeSwipeEntryID: $activeSwipeEntryID,
                                    swipeActionsProvider: swipeActionsProvider,
                                    onTap: { onEntryTap(entry) },
                                    onAction: { onAction(entry, $0) }
                                )
                                .matchedGeometryEffect(id: "entry-\(composed.id)", in: layoutNamespace)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                .opacity(isEntryRevealed(composed.id) ? 1 : 0)
                                .scaleEffect(isEntryRevealed(composed.id) ? 1 : 0.95)
                            case .message(let text):
                                ComposedMessageView(text: text)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Resolved Item

private enum ResolvedItem: Identifiable {
    case entry(Entry, ComposedEntry)
    case message(String)

    var id: String {
        switch self {
        case .entry(let entry, _): return "entry-\(entry.id.uuidString)"
        case .message(let text): return "msg-\(text.prefix(20).hashValue)"
        }
    }
}

// MARK: - Composed Entry View

private struct ComposedEntryView: View {
    let entry: Entry
    let emphasis: EntryEmphasis
    let badge: String?
    @Binding var activeSwipeEntryID: UUID?
    let swipeActionsProvider: (Entry) -> [CardSwipeAction]
    let onTap: () -> Void
    let onAction: (EntryAction) -> Void

    private var categoryColor: Color { Theme.categoryColor(entry.category) }
    private var isDone: Bool { entry.isDoneForPeriod || entry.isCompletedToday }

    var body: some View {
        switch emphasis {
        case .hero:
            heroView
        case .standard:
            standardView
        case .compact:
            compactView
        }
    }

    // MARK: - Hero Emphasis (thin card, no border/glow)

    @ViewBuilder
    private var heroView: some View {
        SwipeableCard(
            actions: swipeActionsProvider(entry),
            activeSwipeID: $activeSwipeEntryID,
            entryID: entry.id,
            onTap: onTap
        ) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 6, height: 6)

                    Text(entry.summary)
                        .font(Theme.Typography.body)
                        .foregroundStyle(isDone ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    habitCheckOff
                }

                if badge != nil {
                    badgeLabel
                        .padding(.leading, 14)
                }
            }
            .padding(12)
            .background(Theme.Colors.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(isDone ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
    }

    // MARK: - Standard Emphasis (borderless row + hairline separator)

    @ViewBuilder
    private var standardView: some View {
        VStack(spacing: 0) {
            SwipeableCard(
                actions: swipeActionsProvider(entry),
                activeSwipeID: $activeSwipeEntryID,
                entryID: entry.id,
                onTap: onTap
            ) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(categoryColor)
                        .frame(width: 6, height: 6)

                    Text(entry.summary)
                        .font(Theme.Typography.body)
                        .foregroundStyle(isDone ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    habitCheckOff

                    if let priority = entry.priority, priority <= 2 {
                        Text("P\(priority)")
                            .font(Theme.Typography.badge)
                            .foregroundStyle(Theme.Colors.accentRed)
                    }

                    badgeLabel
                }
                .padding(.vertical, 10)
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .background(Theme.Colors.bgDeep)
            }

            Rectangle()
                .fill(Theme.Colors.borderSubtle)
                .frame(height: 0.5)
                .padding(.leading, Theme.Spacing.screenPadding + 14)
        }
        .opacity(isDone ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: entry.isCompletedToday)
    }

    // MARK: - Compact Emphasis (flow chip)

    @ViewBuilder
    private var compactView: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 5, height: 5)

                Text(entry.summary)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(isDone ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.Colors.bgCard.opacity(0.6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isDone ? 0.5 : 1.0)
    }

    // MARK: - Shared Subviews

    @ViewBuilder
    private var badgeLabel: some View {
        if let badge {
            Text(badge)
                .font(Theme.Typography.badge)
                .foregroundStyle(badgeColor)
        }
    }

    @ViewBuilder
    private var habitCheckOff: some View {
        if entry.category == .habit && entry.appliesToday {
            Button {
                onAction(.checkOffHabit)
            } label: {
                Image(systemName: entry.isCompletedToday ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(
                        entry.isCompletedToday
                            ? Theme.categoryColor(entry.category)
                            : Theme.Colors.textTertiary
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: entry.isCompletedToday)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var badgeColor: Color {
        guard let badge else { return Theme.Colors.textSecondary }
        let lower = badge.lowercased()
        if lower == "overdue" { return Theme.Colors.accentRed }
        if lower == "today" { return Theme.Colors.accentYellow }
        if lower == "stale" { return Theme.Colors.accentOrange }
        if lower == "new" { return Theme.Colors.accentGreen }
        if lower.hasPrefix("p") { return Theme.Colors.accentRed }
        return Theme.Colors.textSecondary
    }
}

// MARK: - Composed Message View

private struct ComposedMessageView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(Theme.Colors.textSecondary)
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .padding(.vertical, 8)
    }
}

// MARK: - Flow Layout (for compact chip wrapping)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(subviews: subviews, in: proposal.width ?? 0)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(subviews: subviews, in: bounds.width)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(subviews: Subviews, in width: CGFloat) -> (positions: [CGPoint], height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (positions, positions.isEmpty ? 0 : y + rowHeight)
    }
}

// MARK: - Composition Shimmer View

private struct CompositionShimmerView: View {
    @State private var glowPhases: [Bool] = [false, false, false]

    var body: some View {
        VStack(spacing: 20) {
            // Section 1 placeholder
            VStack(alignment: .leading, spacing: 12) {
                // Section title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.bgCard)
                    .frame(width: 120, height: 12)
                    .opacity(glowPhases[0] ? 0.4 : 0.7)

                // Hero card placeholder
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.bgCard)
                            .frame(width: 50, height: 14)
                        Spacer()
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.bgCard)
                            .frame(width: 60, height: 14)
                    }
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.bgCard)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Theme.Colors.bgCard)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, 60)
                }
                .cardStyle()
                .opacity(glowPhases[0] ? 0.45 : 1.0)
                .shadow(
                    color: Theme.Colors.textTertiary.opacity(glowPhases[0] ? 0.15 : 0),
                    radius: 12, y: 0
                )

                // Standard card placeholder
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
                .opacity(glowPhases[1] ? 0.45 : 1.0)
                .shadow(
                    color: Theme.Colors.textTertiary.opacity(glowPhases[1] ? 0.15 : 0),
                    radius: 12, y: 0
                )
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)

            // Section 2 placeholder (compact rows)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.Colors.bgCard)
                    .frame(width: 80, height: 12)
                    .opacity(glowPhases[1] ? 0.4 : 0.7)

                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Theme.Colors.bgCard)
                            .frame(width: 6, height: 6)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.Colors.bgCard)
                            .frame(height: 14)
                            .frame(maxWidth: .infinity)
                            .padding(.trailing, 40)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, Theme.Spacing.screenPadding)
            .opacity(glowPhases[2] ? 0.45 : 1.0)

            // Loading text
            Text("Composing your view...")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .opacity(glowPhases[2] ? 0.4 : 0.7)
        }
        .padding(.top, 20)
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

// MARK: - Previews

#Preview("Dam Home - Empty") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    DamHomeView(
        inputText: $inputText,
        entries: [],
        onMicTap: {},
        onSubmit: {},
        onEntryTap: { _ in },
        onSettingsTap: {},
        onAction: { _, _ in }
    )
    .environment(appState)
    .background(Theme.Colors.bgDeep)
}

#Preview("Dam Home - With Entries") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    DamHomeView(
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
                content: "Review design system",
                category: .todo,
                sourceText: "",
                summary: "Review design system and provide feedback",
                priority: 1,
                dueDate: Date()
            ),
            Entry(
                transcript: "",
                content: "Call dentist",
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
                content: "Voice-controlled garden watering",
                category: .idea,
                sourceText: "",
                summary: "Voice-controlled home garden watering system"
            )
        ],
        onMicTap: {},
        onSubmit: {},
        onEntryTap: { _ in },
        onSettingsTap: {},
        onAction: { _, _ in }
    )
    .environment(appState)
    .background(Theme.Colors.bgDeep)
}
