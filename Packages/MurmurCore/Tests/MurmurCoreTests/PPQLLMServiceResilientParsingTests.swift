import Foundation
import Testing
@testable import MurmurCore

@Suite("PPQLLMService Resilient Parsing", .serialized)
struct PPQLLMServiceResilientParsingTests {
    @Test("Malformed tool call doesn't kill valid ones — failure captured")
    func malformedToolCallIsolated() async throws {
        let validArgs = """
        {"entries":[{"content":"Buy milk","category":"todo","source_text":"buy milk","summary":"Get milk"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let malformedArgs = """
        {"entries":[{"content":"Bad","category":"todo","source_text":"bad",INVALID JSON}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let escapedValid = validArgs.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedMalformed = malformedArgs.replacingOccurrences(of: "\"", with: "\\\"")

        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [
                            {
                                "id": "call_good",
                                "type": "function",
                                "function": {
                                    "name": "create_entries",
                                    "arguments": "\(escapedValid)"
                                }
                            },
                            {
                                "id": "call_bad",
                                "type": "function",
                                "function": {
                                    "name": "create_entries",
                                    "arguments": "\(escapedMalformed)"
                                }
                            }
                        ]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let response = try await service.process(
            transcript: "buy milk and something bad",
            existingEntries: [],
            conversation: LLMConversation()
        )

        #expect(response.actions.count == 1)
        if case .create(let action) = response.actions[0] {
            #expect(action.content == "Buy milk")
        } else {
            Issue.record("Expected create action")
        }

        #expect(response.parseFailures.count == 1)
        #expect(response.parseFailures[0].toolName == "create_entries")
    }

    @Test("Unknown category decodes as .note")
    func unknownCategoryFallback() async throws {
        let args = """
        {"entries":[{"content":"Something","category":"invented_category","source_text":"something","summary":"Thing"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedArgs = args.replacingOccurrences(of: "\"", with: "\\\"")

        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "tool_calls": [{
                            "function": {
                                "name": "create_entries",
                                "arguments": "\(escapedArgs)"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let result = try await service.extractEntries(from: "something", conversation: LLMConversation())

        #expect(result.entries.count == 1)
        #expect(result.entries[0].category == .note)
    }

    @Test("Priority 0 and 99 get clamped to 1 and 5")
    func priorityClamping() async throws {
        let args = """
        {"entries":[\
        {"content":"Low","category":"todo","source_text":"low","summary":"Low","priority":0},\
        {"content":"High","category":"todo","source_text":"high","summary":"High","priority":99}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedArgs = args.replacingOccurrences(of: "\"", with: "\\\"")

        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "tool_calls": [{
                            "function": {
                                "name": "create_entries",
                                "arguments": "\(escapedArgs)"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let result = try await service.extractEntries(from: "test", conversation: LLMConversation())

        #expect(result.entries.count == 2)
        #expect(result.entries[0].priority == 1)
        #expect(result.entries[1].priority == 5)
    }

    @Test("Unknown cadence becomes nil")
    func unknownCadenceFallback() async throws {
        let args = """
        {"entries":[{"content":"Exercise","category":"habit","source_text":"exercise","summary":"Exercise","cadence":"biweekly"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedArgs = args.replacingOccurrences(of: "\"", with: "\\\"")

        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "tool_calls": [{
                            "function": {
                                "name": "create_entries",
                                "arguments": "\(escapedArgs)"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let result = try await service.extractEntries(from: "exercise", conversation: LLMConversation())

        #expect(result.entries.count == 1)
        #expect(result.entries[0].cadence == nil)
    }

    @Test("Update fields priority clamped and unknown cadence dropped")
    func updateFieldsDefensive() async throws {
        let args = """
        {"updates":[{"id":"abc","fields":{"priority":0,"cadence":"biweekly"},"reason":"test"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let escapedArgs = args.replacingOccurrences(of: "\"", with: "\\\"")

        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "tool_calls": [{
                            "function": {
                                "name": "update_entries",
                                "arguments": "\(escapedArgs)"
                            }
                        }]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let response = try await service.process(
            transcript: "test",
            existingEntries: [AgentContextEntry(id: "abc", summary: "Test", category: .todo)],
            conversation: LLMConversation()
        )

        #expect(response.actions.count == 1)
        if case .update(let action) = response.actions[0] {
            #expect(action.fields.priority == 1)
            #expect(action.fields.cadence == nil)
        } else {
            Issue.record("Expected update action")
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
                                "name": "create_entries",
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
