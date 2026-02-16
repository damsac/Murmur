import SwiftUI
import SwiftData

@main
struct MurmurApp: App {
    let modelContainer = PersistenceConfig.modelContainer
    @State private var appState = AppState()

    init() {
        #if DEBUG
        // Support launch argument: -disclosureLevel <0-4>
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-disclosureLevel"),
           idx + 1 < ProcessInfo.processInfo.arguments.count,
           let rawValue = Int(ProcessInfo.processInfo.arguments[idx + 1]),
           let level = DisclosureLevel(rawValue: rawValue) {
            appState.devOverrideLevel = level
            appState.isDevMode = true
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
