import Foundation

/// Parses LLM tool calls (name + arguments JSON) into typed AgentActions.
/// Single source of truth for action parsing — used by both the batch response path
/// (`PPQLLMService`) and the streaming accumulator (`StreamingResponseAccumulator`).
public enum ToolCallParser {
    public struct Result: Sendable {
        public let actions: [AgentAction]
        public let failure: ParseFailure?
    }

    /// Result of parsing an entire assistant message containing multiple tool calls.
    public struct BatchResult {
        public let actions: [AgentAction]
        public let failures: [ParseFailure]
        public let groups: [ToolCallGroup]
    }

    // MARK: - Single Tool Call Parsing

    // swiftlint:disable:next cyclomatic_complexity
    public static func parse(name: String, arguments: String, toolCallID: String) -> Result {
        guard let argumentsData = arguments.data(using: .utf8) else {
            return Result(
                actions: [],
                failure: ParseFailure(
                    toolName: name,
                    rawArguments: arguments,
                    errorDescription: "Invalid UTF-8 in arguments",
                    toolCallID: toolCallID
                )
            )
        }

        do {
            var actions: [AgentAction] = []

            switch name {
            case "create_entries":
                let wrapper = try JSONDecoder().decode(CreateEntriesArguments.self, from: argumentsData)
                actions = wrapper.entries.map { .create($0.asAction) }

            case "update_entries":
                let wrapper = try JSONDecoder().decode(UpdateEntriesArguments.self, from: argumentsData)
                actions = wrapper.updates.map { .update($0.asAction) }

            case "update_list_items":
                let wrapper = try JSONDecoder().decode(UpdateListItemsArguments.self, from: argumentsData)
                let items = wrapper.items.map { (text: $0.text, checked: $0.checked) }
                actions = [.updateListItems(UpdateListItemsAction(
                    id: wrapper.entryId,
                    items: items
                ))]

            case "complete_entries":
                let wrapper = try JSONDecoder().decode(EntryMutationArguments.self, from: argumentsData)
                actions = wrapper.entries.map {
                    .complete(CompleteAction(id: $0.id, reason: $0.normalizedReason))
                }

            case "archive_entries":
                let wrapper = try JSONDecoder().decode(EntryMutationArguments.self, from: argumentsData)
                actions = wrapper.entries.map {
                    .archive(ArchiveAction(id: $0.id, reason: $0.normalizedReason))
                }

            case "update_memory":
                let wrapper = try JSONDecoder().decode(UpdateMemoryArguments.self, from: argumentsData)
                actions = [.updateMemory(UpdateMemoryAction(content: wrapper.content))]

            case "confirm_actions":
                let wrapper = try JSONDecoder().decode(ConfirmActionsArguments.self, from: argumentsData)
                let proposed = parseProposedActions(wrapper.actions)
                actions = [.confirm(ConfirmationRequest(
                    message: wrapper.message,
                    proposedActions: proposed
                ))]

            case "get_current_layout":
                actions = [.layoutRead]

            case "update_layout":
                let wrapper = try JSONDecoder().decode(UpdateLayoutArguments.self, from: argumentsData)
                actions = wrapper.operations.compactMap { $0.asOperation }.isEmpty
                    ? []
                    : [.layoutUpdate(wrapper.operations.compactMap { $0.asOperation })]

            default:
                return Result(actions: [], failure: nil)
            }

            return Result(actions: actions, failure: nil)
        } catch {
            return Result(
                actions: [],
                failure: ParseFailure(
                    toolName: name,
                    rawArguments: arguments,
                    errorDescription: error.localizedDescription,
                    toolCallID: toolCallID
                )
            )
        }
    }

    // MARK: - Batch Parsing (Non-Streaming)

