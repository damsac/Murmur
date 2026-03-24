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
