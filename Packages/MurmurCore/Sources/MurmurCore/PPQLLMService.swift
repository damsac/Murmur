import Foundation

/// LLMService implementation using PPQ.ai's OpenAI-compatible API with tool calling.
public final class PPQLLMService: LLMService, @unchecked Sendable {
    private let apiKey: String
    private let model: String
    private let prompt: LLMPrompt
    private let extractionPrompt: LLMPrompt
    private let session: URLSession

    private static let endpoint = URL(string: "https://api.ppq.ai/chat/completions")!

    public init(
        apiKey: String,
        model: String = "anthropic/claude-sonnet-4.6",
        prompt: LLMPrompt = .entryManager,
        extractionPrompt: LLMPrompt = .entryCreation,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.prompt = prompt
        self.extractionPrompt = extractionPrompt
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
        let summary = parseSummary(from: turn.assistantMessage) ?? summarize(actions: parseResult.actions)
        return AgentResponse(
            actions: parseResult.actions,
            summary: summary,
            usage: turn.usage,
            parseFailures: parseResult.failures
        )
    }

    /// Backward-compatible extraction path for current UI flow.
    /// Uses a create-only prompt so existing confirmation UI behavior is unchanged.
    public func extractEntries(from transcript: String, conversation: LLMConversation) async throws -> LLMResult {
        let turn = try await runTurn(
            userContent: transcript,
            prompt: extractionPrompt,
            conversation: conversation
        )

        let parseResult = parseActions(from: turn.assistantMessage)
        return LLMResult(entries: parseResult.actions.compactMap(\.createdEntry), usage: turn.usage)
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
        let requestMessages = buildRequestMessages(
            userContent: userContent,
            prompt: prompt,
            conversation: conversation
        )

        let request = try buildRequest(messages: requestMessages, prompt: prompt)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PPQError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw PPQError.httpError(statusCode: http.statusCode, body: body)
        }

        let assistantMessage = try parseAssistantMessage(from: data)
        let usage = parseUsage(from: data)
        updateConversation(
            conversation,
            requestMessages: requestMessages,
            assistantMessage: assistantMessage
        )

        return TurnResult(assistantMessage: assistantMessage, usage: usage)
    }

    // MARK: - Request Building

    private func buildRequestMessages(
        userContent: String,
        prompt: LLMPrompt,
        conversation: LLMConversation
    ) -> [[String: Any]] {
        if conversation.messages.isEmpty {
            let temporalContext = buildTemporalContext()
            let systemContent = temporalContext + "\n\n" + prompt.systemPrompt
            return [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": userContent],
            ]
        }

        return conversation.messages + [
            ["role": "user", "content": userContent],
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

    private struct ParseActionResult {
        let actions: [AgentAction]
        let failures: [ParseFailure]
    }

    private func parseActions(from assistantMessage: [String: Any]) -> ParseActionResult {
        guard let toolCalls = assistantMessage["tool_calls"] as? [[String: Any]] else {
            // With toolChoice: .auto, the model may respond with text only (no actions).
            // This is valid — return empty actions and let the caller use parseSummary().
            return ParseActionResult(actions: [], failures: [])
        }

        var actions: [AgentAction] = []
        var failures: [ParseFailure] = []

        for toolCall in toolCalls {
            guard let function = toolCall["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let argumentsString = function["arguments"] as? String,
                  let argumentsData = argumentsString.data(using: .utf8)
            else {
                continue
            }

            do {
                switch name {
                case "create_entries":
                    let wrapper = try JSONDecoder().decode(CreateEntriesArguments.self, from: argumentsData)
                    actions.append(contentsOf: wrapper.entries.map { .create($0.asAction) })

                case "update_entries":
                    let wrapper = try JSONDecoder().decode(UpdateEntriesArguments.self, from: argumentsData)
                    actions.append(contentsOf: wrapper.updates.map { .update($0.asAction) })

                case "complete_entries":
                    let wrapper = try JSONDecoder().decode(EntryMutationArguments.self, from: argumentsData)
                    actions.append(contentsOf: wrapper.entries.map {
                        .complete(CompleteAction(id: $0.id, reason: $0.normalizedReason))
                    })

                case "archive_entries":
                    let wrapper = try JSONDecoder().decode(EntryMutationArguments.self, from: argumentsData)
                    actions.append(contentsOf: wrapper.entries.map {
                        .archive(ArchiveAction(id: $0.id, reason: $0.normalizedReason))
                    })

                default:
                    continue
                }
            } catch {
                failures.append(ParseFailure(
                    toolName: name,
                    rawArguments: argumentsString,
                    errorDescription: error.localizedDescription
                ))
            }
        }

        return ParseActionResult(actions: actions, failures: failures)
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
        if actions.isEmpty {
            return "No actions"
        }

        let createCount = actions.filter {
            if case .create = $0 { return true }
            return false
        }.count
        let updateCount = actions.filter {
            if case .update = $0 { return true }
            return false
        }.count
        let completeCount = actions.filter {
            if case .complete = $0 { return true }
            return false
        }.count
        let archiveCount = actions.filter {
            if case .archive = $0 { return true }
            return false
        }.count

        var parts: [String] = []
        if createCount > 0 { parts.append("created \(createCount)") }
        if updateCount > 0 { parts.append("updated \(updateCount)") }
        if completeCount > 0 { parts.append("completed \(completeCount)") }
        if archiveCount > 0 { parts.append("archived \(archiveCount)") }

        return parts.joined(separator: ", ")
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
        if let int = value as? Int {
            return int
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        return nil
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

// MARK: - Response Decoding Types

private struct CreateEntriesArguments: Decodable {
    let entries: [RawCreateAction]
}

private struct RawCreateAction: Decodable {
    let content: String
    let category: EntryCategory
    let sourceText: String?
    let summary: String?
    let priority: Int?
    let dueDate: String?
    let cadence: HabitCadence?

    enum CodingKeys: String, CodingKey {
        case content
        case category
        case sourceText = "source_text"
        case summary
        case priority
        case dueDate = "due_date"
        case cadence
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
            cadence: cadence
        )
    }
}

private struct UpdateEntriesArguments: Decodable {
    let updates: [RawUpdateAction]
}

private struct RawUpdateAction: Decodable {
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

private struct RawUpdateFields: Decodable {
    let content: String?
    let summary: String?
    let category: EntryCategory?
    let priority: Int?
    let dueDate: String?
    let cadence: HabitCadence?
    let status: AgentEntryStatus?
    let snoozeUntil: String?

    enum CodingKeys: String, CodingKey {
        case content
        case summary
        case category
        case priority
        case dueDate = "due_date"
        case cadence
        case status
        case snoozeUntil = "snooze_until"
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
            snoozeUntilDescription: snoozeUntil
        )
    }
}

private struct EntryMutationArguments: Decodable {
    let entries: [RawEntryMutation]
}

private struct RawEntryMutation: Decodable {
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