    /// Parse all tool calls from an assistant message dictionary.
    /// Used by the non-streaming path in PPQLLMService.
    public static func parseActions(from assistantMessage: [String: Any]) -> BatchResult {
        guard let toolCalls = assistantMessage["tool_calls"] as? [[String: Any]] else {
            // With toolChoice: .auto, the model may respond with text only (no actions).
            return BatchResult(actions: [], failures: [], groups: [])
        }

        var actions: [AgentAction] = []
        var failures: [ParseFailure] = []
        var groups: [ToolCallGroup] = []

        for toolCall in toolCalls {
            guard let function = toolCall["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let argumentsString = function["arguments"] as? String
            else {
                continue
            }

            let toolCallID = toolCall["id"] as? String ?? UUID().uuidString
            let startIndex = actions.count

            let parsed = parse(name: name, arguments: argumentsString, toolCallID: toolCallID)

            if let failure = parsed.failure {
                failures.append(failure)
            }

            actions.append(contentsOf: parsed.actions)

            let endIndex = actions.count
            if endIndex > startIndex {
                groups.append(ToolCallGroup(
                    toolCallID: toolCallID,
                    toolName: name,
                    actionRange: startIndex..<endIndex
                ))
            }
        }

        return BatchResult(actions: actions, failures: failures, groups: groups)
    }

    // MARK: - Confirmation Parsing

    /// Parse proposed actions from a confirm_actions tool call.
    /// Reuses the same decoding types as regular tool calls.
    /// Deduplicates by entry ID — if the LLM proposes conflicting actions on the same entry, keeps only the first.
    static func parseProposedActions(_ proposals: [RawProposedAction]) -> [AgentAction] {
        var result: [AgentAction] = []
        for proposal in proposals {
            guard let data = proposal.argumentsData else { continue }
            do {
                switch proposal.tool {
                case "create_entries":
                    let wrapper = try JSONDecoder().decode(CreateEntriesArguments.self, from: data)
                    result.append(contentsOf: wrapper.entries.map { .create($0.asAction) })
                case "update_entries":
                    let wrapper = try JSONDecoder().decode(UpdateEntriesArguments.self, from: data)
                    result.append(contentsOf: wrapper.updates.map { .update($0.asAction) })
                case "update_list_items":
                    let wrapper = try JSONDecoder().decode(UpdateListItemsArguments.self, from: data)
                    let items = wrapper.items.map { (text: $0.text, checked: $0.checked) }
                    result.append(.updateListItems(UpdateListItemsAction(
                        id: wrapper.entryId,
                        items: items
                    )))
                case "complete_entries":
                    let wrapper = try JSONDecoder().decode(EntryMutationArguments.self, from: data)
                    result.append(contentsOf: wrapper.entries.map {
                        .complete(CompleteAction(id: $0.id, reason: $0.normalizedReason))
                    })
                case "archive_entries":
                    let wrapper = try JSONDecoder().decode(EntryMutationArguments.self, from: data)
                    result.append(contentsOf: wrapper.entries.map {
                        .archive(ArchiveAction(id: $0.id, reason: $0.normalizedReason))
                    })
                default:
                    break
                }
            } catch {
                // Skip individual proposal parse failures silently
            }
        }
        return deduplicateByEntryID(result)
    }

    // MARK: - Summarize

    /// Build a human-readable summary of action counts (e.g. "created 2, updated 1").
    public static func summarize(actions: [AgentAction]) -> String {
        if actions.isEmpty { return "No actions" }

        let labels: [(String, Int)] = [
            ("created", actions.filter { if case .create = $0 { return true }; return false }.count),
            ("updated", actions.filter {
                if case .update = $0 { return true }
                if case .updateListItems = $0 { return true }
                return false
            }.count),
            ("completed", actions.filter { if case .complete = $0 { return true }; return false }.count),
            ("archived", actions.filter { if case .archive = $0 { return true }; return false }.count),
        ]

        let parts = labels.filter { $0.1 > 0 }.map { "\($0.0) \($0.1)" }
        return parts.isEmpty ? "No actions" : parts.joined(separator: ", ")
    }

    // MARK: - Helpers

    /// Safely extract an Int from an Any? that may be Int or NSNumber.
    /// Used when parsing usage dictionaries from JSON.
    public static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }

    /// If the LLM proposes conflicting actions on the same entry, keep only the first.
    private static func deduplicateByEntryID(_ actions: [AgentAction]) -> [AgentAction] {
        var seenIDs = Set<String>()
        return actions.filter { action in
            guard let id = action.mutationEntryID else { return true }
            return seenIDs.insert(id).inserted
        }
    }
}
