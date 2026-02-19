import SwiftUI
import MurmurCore

struct HomeAIComposedView: View {
    @Environment(AppState.self) private var appState
    @Binding var inputText: String
    let entries: [Entry]
    let onMicTap: () -> Void
    let onSubmit: () -> Void
    let onCardTap: (HomeCard) -> Void
    let onSettingsTap: () -> Void
    let onViewsTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 2) {
                Text("Murmur")
                    .font(.largeTitle.weight(.bold))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.Colors.textPrimary)

                Text(greeting)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
            .padding(.bottom, 4)

            // Scrollable cards
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(composedCards, id: \.id) { card in
                        cardView(for: card)
                            .onTapGesture {
                                onCardTap(card)
                            }
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

    private var composedCards: [HomeCard] {
        var cards: [HomeCard] = []

        // Don't Forget card (next urgent reminder)
        if let reminder = entries.filter({ $0.category == .reminder }).first {
            cards.append(.reminder(reminder))
        }

        // Todos count card
        let todoCount = entries.filter { $0.category == .todo && $0.status != .completed }.count
        if todoCount > 0 {
            cards.append(.todoCount(todoCount))
        }

        // Daily habit card
        if let habit = entries.filter({ $0.category == .habit }).first {
            cards.append(.habit(habit))
        }

        // Ideas card (recent ideas)
        let ideas = entries.filter { $0.category == .idea }.prefix(2)
        if !ideas.isEmpty {
            cards.append(.ideas(Array(ideas)))
        }

        return cards
    }

    @ViewBuilder
    private func cardView(for card: HomeCard) -> some View {
        switch card {
        case .reminder(let entry):
            ReminderCard(entry: entry)
        case .todoCount(let count):
            TodoCountCard(count: count)
        case .habit(let entry):
            HabitCard(entry: entry)
        case .ideas(let entries):
            IdeasCard(entries: entries)
        }
    }
}

// MARK: - Home Card Types

enum HomeCard: Identifiable {
    case reminder(Entry)
    case todoCount(Int)
    case habit(Entry)
    case ideas([Entry])

    var id: String {
        switch self {
        case .reminder(let entry): return "reminder-\(entry.id)"
        case .todoCount: return "todo-count"
        case .habit(let entry): return "habit-\(entry.id)"
        case .ideas: return "ideas"
        }
    }
}

// MARK: - Reminder Card

private struct ReminderCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("DON'T FORGET")
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.Colors.accentYellow.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "clock.fill")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.accentYellow)
                }
            }
            .padding(.bottom, 12)

            // Title
            Text(entry.summary)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)

            // Due date
            if let dueDate = entry.dueDate {
                Text(dueText(for: dueDate))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.Colors.accentYellow)
                    .padding(.top, 6)
            }
        }
        .reminderCardStyle()
    }

    private func dueText(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
            return "In \(days) days"
        }
    }
}

// MARK: - Todo Count Card

private struct TodoCountCard: View {
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.accentPurple.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Theme.Colors.accentPurple)
            }

            Text("\(count)")
                .font(Theme.Typography.title)
                .foregroundStyle(Theme.Colors.textPrimary)

            Text("todos remaining")
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Habit Card

private struct HabitCard: View {
    let entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("DAILY HABIT")
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.Colors.accentGreen.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "checkmark.circle.fill")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.accentGreen)
                }
            }
            .padding(.bottom, 12)

            // Title
            Text(entry.summary)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(2)
                .padding(.bottom, 4)

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

// MARK: - Ideas Card

private struct IdeasCard: View {
    let entries: [Entry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("IDEAS")
                    .font(.caption.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Colors.textSecondary)

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Theme.Colors.accentYellow.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "lightbulb.fill")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.accentYellow)
                }
            }
            .padding(.bottom, 12)

            // Ideas list
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Theme.Colors.accentYellow)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(entry.summary)
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textPrimary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 10)

                    if index < entries.count - 1 {
                        Divider()
                            .background(Theme.Colors.textPrimary.opacity(0.04))
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
        onCardTap: { print("Card tapped:", $0.id) },
        onSettingsTap: { print("Settings tapped") },
        onViewsTap: { print("Views tapped") }
    )
    .environment(appState)
}
