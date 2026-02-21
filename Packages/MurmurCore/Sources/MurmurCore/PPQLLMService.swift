import Foundation

/// LLMService implementation using PPQ.ai's OpenAI-compatible API with tool calling.
public final class PPQLLMService: LLMService, @unchecked Sendable {
    private let apiKey: String
    private let model: String
    private let prompt: LLMPrompt
    private let session: URLSession

    private static let endpoint = URL(string: "https://api.ppq.ai/chat/completions")!

    public init(apiKey: String, model: String = "anthropic/claude-sonnet-4.6", prompt: LLMPrompt = .entryExtraction, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.prompt = prompt
        self.session = session
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy 'at' h:mm a zzz"
        formatter.timeZone = .current
        return formatter
    }()

    public func extractEntries(from transcript: String, conversation: LLMConversation) async throws -> LLMResult {
        // Build messages: fresh (empty conversation) or multi-turn (append to history)
        let requestMessages: [[String: Any]]
        if conversation.messages.isEmpty {
            let currentDateTime = Self.dateTimeFormatter.string(from: Date())
            let systemContent = "Current date and time: \(currentDateTime)\n\n" + prompt.systemPrompt
            requestMessages = [
                ["role": "system", "content": systemContent],
                ["role": "user", "content": transcript],
            ]
        } else {
            requestMessages = conversation.messages + [
                ["role": "user", "content": transcript],
            ]
        }

        let request = try buildRequest(messages: requestMessages)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PPQError.invalidResponse
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw PPQError.httpError(statusCode: http.statusCode, body: body)
        }

        let entries = try parseToolCalls(from: data)
        let usage = parseUsage(from: data)

        // Update conversation with full history (including assistant response + tool results)
        updateConversation(conversation, requestMessages: requestMessages, responseData: data)

        return LLMResult(entries: entries, usage: usage)
    }

    // MARK: - Request Building

    private func buildRequest(messages: [[String: Any]]) throws -> URLRequest {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "tools": prompt.tools,
            "tool_choice": prompt.toolChoice,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Conversation Management

    /// Append the full request/response round to the conversation history.
    /// Retains the assistant's complete message (content/thinking + tool_calls).
    private func updateConversation(
        _ conversation: LLMConversation,
        requestMessages: [[String: Any]],
        responseData: Data
    ) {
        // Start from the request messages (includes system + all prior turns + new user)
        conversation.messages = requestMessages

        // Extract and append the full assistant message from the response
        guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let assistantMessage = choices.first?["message"] as? [String: Any]
        else { return }

        conversation.messages.append(assistantMessage)

        // Append tool results so the next turn is valid
        if let toolCalls = assistantMessage["tool_calls"] as? [[String: Any]] {
            for toolCall in toolCalls {
                if let id = toolCall["id"] as? String {
                    conversation.messages.append([
                        "role": "tool",
                        "tool_call_id": id,
                        "content": "Entries received.",
                    ])
                }
            }
        }
    }

    // MARK: - Response Parsing

    private func parseToolCalls(from data: Data) throws -> [ExtractedEntry] {
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let choices = json?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let toolCalls = message["tool_calls"] as? [[String: Any]]
        else {
            throw PPQError.noToolCalls
        }

        var entries: [ExtractedEntry] = []

        for toolCall in toolCalls {
            guard let function = toolCall["function"] as? [String: Any],
                  let argumentsString = function["arguments"] as? String,
                  let argumentsData = argumentsString.data(using: .utf8)
            else {
                continue
            }

            let wrapper = try JSONDecoder().decode(EntriesToolCallArguments.self, from: argumentsData)
            entries.append(contentsOf: wrapper.entries.map { raw in
                ExtractedEntry(
                    content: raw.content,
                    category: raw.category,
                    sourceText: raw.sourceText,
                    summary: raw.summary ?? "",
                    priority: raw.priority,
                    dueDateDescription: raw.dueDate,
                    cadence: raw.cadence
                )
            })
        }

        return entries
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
}

// MARK: - Response Decoding Types

private struct EntriesToolCallArguments: Decodable {
    let entries: [RawEntry]
}

private struct RawEntry: Decodable {
    let content: String
    let category: EntryCategory
    let sourceText: String
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
