import SwiftUI

struct BottomNavBar: View {
    @Binding var selectedTab: Tab
    var isRecording: Bool = false
    var onMicTap: (() -> Void)?
    var onKeyboardTap: (() -> Void)?

    enum Tab: String, CaseIterable {
        case home = "Home"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    private let micSize = Theme.Spacing.micButtonSize
    private let barHeight = Theme.Spacing.bottomNavHeight
    private let notchDepth = Theme.Spacing.notchDepth
    private let kbSize: CGFloat = 40

    var body: some View {
        let totalHeight = barHeight + notchDepth

        ZStack(alignment: .top) {
            // Notched shape background
            NotchedTabBarShape(
                notchRadius: Theme.Spacing.notchRadius,
                notchDepth: notchDepth,
                curveOffset: Theme.Spacing.notchCurveOffset
            )
            .fill(Theme.Colors.bgBody.opacity(0.95))
            .frame(height: totalHeight)

            // Tab items: Home (left), Settings (right)
            HStack(spacing: 0) {
                NavBarItem(tab: .home, isSelected: selectedTab == .home) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .home }
                }

                // Center space for mic + keyboard
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)

                NavBarItem(tab: .settings, isSelected: selectedTab == .settings) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = .settings }
                }
            }
            .padding(.top, notchDepth + 4)

            // Mic button — centered, protruding above the bar
            MicButton(
                size: .large,
                isRecording: isRecording,
                action: { onMicTap?() }
            )
            .accessibilityLabel("Record voice note")
            .offset(y: notchDepth - micSize / 2)

            // Keyboard button — to the right of mic, at bar level
            if let onKeyboardTap {
                Button(action: onKeyboardTap) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: kbSize, height: kbSize)
                        .background(
                            Circle()
                                .fill(Theme.Colors.bgCard)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.borderSubtle, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Type a note")
                .offset(x: micSize / 2 + kbSize / 2 + 6, y: notchDepth + (barHeight - kbSize) / 2)
            }
        }
        .frame(height: totalHeight)
    }
}

// MARK: - Notched Tab Bar Shape

struct NotchedTabBarShape: Shape {
    let notchRadius: CGFloat
    let notchDepth: CGFloat
    let curveOffset: CGFloat // unused — kept for API compat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let midX = rect.midX

        // Single arc that hugs the mic — no bezier transition curves.
        // Arc center sits notchDepth below the bar's top edge.
        // Calculate where the arc intersects the top edge (y = 0).
        let alpha = asin(notchDepth / notchRadius)
        let halfGap = sqrt(notchRadius * notchRadius - notchDepth * notchDepth)
        let startAngle = Angle.radians(.pi + alpha)
        let endAngle = Angle.radians(2 * .pi - alpha)

        // Top-left → flat top → arc → flat top → top-right → bottom
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX - halfGap, y: rect.minY))

        path.addArc(
            center: CGPoint(x: midX, y: notchDepth),
            radius: notchRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// MARK: - Nav Bar Item

private struct NavBarItem: View {
    let tab: BottomNavBar.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(
                        isSelected
                            ? Theme.Colors.accentPurple
                            : Theme.Colors.textTertiary
                    )
                    .frame(height: 24)

                Text(tab.rawValue)
                    .font(Theme.Typography.navLabel)
                    .foregroundStyle(
                        isSelected
                            ? Theme.Colors.accentPurple
                            : Theme.Colors.textTertiary
                    )
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Nav Bar") {
    VStack {
        Spacer()
        BottomNavBar(
            selectedTab: .constant(.home),
            isRecording: false,
            onMicTap: { print("Mic") },
            onKeyboardTap: { print("Keyboard") }
        )
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Recording State") {
    VStack {
        Spacer()
        BottomNavBar(
            selectedTab: .constant(.home),
            isRecording: true,
            onMicTap: { print("Mic") },
            onKeyboardTap: { print("Keyboard") }
        )
    }
    .background(Theme.Colors.bgDeep)
}

#Preview("Settings Selected") {
    VStack {
        Spacer()
        BottomNavBar(
            selectedTab: .constant(.settings),
            onMicTap: { print("Mic") },
            onKeyboardTap: { print("Keyboard") }
        )
    }
    .background(Theme.Colors.bgDeep)
}
