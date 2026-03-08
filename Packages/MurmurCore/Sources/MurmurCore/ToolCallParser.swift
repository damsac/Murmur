import Foundation

/// Parses a single LLM tool call (name + arguments JSON) into typed AgentActions.
/// Shared by both the batch response path and the streaming accumulator.
public enum ToolCallParser {
    public struct Result: Sendable {
        public let actions: [AgentAction]
        public let failure: ParseFailure?
    }

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

    // MARK: - Confirmation Parsing

    private static func parseProposedActions(_ proposals: [RawProposedAction]) -> [AgentAction] {
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
        return result
    }
}
