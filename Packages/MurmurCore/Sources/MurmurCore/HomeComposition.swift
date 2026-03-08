import Foundation

// MARK: - Composition Variant

/// Which home view style the composition targets.
/// Scanner = urgency-grouped, emphasis levels, 5-15 items.
/// Navigator = category-grouped, up to 7 items, briefing.
public enum CompositionVariant: String, Codable, Sendable {
    case scanner
    case navigator
}

// MARK: - Home Composition Types

/// AI-composed home screen layout. Contains sections of entries and messages
/// arranged by the LLM based on urgency, context, and time of day.
/// Mutable — supports incremental layout updates via `apply(operations:)`.
public struct HomeComposition: Codable, Sendable {
    public var sections: [ComposedSection]
    public var composedAt: Date
    public var briefing: String?
    public var variant: CompositionVariant?

    public var isFromToday: Bool {
        Calendar.current.isDateInToday(composedAt)
    }

    public init(
        sections: [ComposedSection],
        composedAt: Date = Date(),
        briefing: String? = nil,
        variant: CompositionVariant? = nil
    ) {
        self.sections = sections
        self.composedAt = composedAt
        self.briefing = briefing
        self.variant = variant
    }

    /// Apply a batch of layout operations in order. Returns a diff for animation.
    public mutating func apply(operations: [LayoutOperation]) -> LayoutDiff {
        var diff = LayoutDiff()
        for op in operations {
            applyOne(op, diff: &diff)
        }
        composedAt = Date()
        return diff
    }

    // MARK: - Private Diff Engine

    // swiftlint:disable:next cyclomatic_complexity
    private mutating func applyOne(_ op: LayoutOperation, diff: inout LayoutDiff) {
        switch op {
        case .addSection(let title, let density, let position):
            let section = ComposedSection(title: title, density: density, items: [])
            let idx = position.map { min($0, sections.count) } ?? sections.count
            sections.insert(section, at: idx)
            diff.addedSections.append(title)

        case .removeSection(let title):
            if let idx = findSection(title: title) {
                for item in sections[idx].items {
                    if case .entry(let e) = item { diff.removedEntries.append(e.id) }
                }
                sections.remove(at: idx)
                diff.removedSections.append(title)
            }

        case .updateSection(let title, let density, let newTitle):
            if let idx = findSection(title: title) {
                if let density { sections[idx].density = density }
                if let newTitle { sections[idx].title = newTitle }
                diff.updatedSections.append(newTitle ?? title)
            }

        case .insertEntry(let entryID, let section, let position, let emphasis, let badge):
            if let idx = findSection(title: section) {
                let entry = ComposedEntry(id: entryID, emphasis: emphasis, badge: badge)
                let item = ComposedItem.entry(entry)
                let pos = position.map { min($0, sections[idx].items.count) }
                    ?? sections[idx].items.count
                sections[idx].items.insert(item, at: pos)
                diff.insertedEntries.append((id: entryID, section: section))
            }

        case .removeEntry(let entryID):
            for sIdx in sections.indices {
                if let iIdx = sections[sIdx].items.firstIndex(where: {
                    if case .entry(let e) = $0 { return e.id == entryID }
                    return false
                }) {
                    sections[sIdx].items.remove(at: iIdx)
                    diff.removedEntries.append(entryID)
                    break
                }
            }

        case .moveEntry(let entryID, let toSection, let toPosition):
            // Guard target exists before removing from source — prevents data loss
            guard let targetIdx = findSection(title: toSection) else { return }

            var movedItem: ComposedItem?
            var fromSectionTitle: String?
            for sIdx in sections.indices {
                if let iIdx = sections[sIdx].items.firstIndex(where: {
                    if case .entry(let e) = $0 { return e.id == entryID }
                    return false
                }) {
                    movedItem = sections[sIdx].items.remove(at: iIdx)
                    fromSectionTitle = sections[sIdx].title ?? ""
                    break
                }
            }
            if let item = movedItem {
                let pos = toPosition.map { min($0, sections[targetIdx].items.count) }
                    ?? sections[targetIdx].items.count
                sections[targetIdx].items.insert(item, at: pos)
                diff.movedEntries.append((
                    id: entryID,
                    fromSection: fromSectionTitle ?? "",
                    toSection: toSection
                ))
            }

        case .updateEntry(let entryID, let emphasis, let badge):
            for sIdx in sections.indices {
                if let iIdx = sections[sIdx].items.firstIndex(where: {
                    if case .entry(let e) = $0 { return e.id == entryID }
                    return false
                }) {
                    if case .entry(let existing) = sections[sIdx].items[iIdx] {
                        let newEntry = ComposedEntry(
                            id: existing.id,
                            emphasis: emphasis ?? existing.emphasis,
                            badge: badge ?? existing.badge
                        )
                        sections[sIdx].items[iIdx] = .entry(newEntry)
                        diff.updatedEntries.append(entryID)
                    }
                    break
                }
            }
        }
    }

    private func findSection(title: String) -> Int? {
        let target = title.lowercased()
        return sections.firstIndex { ($0.title ?? "").lowercased() == target }
    }
}

/// A grouped section of items in the composed home view.
/// Sections have optional titles and density controls for spacing.
public struct ComposedSection: Codable, Sendable, Identifiable {
    public let id: UUID
    public var title: String?
    public var density: SectionDensity
    public var items: [ComposedItem]

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

// MARK: - Layout Diff Types

/// A single operation in a layout diff batch. Applied in order by `HomeComposition.apply(operations:)`.
/// Section targeting uses case-insensitive title matching.
public enum LayoutOperation: Sendable {
    case addSection(title: String, density: SectionDensity, position: Int?)
    case removeSection(title: String)
    case updateSection(title: String, density: SectionDensity?, newTitle: String?)
    case insertEntry(entryID: String, section: String, position: Int?,
                     emphasis: EntryEmphasis, badge: String?)
    case removeEntry(entryID: String)
    case moveEntry(entryID: String, toSection: String, toPosition: Int?)
    case updateEntry(entryID: String, emphasis: EntryEmphasis?, badge: String?)
}

/// Describes what changed after applying operations. Used by the UI for targeted animations.
/// Doubles as its own accumulator during `apply()` — `private(set)` properties are mutated
/// internally but read-only externally.
public struct LayoutDiff: Sendable {
    public fileprivate(set) var insertedEntries: [(id: String, section: String)] = []
    public fileprivate(set) var removedEntries: [String] = []
    public fileprivate(set) var movedEntries: [(id: String, fromSection: String, toSection: String)] = []
    public fileprivate(set) var updatedEntries: [String] = []
    public fileprivate(set) var addedSections: [String] = []
    public fileprivate(set) var removedSections: [String] = []
    public fileprivate(set) var updatedSections: [String] = []

    public var isEmpty: Bool {
        insertedEntries.isEmpty && removedEntries.isEmpty && movedEntries.isEmpty
            && updatedEntries.isEmpty && addedSections.isEmpty && removedSections.isEmpty
            && updatedSections.isEmpty
    }

    public init() {}
}
