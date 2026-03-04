import Foundation

/// Events emitted during streaming LLM response processing.
public enum AgentStreamEvent: Sendable {
    /// A text token from the assistant's content.
    case textDelta(String)

    /// A new tool call has started (name and ID are known).
    case toolCallStarted(ToolCallProgress)

    /// A tool call's arguments are fully received and parsed into actions.
    case toolCallCompleted(ToolCallResult)

    /// A tool call failed to parse.
    case toolCallFailed(ParseFailure)

    /// The stream is complete. Contains the assembled final response.
    case completed(AgentResponse)
}

/// Progress info for a tool call that has started streaming.
public struct ToolCallProgress: Sendable {
    public let index: Int
    public let toolCallID: String
    public let toolName: String

    public init(index: Int, toolCallID: String, toolName: String) {
        self.index = index
        self.toolCallID = toolCallID
        self.toolName = toolName
    }
}

/// Result of a fully received and parsed tool call.
public struct ToolCallResult: Sendable {
    public let toolCallID: String
    public let toolName: String
    public let actions: [AgentAction]
    public let group: ToolCallGroup

    public init(toolCallID: String, toolName: String, actions: [AgentAction], group: ToolCallGroup) {
        self.toolCallID = toolCallID
        self.toolName = toolName
        self.actions = actions
        self.group = group
    }
}
