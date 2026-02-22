import SwiftUI
import SwiftData
import MurmurCore

@main
struct MurmurApp: App {
    let modelContainer = PersistenceConfig.modelContainer
    @State private var appState = AppState()
    @State private var notificationPreferences = NotificationPreferences()
    @Environment(\.scenePhase) private var scenePhase

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
                .environment(notificationPreferences)
                .preferredColorScheme(.dark)
                .task {
                    appState.configurePipeline()
                    await NotificationService.shared.requestPermission()
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if appState.recordingState == .recording {
                    Task {
                        try? await appState.pipeline?.stopRecording()
                        appState.recordingState = .idle
                    }
                }
            }
        }
    }
}
