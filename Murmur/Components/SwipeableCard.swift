import SwiftUI

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

            // Card content.
            // When actions are present, a UIKit overlay handles both tap and swipe —
            // this is necessary because on real devices the UIViewRepresentable overlay
            // is the UIKit hit-test target, making the SwiftUI Button unreachable.
            // The UIKit tap recognizer fires onTap directly; the pan recognizer handles
            // horizontal swipes. When there are no actions, a plain SwiftUI Button is
            // used since there's no overlay to interfere.
            if actions.isEmpty {
                Button(action: onTap) {
                    content()
                }
                .buttonStyle(.plain)
                .background(geometryTracker)
                .contentShape(Rectangle())
                .offset(x: dragOffset)
            } else {
                content()
                    .background(geometryTracker)
                    .contentShape(Rectangle())
                    .offset(x: dragOffset)
                    .overlay {
                        HorizontalPanGestureInstaller(
                            onDrag: { dx in
                                activeSwipeID = entryID
                                let base: CGFloat = revealed ? -totalWidth : 0
                                dragOffset = min(0, max(-totalWidth, base + dx))
                            },
                            onEnd: { dx in
                                let base: CGFloat = revealed ? -totalWidth : 0
                                let finalOffset = base + dx
                                snap(reveal: -finalOffset > totalWidth * 0.35)
                                lastDragEndTime = Date()
                            },
                            onTap: {
                                guard Date().timeIntervalSince(lastDragEndTime) > 0.15 else { return }
                                if revealed {
                                    snap(reveal: false)
                                } else {
                                    onTap()
                                }
                            }
                        )
                    }
            }
        }
        .onChange(of: activeSwipeID) { _, newID in
            if newID != entryID && revealed {
                snap(reveal: false)
            }
        }
    }

    private var geometryTracker: some View {
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
    }

    private func snap(reveal: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            revealed = reveal
            dragOffset = reveal ? -totalWidth : 0
        }
    }
}

// MARK: - UIKit Horizontal Pan + Tap Gesture Installer

/// Installs a UIPanGestureRecognizer (horizontal swipes) and a UITapGestureRecognizer
/// (taps) on the overlay UIView, which is the UIKit hit-test target on real devices.
/// Both pan and tap live on the same UIView so no touch ever falls through to an
/// unreachable SwiftUI Button. gestureRecognizerShouldBegin filters the pan to
/// horizontal-only so ScrollView keeps vertical scrolling. cancelsTouchesInView=false
/// means the scroll view's own pan recognizer is not cancelled during a swipe.
/// The tap recognizer guards against firing during an active pan (pan.state == .began/.changed).
private struct HorizontalPanGestureInstaller: UIViewRepresentable {
    let onDrag: (CGFloat) -> Void
    let onEnd: (CGFloat) -> Void
    let onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pan = HorizontalPanRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)
        context.coordinator.panRecognizer = pan

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDrag = onDrag
        context.coordinator.onEnd = onEnd
        context.coordinator.onTap = onTap
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        uiView.gestureRecognizers?.forEach { uiView.removeGestureRecognizer($0) }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrag: onDrag, onEnd: onEnd, onTap: onTap)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDrag: (CGFloat) -> Void
        var onEnd: (CGFloat) -> Void
        var onTap: () -> Void
        var panRecognizer: UIPanGestureRecognizer?

        init(onDrag: @escaping (CGFloat) -> Void,
             onEnd: @escaping (CGFloat) -> Void,
             onTap: @escaping () -> Void) {
            self.onDrag = onDrag
            self.onEnd = onEnd
            self.onTap = onTap
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view)
            switch gesture.state {
            case .changed:
                onDrag(translation.x)
            case .ended, .cancelled:
                onEnd(translation.x)
            default:
                break
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .recognized else { return }
            // Don't fire if the pan is actively recognizing a drag
            if let pan = panRecognizer, pan.state == .began || pan.state == .changed {
                return
            }
            onTap()
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

/// Tagged subclass so we can identify our pan gesture recognizers if needed.
private final class HorizontalPanRecognizer: UIPanGestureRecognizer {}

// MARK: - Testable Gesture Helpers

/// Returns true when the velocity vector is "horizontal enough" to start a swipe.
/// The 1.2x multiplier means horizontal speed must exceed vertical by 20%.
func isHorizontalSwipe(velocityX: CGFloat, velocityY: CGFloat) -> Bool {
    abs(velocityX) > abs(velocityY) * 1.2
}

/// Determines whether a swipe should snap open (reveal actions) or snap closed.
/// `dragX` is the cumulative horizontal translation (negative = leftward).
/// `totalActionWidth` is the combined width of all action buttons.
/// `revealThreshold` is the fraction of totalActionWidth required to trigger reveal (0-1).
func shouldRevealActions(
    dragX: CGFloat,
    wasRevealed: Bool,
    totalActionWidth: CGFloat,
    revealThreshold: CGFloat = 0.35
) -> Bool {
    guard totalActionWidth > 0 else { return false }
    let base: CGFloat = wasRevealed ? -totalActionWidth : 0
    let finalOffset = base + dragX
    return -finalOffset > totalActionWidth * revealThreshold
}

/// Clamps the drag offset to the valid range [−totalActionWidth, 0].
func clampedDragOffset(
    dragX: CGFloat,
    wasRevealed: Bool,
    totalActionWidth: CGFloat
) -> CGFloat {
    let base: CGFloat = wasRevealed ? -totalActionWidth : 0
    return min(0, max(-totalActionWidth, base + dragX))
}
