import SwiftUI
import MurmurCore

struct LiveFeedRecordingView: View {
    @Environment(AppState.self) private var appState
    let onStopRecording: () -> Void

    @State private var elapsedTime: TimeInterval = 18
    @State private var transcript: String = "...and remind me about the DMV on Thursday"
    @State private var materializedItems: [MaterializedItem] = []
    @State private var inputTokens: Int = 187
    @State private var outputTokens: Int = 94
    @State private var showCursor = true

    var body: some View {
        ZStack {
            // Blurred background content
            BlurredBackgroundView()

            // Dark overlay
            Rectangle()
                .fill(Theme.Colors.bgDeep.opacity(0.85))
                .ignoresSafeArea()
                .background(.ultraThinMaterial.opacity(0.5))

            // Recording overlay content
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 68)

                // LIVE badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(Theme.Colors.accentGreen)
                        .frame(width: 7, height: 7)
                        .modifier(LivePulse())

                    Text("LIVE")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.Colors.accentGreen)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Theme.Colors.accentGreen.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Theme.Colors.accentGreen.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.bottom, 16)

                // Duration
                Text(formattedTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .monospacedDigit()
                    .tracking(1)
                    .padding(.bottom, 28)

                // Pulsing mic with rings
                PulsingMicView()
                    .padding(.bottom, 32)

                // Waveform
                WaveformView(isAnimating: true)
                    .padding(.bottom, 24)

                // Live transcript
                HStack(spacing: 2) {
                    Text(transcript)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textPrimary.opacity(0.6))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)

                    Rectangle()
                        .fill(Theme.Colors.accentPurple)
                        .frame(width: 2, height: 17)
                        .opacity(showCursor ? 1 : 0)
                }
                .frame(maxWidth: 320)
                .padding(.horizontal, 32)
                .padding(.bottom, 28)

                // Materialized items
                VStack(spacing: 8) {
                    ForEach(materializedItems) { item in
                        MaterializedItemCard(item: item)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.97).combined(with: .opacity).combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: materializedItems.count)

                // Token flow
                HStack(spacing: 14) {
                    // Input tokens
                    HStack(spacing: 4) {
                        Text("↑")
                            .foregroundStyle(Theme.Colors.accentPurple.opacity(0.6))
                        Text("\(inputTokens) in")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .font(Theme.Typography.label)
                    .monospacedDigit()
                    .tracking(0.3)

                    Text("·")
                        .foregroundStyle(Color(red: 0.165, green: 0.165, blue: 0.204)) // #2A2A34

                    // Output tokens
                    HStack(spacing: 4) {
                        Text("↓")
                            .foregroundStyle(Theme.Colors.accentGreen.opacity(0.6))
                        Text("\(outputTokens) out")
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .font(Theme.Typography.label)
                    .monospacedDigit()
                    .tracking(0.3)
                }
                .padding(.bottom, 20)

                // Stop hint
                Text("Tap to stop")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.Colors.textTertiary)

                Spacer()
            }
            .onTapGesture {
                onStopRecording()
            }
        }
        .onAppear {
            startSimulation()
        }
    }

    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startSimulation() {
        // Add initial item
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            materializedItems.append(MaterializedItem(
                category: .todo,
                summary: "Pick up dry cleaning before 6pm"
            ))
        }

        // Add second item
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            materializedItems.append(MaterializedItem(
                category: .reminder,
                summary: "DMV appointment Thursday"
            ))
        }

        // Cursor blink
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            showCursor.toggle()
        }

        // Time increment
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }

        // Token increment (simulating streaming)
        Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            outputTokens += 1
        }
    }
}

// MARK: - Blurred Background

private struct BlurredBackgroundView: View {
    var body: some View {
        VStack(spacing: 14) {
            Spacer()
                .frame(height: 130)

            // Simulate home cards
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.bgCard)
                .frame(height: 90)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)
                    .frame(height: 110)

                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)
                    .frame(height: 110)
            }

            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.bgCard)
                .frame(height: 140)

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .blur(radius: 8)
        .opacity(0.3)
    }
}

// MARK: - Materialized Item

struct MaterializedItem: Identifiable {
    let id = UUID()
    let category: EntryCategory
    let summary: String
}

private struct MaterializedItemCard: View {
    let item: MaterializedItem

    var body: some View {
        HStack(spacing: 10) {
            // Category dot
            Circle()
                .fill(Theme.categoryColor(item.category))
                .frame(width: 7, height: 7)

            // Category label
            Text(item.category.displayName.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Theme.categoryColor(item.category))

            // Summary
            Text(item.summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Colors.bgCard)

                // Top gradient line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Theme.Colors.textPrimary.opacity(0.06),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
    }
}

// MARK: - Live Pulse Animation

private struct LivePulse: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.7 : 1)
            .scaleEffect(isPulsing ? 0.9 : 1)
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

#Preview("Live Feed Recording") {
    @Previewable @State var appState = AppState()

    LiveFeedRecordingView(
        onStopRecording: { print("Stop recording") }
    )
    .environment(appState)
}
