import Foundation
import Testing
@testable import MurmurCore

@Suite("StreamingResponseAccumulator")
struct StreamingResponseAccumulatorTests {

    // MARK: - Text Delta Accumulation

    @Test("Text deltas accumulate and emit")
    func textDeltaAccumulation() {
        let acc = StreamingResponseAccumulator()

        let events1 = acc.feed(chunk: makeTextChunk("Hello"))
        #expect(events1.count == 1)
        if case .textDelta(let text) = events1[0] {
            #expect(text == "Hello")
        } else {
            Issue.record("Expected textDelta")
        }

        let events2 = acc.feed(chunk: makeTextChunk(" world"))
        #expect(events2.count == 1)
        if case .textDelta(let text) = events2[0] {
            #expect(text == " world")
        } else {
            Issue.record("Expected textDelta")
        }

        let response = acc.buildFinalResponse()
        #expect(response.textResponse == "Hello world")
        #expect(response.actions.isEmpty)
    }

    // MARK: - Single Tool Call

    @Test("Single tool call across multiple argument fragments")
    func singleToolCallFragmented() {
        let acc = StreamingResponseAccumulator()

        // First chunk: tool call start with partial arguments
        let chunk1: [String: Any] = [
            "choices": [[
                "delta": [
                    "tool_calls": [[
                        "index": 0,
                        "id": "call_abc",
                        "function": [
                            "name": "create_entries",
                            "arguments": #"{"entries":[{"content":"Buy"#,
                        ],
                    ]],
                ],
            ]],
        ]
        let events1 = acc.feed(chunk: chunk1)
        // Should emit toolCallStarted
        #expect(events1.contains(where: {
            if case .toolCallStarted(let p) = $0 {
                return p.toolName == "create_entries" && p.toolCallID == "call_abc"
            }
            return false
        }))

        // Second chunk: more arguments
        let chunk2: [String: Any] = [
            "choices": [[
                "delta": [
                    "tool_calls": [[
                        "index": 0,
                        "function": [
                            "arguments": #" milk","category":"todo","source_text":"buy milk","summary":"Get milk"}]}"#,
                        ],
                    ]],
                ],
            ]],
        ]
        let events2 = acc.feed(chunk: chunk2)
        // No completion yet (no new index to trigger it)
        #expect(!events2.contains(where: { if case .toolCallCompleted = $0 { return true }; return false }))

        // Finish
        let finalEvents = acc.finish()
        #expect(finalEvents.count == 1)
        if case .toolCallCompleted(let result) = finalEvents[0] {
            #expect(result.toolName == "create_entries")
            #expect(result.actions.count == 1)
            if case .create(let action) = result.actions[0] {
                #expect(action.content == "Buy milk")
            }
        } else {
            Issue.record("Expected toolCallCompleted")
        }

        let response = acc.buildFinalResponse()
        #expect(response.actions.count == 1)
        #expect(response.toolCallGroups.count == 1)
    }

    // MARK: - Multiple Tool Calls

    @Test("Multiple tool calls with boundary detection")
    func multipleToolCalls() {
        let acc = StreamingResponseAccumulator()

        // First tool call
        let chunk1: [String: Any] = [
            "choices": [[
                "delta": [
                    "tool_calls": [[
                        "index": 0,
                        "id": "call_1",
                        "function": [
                            "name": "create_entries",
                            "arguments": #"{"entries":[{"content":"Buy milk","category":"todo","source_text":"buy milk","summary":"Milk"}]}"#,
                        ],
                    ]],
                ],
            ]],
        ]
        let events1 = acc.feed(chunk: chunk1)
        #expect(events1.contains(where: { if case .toolCallStarted = $0 { return true }; return false }))

        // Second tool call — triggers completion of first
        let chunk2: [String: Any] = [
            "choices": [[
                "delta": [
                    "tool_calls": [[
                        "index": 1,
                        "id": "call_2",
                        "function": [
                            "name": "complete_entries",
                            "arguments": #"{"entries":[{"id":"abc","reason":"Done"}]}"#,
                        ],
                    ]],
                ],
            ]],
        ]
        let events2 = acc.feed(chunk: chunk2)
        // Should contain toolCallCompleted for index 0 AND toolCallStarted for index 1
        #expect(events2.contains(where: {
            if case .toolCallCompleted(let r) = $0 { return r.toolCallID == "call_1" }
            return false
        }))
        #expect(events2.contains(where: {
            if case .toolCallStarted(let p) = $0 { return p.toolCallID == "call_2" }
            return false
        }))

        // Finish flushes the last tool call
        let finalEvents = acc.finish()
        #expect(finalEvents.count == 1)
        if case .toolCallCompleted(let result) = finalEvents[0] {
            #expect(result.toolCallID == "call_2")
            #expect(result.toolName == "complete_entries")
        }

        let response = acc.buildFinalResponse()
        #expect(response.actions.count == 2)
        #expect(response.toolCallGroups.count == 2)
    }

    // MARK: - Usage Capture

    @Test("Usage captured from final chunk")
    func usageCapture() {
        let acc = StreamingResponseAccumulator()

        let chunk: [String: Any] = [
            "choices": [[
                "delta": ["content": "Hi"],
            ]],
            "usage": [
                "prompt_tokens": 150,
                "completion_tokens": 42,
            ],
        ]
        _ = acc.feed(chunk: chunk)

        let response = acc.buildFinalResponse()
        #expect(response.usage.inputTokens == 150)
        #expect(response.usage.outputTokens == 42)
    }

    @Test("Missing usage defaults to zero")
    func missingUsage() {
        let acc = StreamingResponseAccumulator()

        _ = acc.feed(chunk: makeTextChunk("test"))
        let response = acc.buildFinalResponse()
        #expect(response.usage == .zero)
    }

    // MARK: - Text-only Response

    @Test("Text-only response sets textResponse")
    func textOnlyResponse() {
        let acc = StreamingResponseAccumulator()

        _ = acc.feed(chunk: makeTextChunk("I can"))
        _ = acc.feed(chunk: makeTextChunk("'t help with that."))
        _ = acc.finish()

        let response = acc.buildFinalResponse()
        #expect(response.textResponse == "I can't help with that.")
        #expect(response.actions.isEmpty)
    }

    @Test("Mixed text + tools does not set textResponse")
    func mixedTextAndTools() {
        let acc = StreamingResponseAccumulator()

        _ = acc.feed(chunk: makeTextChunk("Added a reminder."))
        _ = acc.feed(chunk: [
            "choices": [[
                "delta": [
                    "tool_calls": [[
                        "index": 0,
                        "id": "call_1",
                        "function": [
                            "name": "create_entries",
                            "arguments": #"{"entries":[{"content":"Dentist","category":"reminder","source_text":"dentist","summary":"Dentist"}]}"#,
                        ],
                    ]],
                ],
            ]],
        ])
        _ = acc.finish()

        let response = acc.buildFinalResponse()
        #expect(response.textResponse == nil)
        #expect(response.actions.count == 1)
    }

    // MARK: - Parse Failure

    @Test("Malformed tool call arguments emit toolCallFailed")
    func malformedToolCall() {
        let acc = StreamingResponseAccumulator()

        _ = acc.feed(chunk: [
            "choices": [[
                "delta": [
                    "tool_calls": [[
                        "index": 0,
                        "id": "call_bad",
                        "function": [
                            "name": "create_entries",
                            "arguments": "{invalid json}",
                        ],
                    ]],
                ],
            ]],
        ])

        let events = acc.finish()
        #expect(events.contains(where: { if case .toolCallFailed = $0 { return true }; return false }))

        let response = acc.buildFinalResponse()
        #expect(response.parseFailures.count == 1)
        #expect(response.parseFailures[0].toolName == "create_entries")
    }

    // MARK: - Assembled Message

    @Test("Assembled message reconstructs full assistant message")
    func assembledMessage() {
        let acc = StreamingResponseAccumulator()

        _ = acc.feed(chunk: makeTextChunk("Done."))
        _ = acc.feed(chunk: [
            "choices": [[
                "delta": [
                    "tool_calls": [[
                        "index": 0,
                        "id": "call_1",
                        "function": [
                            "name": "create_entries",
                            "arguments": #"{"entries":[]}"#,
                        ],
                    ]],
                ],
            ]],
        ])
        _ = acc.finish()

        let message = acc.assembledMessage()
        #expect(message["role"] as? String == "assistant")
        #expect(message["content"] as? String == "Done.")

        let toolCalls = message["tool_calls"] as? [[String: Any]]
        #expect(toolCalls?.count == 1)
        #expect(toolCalls?[0]["id"] as? String == "call_1")
    }

    // MARK: - Empty Chunks

    @Test("Empty choices array is handled gracefully")
    func emptyChoices() {
        let acc = StreamingResponseAccumulator()
        let events = acc.feed(chunk: ["choices": [] as [[String: Any]]])
        #expect(events.isEmpty)
    }

    @Test("Chunk without choices is handled gracefully")
    func noChoices() {
        let acc = StreamingResponseAccumulator()
        let events = acc.feed(chunk: ["id": "chatcmpl-123"])
        #expect(events.isEmpty)
    }

    // MARK: - Helpers

    private func makeTextChunk(_ text: String) -> [String: Any] {
        [
            "choices": [[
                "delta": ["content": text],
            ]],
        ]
    }
}
