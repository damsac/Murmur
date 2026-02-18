import SwiftUI
import SwiftData
import MurmurCore

/// Legacy wrapper — retained for DevScreen previews. In production, RootView
/// manages tabs and the nav bar directly.
struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \Entry.createdAt, order: .reverse) private var entries: [Entry]
    @State private var selectedTab: BottomNavBar.Tab = .home
    @State private var inputText = ""
    @State private var showTextInput = false

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                HomeAIComposedView(
                    inputText: $inputText,
                    entries: entries,
                    onMicTap: {},
                    onSubmit: {},
                    onCardTap: { _ in },
                    onSettingsTap: { selectedTab = .settings },
                    onViewsTap: {}
                )

            case .settings:
                SettingsMinimalView(
                    onBack: { selectedTab = .home },
                    onTopUp: {}
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.bgDeep)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomNavBar(
                selectedTab: $selectedTab,
                onMicTap: {},
                onKeyboardTap: { showTextInput = true }
            )
            .background(
                Theme.Colors.bgBody.opacity(0.95),
                ignoresSafeAreaEdges: .bottom
            )
        }
    }
}

#Preview("MainTabView") {
    @Previewable @State var appState = AppState()

    appState.disclosureLevel = .gridAwakens

    return MainTabView()
        .environment(appState)
}
