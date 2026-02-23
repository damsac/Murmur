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

            // Flat smart list
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(sortedEntries) { entry in
                        SwipeableCard(
                            actions: swipeActions(for: entry),
                            activeSwipeID: $activeSwipeEntryID,
                            entryID: entry.id,
                            onTap: { onEntryTap(entry) }
                        ) {
                            SmartListRow(entry: entry)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
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

    /// Sort entries by relevance: priority (urgent first), due date (soonest first), then recency.
    private var sortedEntries: [Entry] {
        entries.sorted { lhs, rhs in
            let pa = lhs.priority ?? Int.max
            let pb = rhs.priority ?? Int.max
            if pa != pb { return pa < pb }

            let da = lhs.dueDate ?? Date.distantFuture
            let db = rhs.dueDate ?? Date.distantFuture
            if da != db { return da < db }

            return lhs.createdAt > rhs.createdAt
        }
    }

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

// MARK: - Smart List Row

private struct SmartListRow: View {
    let entry: Entry

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
        if isOverdue { return Theme.Colors.accentRed }
        if entry.dueDate != nil { return Theme.Colors.accentYellow }
        return nil
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

            // Summary
            Text(entry.summary)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                .simultaneousGesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            guard !actions.isEmpty else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > abs(dy) * 0.6 else { return }
                            if abs(dx) > 5 { activeSwipeID = entryID }
                            let base: CGFloat = revealed ? -totalWidth : 0
                            dragOffset = min(0, max(-totalWidth, base + dx))
                        }
                        .onEnded { value in
                            guard !actions.isEmpty else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > abs(dy) * 0.6 else { return }
                            snap(reveal: -dragOffset > totalWidth * 0.35)
                            lastDragEndTime = Date()
                        }
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

#Preview("Home - Smart List") {
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
                dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
            ),
            Entry(
                transcript: "",
                content: "Review design system and provide feedback",
                category: .todo,
                sourceText: "",
                summary: "Review design system and provide feedback",
                priority: 1
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
