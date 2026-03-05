import Foundation
import os.log

private let sseLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "murmur", category: "SSE")

/// Stateful accumulator fed SSE JSON chunk dictionaries.
/// Emits `AgentStreamEvent` values as tool calls complete and text arrives.
public final class StreamingResponseAccumulator {
    private var textContent: String = ""
    private var toolCalls: [Int: InProgressToolCall] = [:]
    private var usage: TokenUsage = .zero
    private var completedToolCallIndices: Set<Int> = []
    private var allActions: [AgentAction] = []
    private var allFailures: [ParseFailure] = []
    private var allGroups: [ToolCallGroup] = []

    struct InProgressToolCall {
        var id: String
        var name: String
        var arguments: String
        var started: Bool
    }

    public init() {}

    /// Process one SSE data chunk and return any events it produces.
    public func feed(chunk: [String: Any]) -> [AgentStreamEvent] {
        var events: [AgentStreamEvent] = []

        captureUsage(from: chunk)

        guard let choices = chunk["choices"] as? [[String: Any]],
              let delta = choices.first?["delta"] as? [String: Any]
        else {
            sseLog.debug("[SSE] Accumulator.feed — chunk has no choices/delta")
            return events
        }

        // Text content delta
        if let content = delta["content"] as? String, !content.isEmpty {
            textContent += content
            sseLog.debug("[SSE] Accumulator.feed — textDelta: \(content.prefix(50))... (total: \(self.textContent.count) chars)")
            events.append(.textDelta(content))
        }

        // Tool call deltas
        if let toolCallDeltas = delta["tool_calls"] as? [[String: Any]] {
            sseLog.debug("[SSE] Accumulator.feed — \(toolCallDeltas.count) tool call delta(s)")
            for toolCallDelta in toolCallDeltas {
                events.append(contentsOf: processToolCallDelta(toolCallDelta))
            }
        }

        return events
    }

    /// Flush any remaining in-progress tool calls. Call after the stream ends.
    public func finish() -> [AgentStreamEvent] {
        let pendingIndices = toolCalls.keys.sorted().filter { !completedToolCallIndices.contains($0) }
        sseLog.info("[SSE] Accumulator.finish — \(pendingIndices.count) pending tool calls to flush")
        var events: [AgentStreamEvent] = []
        for index in pendingIndices {
            events.append(contentsOf: completeToolCall(at: index))
        }
        sseLog.info("[SSE] Accumulator.finish — stream complete, total text: \(self.textContent.count) chars, total actions: \(self.allActions.count)")
        return events
    }

    /// The full assistant message reconstructed from accumulated chunks.
    /// Suitable for appending to conversation history.
    public func assembledMessage() -> [String: Any] {
        var message: [String: Any] = ["role": "assistant"]

        if !textContent.isEmpty {
            message["content"] = textContent
        }

        if !toolCalls.isEmpty {
            let assembled: [[String: Any]] = toolCalls.keys.sorted().compactMap { index in
                guard let tc = toolCalls[index] else { return nil }
                return [
                    "id": tc.id,
                    "type": "function",
                    "function": [
                        "name": tc.name,
                        "arguments": tc.arguments,
                    ],
                ]
            }
            message["tool_calls"] = assembled
        }

        return message
    }

    /// Build the final AgentResponse from all accumulated data.
    public func buildFinalResponse() -> AgentResponse {
        let summary = textContent.isEmpty ? summarize(actions: allActions) : textContent
        let textResponse = allActions.isEmpty && !textContent.isEmpty ? textContent : nil

        return AgentResponse(
            actions: allActions,
            summary: summary,
            usage: usage,
            parseFailures: allFailures,
            toolCallGroups: allGroups,
            textResponse: textResponse
        )
    }

    // MARK: - Private

    private func captureUsage(from chunk: [String: Any]) {
        guard let usageDict = chunk["usage"] as? [String: Any] else { return }
        let input = intValue(usageDict["prompt_tokens"])
            ?? intValue(usageDict["input_tokens"])
            ?? 0
        let output = intValue(usageDict["completion_tokens"])
            ?? intValue(usageDict["output_tokens"])
            ?? 0
        if input > 0 || output > 0 {
            usage = TokenUsage(inputTokens: input, outputTokens: output)
        }
    }

