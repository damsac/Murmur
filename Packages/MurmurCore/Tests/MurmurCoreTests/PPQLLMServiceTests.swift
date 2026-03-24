import Foundation
import Testing
@testable import MurmurCore

@Suite("PPQLLMService", .serialized)
struct PPQLLMServiceTests {
    // MARK: - Agent Process Tests

    @Test("Agent process returns text summary when no tool calls")
    func agentTextOnlyResponse() async throws {
        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "role": "assistant",
                        "content": "I didn't find any actionable items in that."
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let response = try await service.process(
            transcript: "um uh hmm",
            existingEntries: [],
            conversation: LLMConversation()
        )
        #expect(response.actions.isEmpty)
        #expect(response.summary == "I didn't find any actionable items in that.")
    }

    @Test("Parses agent tools into typed update/complete/archive actions")
    func parsesAgentActions() async throws {
        let updateArgs = """
        {"updates":[{"id":"abc123","fields":{"priority":1,"due_date":"Friday","status":"snoozed","snooze_until":"Friday 9am"},"reason":"User moved and snoozed this"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let completeArgs = """
        {"entries":[{"id":"def456","reason":"User said this is done"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)
        let archiveArgs = """
        {"entries":[{"id":"ghi789","reason":"No longer relevant"}]}
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        let escapedUpdate = updateArgs.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedComplete = completeArgs.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedArchive = archiveArgs.replacingOccurrences(of: "\"", with: "\\\"")

        let responseJSON = """
            {
                "choices": [{
                    "message": {
                        "role": "assistant",
                        "content": null,
                        "tool_calls": [
                            {
                                "id": "call_upd",
                                "type": "function",
                                "function": {
                                    "name": "update_entries",
                                    "arguments": "\(escapedUpdate)"
                                }
                            },
                            {
                                "id": "call_comp",
                                "type": "function",
                                "function": {
                                    "name": "complete_entries",
                                    "arguments": "\(escapedComplete)"
                                }
                            },
                            {
                                "id": "call_arch",
                                "type": "function",
                                "function": {
                                    "name": "archive_entries",
                                    "arguments": "\(escapedArchive)"
                                }
                            }
                        ]
                    }
                }]
            }
            """

        let (service, _) = makeService(responseBody: responseJSON, statusCode: 200)
        let response = try await service.process(
            transcript: "Move dentist to Friday, mark groceries done, archive old idea",
            existingEntries: [
                AgentContextEntry(id: "abc123", summary: "Call dentist", category: .reminder),
                AgentContextEntry(id: "def456", summary: "Buy groceries", category: .todo),
                AgentContextEntry(id: "ghi789", summary: "Old app idea", category: .idea),
            ],
            conversation: LLMConversation()
        )

        #expect(response.actions.count == 3)

        if case .update(let action) = response.actions[0] {
            #expect(action.id == "abc123")
            #expect(action.fields.priority == 1)
            #expect(action.fields.dueDateDescription == "Friday")
            #expect(action.fields.status == .snoozed)
            #expect(action.fields.snoozeUntilDescription == "Friday 9am")
            #expect(action.reason == "User moved and snoozed this")
        } else {
            Issue.record("Expected update action")
        }

        if case .complete(let action) = response.actions[1] {
            #expect(action.id == "def456")
            #expect(action.reason == "User said this is done")
        } else {
            Issue.record("Expected complete action")
        }

        if case .archive(let action) = response.actions[2] {
            #expect(action.id == "ghi789")
            #expect(action.reason == "No longer relevant")
        } else {
            Issue.record("Expected archive action")
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
