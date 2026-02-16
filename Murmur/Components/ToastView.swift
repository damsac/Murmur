import SwiftUI

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isShowing: Bool

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
            // Icon
            Image(systemName: type.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(type.color)

            // Message
            Text(message)
                .font(Theme.Typography.bodyMedium)
                .foregroundStyle(Theme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.bgCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                )
                .shadow(
                    color: type.color.opacity(0.2),
                    radius: 16,
                    x: 0,
                    y: 4
                )
        )
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .transition(
            .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .move(edge: .top).combined(with: .opacity)
            )
        )
    }
}

// Toast container for managing display timing
struct ToastContainer: ViewModifier {
    @Binding var toast: ToastConfig?

    struct ToastConfig {
        let message: String
        let type: ToastView.ToastType
        let duration: TimeInterval

        init(message: String, type: ToastView.ToastType, duration: TimeInterval = 3.0) {
            self.message = message
            self.type = type
            self.duration = duration
        }
    }

    @State private var workItem: DispatchWorkItem?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let config = toast {
                ToastView(
                    message: config.message,
                    type: config.type,
                    isShowing: Binding(
                        get: { toast != nil },
                        set: { if !$0 { toast = nil } }
                    )
                )
                .padding(.top, 60)
                .zIndex(999)
                .onAppear {
                    workItem?.cancel()
                    let task = DispatchWorkItem {
                        withAnimation(Animations.toastSpring) {
                            toast = nil
                        }
                    }
                    workItem = task
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + config.duration,
                        execute: task
                    )
                }
            }
        }
        .animation(Animations.toastSpring, value: toast != nil)
    }
}

extension View {
    func toast(_ toast: Binding<ToastContainer.ToastConfig?>) -> some View {
        modifier(ToastContainer(toast: toast))
    }
}

#Preview {
    @Previewable @State var showSuccess = true
    @Previewable @State var showWarning = false
    @Previewable @State var showError = false

    VStack(spacing: 20) {
        ToastView(
            message: "Entry saved successfully",
            type: .success,
            isShowing: $showSuccess
        )

        ToastView(
            message: "Low token balance",
            type: .warning,
            isShowing: $showWarning
        )

        ToastView(
            message: "Failed to save entry",
            type: .error,
            isShowing: $showError
        )

        Spacer()
    }
    .padding(.top, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.bgDeep)
}
