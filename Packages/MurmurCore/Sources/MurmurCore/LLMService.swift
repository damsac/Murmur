import Foundation

/// Opaque conversation state for multi-turn LLM interactions.
/// Retains full message history including tool calls and model reasoning.
public final class LLMConversation: @unchecked Sendable {
    /// Stable identifier for this conversation. Used to link multi-turn LLM requests in analytics.
    public let id: UUID = UUID()

    /// Number of LLM turns completed in this conversation. Incremented before each HTTP call.
    public private(set) var turnCount: Int = 0

    var messages: [[String: Any]] = []

    public init() {}

    /// Increment the turn counter. Called by the LLM service before each HTTP request.
    public func incrementTurn() { turnCount += 1 }

    /// Number of messages in the conversation history.
    public var messageCount: Int { messages.count }

    /// Truncate conversation history, keeping the most recent messages.
    /// Preserves the first message (system context) and trims the oldest middle messages.
    public func truncate(keepingLast maxMessages: Int) {
        guard messages.count > maxMessages else { return }
        let excess = messages.count - maxMessages
        if excess > 0 && messages.count > 1 {
            messages.removeSubrange(1..<min(1 + excess, messages.count))
        }
    }

    /// Replace synthetic tool result messages with real execution outcomes.
    /// Matches on `tool_call_id` and overwrites `content` in-place.
    public func replaceToolResults(_ results: [(toolCallID: String, content: String)]) {
        let lookup = Dictionary(uniqueKeysWithValues: results.map { ($0.toolCallID, $0.content) })
        for i in messages.indices {
            guard let role = messages[i]["role"] as? String, role == "tool",
                  let callID = messages[i]["tool_call_id"] as? String,
                  let replacement = lookup[callID]
            else { continue }
            messages[i]["content"] = replacement
        }
    }
}

public enum LLMToolChoice: Sendable {
    case auto
    case function(name: String)

    var requestBodyValue: Any {
        switch self {
        case .auto:
            return "auto"
        case .function(let name):
            return ["type": "function", "function": ["name": name]]
        }
    }
}

/// Protocol for the entry-management agent.
public protocol MurmurAgent: Sendable {
    func process(
        transcript: String,
        existingEntries: [AgentContextEntry],
        conversation: LLMConversation
    ) async throws -> AgentResponse
}

/// Agent that supports SSE streaming responses.
public protocol StreamingMurmurAgent: MurmurAgent {
    func processStreaming(
        transcript: String,
        existingEntries: [AgentContextEntry],
        conversation: LLMConversation
    ) -> AsyncThrowingStream<AgentStreamEvent, Error>
}
