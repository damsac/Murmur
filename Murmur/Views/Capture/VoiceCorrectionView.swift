import SwiftUI
import MurmurCore

struct VoiceCorrectionView: View {
    @Environment(AppState.self) private var appState
    let transcript: String
    let duration: TimeInterval
    let items: [ConfirmItem]
    let editingIndex: Int
    let correctionDuration: TimeInterval
    let correctionTranscript: String
    let onFinishCorrection: () -> Void
    let onCancelCorrection: () -> Void

    @State private var showFullTranscript: Bool = false

    var body: some View {
        ZStack {
            Theme.Colors.bgDeep
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review")
                            .font(.title2.weight(.bold))
                            .tracking(-0.3)
                            .foregroundStyle(Theme.Colors.textPrimary)

                        Text("Correcting item \(editingIndex + 1) of \(items.count)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(.top, 70)
                    .padding(.bottom, 16)

                    // Transcript section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "mic")
                                    .font(.caption2.weight(.semibold))
                                Text("TRANSCRIPT")
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.6)
                            }
                            .foregroundStyle(Theme.Colors.textTertiary)

                            Spacer()

                            Text(formattedDuration)
                                .font(.caption2)
                                .foregroundStyle(Theme.Colors.textMuted)
                        }

                        Text("\"\(transcript)\"")
                            .font(.subheadline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .italic()
                            .lineSpacing(2)
                            .lineLimit(showFullTranscript ? nil : 3)
                            .onTapGesture {
                                showFullTranscript.toggle()
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.Colors.textPrimary.opacity(0.03))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.Colors.textPrimary.opacity(0.05), lineWidth: 1)
                            )
                    )
                    .padding(.bottom, 24)

                    // Items header
                    HStack {
                        Text("EXTRACTED")
                            .font(.caption.weight(.semibold))
                            .tracking(0.8)
                            .foregroundStyle(Theme.Colors.textSecondary)

                        Spacer()

                        Text("\(items.count) items")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                    .padding(.bottom, 12)

                    // Item cards
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index == editingIndex {
                            // Editing state
                            VoiceCorrectionItemCard(
                                item: item,
                                correctionDuration: correctionDuration,
                                correctionTranscript: correctionTranscript
                            )
                            .padding(.bottom, 10)
                        } else {
                            // Dimmed state
                            DimmedItemCard(item: item)
                                .padding(.bottom, 10)
                        }
                    }

                    // Bottom spacing for sticky footer
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
            }

            // Sticky footer (disabled during correction)
            VStack {
                Spacer()

                VStack(spacing: 0) {
                    Button(action: {}) {
                        Text("Finish correction to continue")
                            .font(.headline)
                            .foregroundStyle(Theme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Theme.Colors.accentPurple.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Theme.Colors.accentPurple.opacity(0.1), lineWidth: 1)
                                    )
                            )
                    }
                    .disabled(true)
                    .buttonStyle(.plain)
                    .opacity(0.4)
                }
                .padding(.horizontal, Theme.Spacing.screenPadding)
                .padding(.bottom, 40)
                .background(
                    LinearGradient(
                        colors: [Color.clear, Theme.Colors.bgDeep.opacity(0.9), Theme.Colors.bgDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                )
            }
        }
    }

    private var formattedDuration: String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }
}

// MARK: - Voice Correction Item Card

private struct VoiceCorrectionItemCard: View {
    let item: ConfirmItem
    let correctionDuration: TimeInterval
    let correctionTranscript: String

