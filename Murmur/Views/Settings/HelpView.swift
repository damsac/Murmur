import SwiftUI

struct HelpView: View {
    let onBack: () -> Void

    @State private var expandedCard: HelpCard?

    var body: some View {
        ZStack(alignment: .top) {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                NavHeader(
                    title: "Help",
                    showBackButton: true,
                    backAction: onBack,
                    trailingButtons: []
                )

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(HelpCard.allCases) { card in
                            HelpCardView(
                                card: card,
                                isExpanded: expandedCard == card,
                                onToggle: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        expandedCard = expandedCard == card ? nil : card
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.screenPadding)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Help Card Enum

private enum HelpCard: String, CaseIterable, Identifiable {
    case howItWorks
    case whatCanISay
    case managingEntries
    case tips
    case faq

    var id: String { rawValue }

    var title: String {
        switch self {
        case .howItWorks:      return "How Murmur Works"
        case .whatCanISay:     return "What Can I Say?"
        case .managingEntries: return "Managing Entries"
        case .tips:            return "Tips & Tricks"
        case .faq:             return "FAQ"
        }
    }

    var icon: String {
        switch self {
        case .howItWorks:      return "waveform.circle"
        case .whatCanISay:     return "mic.fill"
        case .managingEntries: return "hand.draw"
        case .tips:            return "lightbulb"
        case .faq:             return "questionmark.bubble"
        }
    }
}

// MARK: - Help Card View

private struct HelpCardView: View {
    let card: HelpCard
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Image(systemName: card.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.Colors.accentPurple)
                        .frame(width: 28)

                    Text(card.title)
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle()
                        .fill(Theme.Colors.borderSubtle)
                        .frame(height: 0.5)
                        .padding(.horizontal, 16)

                    cardContent
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                        .padding(.bottom, 16)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                .fill(Theme.Colors.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius)
                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                )
        )
        .clipped()
    }

    @ViewBuilder
    private var cardContent: some View {
        switch card {
        case .howItWorks:      HowItWorksContent()
        case .whatCanISay:     WhatCanISayContent()
        case .managingEntries: ManagingEntriesContent()
        case .tips:            TipsContent()
        case .faq:             FAQContent()
        }
    }
}

// MARK: - How It Works

private struct HowItWorksContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HelpStep(number: "1", text: "Speak or type anything that's on your mind")
            HelpStep(number: "2", text: "Murmur's AI extracts structured entries — todos, reminders, notes, and more")
            HelpStep(number: "3", text: "Entries are organized by category with due dates, priorities, and context filled in automatically")
        }
    }
}

private struct HelpStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.Colors.accentPurple)
                .frame(width: 20, height: 20)
                .background(
                    Circle()
                        .fill(Theme.Colors.accentPurple.opacity(0.12))
                )

            Text(text)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - What Can I Say

private struct WhatCanISayContent: View {
    private let examples: [(String, String, Color)] = [
        ("Todo", "\"Pick up dry cleaning tomorrow\"", Theme.Colors.accentPurple),
        ("List", "\"Groceries: eggs, milk, bread\"", Theme.Colors.accentBlue),
        ("Reminder", "\"Dentist appointment Thursday at 3\"", Theme.Colors.accentYellow),
        ("Note", "\"The wifi password is sunshine42\"", Theme.Colors.accentSlate),
        ("Idea", "\"App that turns receipts into meal plans\"", Theme.Colors.accentOrange),
        ("Habit", "\"Start meditating every morning\"", Theme.Colors.accentGreen),
        ("Question", "\"What's the capital of Portugal?\"", Theme.Colors.accentFuchsia),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(examples, id: \.0) { name, example, color in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(color)
                        Text(example)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
        }
    }
}

// MARK: - Managing Entries

private struct ManagingEntriesContent: View {
    private let gestures: [(String, String)] = [
        ("Swipe left", "Complete or snooze an entry"),
        ("Tap an entry", "View full details and edit"),
        ("Focus tab", "AI picks your most important items"),
        ("All tab", "See everything, sorted by recency"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(gestures, id: \.0) { action, description in
                HStack(alignment: .top, spacing: 8) {
                    Text(action)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .frame(width: 80, alignment: .leading)

                    Text(description)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Tips & Tricks

private struct TipsContent: View {
    private let tips: [(String, String)] = [
        ("lightbulb.min", "Say multiple things at once — Murmur splits them into separate entries"),
        ("calendar", "Mention dates naturally: \"next Friday\", \"in two weeks\", \"tomorrow at 3\""),
        ("repeat", "Habits track daily or weekly — check them off right from the home screen"),
        ("moon.zzz", "Snooze entries to hide them until you're ready to deal with them"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(tips, id: \.0) { icon, text in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.accentPurple)
                        .frame(width: 20)
                        .padding(.top, 1)

                    Text(text)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - FAQ

private struct FAQContent: View {
    @State private var expandedQuestion: String?

    private let questions: [(String, String)] = [
        ("What are credits?", "Each time Murmur processes your voice input, it uses one credit. You can check your balance and top up in Settings."),
        ("Can I edit entries after they're created?", "Yes — tap any entry to open the detail view where you can edit the text, change the category, adjust due dates, and more."),
        ("Where is my data stored?", "All your entries are stored locally on your device. Nothing is sent to external servers except the voice transcription and AI processing step."),
        ("What happens to completed entries?", "Completed entries move to the Archive. You can find them in Settings > Archive and restore them if needed."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(questions, id: \.0) { question, answer in
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            expandedQuestion = expandedQuestion == question ? nil : question
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text(question)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.Colors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .rotationEffect(.degrees(expandedQuestion == question ? 90 : 0))
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if expandedQuestion == question {
                        Text(answer)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 10)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    if question != questions.last?.0 {
                        Rectangle()
                            .fill(Theme.Colors.borderFaint)
                            .frame(height: 0.5)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Help View") {
    HelpView(onBack: { print("Back") })
}
