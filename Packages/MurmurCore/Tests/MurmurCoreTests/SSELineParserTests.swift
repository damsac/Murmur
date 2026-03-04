import Foundation
import Testing
@testable import MurmurCore

@Suite("SSELineParser")
struct SSELineParserTests {
    @Test("Parses valid JSON data line")
    func validDataLine() {
        let line = #"data: {"id":"chatcmpl-123","choices":[{"delta":{"content":"Hello"}}]}"#
        let event = SSELineParser.parse(line: line)

        guard case .data(let json) = event else {
            Issue.record("Expected .data event")
            return
        }
        #expect(json["id"] as? String == "chatcmpl-123")
    }

    @Test("Parses [DONE] sentinel")
    func doneSentinel() {
        let event = SSELineParser.parse(line: "data: [DONE]")
        guard case .done = event else {
            Issue.record("Expected .done event")
            return
        }
    }

    @Test("Skips empty lines")
    func emptyLine() {
        #expect(SSELineParser.parse(line: "") == nil)
        #expect(SSELineParser.parse(line: "   ") == nil)
    }

    @Test("Skips SSE comment lines")
    func commentLine() {
        #expect(SSELineParser.parse(line: ": keep-alive") == nil)
    }

    @Test("Skips lines without data: prefix")
    func nonDataLine() {
        #expect(SSELineParser.parse(line: "event: message") == nil)
        #expect(SSELineParser.parse(line: "id: 123") == nil)
    }

    @Test("Returns nil for malformed JSON")
    func malformedJSON() {
        #expect(SSELineParser.parse(line: "data: {not valid json}") == nil)
    }

    @Test("Handles data: without space")
    func dataNoSpace() {
        let line = #"data:{"choices":[{"delta":{"content":"Hi"}}]}"#
        let event = SSELineParser.parse(line: line)

        guard case .data(let json) = event else {
            Issue.record("Expected .data event")
            return
        }
        let choices = json["choices"] as? [[String: Any]]
        #expect(choices != nil)
    }

    @Test("[DONE] with extra whitespace")
    func doneWithWhitespace() {
        let event = SSELineParser.parse(line: "data:  [DONE] ")
        guard case .done = event else {
            Issue.record("Expected .done event")
            return
        }
    }
}

// Equatable conformance for testing
extension SSELineParser.Event: Equatable {
    public static func == (lhs: SSELineParser.Event, rhs: SSELineParser.Event) -> Bool {
        switch (lhs, rhs) {
        case (.done, .done): return true
        case (.data, .data): return true  // shallow comparison for nil checks
        default: return false
        }
    }
}
