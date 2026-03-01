import Foundation
import MurmurCore

/// Builds real tool-result strings from execution outcomes, replacing synthetic "accepted" messages.
enum ToolResultBuilder {

    /// Produce per-tool_call_id result strings from execution outcomes and parse failures.
    static func build(
        groups: [ToolCallGroup],
        outcomes: [AgentActionExecutor.ActionOutcome],
        parseFailures: [ParseFailure]
    ) -> [(toolCallID: String, content: String)] {
        var results: [(toolCallID: String, content: String)] = []
        var coveredToolCallIDs = Set<String>()

        for group in groups {
            coveredToolCallIDs.insert(group.toolCallID)
            let slice = outcomes[group.actionRange]
            let content = formatGroupOutcomes(toolName: group.toolName, outcomes: Array(slice))
            results.append((toolCallID: group.toolCallID, content: content))
        }

        // Parse failures with a toolCallID not covered by any group
        for failure in parseFailures {
            guard let id = failure.toolCallID, !coveredToolCallIDs.contains(id) else { continue }
            results.append((
                toolCallID: id,
                content: "Error: failed to parse \(failure.toolName) — \(failure.errorDescription)"
            ))
        }

        return results
    }

    // MARK: - Private

    private static func formatGroupOutcomes(
        toolName: String,
        outcomes: [AgentActionExecutor.ActionOutcome]
    ) -> String {
        let parts: [String] = outcomes.compactMap { outcome in
            switch outcome {
            case .applied(let entry):
                return formatApplied(toolName: toolName, entry: entry)
            case .memorySaved(let wordCount):
                return "Memory updated (\(wordCount) words)"
            case .skipped:
                return nil
            case .failed(let reason):
                return "Failed: \(reason)"
            }
        }

        if parts.isEmpty {
            return "\(toolName) accepted."
        }
        return parts.joined(separator: ", ")
    }

    private static func formatApplied(toolName: String, entry: Entry) -> String {
        let shortID = entry.shortID
        let summary = entry.summary.isEmpty ? entry.content.prefix(30) : entry.summary.prefix(30)

        switch toolName {
        case "create_entries":
            return "Created [\(shortID)] '\(summary)'"
        case "update_entries":
            return "Updated [\(shortID)]"
        case "complete_entries":
            return "Completed [\(shortID)]"
        case "archive_entries":
            return "Archived [\(shortID)]"
        default:
            return "Applied [\(shortID)]"
        }
    }
}
