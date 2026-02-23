import SwiftUI
import MurmurCore

// MARK: - Simple Toast

struct ToastView: View {
    let message: String
    let type: ToastType

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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(toastBackground(color: type.color))
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .transition(toastTransition)
    }
}

// MARK: - Agent Response Toast

struct AgentToastView: View {
    let summary: String
    let actions: [AgentAction]
    let onUndo: () -> Void
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Summary row
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.Colors.accentPurple)

                Text(summary)
                    .font(Theme.Typography.bodyMedium)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(isExpanded ? nil : 2)

                Button(action: onUndo) {
                    Text("Undo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.Colors.accentPurple)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.accentPurple.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Expanded action list
            if isExpanded && !actions.isEmpty {
                Divider()
                    .background(Theme.Colors.borderFaint)
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                        actionRow(action)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .background(toastBackground(color: Theme.Colors.accentPurple))
        .padding(.horizontal, Theme.Spacing.screenPadding)
        .transition(toastTransition)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Agent response: \(summary)")
        .accessibilityHint("Tap to see details. Double tap Undo to reverse.")
    }

    @ViewBuilder
    private func actionRow(_ action: AgentAction) -> some View {
        HStack(spacing: 8) {
            Image(systemName: action.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(action.color)
                .frame(width: 16)

            Text(action.label)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
    }
}

// MARK: - AgentAction Display Helpers

private extension AgentAction {
    var icon: String {
        switch self {
        case .create: return "plus.circle.fill"
        case .update: return "pencil.circle.fill"
        case .complete: return "checkmark.circle.fill"
        case .archive: return "archivebox.fill"
        }
    }

    var color: Color {
        switch self {
        case .create: return Theme.Colors.accentPurple
        case .update: return Theme.Colors.accentBlue
        case .complete: return Theme.Colors.accentGreen
        case .archive: return Theme.Colors.accentYellow
        }
    }

    var label: String {
        switch self {
        case .create(let a): return "Created \"\(a.summary)\""
        case .update(let a): return "Updated — \(a.reason)"
        case .complete(let a): return "Completed — \(a.reason)"
        case .archive(let a): return "Archived — \(a.reason)"
        }
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

    enum ToastConfig {
        case simple(message: String, type: ToastView.ToastType, duration: TimeInterval)
        case agent(summary: String, actions: [AgentAction], undo: UndoTransaction, duration: TimeInterval)

        init(message: String, type: ToastView.ToastType, duration: TimeInterval = 3.0) {
            self = .simple(message: message, type: type, duration: duration)
        }

        var duration: TimeInterval {
            switch self {
            case .simple(_, _, let d): return d
            case .agent(_, _, _, let d): return d
            }
        }
    }

    @State private var dismissTask: Task<Void, Never>?
    @State private var isExpanded = false

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let config = toast {
                toastContent(config)
                    .padding(.top, 60)
                    .zIndex(999)
                    .onAppear { scheduleDismiss(after: config.duration) }
            }
        }
        .animation(Animations.toastSpring, value: toast != nil)
    }

    @ViewBuilder
    private func toastContent(_ config: ToastConfig) -> some View {
        switch config {
        case .simple(let message, let type, _):
            ToastView(message: message, type: type)
                .onTapGesture { dismiss() }

        case .agent(let summary, let actions, _, _):
            AgentToastView(
                summary: summary,
                actions: actions,
                onUndo: handleUndo
            )
        }
    }

    private func handleUndo() {
        guard case .agent(_, _, let undo, _) = toast, !undo.isEmpty else { return }
        // Store undo before clearing toast — caller handles execution
        undoCallback?(undo)
        dismiss()
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

    // Undo callback — set by the view modifier
    var undoCallback: ((UndoTransaction) -> Void)?
}

extension View {
    func toast(_ toast: Binding<ToastContainer.ToastConfig?>) -> some View {
        modifier(ToastContainer(toast: toast))
    }

    func toast(
        _ toast: Binding<ToastContainer.ToastConfig?>,
        onUndo: @escaping (UndoTransaction) -> Void
    ) -> some View {
        var container = ToastContainer(toast: toast)
        container.undoCallback = onUndo
        return modifier(container)
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
