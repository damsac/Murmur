import Testing
@testable import Murmur

@Suite("EntryCategory")
struct EntryCategoryTests {
    @Test("all cases exist")
    func allCases() {
        #expect(EntryCategory.allCases.count == 8)
    }

    @Test("labels are capitalized")
    func labels() {
        #expect(EntryCategory.todo.rawValue == "todo")
        #expect(EntryCategory.insight.rawValue == "insight")
    }
}

@Suite("Entry defaults")
struct EntryTests {
    @Test("entry can be created")
    func creation() {
        let entry = Entry(
            summary: "Test entry",
            category: .todo
        )
        #expect(entry.summary == "Test entry")
        #expect(entry.category == .todo)
        #expect(entry.status == .active)
    }
}
