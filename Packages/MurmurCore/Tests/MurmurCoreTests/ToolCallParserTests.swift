import Foundation
import Testing
@testable import MurmurCore

@Suite("ToolCallParser")
struct ToolCallParserTests {
    @Test("Parses create_entries")
    func parseCreate() {
        let args = #"{"entries":[{"content":"Buy milk","category":"todo","source_text":"buy milk","summary":"Milk"}]}"#
        let result = ToolCallParser.parse(name: "create_entries", arguments: args, toolCallID: "call_1")

        #expect(result.failure == nil)
        #expect(result.actions.count == 1)
        if case .create(let action) = result.actions[0] {
            #expect(action.content == "Buy milk")
            #expect(action.category == .todo)
        } else {
            Issue.record("Expected create action")
        }
    }

    @Test("Parses update_entries")
    func parseUpdate() {
        let args = #"{"updates":[{"id":"abc","fields":{"priority":2},"reason":"User asked"}]}"#
        let result = ToolCallParser.parse(name: "update_entries", arguments: args, toolCallID: "call_2")

        #expect(result.failure == nil)
        #expect(result.actions.count == 1)
        if case .update(let action) = result.actions[0] {
            #expect(action.id == "abc")
            #expect(action.fields.priority == 2)
        } else {
            Issue.record("Expected update action")
        }
    }

    @Test("Parses complete_entries")
    func parseComplete() {
        let args = #"{"entries":[{"id":"def","reason":"Done"}]}"#
        let result = ToolCallParser.parse(name: "complete_entries", arguments: args, toolCallID: "call_3")

        #expect(result.failure == nil)
        #expect(result.actions.count == 1)
        if case .complete(let action) = result.actions[0] {
            #expect(action.id == "def")
            #expect(action.reason == "Done")
        } else {
            Issue.record("Expected complete action")
        }
    }

    @Test("Parses archive_entries")
    func parseArchive() {
        let args = #"{"entries":[{"id":"ghi","reason":"Old"}]}"#
        let result = ToolCallParser.parse(name: "archive_entries", arguments: args, toolCallID: "call_4")

        #expect(result.failure == nil)
        #expect(result.actions.count == 1)
        if case .archive(let action) = result.actions[0] {
            #expect(action.id == "ghi")
        } else {
            Issue.record("Expected archive action")
        }
    }

    @Test("Parses update_memory")
    func parseUpdateMemory() {
        let args = #"{"content":"User likes brief responses."}"#
        let result = ToolCallParser.parse(name: "update_memory", arguments: args, toolCallID: "call_5")

        #expect(result.failure == nil)
        #expect(result.actions.count == 1)
        if case .updateMemory(let action) = result.actions[0] {
            #expect(action.content == "User likes brief responses.")
        } else {
            Issue.record("Expected updateMemory action")
        }
    }

    @Test("Unknown tool name returns empty result")
    func unknownTool() {
        let result = ToolCallParser.parse(name: "unknown_tool", arguments: "{}", toolCallID: "call_x")
        #expect(result.actions.isEmpty)
        #expect(result.failure == nil)
    }

    @Test("Invalid JSON returns parse failure")
    func invalidJSON() {
        let result = ToolCallParser.parse(name: "create_entries", arguments: "{bad json}", toolCallID: "call_bad")
        #expect(result.actions.isEmpty)
        #expect(result.failure != nil)
        #expect(result.failure?.toolName == "create_entries")
        #expect(result.failure?.toolCallID == "call_bad")
    }

    @Test("Multiple entries in one create_entries call")
    func multipleEntries() {
        let args = #"{"entries":[{"content":"A","category":"todo","source_text":"a","summary":"A"},{"content":"B","category":"note","source_text":"b","summary":"B"}]}"#
        let result = ToolCallParser.parse(name: "create_entries", arguments: args, toolCallID: "call_multi")

        #expect(result.actions.count == 2)
        if case .create(let a1) = result.actions[0], case .create(let a2) = result.actions[1] {
            #expect(a1.content == "A")
            #expect(a2.content == "B")
        } else {
            Issue.record("Expected two create actions")
        }
    }

    @Test("Parses confirm_actions with proposed actions")
    func parseConfirm() {
        let args = #"{"message":"Which one?","actions":[{"tool":"complete_entries","arguments":{"entries":[{"id":"x","reason":"done"}]}}]}"#
        let result = ToolCallParser.parse(name: "confirm_actions", arguments: args, toolCallID: "call_confirm")

        #expect(result.failure == nil)
        #expect(result.actions.count == 1)
        if case .confirm(let request) = result.actions[0] {
            #expect(request.message == "Which one?")
            #expect(request.proposedActions.count == 1)
        } else {
            Issue.record("Expected confirm action")
        }
    }
}
