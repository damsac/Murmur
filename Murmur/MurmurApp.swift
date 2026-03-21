import SwiftUI
import SwiftData
import StoreKit
import MurmurCore
import StudioAnalytics

@main
struct MurmurApp: App {
    let modelContainer = PersistenceConfig.modelContainer
    @State private var appState = AppState()
    @State private var notificationPreferences = NotificationPreferences()
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("colorPalette") private var colorPalette: String = "classic"

    var body: some Scene {
        WindowGroup {
            RootView()
                .id(colorPalette)
                .environment(appState)
                .environment(notificationPreferences)
                .preferredColorScheme(.dark)
                .task {
                    if let endpoint = APIKeyProvider.analyticsEndpoint,
                       let apiKey = APIKeyProvider.analyticsAPIKey {
                        StudioAnalytics.configure(
                            appId: "murmur-ios",
                            endpoint: endpoint,
                            apiKey: apiKey
                        )
                        StudioAnalytics.track("app.launch")
                    }
                    appState.configurePipeline()
                }
                .task {
                    // Re-schedule habit reminder on every launch — repeating triggers survive normal
                    // relaunches but are wiped on reinstall (common during TestFlight).
                    if notificationPreferences.habitsEnabled {
                        NotificationService.shared.scheduleHabitReminder(preferences: notificationPreferences)
                    }
                }
                .task {
                    await listenForTransactionUpdates()
                }
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if appState.conversation.isRecording {
                    appState.conversation.cancelRecording()
                }
                StudioAnalytics.flush()
            }
        }
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
            if let credits = TopUpCatalog.creditsByProductID[transaction.productID] {
                try? await appState.applyTopUp(credits: credits)
            }
            await transaction.finish()
        }
    }
}
