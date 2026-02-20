import SwiftUI
import MurmurCore

struct HomeAIComposedView: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    let entries: [Entry]
    let onMicTap: () -> Void
    let onSubmit: () -> Void
    let onEntryTap: (Entry) -> Void
    let onSettingsTap: () -> Void
    let onViewsTap: () -> Void

    var body: some View {
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

            // Scrollable cards
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(composedCards, id: \.id) { card in
                        cardView(for: card)
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 16)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private var composedCards: [HomeCard] {
        var cards: [HomeCard] = []

        let reminders = entries.filter { $0.category == .reminder }
        if !reminders.isEmpty {
            cards.append(.reminders(reminders))
        }

        let todos = entries.filter { $0.category == .todo && $0.status != .completed }
        if !todos.isEmpty {
            cards.append(.todos(todos))
        }

        let habits = entries.filter { $0.category == .habit }
        if !habits.isEmpty {
            cards.append(.habits(habits))
        }

        let ideas = entries.filter { $0.category == .idea }
        if !ideas.isEmpty {
            cards.append(.ideas(Array(ideas.prefix(3))))
        }

        return cards
    }

    @ViewBuilder
    private func cardView(for card: HomeCard) -> some View {
        switch card {
        case .reminders(let entries):
            ExpandableStackCard(
                entries: entries,
                icon: "bell.fill",
                label: "Reminder",
                labelPlural: "Reminders",
                accentColor: Theme.Colors.accentYellow,
                onTap: onEntryTap
            )
        case .todos(let entries):
            ExpandableStackCard(
                entries: entries,
                icon: "checklist",
                label: "Todo",
                labelPlural: "Todos",
                accentColor: Theme.Colors.accentPurple,
                onTap: onEntryTap
            )
        case .habits(let entries):
            ExpandableStackCard(
                entries: entries,
                icon: "flame.fill",
                label: "Habit",
                labelPlural: "Habits",
                accentColor: Theme.Colors.accentGreen,
                onTap: onEntryTap
            )
        case .ideas(let entries):
            IdeasCard(entries: entries, onTap: onEntryTap)
        }
    }
}

// MARK: - Home Card Types

enum HomeCard: Identifiable {
    case reminders([Entry])
    case todos([Entry])
    case habits([Entry])
    case ideas([Entry])

    var id: String {
        switch self {
        case .reminders: return "reminders"
        case .todos: return "todos"
        case .habits: return "habits"
        case .ideas: return "ideas"
        }
    }
}

// MARK: - Expandable Stack Card

private struct ExpandableStackCard: View {
    let entries: [Entry]
    let icon: String
    let label: String
    let labelPlural: String
    let accentColor: Color
    let onTap: (Entry) -> Void

    @State private var isExpanded = false
    @State private var cardHeight: CGFloat = 86

    private let peekOffset: CGFloat = 20
    private let expandedSpacing: CGFloat = 12
    private let maxVisible = 3

    // MARK: - Urgency

    private var isAnyOverdue: Bool {
        let now = Date()
        return entries.contains { $0.dueDate.map { $0 < now } ?? false }
    }

    private var groupUrgencyAccent: Color? {
        guard entries.contains(where: { $0.dueDate != nil }) else { return nil }
        return isAnyOverdue ? Theme.Colors.accentRed : Theme.Colors.accentYellow
    }

    private var groupUrgencyIntensity: Double {
        isAnyOverdue ? 1.2 : 1.0
    }

    private var frontDueText: String? {
        let now = Date()
        let calendar = Calendar.current
        if isAnyOverdue {
            let count = entries.filter { $0.dueDate.map { $0 < now } ?? false }.count
            return count == 1 ? "Overdue" : "\(count) overdue"
        }
        guard let soonest = entries.compactMap({ $0.dueDate }).filter({ $0 >= now }).min() else { return nil }
        if calendar.isDateInToday(soonest) { return "Due today" }
        if calendar.isDateInTomorrow(soonest) { return "Due tomorrow" }
        let days = calendar.dateComponents([.day], from: now, to: soonest).day ?? 0
        return "Due in \(days)d"
    }

