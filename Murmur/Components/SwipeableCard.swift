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
    @State private var isDraggingHorizontally = false

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

            // Card content slides left to reveal actions
            content()
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
                .simultaneousGesture(
                    DragGesture(minimumDistance: actions.isEmpty ? .infinity : 10, coordinateSpace: .local)
                        .onChanged { value in
                            guard !actions.isEmpty else { return }
                            let dx = value.translation.width
                            let dy = value.translation.height
                            guard abs(dx) > abs(dy) else { return }
                            isDraggingHorizontally = true
                            activeSwipeID = entryID
                            let base: CGFloat = revealed ? -totalWidth : 0
                            dragOffset = min(0, max(-totalWidth, base + dx))
                        }
                        .onEnded { _ in
                            guard isDraggingHorizontally else { return }
                            isDraggingHorizontally = false
                            snap(reveal: -dragOffset > totalWidth * 0.35)
                            lastDragEndTime = Date()
                        }
                )
        }
        .onTapGesture {
            guard Date().timeIntervalSince(lastDragEndTime) > 0.15 else { return }
            if revealed {
                snap(reveal: false)
            } else {
                onTap()
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
