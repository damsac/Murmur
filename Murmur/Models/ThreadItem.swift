import Foundation
import MurmurCore

/// A single item in the conversation thread.
/// Each variant carries the data needed for rendering.
enum ThreadItem: Identifiable {
    /// User's voice or text input
    case userInput(id: UUID = UUID(), text: String, isCollapsed: Bool = false)

    /// Agent executed actions — entries created/updated/completed/archived
    case actionResult(id: UUID = UUID(), result: ActionResultData)

    /// Agent responded with text (clarification, summary, recommendation)
    case agentText(id: UUID = UUID(), text: String)

    /// Ephemeral status: recording or processing
    case status(id: UUID, kind: StatusKind)

    /// Error with optional retry
    case error(id: UUID = UUID(), message: String, retryText: String? = nil)

    var id: UUID {
        switch self {
        case .userInput(let id, _, _): return id
        case .actionResult(let id, _): return id
        case .agentText(let id, _): return id
        case .status(let id, _): return id
        case .error(let id, _, _): return id
        }
    }
}

enum StatusKind: Equatable {
    case recording(transcript: String)
    case processing
}

/// Data for an action result thread item.
struct ActionResultData {
    let summary: String
    let applied: [AppliedActionInfo]
    let failures: [String]
    let undo: UndoTransaction
    let generation: Int

    var isEmpty: Bool { applied.isEmpty && failures.isEmpty }
}

/// Info about a single applied action for display in the thread.
struct AppliedActionInfo: Identifiable {
    let id: UUID
    let entry: Entry
    let actionType: ActionType

    enum ActionType: String {
        case created = "Created"
        case updated = "Updated"
        case completed = "Completed"
        case archived = "Archived"

        static func from(_ action: AgentAction) -> ActionType {
            switch action {
            case .create: return .created
            case .update: return .updated
            case .complete: return .completed
            case .archive: return .archived
            case .updateMemory: return .updated
            }
        }
    }
}
