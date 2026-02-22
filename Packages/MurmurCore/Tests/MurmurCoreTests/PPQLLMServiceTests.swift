import Foundation
import Testing
@testable import MurmurCore

@Suite("PPQLLMService", .serialized)
struct PPQLLMServiceTests {
    // MARK: - Response Parsing via MockURLProtocol

    @Test("Parses tool call response into ExtractedEntries")
    func parsesToolCallResponse() async throws {
        let args = """
        {"entries":[\
        {"content":"Buy groceries","category":"todo",\
        "source_text":"I need to buy groceries",\
        "summary":"Get groceries","priority":3},\
        {"content":"Meeting moved to Thursday","category":"reminder",\
        "source_text":"my meeting got moved to Thursday",\
        "summary":"Meeting rescheduled","due_date":"Thursday"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedArgs = args.replacingOccurrences(of: "\"", with: "\\\"")
        let responseJSON = """
            {
                "id": "chatcmpl-123",
                "object": "chat.completion",
                "choices": [{
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_abc",
                            "type": "function",
                            "function": {
                                "name": "extract_entries",
                                "arguments": "\(escapedArgs)"
                            }
                        }]
                    },
                    "finish_reason": "stop"
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let result = try await service.extractEntries(
            from: "I need to buy groceries and my meeting got moved to Thursday",
            conversation: LLMConversation()
        )
        let entries = result.entries

        #expect(entries.count == 2)

        #expect(entries[0].content == "Buy groceries")
        #expect(entries[0].category == .todo)
        #expect(entries[0].sourceText == "I need to buy groceries")
        #expect(entries[0].summary == "Get groceries")
        #expect(entries[0].priority == 3)
        #expect(entries[0].dueDateDescription == nil)

        #expect(entries[1].content == "Meeting moved to Thursday")
        #expect(entries[1].category == .reminder)
        #expect(entries[1].sourceText == "my meeting got moved to Thursday")
        #expect(entries[1].summary == "Meeting rescheduled")
        #expect(entries[1].priority == nil)
        #expect(entries[1].dueDateDescription == "Thursday")
        #expect(result.usage == .zero)
    }

