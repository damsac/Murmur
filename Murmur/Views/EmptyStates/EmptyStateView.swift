import SwiftUI

enum EmptyStateType {
    case todo
    case ideas
    case reminders
    case home

    var icon: String {
        switch self {
        case .todo: return "checkmark"
        case .ideas: return "lightbulb"
        case .reminders: return "clock"
        case .home: return ""
        }
    }

    var iconColor: Color {
        switch self {
        case .todo: return Theme.Colors.accentGreen
        case .ideas: return Theme.Colors.accentYellow
        case .reminders: return Theme.Colors.accentBlue
        case .home: return Theme.Colors.accentPurple
        }
    }

    var title: String {
        switch self {
        case .todo: return "All clear"
        case .ideas: return "No ideas yet"
        case .reminders: return "No reminders"
        case .home: return "Nothing here yet"
        }
    }

    var subtitle: String {
        switch self {
        case .todo: return "No active todos. Say something to create one."
        case .ideas: return "Your lightbulb moments will appear here. Say or type an idea to get started."
        case .reminders: return "When you mention a time or date, Murmur will create a reminder for you."
        case .home: return "Your thoughts, todos, and reminders will appear here as you capture them."
        }
    }

    var showCTA: Bool {
        self == .home
    }
}

struct EmptyStateView: View {
    let type: EmptyStateType
    let onAction: (() -> Void)?

    init(type: EmptyStateType, onAction: (() -> Void)? = nil) {
        self.type = type
        self.onAction = onAction
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon or illustration
            if type == .home {
                // Ghost card stack for home
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clear)
                        .stroke(
                            Theme.Colors.textPrimary.opacity(0.06),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .frame(width: 100, height: 60)
                        .offset(y: 0)

                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clear)
                        .stroke(
                            Theme.Colors.textPrimary.opacity(0.04),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .frame(width: 80, height: 50)
                        .offset(y: 40)
                        .opacity(0.6)

                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clear)
                        .stroke(
                            Theme.Colors.textPrimary.opacity(0.03),
                            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                        )
                        .frame(width: 60, height: 40)
                        .offset(y: 70)
                        .opacity(0.3)
                }
                .frame(height: 110)
                .padding(.bottom, 32)
            } else {
                // Icon circle for other states
                ZStack {
                    Circle()
                        .fill(type.iconColor.opacity(0.08))
                        .frame(width: 72, height: 72)

                    Image(systemName: type.icon)
                        .font(.largeTitle.weight(.medium))
                        .foregroundStyle(type.iconColor)
                }
                .padding(.bottom, 24)
            }

            // Title
            Text(type.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.bottom, 8)

            // Subtitle
            Text(type.subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 40)

            // CTA button for home
            if type.showCTA, let action = onAction {
                Button(action: action) {
                    HStack(spacing: 8) {
                        Image(systemName: "mic")
                            .font(Theme.Typography.bodyMedium)

                        Text("Capture your first thought")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Theme.Colors.accentPurpleLight)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Theme.Colors.accentPurple.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.Colors.accentPurple.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty Todo") {
    @Previewable @State var appState = AppState()

    EmptyStateView(type: .todo)
        .background(Theme.Colors.bgDeep)
        .environment(appState)
}

#Preview("Empty Ideas") {
    @Previewable @State var appState = AppState()

    EmptyStateView(type: .ideas)
        .background(Theme.Colors.bgDeep)
        .environment(appState)
}

#Preview("Empty Reminders") {
    @Previewable @State var appState = AppState()

    EmptyStateView(type: .reminders)
        .background(Theme.Colors.bgDeep)
        .environment(appState)
}

#Preview("Empty Home") {
    @Previewable @State var appState = AppState()

    EmptyStateView(type: .home, onAction: { print("Start recording") })
        .background(Theme.Colors.bgDeep)
        .environment(appState)
}
