import SwiftUI
import MurmurCore

struct OnboardingResultView: View {
    let entries: [Entry]
    let onSaveAndComplete: () -> Void

    @State private var cardVisible = false

    var body: some View {
        ZStack {
            // Background — matches welcome screen
            ZStack {
                Theme.Colors.bgDeep
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Theme.Colors.accentPurple.opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .bottom,
                    endPoint: .center
                )
                .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer()

                // Small caps label
                Text("MURMUR CAPTURED")
                    .font(Theme.Typography.badge)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .kerning(1.5)
                    .opacity(cardVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.35), value: cardVisible)

                Spacer().frame(height: 20)

                // Entry cards — spring-animated in as a group
                VStack(spacing: 10) {
                    ForEach(entries) { entry in
                        EntryCard(entry: entry, showCategory: true, onTap: nil)
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .scaleEffect(cardVisible ? 1.0 : 0.88)
                .opacity(cardVisible ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: cardVisible)

                Spacer().frame(height: 24)

                // Body
                Text("One thought, three things captured. Say anything — Murmur sorts it out.")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(cardVisible ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.15), value: cardVisible)

                Spacer()

                // CTA
                Button(action: onSaveAndComplete) {
                    Text("Start capturing")
                        .font(Theme.Typography.bodyMedium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Theme.purpleGradient)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.cardRadius))
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 48)
                .opacity(cardVisible ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.35), value: cardVisible)
            }
        }
        .onAppear {
            withAnimation {
                cardVisible = true
            }
        }
    }
}

#Preview("Onboarding Result") {
    let transcript = "Gotta call mom before the weekend. We're out of milk and eggs too. Oh — what if you could share entries with other people?"
    OnboardingResultView(
        entries: [
            Entry(transcript: transcript, content: "Call mom before the weekend", category: .reminder, sourceText: "Gotta call mom before the weekend.", summary: "Call mom before the weekend"),
            Entry(transcript: transcript, content: "Pick up milk and eggs", category: .todo, sourceText: "We're out of milk and eggs too.", summary: "Pick up milk and eggs"),
            Entry(
                transcript: transcript,
                content: "Let users share entries with friends",
                category: .idea,
                sourceText: "What if you could share entries with other people?",
                summary: "Share entries with friends"
            ),
        ],
        onSaveAndComplete: { print("save and complete") }
    )
}
