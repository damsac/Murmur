import Foundation

@MainActor
final class AgentMemoryStore {
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("agent-memory.txt")
    }

    func load() -> String {
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return text
    }

    func save(_ content: String) throws {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
