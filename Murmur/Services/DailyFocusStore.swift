import Foundation
import MurmurCore

@MainActor
final class DailyFocusStore {
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.fileURL = docs.appendingPathComponent("daily-focus.json")
    }

    func load() -> DailyFocus? {
        guard let data = try? Data(contentsOf: fileURL),
              let focus = try? JSONDecoder().decode(DailyFocus.self, from: data)
        else {
            return nil
        }
        return focus
    }

    func save(_ focus: DailyFocus) throws {
        let data = try JSONEncoder().encode(focus)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
