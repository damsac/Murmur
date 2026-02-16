import Foundation
import SwiftData

enum PersistenceConfig {
    static let appGroupIdentifier: String = {
        // Read from Info.plist which is generated from build settings
        // This will be set if APP_GROUP_IDENTIFIER is configured in project.local.yml
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              !identifier.isEmpty else {
            fatalError("AppGroupIdentifier not configured — ensure APP_GROUP_IDENTIFIER is set in project.local.yml")
        }
        return identifier
    }()
    static let schemaVersion = 1

    static var modelContainer: ModelContainer {
        deleteStoreIfSchemaChanged()
        let schema = Schema([
            Entry.self,
            Tag.self,
            CreditBalance.self,
            UserProgress.self
        ])
        let config = ModelConfiguration(
            "Murmur",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    static var storeURL: URL {
        let containerURL: URL
        if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            containerURL = groupURL
        } else {
            // Fallback for simulator/development when App Group entitlement
            // is not available (no development team configured for signing).
            print("⚠️ App Group container unavailable — using default documents directory.")
            containerURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        return containerURL.appendingPathComponent("Murmur.store")
    }

    private static func deleteStoreIfSchemaChanged() {
        let defaults = UserDefaults(suiteName: appGroupIdentifier) ?? .standard
        let stored = defaults.integer(forKey: "MurmurSchemaVersion")
        guard stored < schemaVersion else { return }
        let base = storeURL.path
        for suffix in ["", "-wal", "-shm"] {
            try? FileManager.default.removeItem(atPath: base + suffix)
        }
        defaults.set(schemaVersion, forKey: "MurmurSchemaVersion")
    }
}
