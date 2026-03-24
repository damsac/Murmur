import Foundation
import Testing
@testable import Murmur

// MARK: - Horizontal Gesture Detection

@Suite("Horizontal swipe detection")
struct HorizontalSwipeDetectionTests {
    @Test("purely horizontal velocity is recognized as swipe")
    func purelyHorizontal() {
        #expect(isHorizontalSwipe(velocityX: 500, velocityY: 0))
        #expect(isHorizontalSwipe(velocityX: -500, velocityY: 0))
    }

    @Test("purely vertical velocity is NOT recognized as swipe")
    func purelyVertical() {
        #expect(!isHorizontalSwipe(velocityX: 0, velocityY: 500))
        #expect(!isHorizontalSwipe(velocityX: 0, velocityY: -500))
    }

    @Test("diagonal velocity below 1.2x threshold is rejected")
    func diagonalBelowThreshold() {
        // velocityX = 100, velocityY = 100 -> 100 > 100 * 1.2 = 120 -> false
        #expect(!isHorizontalSwipe(velocityX: 100, velocityY: 100))
        // velocityX = 119, velocityY = 100 -> 119 > 120 -> false
        #expect(!isHorizontalSwipe(velocityX: 119, velocityY: 100))
    }

    @Test("diagonal velocity above 1.2x threshold is accepted")
    func diagonalAboveThreshold() {
        // velocityX = 121, velocityY = 100 -> 121 > 120 -> true
        #expect(isHorizontalSwipe(velocityX: 121, velocityY: 100))
        // negative direction
        #expect(isHorizontalSwipe(velocityX: -200, velocityY: 100))
    }

    @Test("zero velocity in both axes is not a swipe")
    func zeroVelocity() {
        #expect(!isHorizontalSwipe(velocityX: 0, velocityY: 0))
    }
}

// MARK: - Swipe Snap Threshold

@Suite("Swipe snap threshold")
struct SwipeSnapThresholdTests {
    let actionWidth: CGFloat = 148  // 74 * 2 actions

    @Test("small leftward drag from closed does NOT reveal")
    func smallDragFromClosed() {
        // Drag -30 with threshold at 35% of 148 = 51.8
        #expect(!shouldRevealActions(dragX: -30, wasRevealed: false, totalActionWidth: actionWidth))
    }

    @Test("large leftward drag from closed DOES reveal")
    func largeDragFromClosed() {
        // Drag -80, threshold 51.8 -> -(-80) = 80 > 51.8 -> true
        #expect(shouldRevealActions(dragX: -80, wasRevealed: false, totalActionWidth: actionWidth))
    }

    @Test("rightward drag from closed does NOT reveal")
    func rightwardDragFromClosed() {
        // Positive drag should never reveal
        #expect(!shouldRevealActions(dragX: 50, wasRevealed: false, totalActionWidth: actionWidth))
    }

    @Test("small rightward drag from revealed stays revealed")
    func smallDragFromRevealed() {
        // When revealed, base = -148, drag +30 -> finalOffset = -118, -(-118) = 118 > 51.8 -> true
        #expect(shouldRevealActions(dragX: 30, wasRevealed: true, totalActionWidth: actionWidth))
    }

    @Test("large rightward drag from revealed snaps closed")
    func largeDragFromRevealed() {
        // When revealed, base = -148, drag +140 -> finalOffset = -8, -(-8) = 8 > 51.8 -> false
        #expect(!shouldRevealActions(dragX: 140, wasRevealed: true, totalActionWidth: actionWidth))
    }

    @Test("exact threshold boundary (35%)")
    func exactThresholdBoundary() {
        // threshold = actionWidth * 0.35 = 51.8
        // Just below: should NOT reveal
        #expect(!shouldRevealActions(dragX: -51, wasRevealed: false, totalActionWidth: actionWidth))
        // Just above: should reveal
        #expect(shouldRevealActions(dragX: -52, wasRevealed: false, totalActionWidth: actionWidth))
    }
}

// MARK: - Drag Offset Clamping

@Suite("Drag offset clamping")
struct DragOffsetClampingTests {
    let actionWidth: CGFloat = 148

    @Test("drag is clamped to zero on the right")
    func clampedRight() {
        let offset = clampedDragOffset(dragX: 50, wasRevealed: false, totalActionWidth: actionWidth)
        #expect(offset == 0)
    }

    @Test("drag is clamped to negative totalWidth on the left")
    func clampedLeft() {
        let offset = clampedDragOffset(dragX: -300, wasRevealed: false, totalActionWidth: actionWidth)
        #expect(offset == -actionWidth)
    }

    @Test("drag within range is not clamped")
    func withinRange() {
        let offset = clampedDragOffset(dragX: -80, wasRevealed: false, totalActionWidth: actionWidth)
        #expect(offset == -80)
    }

    @Test("revealed card drag starts from negative totalWidth")
    func revealedBaseline() {
        // When revealed, base = -148, drag +50 -> -98
        let offset = clampedDragOffset(dragX: 50, wasRevealed: true, totalActionWidth: actionWidth)
        #expect(offset == -98)
    }

    @Test("revealed card rightward drag clamps at zero")
    func revealedClampedRight() {
        // When revealed, base = -148, drag +200 -> 52 -> clamped to 0
        let offset = clampedDragOffset(dragX: 200, wasRevealed: true, totalActionWidth: actionWidth)
        #expect(offset == 0)
    }

    @Test("revealed card leftward drag clamps at negative totalWidth")
    func revealedClampedLeft() {
        // When revealed, base = -148, drag -50 -> -198 -> clamped to -148
        let offset = clampedDragOffset(dragX: -50, wasRevealed: true, totalActionWidth: actionWidth)
        #expect(offset == -actionWidth)
    }
}

// MARK: - Empty Actions Guard

@Suite("Cards with no swipe actions")
struct NoActionCardTests {
    @Test("zero totalActionWidth means reveal is never triggered")
    func zeroWidthNeverReveals() {
        #expect(!shouldRevealActions(dragX: -100, wasRevealed: false, totalActionWidth: 0))
        #expect(!shouldRevealActions(dragX: -100, wasRevealed: true, totalActionWidth: 0))
    }

    @Test("zero totalActionWidth clamps drag to zero")
    func zeroWidthClampsDragToZero() {
        // min(0, max(0, 0 + (-50))) = min(0, 0) = 0
        let offset = clampedDragOffset(dragX: -50, wasRevealed: false, totalActionWidth: 0)
        #expect(offset == 0)
    }
}
