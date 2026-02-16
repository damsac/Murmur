import SwiftUI

struct OnboardingFlowView: View {
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case micPermission
    }

    var body: some View {
        ZStack {
            switch currentStep {
            case .welcome:
                OnboardingWelcomeView(onContinue: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        currentStep = .micPermission
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

            case .micPermission:
                OnboardingMicPromptView(
                    onAllow: {
                        // Mic permission granted, complete onboarding
                        onComplete()
                    },
                    onSkip: {
                        // User skipped mic permission, still complete onboarding
                        onComplete()
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }
}

#Preview("Onboarding Flow") {
    OnboardingFlowView(onComplete: { print("Onboarding complete") })
}
