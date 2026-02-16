import SwiftUI

struct BottomNavBar: View {
    @Binding var selectedTab: Tab
    let showMicButton: Bool

    enum Tab: String, CaseIterable {
        case home = "Home"
        case views = "Views"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .views: return "square.grid.2x2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            NavBarItem(
                tab: .home,
                isSelected: selectedTab == .home
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .home
                }
            }

            if showMicButton {
                // Spacer for floating mic button
                Spacer()
                    .frame(width: 80)
            }

            NavBarItem(
                tab: .views,
                isSelected: selectedTab == .views
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .views
                }
            }

            NavBarItem(
                tab: .settings,
                isSelected: selectedTab == .settings
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = .settings
                }
            }
        }
        .frame(height: Theme.Spacing.bottomNavHeight)
        .background(
            ZStack {
                // Blur background
                Theme.Colors.bgDeep.opacity(0.92)

                // Top border
                VStack {
                    Rectangle()
                        .fill(Theme.Colors.borderSubtle)
                        .frame(height: 1)
                    Spacer()
                }
            }
        )
        .background(.ultraThinMaterial.opacity(0.5))
    }
}

private struct NavBarItem: View {
    let tab: BottomNavBar.Tab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 24, weight: .medium))
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
            .padding(.top, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("With Mic Button") {
    VStack {
        Spacer()
        ZStack {
            BottomNavBar(
                selectedTab: .constant(.home),
                showMicButton: true
            )

            // Simulated floating mic button
            MicButton(size: .large, isRecording: false) {}
                .offset(y: -50)
        }
    }
    .background(Theme.Colors.bgDeep)
    .ignoresSafeArea()
}

#Preview("Without Mic Button") {
    VStack {
        Spacer()
        BottomNavBar(
            selectedTab: .constant(.views),
            showMicButton: false
        )
    }
    .background(Theme.Colors.bgDeep)
    .ignoresSafeArea()
}

#Preview("All States") {
    VStack(spacing: 0) {
        Spacer()

        ForEach(BottomNavBar.Tab.allCases, id: \.self) { tab in
            BottomNavBar(
                selectedTab: .constant(tab),
                showMicButton: false
            )
            .padding(.bottom, 20)
        }
    }
    .background(Theme.Colors.bgDeep)
    .ignoresSafeArea()
}
