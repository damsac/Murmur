import SwiftUI
import MurmurCore

// MARK: - Simple Toast

struct ToastView: View {
    let message: String
    let type: ToastType
    var actionLabel: String?
    var action: (() -> Void)?

    enum ToastType {
        case success
        case warning
        case error
        case info

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return Theme.Colors.accentGreen
            case .warning: return Theme.Colors.accentYellow
            case .error: return Theme.Colors.accentRed
            case .info: return Theme.Colors.accentBlue
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(type.color)

            Text(message)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Action button (e.g. Undo)
            if let label = actionLabel, let action {
                Button(label, action: action)
                    .font(Theme.Typography.bodyMedium.weight(.semibold))
                    .foregroundStyle(type.color)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(toastBackground(color: type.color))
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .transition(toastTransition)
    }
}

// MARK: - Shared Styling

private func toastBackground(color: Color) -> some View {
    RoundedRectangle(cornerRadius: 16)
        .fill(Theme.Colors.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.2), radius: 16, x: 0, y: 4)
}

private var toastTransition: AnyTransition {
    .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
}

// MARK: - Toast Container

struct ToastContainer: ViewModifier {
    @Binding var toast: ToastConfig?

    struct ToastConfig {
        let message: String
        let type: ToastView.ToastType
        let duration: TimeInterval
        let actionLabel: String?
        let action: (() -> Void)?

        init(message: String, type: ToastView.ToastType, duration: TimeInterval = 3.0, actionLabel: String? = nil, action: (() -> Void)? = nil) {
            self.message = message
            self.type = type
            self.duration = duration
            self.actionLabel = actionLabel
            self.action = action
        }
    }

    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let config = toast {
                ToastView(
                    message: config.message,
                    type: config.type,
                    actionLabel: config.actionLabel,
                    action: config.action.map { act in { dismiss(); act() } }
                )
                .onTapGesture { dismiss() }
                .padding(.top, 60)
                .zIndex(999)
                .onAppear {
                    if config.duration > 0 {
                        scheduleDismiss(after: config.duration)
                    }
                }
            }
        }
        .animation(Animations.toastSpring, value: toast != nil)
    }

    private func scheduleDismiss(after duration: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            dismiss()
        }
    }

    private func dismiss() {
        dismissTask?.cancel()
        withAnimation(Animations.toastSpring) {
            toast = nil
        }
    }
}

extension View {
    func toast(_ toast: Binding<ToastContainer.ToastConfig?>) -> some View {
        modifier(ToastContainer(toast: toast))
    }
}

#Preview {
    VStack(spacing: 20) {
        ToastView(message: "Entry saved successfully", type: .success)
        ToastView(message: "Low token balance", type: .warning)
        ToastView(message: "Failed to save entry", type: .error)
        Spacer()
    }
    .padding(.top, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.bgDeep)
}
