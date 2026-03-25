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
    let entryId: String
    let category: String
    let source: String
}

struct EntryCompleted: AnalyticsEvent {
    static let eventName = "entry.completed"
    let entryId: String
    let category: String
    let timeSinceCreationMs: Int
    let source: String
}

struct EntryArchived: AnalyticsEvent {
    static let eventName = "entry.archived"
    let entryId: String
    let category: String
    let timeSinceCreationMs: Int
    let source: String
}

struct EntryDeleted: AnalyticsEvent {
    static let eventName = "entry.deleted"
    let entryId: String
    let category: String
    let timeSinceCreationMs: Int
    let source: String
}

// MARK: - Implicit Feedback

struct EntryCategoryChanged: AnalyticsEvent {
    static let eventName = "entry.category_changed"
    let entryId: String
    let category: String
    let newCategory: String
    let timeSinceCreationMs: Int
    let source: String
}

struct EntryEdited: AnalyticsEvent {
    static let eventName = "entry.edited"
    let entryId: String
    let category: String
    let fieldChanged: String
    let timeSinceCreationMs: Int
    let source: String
}

struct EntryDetailViewed: AnalyticsEvent {
    static let eventName = "entry.detail_viewed"
    let entryId: String
    let category: String
    let timeSinceCreationMs: Int
    let source: String
}

// MARK: - Credits

struct CreditCharged: AnalyticsEvent {
    static let eventName = "credits.charged"
    let requestId: String  // UUID string — preserves uppercase wire format
    let credits: Int64
    let balanceAfter: Int64
}
