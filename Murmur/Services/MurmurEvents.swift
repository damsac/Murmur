import Foundation
import StudioAnalytics

// MARK: - App Lifecycle

struct AppLaunched: AnalyticsEvent {
    static let eventName = "app.launch"
}

// MARK: - Recording

struct RecordingStarted: AnalyticsEvent {
    static let eventName = "recording.start"
    let source: String
}

struct RecordingComplete: AnalyticsEvent {
    static let eventName = "recording.complete"
    let durationMs: Int
    let transcriptLength: Int
}

// MARK: - Entry CRUD

struct EntryCreated: AnalyticsEvent {
    static let eventName = "entry.created"
    let category: String
    let source: String
}

struct EntryCompleted: AnalyticsEvent {
    static let eventName = "entry.completed"
    let category: String
    let ageHours: Int
    let source: String
}

struct EntryArchived: AnalyticsEvent {
    static let eventName = "entry.archived"
    let category: String
    let ageHours: Int
    let source: String
}

struct EntryDeleted: AnalyticsEvent {
    static let eventName = "entry.deleted"
    let category: String
    let ageHours: Int
    let source: String
}

// MARK: - Credits

struct CreditCharged: AnalyticsEvent {
    static let eventName = "credits.charged"
    let requestId: String  // UUID string — preserves uppercase wire format
    let credits: Int64
    let balanceAfter: Int64
}
