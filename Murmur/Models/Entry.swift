import Foundation
import SwiftData
import MurmurCore

/// The atomic unit — every voice input is interpreted, categorized, and stored as an Entry.
@Model
public final class Entry {
    @Attribute(.unique) public var id: UUID

    /// Original voice-to-text transcription (full recording)
    public var transcript: String

    /// AI-structured version of the transcript (cleaned/formatted)
    public var content: String

    /// Stored as raw string for SwiftData predicate support
    public var categoryRawValue: String

    /// AI-assigned category
    public var category: EntryCategory {
        get { EntryCategory(from: categoryRawValue) }
        set { categoryRawValue = newValue.rawValue }
    }

    /// The specific part of the transcript this entry was extracted from
    public var sourceText: String

    /// When the entry was captured
    public var createdAt: Date

    /// When the entry was last modified
    public var updatedAt: Date

    // MARK: - LLM-populated fields

    /// One-liner summary for cards/lists
    public var summary: String

    /// User-added supplementary notes
    public var notes: String = ""

    /// Priority 1-5 scale (1 = highest)
    public var priority: Int?

    /// Raw time phrase extracted by LLM (e.g. "next Thursday", "in 2 hours")
    public var dueDateDescription: String?

    /// Resolved date from dueDateDescription (resolved on-device)
    public var dueDate: Date?

    // MARK: - Status (app-managed, not LLM)

    /// Stored as raw string for SwiftData predicate support
    public var statusRawValue: String

    /// Entry lifecycle status
    public var status: EntryStatus {
        get { EntryStatus(from: statusRawValue) }
        set { statusRawValue = newValue.rawValue }
    }

    /// When the entry was marked completed
    public var completedAt: Date?

    /// When a snoozed entry should resurface
    public var snoozeUntil: Date?

    // MARK: - Source metadata

    /// Recording length in seconds
    public var audioDuration: TimeInterval?

    /// Stored as raw string for SwiftData predicate support
    public var sourceRawValue: String

    /// How the entry was captured
    public var source: EntrySource {
        get { EntrySource(from: sourceRawValue) }
        set { sourceRawValue = newValue.rawValue }
    }

    /// Resolve a natural language date phrase (e.g. "next Thursday") to a Date using NSDataDetector.
    public static func resolveDate(from phrase: String?) -> Date? {
        guard let phrase, !phrase.isEmpty else { return nil }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        let range = NSRange(phrase.startIndex..., in: phrase)
        return detector.matches(in: phrase, options: [], range: range).first?.date
    }

    /// Bridge initializer: convert an ExtractedEntry (from MurmurCore) into a persistable Entry.
    public convenience init(
        from extracted: ExtractedEntry,
        transcript: String,
        source: EntrySource,
        audioDuration: TimeInterval?
    ) {
        self.init(
            transcript: transcript,
            content: extracted.content,
            category: extracted.category,
            sourceText: extracted.sourceText,
            summary: extracted.summary,
            priority: extracted.priority,
            dueDateDescription: extracted.dueDateDescription,
            dueDate: Entry.resolveDate(from: extracted.dueDateDescription),
            audioDuration: audioDuration,
            source: source
        )
    }

    public init(
        id: UUID = UUID(),
        transcript: String,
        content: String,
        category: EntryCategory,
        sourceText: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        summary: String = "",
        priority: Int? = nil,
        dueDateDescription: String? = nil,
        dueDate: Date? = nil,
        status: EntryStatus = .active,
        completedAt: Date? = nil,
        snoozeUntil: Date? = nil,
        audioDuration: TimeInterval? = nil,
        source: EntrySource = .voice
    ) {
        self.id = id
        self.transcript = transcript
        self.content = content
        self.categoryRawValue = category.rawValue
        self.sourceText = sourceText
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.summary = summary
        self.priority = priority
        self.dueDateDescription = dueDateDescription
        self.dueDate = dueDate
        self.statusRawValue = status.rawValue
        self.completedAt = completedAt
        self.snoozeUntil = snoozeUntil
        self.audioDuration = audioDuration
        self.sourceRawValue = source.rawValue
    }
}

/// Entry lifecycle status
public enum EntryStatus: String, Codable, Sendable, CaseIterable {
    case active
    case completed
    case archived
    case snoozed

    public var displayName: String {
        switch self {
        case .active: return "Active"
        case .completed: return "Completed"
        case .archived: return "Archived"
        case .snoozed: return "Snoozed"
        }
    }

    /// Defensive initializer — falls back to .active for unknown raw values
    public init(from rawValue: String) {
        self = EntryStatus(rawValue: rawValue) ?? .active
    }
}
