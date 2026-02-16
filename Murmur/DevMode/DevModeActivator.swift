import SwiftUI

/// View modifier that enables dev mode activation via 5 taps
struct DevModeActivator: ViewModifier {
    @Environment(AppState.self) private var appState
    @State private var tapCount = 0
    @State private var showDevMode = false
    @State private var resetTimer: Timer?

    func body(content: Content) -> some View {
        content
            .onTapGesture(count: 1) {
                tapCount += 1

                // Reset timer on each tap
                resetTimer?.invalidate()
                resetTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                    tapCount = 0
                }

                // Show dev mode on 5th tap
                if tapCount >= 5 {
                    tapCount = 0
                    resetTimer?.invalidate()
                    showDevMode = true
                    appState.isDevMode = true

                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }
            }
            .sheet(isPresented: $showDevMode) {
                DevModeView()
            }
    }
}

extension View {
    /// Makes this view activate Dev Mode when tapped 5 times within 2 seconds
    func devModeActivator() -> some View {
        modifier(DevModeActivator())
    }
}