    @State private var cursorVisible = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Category badge
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.categoryColor(item.category))
                    .frame(width: 6, height: 6)

                Text(item.category.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.categoryColor(item.category))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.categoryColor(item.category).opacity(0.10))
            )
            .padding(.bottom, 8)

            // Summary
            Text(item.summary)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(2)
                .padding(.bottom, 12)

            // Original value (struck through)
            VStack(alignment: .leading, spacing: 4) {
                Text("ORIGINAL")
                    .font(Theme.Typography.badge)
                    .tracking(0.6)
                    .foregroundStyle(Theme.Colors.textTertiary)

                Text(item.summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .strikethrough(true, color: Theme.Colors.accentRed.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.accentRed.opacity(0.06))
            )
            .padding(.bottom, 12)

            // Correction zone
            VStack(spacing: 0) {
                // Recording header
                HStack(spacing: 12) {
                    // Pulsing mic
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.accentYellow.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "mic")
                            .font(.headline.weight(.medium))
                            .foregroundStyle(Theme.Colors.accentYellow)
                    }
                    .modifier(PulsingRingModifier(color: Theme.Colors.accentYellow))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recording correction...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.Colors.accentYellow)

                        Text("Speak your fix")
                            .font(.caption2)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }

                    Spacer()

                    Text(formattedCorrectionDuration)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .monospacedDigit()
                }
                .padding(.bottom, 12)

                // Waveform
                HStack(spacing: 2) {
                    ForEach(0..<16, id: \.self) { index in
                        WaveBar(index: index, color: Theme.Colors.accentYellow)
                    }
                }
                .frame(height: 32)
                .padding(.bottom, 10)

                // Live transcript
                HStack(spacing: 0) {
                    Text("\"\(correctionTranscript)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .italic()
                        .lineSpacing(2)
                        .opacity(0.8)

                    // Blinking cursor
                    Rectangle()
                        .fill(Theme.Colors.accentYellow)
                        .frame(width: 2, height: 14)
                        .opacity(cursorVisible ? 1 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                                cursorVisible.toggle()
                            }
                        }
                }

                // Hint
                Text("Original + correction sent to LLM to fix")
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Theme.Colors.accentYellow.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Theme.Colors.accentYellow.opacity(0.18), lineWidth: 1.5)
                    )
            )
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Theme.Colors.accentYellow.opacity(0.25), lineWidth: 1.5)
                    )

                // Top gradient line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Theme.categoryColor(item.category).opacity(0.12),
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

    private var formattedCorrectionDuration: String {
        let minutes = Int(correctionDuration) / 60
        let seconds = Int(correctionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Dimmed Item Card

private struct DimmedItemCard: View {
    let item: ConfirmItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category badge
            HStack(spacing: 5) {
                Circle()
                    .fill(Theme.categoryColor(item.category))
                    .frame(width: 6, height: 6)

                Text(item.category.displayName.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.categoryColor(item.category))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.categoryColor(item.category).opacity(0.10))
            )

            // Summary
            Text(item.summary)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(2)
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.Colors.bgCard)

                // Top gradient line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Theme.categoryColor(item.category).opacity(0.12),
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
        .opacity(0.35)
    }
}

// MARK: - Wave Bar

private struct WaveBar: View {
    let index: Int
    let color: Color

    private let heights: [CGFloat] = [8, 16, 24, 12, 20, 28, 14, 22, 10, 18, 26, 8, 20, 14, 24, 10]
    private let delays: [Double] = [0, 0.08, 0.16, 0.24, 0.32, 0.1, 0.2, 0.28, 0.36, 0.04, 0.12, 0.22, 0.3, 0.06, 0.18, 0.26]

    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3)
            .frame(height: heights[index])
            .scaleEffect(y: isAnimating ? 1.0 : 0.4, anchor: .center)
            .opacity(isAnimating ? 1.0 : 0.5)
            .animation(
                .easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delays[index]),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Pulsing Ring Modifier

private struct PulsingRingModifier: ViewModifier {
    let color: Color

    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .background(
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 1)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0.0 : 0.2)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                        value: isPulsing
                    )
            )
            .onAppear {
                isPulsing = true
            }
    }
}

#Preview("Voice Correction") {
    @Previewable @State var appState = AppState()

    VoiceCorrectionView(
        transcript: "...remind me about the DMV on Thursday...",
        duration: 12,
        items: [
            ConfirmItem(category: .todo, summary: "Pick up dry cleaning before 6pm", priority: nil, dueDate: nil),
            ConfirmItem(category: .reminder, summary: "DMV appointment Thursday", priority: nil, dueDate: nil),
            ConfirmItem(category: .idea, summary: "App that turns grocery receipts into meal plans", priority: nil, dueDate: nil)
        ],
        editingIndex: 1,
        correctionDuration: 3,
        correctionTranscript: "Actually it's not Thursday, it's next Friday the",
        onFinishCorrection: { print("Finish correction") },
        onCancelCorrection: { print("Cancel correction") }
    )
    .environment(appState)
}
