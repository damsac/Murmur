import Foundation

// MARK: - Home Composition Types

/// AI-composed home screen layout. Contains sections of entries and messages
/// arranged by the LLM based on urgency, context, and time of day.
public struct HomeComposition: Codable, Sendable {
    public let sections: [ComposedSection]
    public let composedAt: Date

    public var isFromToday: Bool {
        Calendar.current.isDateInToday(composedAt)
    }

    public init(sections: [ComposedSection], composedAt: Date = Date()) {
        self.sections = sections
        self.composedAt = composedAt
    }
}

/// A grouped section of items in the composed home view.
/// Sections have optional titles and density controls for spacing.
public struct ComposedSection: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String?
    public let density: SectionDensity
    public let items: [ComposedItem]

    enum CodingKeys: String, CodingKey {
        case title, density, items
    }

    public init(title: String? = nil, density: SectionDensity = .relaxed, items: [ComposedItem]) {
        self.id = UUID()
        self.title = title
        self.density = density
        self.items = items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.density = try container.decodeIfPresent(SectionDensity.self, forKey: .density) ?? .relaxed
        self.items = try container.decode([ComposedItem].self, forKey: .items)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encode(density, forKey: .density)
        try container.encode(items, forKey: .items)
    }
}

/// Section density controls visual spacing between items.
public enum SectionDensity: String, Codable, Sendable {
    case compact
    case relaxed
}

/// A single item in a composed section: either an entry reference or a text message.
/// Uses a `"type"` discriminator for JSON encoding/decoding.
public enum ComposedItem: Codable, Sendable, Identifiable {
    case entry(ComposedEntry)
    case message(String)

    public var id: String {
        switch self {
        case .entry(let entry): return "entry-\(entry.id)"
        case .message(let text): return "msg-\(text.prefix(20).hashValue)"
        }
    }

    // MARK: - Custom Codable with "type" discriminator

    enum CodingKeys: String, CodingKey {
        case type
        case id, emphasis, badge  // entry fields
        case text                 // message field
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "entry":
            let id = try container.decode(String.self, forKey: .id)
            let emphasis = try container.decodeIfPresent(EntryEmphasis.self, forKey: .emphasis) ?? .standard
            let badge = try container.decodeIfPresent(String.self, forKey: .badge)
            self = .entry(ComposedEntry(id: id, emphasis: emphasis, badge: badge))
        case "message":
            let text = try container.decode(String.self, forKey: .text)
            self = .message(text)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown ComposedItem type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .entry(let entry):
            try container.encode("entry", forKey: .type)
            try container.encode(entry.id, forKey: .id)
            try container.encode(entry.emphasis, forKey: .emphasis)
            try container.encodeIfPresent(entry.badge, forKey: .badge)
        case .message(let text):
            try container.encode("message", forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }
}

/// Reference to an entry with visual emphasis and optional badge annotation.
public struct ComposedEntry: Codable, Sendable {
    public let id: String           // 6-char short ID
    public let emphasis: EntryEmphasis
    public let badge: String?

    public init(id: String, emphasis: EntryEmphasis = .standard, badge: String? = nil) {
        self.id = id
        self.emphasis = emphasis
        self.badge = badge
    }
}

/// Visual emphasis level for entries in the composed view.
public enum EntryEmphasis: String, Codable, Sendable {
    case hero       // Large card, full content, subtle glow
    case standard   // Medium card, summary + metadata
    case compact    // Single line, category dot + summary
}
