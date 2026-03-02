import SwiftUI

enum Animations {
    // MARK: - Ring Pulse (for mic button)
    static let ringPulse = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: false)

    // MARK: - Mic Glow
    static let micGlow = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)

    // MARK: - Waveform Bar
    static let waveBar = Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)

    // MARK: - Card Appear
    static let cardAppear = Animation.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0.3)

    // MARK: - Toast Spring
    static let toastSpring = Animation.spring(response: 0.5, dampingFraction: 0.68, blendDuration: 0.2)

    // MARK: - Subtle Pulse
    static let subtlePulse = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)

    // MARK: - Cursor Blink
    static let cursorBlink = Animation.linear(duration: 0.8).repeatForever(autoreverses: false)

    // MARK: - Quick Fade
    static let quickFade = Animation.easeOut(duration: 0.2)

    // MARK: - Smooth Slide
    static let smoothSlide = Animation.spring(response: 0.4, dampingFraction: 0.8)

    // MARK: - Overlay Dismiss
    static let overlayDismiss = Animation.easeOut(duration: 0.25)
}
