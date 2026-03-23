import Foundation

// MARK: - Errors

public enum PPQError: LocalizedError, Sendable {
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case noToolCalls

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from PPQ API"
        case .httpError(let code, let body):
            return "PPQ API error (HTTP \(code)): \(body)"
        case .noToolCalls:
            return "PPQ API returned no tool calls"
        }
    }
}

// MARK: - Response Decoding Types

struct CreateEntriesArguments: Decodable {
    let entries: [RawCreateAction]
}

struct RawCreateAction: Decodable {
    let content: String
    let category: EntryCategory
    let sourceText: String?
    let summary: String?
    let priority: Int?
    let dueDate: String?
    let cadence: HabitCadence?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case content
        case category
        case sourceText = "source_text"
        case summary
        case priority
        case dueDate = "due_date"
        case cadence
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(EntryCategory.self, forKey: .category)
        sourceText = try container.decodeIfPresent(String.self, forKey: .sourceText)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        // Defensive: unknown cadence values become nil
        if let cadenceString = try container.decodeIfPresent(String.self, forKey: .cadence) {
            cadence = HabitCadence(rawValue: cadenceString)
        } else {
            cadence = nil
        }
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    var asAction: CreateAction {
        let normalizedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSource = sourceText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSource: String
        if let normalizedSource, !normalizedSource.isEmpty {
            finalSource = normalizedSource
        } else {
            finalSource = content
        }

        let finalSummary: String
        if let normalizedSummary, !normalizedSummary.isEmpty {
            finalSummary = normalizedSummary
        } else {
            finalSummary = ""
        }
        return CreateAction(
            content: content,
            category: category,
            sourceText: finalSource,
            summary: finalSummary,
            priority: priority.map { max(1, min(5, $0)) },
            dueDateDescription: dueDate,
            cadence: cadence,
            notes: notes
        )
    }
}

struct UpdateEntriesArguments: Decodable {
    let updates: [RawUpdateAction]
}

struct RawUpdateAction: Decodable {
    let id: String
    let fields: RawUpdateFields
    let reason: String?

    var asAction: UpdateAction {
        let normalized = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalReason: String
        if let normalized, !normalized.isEmpty {
            finalReason = normalized
        } else {
            finalReason = "No reason provided"
        }
        return UpdateAction(
            id: id,
            fields: fields.asFields,
            reason: finalReason
        )
    }
}

struct RawUpdateFields: Decodable {
    let content: String?
    let summary: String?
    let category: EntryCategory?
    let priority: Int?
    let dueDate: String?
    let cadence: HabitCadence?
    let status: AgentEntryStatus?
    let snoozeUntil: String?
    let checkOffHabit: Bool?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case content
        case summary
        case category
        case priority
        case dueDate = "due_date"
        case cadence
        case status
        case snoozeUntil = "snooze_until"
        case checkOffHabit = "check_off_habit"
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        category = try container.decodeIfPresent(EntryCategory.self, forKey: .category)
        priority = try container.decodeIfPresent(Int.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(String.self, forKey: .dueDate)
        // Defensive: unknown cadence values become nil
        if let cadenceString = try container.decodeIfPresent(String.self, forKey: .cadence) {
            cadence = HabitCadence(rawValue: cadenceString)
        } else {
            cadence = nil
        }
        status = try container.decodeIfPresent(AgentEntryStatus.self, forKey: .status)
        snoozeUntil = try container.decodeIfPresent(String.self, forKey: .snoozeUntil)
        checkOffHabit = try container.decodeIfPresent(Bool.self, forKey: .checkOffHabit)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    var asFields: UpdateFields {
        UpdateFields(
            content: content,
            summary: summary,
            category: category,
            priority: priority.map { max(1, min(5, $0)) },
            dueDateDescription: dueDate,
            cadence: cadence,
            status: status,
            snoozeUntilDescription: snoozeUntil,
            checkOffHabit: checkOffHabit,
            notes: notes
        )
    }
}

struct ComposeViewArguments: Decodable {
    let sections: [RawComposedSection]
    let briefing: String?
}

struct RawComposedSection: Decodable {
    let title: String?
    let density: SectionDensity?
    let items: [RawComposedItem]
}

struct RawComposedItem: Decodable {
    let type: String
    let id: String?
    let emphasis: String?
    let badge: String?
    let text: String?
}

struct UpdateLayoutArguments: Decodable {
    let operations: [RawLayoutOperation]
}

struct RawLayoutOperation: Decodable {
    let op: String
    let title: String?
    let density: String?
    let position: Int?
    let newTitle: String?
    let entryId: String?
    let section: String?
    let toSection: String?
    let toPosition: Int?
    let emphasis: String?
    let badge: String?

    enum CodingKeys: String, CodingKey {
        case op, title, density, position
        case newTitle = "new_title"
        case entryId = "entry_id"
        case section
        case toSection = "to_section"
        case toPosition = "to_position"
        case emphasis, badge
    }

    var asOperation: LayoutOperation? {
        switch op {
        case "add_section":
            guard let title else { return nil }
            let d = density.flatMap { SectionDensity(rawValue: $0) } ?? .relaxed
            return .addSection(title: title, density: d, position: position)
        case "remove_section":
            guard let title else { return nil }
            return .removeSection(title: title)
        case "update_section":
            guard let title else { return nil }
            let d = density.flatMap { SectionDensity(rawValue: $0) }
            return .updateSection(title: title, density: d, newTitle: newTitle)
        case "insert_entry":
            guard let entryId, let section else { return nil }
            let e = emphasis.flatMap { EntryEmphasis(rawValue: $0) } ?? .standard
            return .insertEntry(entryID: entryId, section: section, position: position, emphasis: e, badge: badge)
        case "remove_entry":
            guard let entryId else { return nil }
            return .removeEntry(entryID: entryId)
        case "move_entry":
            guard let entryId, let toSection else { return nil }
            return .moveEntry(entryID: entryId, toSection: toSection, toPosition: toPosition)
        case "update_entry":
            guard let entryId else { return nil }
            let e = emphasis.flatMap { EntryEmphasis(rawValue: $0) }
            return .updateEntry(entryID: entryId, emphasis: e, badge: badge)
        default:
            return nil
        }
    }
}

struct EntryMutationArguments: Decodable {
    let entries: [RawEntryMutation]
}

struct UpdateMemoryArguments: Decodable {
    let content: String
}

struct RawEntryMutation: Decodable {
    let id: String
    let reason: String?

    var normalizedReason: String {
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            return trimmed
        }
        return "No reason provided"
    }
}

struct ConfirmActionsArguments: Decodable {
    let message: String
    let actions: [RawProposedAction]
}

struct RawProposedAction: Decodable {
    let tool: String
    let arguments: AnyCodable

    /// Re-serialize the arguments object back to Data for reuse by existing decoders.
    var argumentsData: Data? {
        try? JSONSerialization.data(withJSONObject: arguments.value)
    }
}

/// Wrapper to decode arbitrary JSON objects from the arguments field.
struct AnyCodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues(\.value)
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = NSNull()
        }
    }
}