    var body: some View {
        let visible = Array(entries.prefix(maxVisible))

        ZStack(alignment: .top) {
            ForEach(Array(visible.enumerated().reversed()), id: \.element.id) { idx, entry in
                card(entry: entry, index: idx, total: visible.count)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, isExpanded
            ? CGFloat(visible.count - 1) * (cardHeight + expandedSpacing)
            : CGFloat(visible.count - 1) * peekOffset
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: isExpanded)
    }

    @ViewBuilder
    private func card(entry: Entry, index: Int, total: Int) -> some View {
        let isFront = index == 0
        let isSingle = entries.count == 1
        let expandAnim = Animation.spring(response: 0.5, dampingFraction: 0.72)
            .delay(isExpanded ? Double(index) * 0.05 : Double(total - 1 - index) * 0.04)

        Button {
            if isSingle || !isFront {
                onTap(entry)
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    isExpanded.toggle()
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text(isSingle ? label : labelPlural)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer()
                    if isFront && !isSingle {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }
                Text(entry.summary)
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Due date urgency row (front card only)
                if isFront, let dueText = frontDueText {
                    HStack(spacing: 4) {
                        Image(systemName: isAnyOverdue ? "exclamationmark.circle.fill" : "calendar")
                            .font(.caption2)
                        Text(dueText)
                            .font(Theme.Typography.label)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(isAnyOverdue ? Theme.Colors.accentRed : Theme.Colors.accentYellow)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(accent: isFront ? groupUrgencyAccent : nil, intensity: isFront ? groupUrgencyIntensity : 1.0)
        }
        .buttonStyle(.plain)
        // Navigate into the front entry while expanded without triggering collapse
        .overlay(alignment: .bottomTrailing) {
            if isFront && isExpanded {
                Button { onTap(entry) } label: {
                    HStack(spacing: 3) {
                        Text("Open")
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Capsule())
                    .padding(Theme.Spacing.cardPadding)
                }
                .buttonStyle(.plain)
            }
        }
        // Measure front card height for accurate expanded offsets
        .background(
            Group {
                if isFront {
                    GeometryReader { geo in
                        Color.clear.onAppear { cardHeight = geo.size.height }
                    }
                }
            }
            .allowsHitTesting(false)
        )
        .shadow(
            color: .black.opacity(isFront ? 0.14 : 0.06),
            radius: isFront ? 10 : 3,
            y: isFront ? 5 : 2
        )
        .offset(y: isExpanded
            ? CGFloat(index) * (cardHeight + expandedSpacing)
            : CGFloat(index) * peekOffset
        )
        .scaleEffect(isExpanded ? 1.0 : 1.0 - CGFloat(index) * 0.03, anchor: .top)
        .opacity(isExpanded ? 1.0 : 1.0 - Double(index) * 0.15)
        .zIndex(Double(total - index))
        .animation(expandAnim, value: isExpanded)
    }
}

// MARK: - Ideas Card

private struct IdeasCard: View {
    let entries: [Entry]
    let onTap: (Entry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label row
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.Colors.accentYellow)
                Text("Ideas")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text("\(entries.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .padding(.bottom, 12)

            // Ideas list — each row tappable
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Button { onTap(entry) } label: {
                        Text(entry.summary)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)

                    if index < entries.count - 1 {
                        Rectangle()
                            .fill(Theme.Colors.borderFaint)
                            .frame(height: 1)
                    }
                }
            }
        }
        .cardStyle()
    }
}

#Preview("Home AI Composed") {
    @Previewable @State var appState = AppState()
    @Previewable @State var inputText = ""

    HomeAIComposedView(
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
                category: .todo,
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
        onViewsTap: { print("Views tapped") }
    )
    .environment(appState)
    .background(Theme.Colors.bgDeep)
}
