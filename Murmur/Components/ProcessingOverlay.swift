import SwiftUI

struct ProcessingOverlay: View {
    let entries: [Entry]
    let transcript: String?

    @State private var showCards = false
    @State private var spinnerRotation: Double = 0

    var body: some View {
        ZStack {
            // Background
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Center: Processing indicator
                VStack(spacing: 40) {
                    // Spinner
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Theme.Colors.accentPurple,
                                    Theme.Colors.accentPurpleLight,
                                    Theme.Colors.accentPurple.opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 48, height: 48)
                        .rotationEffect(.degrees(spinnerRotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                spinnerRotation = 360
                            }
                        }

                    // Frozen waveform
                    WaveformView(isAnimating: false)
                        .frame(height: 60)
                        .padding(.horizontal, 60)
                        .opacity(0.6)

                    // Processing text
                    Text("Processing...")
                        .font(Theme.Typography.navTitle)
                        .foregroundStyle(Theme.Colors.textPrimary)

                    Text("AI is organizing your thoughts")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                }

                Spacer()

                // Bottom: Materializing cards
                if !entries.isEmpty {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                ConfirmItemCard(
                                    entry: entry,
                                    onVoiceCorrect: { },
                                    onDiscard: { }
                                )
                                .opacity(showCards ? 1 : 0)
                                .offset(y: showCards ? 0 : 30)
                                .animation(
                                    Animations.cardAppear.delay(Double(index) * 0.15),
                                    value: showCards
                                )
                            }
                        }
                        .padding(.horizontal, Theme.Spacing.screenPadding)
                    }
                    .frame(maxHeight: 300)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showCards = true
            }
        }
    }
}

#Preview("Processing - No Cards") {
    ProcessingOverlay(
        entries: [],
        transcript: "Review the new design system"
    )
}

#Preview("Processing - Single Card") {
    ProcessingOverlay(
        entries: [
            Entry(
                summary: "Review the new design system and provide feedback to the team",
                category: .todo,
                priority: 2,
                aiGenerated: true
            )
        ],
        transcript: nil
    )
}

#Preview("Processing - Multiple Cards") {
    ProcessingOverlay(
        entries: [
            Entry(
                summary: "Review the new design system and provide feedback to the team by end of week",
                category: .todo,
                priority: 2,
                aiGenerated: true
            ),
            Entry(
                summary: "The best interfaces are invisible - they get out of the way and let users focus on their work",
                category: .insight,
                aiGenerated: true
            ),
            Entry(
                summary: "Build a browser extension for quick voice notes that syncs with mobile app",
                category: .idea,
                priority: 1,
                aiGenerated: true
            )
        ],
        transcript: "Review the design system, thought about invisible interfaces, idea for browser extension"
    )
}

#Preview("Processing - Many Cards") {
    ProcessingOverlay(
        entries: [
            Entry(
                summary: "Complete quarterly performance reviews",
                category: .todo,
                priority: 2
            ),
            Entry(
                summary: "Schedule 1:1s with direct reports",
                category: .todo,
                priority: 1
            ),
            Entry(
                summary: "Good design is as little design as possible",
                category: .insight
            ),
            Entry(
                summary: "Create a design system for the new product",
                category: .idea,
                priority: 1
            ),
            Entry(
                summary: "What's the difference between UX and UI?",
                category: .question
            )
        ],
        transcript: nil
    )
}