    @Test("Handles all entry categories")
    func allCategories() async throws {
        let args = """
        {"entries":[\
        {"content":"Do laundry","category":"todo","source_text":"do laundry"},\
        {"content":"Wifi password is abc123","category":"note","source_text":"wifi password"},\
        {"content":"Dentist on Friday","category":"reminder","source_text":"dentist friday"},\
        {"content":"App for tracking plants","category":"idea","source_text":"app for plants"},\
        {"content":"Eggs, bread, butter","category":"list","source_text":"eggs bread butter"},\
        {"content":"Meditate every morning","category":"habit","source_text":"meditate morning"},\
        {"content":"Capital of Portugal?","category":"question","source_text":"capital portugal"},\
        {"content":"Feeling more productive","category":"thought","source_text":"feeling productive"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedArgs = args.replacingOccurrences(of: "\"", with: "\\\"")
        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "tool_calls": [{
                            "function": {
                                "name": "extract_entries",
                                "arguments": "\(escapedArgs)"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let result = try await service.extractEntries(from: "test", conversation: LLMConversation())
        let entries = result.entries

        #expect(entries.count == 8)
        #expect(entries[0].category == .todo)
        #expect(entries[1].category == .note)
        #expect(entries[2].category == .reminder)
        #expect(entries[3].category == .idea)
        #expect(entries[4].category == .list)
        #expect(entries[5].category == .habit)
        #expect(entries[6].category == .question)
        #expect(entries[7].category == .thought)
    }

    @Test("Missing optional fields default gracefully")
    func missingOptionalFields() async throws {
        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "tool_calls": [{
                            "function": {
                                "name": "extract_entries",
                                "arguments": "{\\"entries\\":[{\\"content\\":\\"Buy milk\\",\\"category\\":\\"todo\\",\\"source_text\\":\\"buy milk\\"}]}"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let result = try await service.extractEntries(from: "buy milk", conversation: LLMConversation())
        let entries = result.entries

        #expect(entries.count == 1)
        #expect(entries[0].content == "Buy milk")
        #expect(entries[0].category == .todo)
        #expect(entries[0].summary == "")
        #expect(entries[0].priority == nil)
        #expect(entries[0].dueDateDescription == nil)
    }

    @Test("Throws on HTTP error")
    func httpError() async throws {
        let (service, _) = makeService(
            responseBody: "{\"error\": \"unauthorized\"}",
            statusCode: 401
        )

        await #expect(throws: PPQError.self) {
            try await service.extractEntries(from: "test", conversation: LLMConversation())
        }
    }

    @Test("Throws on missing tool calls")
    func noToolCalls() async throws {
        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "role": "assistant",
                        "content": "I extracted some entries."
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)

        await #expect(throws: PPQError.self) {
            try await service.extractEntries(from: "test", conversation: LLMConversation())
        }
    }

    @Test("Multi-turn conversation accumulates message history")
    func conversationAccumulation() async throws {
        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [{
                            "id": "call_1",
                            "type": "function",
                            "function": {
                                "name": "extract_entries",
                                "arguments": "{\\"entries\\":[{\\"content\\":\\"Buy milk\\",\\"category\\":\\"todo\\",\\"source_text\\":\\"buy milk\\"}]}"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, delegate) = makeService(responseBody: responseJSON, statusCode: 200)
        let conversation = LLMConversation()

        // First call — should send [system, user]
        _ = try await service.extractEntries(from: "buy milk", conversation: conversation)

        let body1 = try #require(delegate.lastRequestBody)
        let json1 = try #require(JSONSerialization.jsonObject(with: body1) as? [String: Any])
        let messages1 = try #require(json1["messages"] as? [[String: Any]])
        #expect(messages1.count == 2)
        #expect(messages1[0]["role"] as? String == "system")
        #expect(messages1[1]["role"] as? String == "user")
        #expect(messages1[1]["content"] as? String == "buy milk")

        // Conversation should now have: system, user, assistant, tool
        #expect(conversation.messages.count == 4)
        #expect(conversation.messages[2]["role"] as? String == "assistant")
        #expect(conversation.messages[3]["role"] as? String == "tool")

        // Second call — should send accumulated history + new user message
        _ = try await service.extractEntries(from: "change to eggs", conversation: conversation)

        let body2 = try #require(delegate.lastRequestBody)
        let json2 = try #require(JSONSerialization.jsonObject(with: body2) as? [String: Any])
        let messages2 = try #require(json2["messages"] as? [[String: Any]])
        #expect(messages2.count == 5) // system, user, assistant, tool, user
        #expect(messages2[0]["role"] as? String == "system")
        #expect(messages2[1]["role"] as? String == "user")
        #expect(messages2[1]["content"] as? String == "buy milk")
        #expect(messages2[2]["role"] as? String == "assistant")
        #expect(messages2[3]["role"] as? String == "tool")
        #expect(messages2[4]["role"] as? String == "user")
        #expect(messages2[4]["content"] as? String == "change to eggs")
    }

    @Test("Sends correct request structure")
    func requestStructure() async throws {
        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "tool_calls": [{
                            "function": {
                                "name": "extract_entries",
                                "arguments": "{\\"entries\\":[]}"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, delegate) = makeService(responseBody: responseJSON, statusCode: 200)
        _ = try await service.extractEntries(from: "Buy milk", conversation: LLMConversation())

        // Verify request was sent correctly
        let request = try #require(delegate.lastRequest)
        #expect(request.url?.absoluteString == "https://api.ppq.ai/chat/completions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        // Verify request body contains expected fields
        let body = try #require(delegate.lastRequestBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["model"] as? String == "anthropic/claude-sonnet-4.6")

        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
        #expect(messages[0]["role"] as? String == "system")
        #expect(messages[1]["role"] as? String == "user")
        #expect(messages[1]["content"] as? String == "Buy milk")

        // Verify tools are present
        let tools = try #require(json["tools"] as? [[String: Any]])
        #expect(tools.count == 1)
        let function = (tools[0]["function"] as? [String: Any])
        #expect(function?["name"] as? String == "extract_entries")
    }

    // MARK: - Helpers

    private func makeService(
        responseBody: String,
        statusCode: Int
    ) -> (PPQLLMService, MockURLProtocolDelegate) {
        let delegate = MockURLProtocolDelegate(
            responseBody: responseBody.data(using: .utf8)!,
            statusCode: statusCode
        )
        MockURLProtocol.delegate = delegate

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        let service = PPQLLMService(apiKey: "test-key", session: session)
        return (service, delegate)
    }
}

// MARK: - Mock URL Protocol

final class MockURLProtocolDelegate: @unchecked Sendable {
    let responseBody: Data
    let statusCode: Int
    var lastRequest: URLRequest?
    var lastRequestBody: Data?

    init(responseBody: Data, statusCode: Int) {
        self.responseBody = responseBody
        self.statusCode = statusCode
    }
}

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var delegate: MockURLProtocolDelegate?

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let delegate = Self.delegate else { return }
        delegate.lastRequest = request

        // Capture body from stream (URLSession converts httpBody to stream)
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 4096)
                if read > 0 {
                    data.append(buffer, count: read)
                } else {
                    break
                }
            }
            stream.close()
            delegate.lastRequestBody = data
        } else {
            delegate.lastRequestBody = request.httpBody
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: delegate.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: delegate.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
