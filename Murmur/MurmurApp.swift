import SwiftUI
import SwiftData
import StoreKit
import MurmurCore

@main
struct MurmurApp: App {
    let modelContainer = PersistenceConfig.modelContainer
    @State private var appState = AppState()
    @State private var notificationPreferences = NotificationPreferences()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(notificationPreferences)
                .preferredColorScheme(.dark)
                .task {
                    appState.configurePipeline()
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
