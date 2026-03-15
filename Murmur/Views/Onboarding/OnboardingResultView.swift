import SwiftUI
import MurmurCore

struct OnboardingResultView: View {
    let entries: [Entry]
    let onSaveAndComplete: () -> Void

    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var ctaVisible = false
    @State private var habitChecked = false
    @State private var swipeCalloutVisible = false
    @State private var habitCalloutVisible = false
    @State private var calendarCalloutVisible = false

    private var todoEntry: Entry? { entries.first(where: { $0.category == .todo }) }
    private var reminderEntry: Entry? { entries.first(where: { $0.category == .reminder }) }
    private var habitEntry: Entry? { entries.first(where: { $0.category == .habit }) }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            ZStack {
                Theme.Colors.bgDeep.ignoresSafeArea()
                LinearGradient(
                    colors: [Theme.Colors.accentPurple.opacity(0.10), .clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Zones-style greeting + briefing
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Theme.Colors.textPrimary)
                        Text("1 deadline coming up · 1 habit today")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(headerVisible ? 1 : 0)
                    .offset(y: headerVisible ? 0 : 6)
                    .padding(.bottom, 20)

                    // Hero card
                    if let todo = todoEntry {
                        OnboardingHeroCard(entry: todo)
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 8)
                            .padding(.bottom, 8)
                    }

                    // Standard card
                    if let reminder = reminderEntry {
                        OnboardingStandardCard(entry: reminder)
                            .opacity(cardsVisible ? 1 : 0)
                            .offset(y: cardsVisible ? 0 : 8)
                            .padding(.bottom, 24)
                    }

                    // Habits strip
                    if let habit = habitEntry {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TODAY'S HABITS")
                                .font(Theme.Typography.badge)
                                .foregroundStyle(Theme.Colors.textTertiary)
                                .tracking(0.8)

                            OnboardingHabitRow(entry: habit, checked: $habitChecked)
                        }
                        .opacity(cardsVisible ? 1 : 0)
                        .offset(y: cardsVisible ? 0 : 8)
                        .padding(.bottom, 16)
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.top, 24)
            }
            .scrollIndicators(.hidden)

            // CTA pinned to bottom
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, Theme.Colors.bgDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)

                Button(action: onSaveAndComplete) {
                    HStack(spacing: 8) {
                        Text("Start capturing")
                            .font(Theme.Typography.bodyMedium)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Theme.purpleGradient)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 48)
                .background(Theme.Colors.bgDeep)
            }
            .opacity(ctaVisible ? 1 : 0)
            .offset(y: ctaVisible ? 0 : 12)
        }
        .onAppear { animate() }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning." }
        if hour < 17 { return "Good afternoon." }
        return "Good evening."
    }

    private func animate() {
        withAnimation(.easeOut(duration: 0.4)) {
            headerVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82).delay(0.25)) {
            cardsVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
            ctaVisible = true
        }
    }
}

// MARK: - Hero Card

private struct OnboardingHeroCard: View {
    let entry: Entry

    private var accent: Color { Theme.categoryColor(entry.category) }

    private var dueDateLabel: String? {
        guard let due = entry.dueDate else { return nil }
        let cal = Calendar.current
        if cal.isDateInToday(due) { return "Due today" }
        if cal.isDateInTomorrow(due) { return "Due tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return "Due \(f.string(from: due))"
    }

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 3)
                .padding(.vertical, 6)
                .padding(.leading, 14)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 0) {
                    HStack(spacing: 6) {
                        Circle().fill(accent).frame(width: 7, height: 7)
                        Text(entry.category.displayName.uppercased())
                            .font(Theme.Typography.badge)
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .tracking(0.8)
                    }
                    Spacer()
                    if let label = dueDateLabel {
                        Text(label)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.Colors.accentYellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.Colors.accentYellow.opacity(0.12), in: Capsule())
                    }
                }

                Text(entry.summary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Blocking the team — needs to ship by end of week")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
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
    }
}

// MARK: - Standard Card

private struct OnboardingStandardCard: View {
    let entry: Entry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(2)
                Text("This week")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
        }
        .cardStyle()
    }
}

// MARK: - Habit Row (interactive)

private struct OnboardingHabitRow: View {
    let entry: Entry
    @Binding var checked: Bool

    private var accent: Color { Theme.categoryColor(entry.category) }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    checked.toggle()
                }
            } label: {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(checked ? accent : Theme.Colors.textTertiary)
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: checked)
                    .frame(width: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.subheadline)
                    .foregroundStyle(checked ? Theme.Colors.textTertiary : Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text("Daily")
                    .font(.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
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
        .opacity(checked ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: checked)
    }
}

// MARK: - Preview

#Preview("Onboarding Result") {
    OnboardingResultView(
        entries: [
            // swiftlint:disable:next line_length
            Entry(transcript: "", content: "Finish client proposal", category: .todo, sourceText: "", summary: "Finish client proposal", priority: 1, dueDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())),
            Entry(transcript: "", content: "Call dentist this week", category: .reminder, sourceText: "", summary: "Call dentist this week"),
            Entry(transcript: "", content: "Morning run", category: .habit, sourceText: "", summary: "Morning run", cadenceRawValue: "daily"),
        ],
        onSaveAndComplete: { print("save and complete") }
    )
}
