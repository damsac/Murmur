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

            // Card content — uses Button for scroll-friendly tap handling
            Button {
                guard Date().timeIntervalSince(lastDragEndTime) > 0.15 else { return }
                if revealed {
                    snap(reveal: false)
                } else {
                    onTap()
                }
            } label: {
                content()
            }
            .buttonStyle(.plain)
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
            .contentShape(Rectangle())
            .offset(x: dragOffset)
            .overlay {
                // UIKit pan gesture recognizer that only recognizes horizontal drags.
                // Unlike SwiftUI's DragGesture + simultaneousGesture, this properly
                // yields to ScrollView for vertical scrolling via gestureRecognizerShouldBegin.
                if !actions.isEmpty {
                    HorizontalPanGestureView { dx in
                        activeSwipeID = entryID
                        let base: CGFloat = revealed ? -totalWidth : 0
                        dragOffset = min(0, max(-totalWidth, base + dx))
                    } onEnd: { dx in
                        let base: CGFloat = revealed ? -totalWidth : 0
                        let finalOffset = base + dx
                        snap(reveal: -finalOffset > totalWidth * 0.35)
                        lastDragEndTime = Date()
                    }
                    .allowsHitTesting(true)
                }
            }
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

// MARK: - UIKit Horizontal Pan Gesture

/// A UIKit-based pan gesture recognizer that only activates for horizontal drags.
/// Uses `gestureRecognizerShouldBegin` to explicitly fail for vertical movement,
/// allowing the parent ScrollView to scroll unimpeded.
private struct HorizontalPanGestureView: UIViewRepresentable {
    let onDrag: (CGFloat) -> Void
    let onEnd: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onDrag = onDrag
        context.coordinator.onEnd = onEnd
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDrag: onDrag, onEnd: onEnd)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onDrag: (CGFloat) -> Void
        var onEnd: (CGFloat) -> Void

        init(onDrag: @escaping (CGFloat) -> Void, onEnd: @escaping (CGFloat) -> Void) {
            self.onDrag = onDrag
            self.onEnd = onEnd
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

        // Only begin recognizing if the velocity is more horizontal than vertical.
        // This lets ScrollView's vertical pan gesture win for scrolling.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }

        // Allow simultaneous recognition so the Button tap still works
        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}