    private func processToolCallDelta(_ toolCallDelta: [String: Any]) -> [AgentStreamEvent] {
        guard let index = toolCallDelta["index"] as? Int else { return [] }
        var events: [AgentStreamEvent] = []

        // A new index means the previous tool call is complete
        if toolCalls[index] == nil {
            events.append(contentsOf: completePendingBefore(index: index))
            initToolCall(at: index, from: toolCallDelta)
        } else {
            accumulateToolCall(at: index, from: toolCallDelta)
        }

        // Emit toolCallStarted once name and id are known
        if let tc = toolCalls[index], !tc.started, !tc.name.isEmpty, !tc.id.isEmpty {
            toolCalls[index]?.started = true
            events.append(.toolCallStarted(ToolCallProgress(
                index: index,
                toolCallID: tc.id,
                toolName: tc.name
            )))
        }

        return events
    }

    private func initToolCall(at index: Int, from delta: [String: Any]) {
        let id = delta["id"] as? String ?? ""
        let function = delta["function"] as? [String: Any]
        let name = function?["name"] as? String ?? ""
        let argFragment = function?["arguments"] as? String ?? ""
        toolCalls[index] = InProgressToolCall(
            id: id, name: name, arguments: argFragment, started: false
        )
    }

    private func accumulateToolCall(at index: Int, from delta: [String: Any]) {
        if let id = delta["id"] as? String, !id.isEmpty {
            toolCalls[index]?.id = id
        }
        guard let function = delta["function"] as? [String: Any] else { return }
        if let name = function["name"] as? String, !name.isEmpty {
            toolCalls[index]?.name = name
        }
        if let argFragment = function["arguments"] as? String {
            toolCalls[index]?.arguments += argFragment
        }
    }

    private func completePendingBefore(index: Int) -> [AgentStreamEvent] {
        let pendingIndices = toolCalls.keys.sorted().filter {
            $0 < index && !completedToolCallIndices.contains($0)
        }
        var events: [AgentStreamEvent] = []
        for idx in pendingIndices {
            events.append(contentsOf: completeToolCall(at: idx))
        }
        return events
    }

    private func completeToolCall(at index: Int) -> [AgentStreamEvent] {
        guard let tc = toolCalls[index], !completedToolCallIndices.contains(index) else {
            return []
        }
        completedToolCallIndices.insert(index)
        sseLog.info("[SSE] Accumulator.completeToolCall — index=\(index), name=\(tc.name), id=\(tc.id), args=\(tc.arguments.count) chars")

        let parsed = ToolCallParser.parse(
            name: tc.name,
            arguments: tc.arguments,
            toolCallID: tc.id
        )

        var events: [AgentStreamEvent] = []

        if let failure = parsed.failure {
            allFailures.append(failure)
            events.append(.toolCallFailed(failure))
        }

        if !parsed.actions.isEmpty {
            let startIndex = allActions.count
            allActions.append(contentsOf: parsed.actions)
            let endIndex = allActions.count

            let group = ToolCallGroup(
                toolCallID: tc.id,
                toolName: tc.name,
                actionRange: startIndex..<endIndex
            )
            allGroups.append(group)

            events.append(.toolCallCompleted(ToolCallResult(
                toolCallID: tc.id,
                toolName: tc.name,
                actions: parsed.actions,
                group: group
            )))
        }

        return events
    }

    private func summarize(actions: [AgentAction]) -> String {
        if actions.isEmpty { return "No actions" }

        let labels: [(String, Int)] = [
            ("created", actions.filter { if case .create = $0 { return true }; return false }.count),
            ("updated", actions.filter { if case .update = $0 { return true }; return false }.count),
            ("completed", actions.filter { if case .complete = $0 { return true }; return false }.count),
            ("archived", actions.filter { if case .archive = $0 { return true }; return false }.count),
        ]

        let parts = labels.filter { $0.1 > 0 }.map { "\($0.0) \($0.1)" }
        return parts.isEmpty ? "No actions" : parts.joined(separator: ", ")
    }

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}
