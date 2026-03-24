import Foundation
import os.log

private let sseLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "murmur", category: "SSE")

// swiftlint:disable type_body_length
/// MurmurAgent implementation using PPQ.ai's OpenAI-compatible API with tool calling.
public final class PPQLLMService: MurmurAgent, StreamingMurmurAgent, @unchecked Sendable {
    private let apiKey: String
    public let model: String
    private let prompt: LLMPrompt
    private let session: URLSession

    /// Persistent memory content injected into the system prompt.
    public var agentMemory: String?

    /// Active layout variant. Set by AppState before composition/agent calls.
    public var compositionVariant: CompositionVariant = .scanner

    private static let endpoint = URL(string: "https://api.ppq.ai/chat/completions")!

    public init(
        apiKey: String,
        model: String = "anthropic/claude-haiku-4.5",
        prompt: LLMPrompt = .entryManager,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.prompt = prompt
        self.session = session
    }

    /// Tracks how many recordings have been processed in this service instance (≈ session).
    private var sessionRecordingCount = 0

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a zzz"
        formatter.timeZone = .current
        return formatter
    }()

    /// Builds a compact temporal context block (~20 tokens) for the system prompt.
    private func buildTemporalContext(for date: Date = Date()) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        let timeOfDay: String
        switch hour {
        case 5..<12: timeOfDay = "morning"
        case 12..<17: timeOfDay = "afternoon"
        case 17..<21: timeOfDay = "evening"
        default: timeOfDay = "night"
        }

        let isWeekend = calendar.isDateInWeekend(date)
        let dayType = isWeekend ? "weekend" : "weekday"
        let dateString = Self.dateTimeFormatter.string(from: date)

        var context = "Current: \(dateString) (\(dayType), \(timeOfDay))"
        if sessionRecordingCount > 1 {
            context += "\nThis session: recording #\(sessionRecordingCount)"
        }
        return context
    }

    public func process(
        transcript: String,
        existingEntries: [AgentContextEntry],
        conversation: LLMConversation
    ) async throws -> AgentResponse {
        sseLog.info("[SSE] process() called — NON-STREAMING path (runTurn)")
        sessionRecordingCount += 1
        let userContent = buildAgentUserContent(
            transcript: transcript,
            existingEntries: existingEntries
        )

        let turn = try await runTurn(
            userContent: userContent,
            prompt: prompt,
            conversation: conversation
        )

        let parseResult = parseActions(from: turn.assistantMessage)
        let textContent = parseSummary(from: turn.assistantMessage)
        let summary = textContent ?? summarize(actions: parseResult.actions)
        // textResponse is only set when the agent responds with text and no actions
        let textResponse = parseResult.actions.isEmpty ? textContent : nil
        sseLog.info("[SSE] process() complete — \(parseResult.actions.count) actions, textResponse=\(textResponse != nil)")
        return AgentResponse(
            actions: parseResult.actions,
            summary: summary,
            usage: turn.usage,
            parseFailures: parseResult.failures,
            toolCallGroups: parseResult.groups,
            textResponse: textResponse
        )
    }

    // MARK: - Home Composition

    /// One-shot LLM call to compose the home view layout.
    /// Uses a separate conversation (not the ongoing agent conversation).
    public func composeHomeView(
        entries: [AgentContextEntry],
        variant: CompositionVariant = .scanner
    ) async throws -> (composition: HomeComposition, usage: TokenUsage) {
        sseLog.info("[SSE] composeHomeView(\(variant.rawValue)) called — \(entries.count) entries")
        let userContent = buildCompositionUserContent(entries: entries)
        let conversation = LLMConversation()
        let prompt: LLMPrompt = variant == .scanner ? .homeComposition : .navigatorComposition

        let turn = try await runTurn(
            userContent: userContent,
            prompt: prompt,
            conversation: conversation
        )

        var composition = try parseHomeComposition(from: turn.assistantMessage)
        composition.variant = variant
        sseLog.info("[SSE] composeHomeView() complete — \(composition.sections.count) sections, usage: in=\(turn.usage.inputTokens) out=\(turn.usage.outputTokens)")
        return (composition, turn.usage)
    }

    // MARK: - Layout Refresh

    /// Diff-only refresh: compare current layout against entries, return operations.
    /// One-shot isolated call — does not affect the agent conversation.
    public func refreshLayout(
        entries: [AgentContextEntry],
        currentLayout: HomeComposition,
        variant: CompositionVariant
    ) async throws -> (operations: [LayoutOperation], usage: TokenUsage) {
        sseLog.info("[SSE] refreshLayout(\(variant.rawValue)) called — \(entries.count) entries")
        let conversation = LLMConversation()
        let userContent = buildRefreshUserContent(entries: entries, layout: currentLayout, variant: variant)

        let turn = try await runTurn(
            userContent: userContent,
            prompt: .layoutRefresh,
            conversation: conversation
        )

        let operations = parseLayoutOperations(from: turn.assistantMessage)
        sseLog.info("[SSE] refreshLayout() complete — \(operations.count) operations, usage: in=\(turn.usage.inputTokens) out=\(turn.usage.outputTokens)")
        return (operations, turn.usage)
    }

    private func buildCompositionUserContent(entries: [AgentContextEntry]) -> String {
        guard !entries.isEmpty else {
            return "[COMPOSITION] No entries."
        }

        let sortedEntries = entries.sorted { lhs, rhs in
            let leftPriority = lhs.priority ?? 6
            let rightPriority = rhs.priority ?? 6
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return lhs.createdAt > rhs.createdAt
        }

        var lines = ["[COMPOSITION] Compose the home view from these entries.", "", "## Current Entries", ""]
        lines.append(contentsOf: sortedEntries.map(formatContextLine(for:)))
        return lines.joined(separator: "\n")
    }

    private func parseHomeComposition(from assistantMessage: [String: Any]) throws -> HomeComposition {
        guard let toolCalls = assistantMessage["tool_calls"] as? [[String: Any]],
              let firstCall = toolCalls.first,
              let function = firstCall["function"] as? [String: Any],
              let name = function["name"] as? String, name == "compose_view",
              let argsString = function["arguments"] as? String,
              let argsData = argsString.data(using: .utf8)
        else {
            throw PPQError.noToolCalls
        }

        let args = try JSONDecoder().decode(ComposeViewArguments.self, from: argsData)
        let sections = args.sections.map { rawSection in
            ComposedSection(
                title: rawSection.title,
                density: rawSection.density ?? .relaxed,
                items: rawSection.items.compactMap { rawItem in
                    switch rawItem.type {
                    case "entry":
                        guard let id = rawItem.id else { return nil }
                        let emphasis = rawItem.emphasis.flatMap { EntryEmphasis(rawValue: $0) } ?? .standard
                        return ComposedItem.entry(ComposedEntry(id: id, emphasis: emphasis, badge: rawItem.badge))
                    case "message":
                        guard let text = rawItem.text else { return nil }
                        return ComposedItem.message(text)
                    default:
                        return nil
                    }
                }
            )
        }

        return HomeComposition(sections: sections, briefing: args.briefing)
    }

    // MARK: - Refresh Parsing

    private func parseLayoutOperations(from assistantMessage: [String: Any]) -> [LayoutOperation] {
        guard let toolCalls = assistantMessage["tool_calls"] as? [[String: Any]],
              let firstCall = toolCalls.first,
              let function = firstCall["function"] as? [String: Any],
              let name = function["name"] as? String, name == "update_layout",
              let argsString = function["arguments"] as? String,
              let argsData = argsString.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode(UpdateLayoutArguments.self, from: argsData)
        else {
            return []
        }
        return wrapper.operations.compactMap { $0.asOperation }
    }

    private func buildRefreshUserContent(
        entries: [AgentContextEntry],
        layout: HomeComposition,
        variant: CompositionVariant
    ) -> String {
        var lines: [String] = []

        lines.append("## Current Layout")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let layoutJSON = try? encoder.encode(layout),
           let layoutString = String(data: layoutJSON, encoding: .utf8) {
            lines.append(layoutString)
        } else {
            lines.append("{}")
        }

        lines.append("")
        lines.append("## Layout Instructions")
        lines.append(Self.layoutInstructions(for: variant))

        lines.append("")
        lines.append("## Current Entries")
        if entries.isEmpty {
            lines.append("No entries.")
        } else {
            let sorted = entries.sorted { lhs, rhs in
                let lp = lhs.priority ?? 6
                let rp = rhs.priority ?? 6
                if lp != rp { return lp < rp }
                return lhs.createdAt > rhs.createdAt
            }
            lines.append(contentsOf: sorted.map(formatContextLine(for:)))
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Layout Instructions

    /// Variant-specific layout constraints. Used by both agent user content and refresh.
    static func layoutInstructions(for variant: CompositionVariant) -> String {
        switch variant {
        case .scanner:
            return """
                Group by urgency/context, not category. 3-5 sections, up to 7 items. \
                Hero for urgent (1-2 max), compact for low-priority. \
                Badges: Overdue, Today, Stale, P1, New.
                """
        case .navigator:
            return """
                Sections named by category (todo, reminder, habit, idea, list, note, question). \
                Standard emphasis for all. Relaxed density. 7 items max total. \
                No inline message items. \
                Badge = short reason for attention (Overdue, Due today, High priority, New, Stale).
                """
        }
    }

    // MARK: - Turn Execution

    private struct TurnResult {
        let assistantMessage: [String: Any]
        let usage: TokenUsage
    }

    private func runTurn(
        userContent: String,
        prompt: LLMPrompt,
        conversation: LLMConversation
    ) async throws -> TurnResult {
        sseLog.info("[SSE] runTurn — building request (non-streaming, no stream:true in body)")
        conversation.incrementTurn()
        let requestMessages = buildRequestMessages(
            userContent: userContent,
            prompt: prompt,
            conversation: conversation
        )

        let request = try buildRequest(messages: requestMessages, prompt: prompt)
        sseLog.info("[SSE] runTurn — sending HTTP request to \(Self.endpoint.absoluteString)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            sseLog.error("[SSE] runTurn — invalid response (not HTTPURLResponse)")
            throw PPQError.invalidResponse
        }

        sseLog.info("[SSE] runTurn — HTTP \(http.statusCode), body size: \(data.count) bytes")

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            sseLog.error("[SSE] runTurn — HTTP error \(http.statusCode)")
            throw PPQError.httpError(statusCode: http.statusCode, body: body)
        }

        let assistantMessage = try parseAssistantMessage(from: data)
        let usage = parseUsage(from: data)
        sseLog.info("[SSE] runTurn — parsed response, usage: in=\(usage.inputTokens) out=\(usage.outputTokens)")
        updateConversation(
            conversation,
            requestMessages: requestMessages,
            assistantMessage: assistantMessage
        )

        return TurnResult(assistantMessage: assistantMessage, usage: usage)
    }

    // MARK: - Streaming

    /// Stream agent response via SSE, yielding events as text and tool calls arrive.
    public func processStreaming(
        transcript: String,
        existingEntries: [AgentContextEntry],
        conversation: LLMConversation
    ) -> AsyncThrowingStream<AgentStreamEvent, Error> {
        sessionRecordingCount += 1
        let userContent = buildAgentUserContent(
            transcript: transcript,
            existingEntries: existingEntries
        )
        let requestMessages = buildRequestMessages(
            userContent: userContent,
            prompt: prompt,
            conversation: conversation
        )

        conversation.incrementTurn()

        return AsyncThrowingStream { continuation in
            let task = Task { [self] in
                do {
                    sseLog.info("[SSE] processStreaming — starting SSE request")
                    let request = try self.buildStreamingRequest(
                        messages: requestMessages,
                        prompt: self.prompt
                    )
                    let (bytes, response) = try await self.session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw PPQError.invalidResponse
                    }
                    guard http.statusCode == 200 else {
                        throw PPQError.httpError(
                            statusCode: http.statusCode,
                            body: "streaming request failed"
                        )
                    }

                    sseLog.info("[SSE] processStreaming — HTTP \(http.statusCode), consuming SSE stream")
                    let accumulator = StreamingResponseAccumulator()

                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }

                        guard let event = SSELineParser.parse(line: line) else { continue }

                        switch event {
                        case .data(let chunk):
                            for streamEvent in accumulator.feed(chunk: chunk) {
                                continuation.yield(streamEvent)
                            }
                        case .done:
                            sseLog.info("[SSE] processStreaming — received [DONE]")
                            for streamEvent in accumulator.finish() {
                                continuation.yield(streamEvent)
                            }

                            let assistantMessage = accumulator.assembledMessage()
                            self.updateConversation(
                                conversation,
                                requestMessages: requestMessages,
                                assistantMessage: assistantMessage
                            )

                            let finalResponse = accumulator.buildFinalResponse()
                            sseLog.info("[SSE] processStreaming — complete, \(finalResponse.actions.count) actions")
                            continuation.yield(.completed(finalResponse))
                        }
                    }

                    continuation.finish()
                } catch {
                    sseLog.error("[SSE] processStreaming — error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Request Building

    private func buildRequestMessages(
        userContent: String,
        prompt: LLMPrompt,
        conversation: LLMConversation
    ) -> [[String: Any]] {
        if conversation.messages.isEmpty {
            let temporalContext = buildTemporalContext()
            var systemContent = temporalContext + "\n\n" + prompt.systemPrompt
            if let memory = agentMemory, !memory.isEmpty {
                systemContent += "\n\n## Your Memory\n" + memory
            }
            return [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": userContent],
            ]
        }

        let temporalContext = buildTemporalContext()
        return conversation.messages + [
            ["role": "user", "content": "[\(temporalContext)]\n\n\(userContent)"],
        ]
    }

    private func buildRequest(messages: [[String: Any]], prompt: LLMPrompt) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": prompt.tools,
            "tool_choice": prompt.toolChoice.requestBodyValue,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    private func buildStreamingRequest(messages: [[String: Any]], prompt: LLMPrompt) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": prompt.tools,
            "tool_choice": prompt.toolChoice.requestBodyValue,
            "stream": true,
            "stream_options": ["include_usage": true],
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Conversation Management

    /// Append the full request/response round to the conversation history.
    /// Retains the assistant's complete message (content + tool_calls).
    private func updateConversation(
        _ conversation: LLMConversation,
        requestMessages: [[String: Any]],
        assistantMessage: [String: Any]
    ) {
        conversation.messages = requestMessages
        conversation.messages.append(assistantMessage)

        if let toolCalls = assistantMessage["tool_calls"] as? [[String: Any]] {
            for toolCall in toolCalls {
                guard let id = toolCall["id"] as? String else { continue }
                let function = toolCall["function"] as? [String: Any]
                let toolName = function?["name"] as? String ?? "tool"
                conversation.messages.append([
                    "role": "tool",
                    "tool_call_id": id,
                    "content": "\(toolName) accepted.",
                ])
            }
        }
    }

    // MARK: - Response Parsing

    private func parseAssistantMessage(from data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let assistantMessage = choices.first?["message"] as? [String: Any]
        else {
            throw PPQError.invalidResponse
        }

        return assistantMessage
    }

    private func parseActions(from assistantMessage: [String: Any]) -> ToolCallParser.BatchResult {
        ToolCallParser.parseActions(from: assistantMessage)
    }

    private func parseSummary(from assistantMessage: [String: Any]) -> String? {
        if let content = assistantMessage["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        if let contentParts = assistantMessage["content"] as? [[String: Any]] {
            let text = contentParts
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }

        return nil
    }

    private func summarize(actions: [AgentAction]) -> String {
        ToolCallParser.summarize(actions: actions)
    }

    private func parseUsage(from data: Data) -> TokenUsage {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let usage = json["usage"] as? [String: Any]
        else {
            return .zero
        }

        let inputTokens = intValue(
            usage["prompt_tokens"]
        ) ?? intValue(
            usage["input_tokens"]
        ) ?? 0

        let outputTokens = intValue(
            usage["completion_tokens"]
        ) ?? intValue(
            usage["output_tokens"]
        ) ?? 0

        return TokenUsage(inputTokens: inputTokens, outputTokens: outputTokens)
    }

    private func intValue(_ value: Any?) -> Int? {
        ToolCallParser.intValue(value)
    }

    // MARK: - Context Formatting

    private func buildAgentUserContent(
        transcript: String,
        existingEntries: [AgentContextEntry]
    ) -> String {
        guard !existingEntries.isEmpty else {
            return transcript
        }

        let sortedEntries = existingEntries.sorted { lhs, rhs in
            let leftPriority = lhs.priority ?? 6
            let rightPriority = rhs.priority ?? 6
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return lhs.createdAt > rhs.createdAt
        }

        var lines: [String] = ["## Current Entries", ""]
        lines.append(contentsOf: sortedEntries.map(formatContextLine(for:)))
        lines.append("")
        lines.append("## Layout Instructions")
        lines.append(Self.layoutInstructions(for: compositionVariant))
        lines.append("")
        lines.append("## User Transcript")
        lines.append(transcript)

        return lines.joined(separator: "\n")
    }

    private func formatContextLine(for entry: AgentContextEntry) -> String {
        var line = "- [\(entry.id)] \(entry.category.rawValue.uppercased())"
        if let priority = entry.priority {
            line += " P\(priority)"
        }

        let summary = cleaned(entry.summary) ?? "(no summary)"
        line += " \"\(summary)\""

        if let dueDate = cleaned(entry.dueDateDescription) {
            line += " due:\(dueDate)"
        }

        if let cadence = entry.cadence {
            line += " cadence:\(cadence.rawValue)"
        }

        if entry.status != .active {
            line += " status:\(entry.status.rawValue)"
        }

        if let streak = entry.currentStreak, streak > 1 {
            line += " streak:\(streak)"
        }

        if let notes = cleaned(entry.notes), !notes.isEmpty {
            let truncated = notes.count > 100 ? String(notes.prefix(100)) + "..." : notes
            line += " notes:\"\(truncated)\""
        }

        return line
    }

    private func cleaned(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }
}
// swiftlint:enable type_body_length
