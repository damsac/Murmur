import Foundation
import MurmurCore

@MainActor
final class HomeCompositionStore {
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("home-composition.json")
    }

    func load(expectedVariant: CompositionVariant? = nil) -> HomeComposition? {
        guard let data = try? Data(contentsOf: fileURL),
              let composition = try? JSONDecoder().decode(HomeComposition.self, from: data)
        else {
            return nil
        }
        // Reject wrong-variant cache (old caches without variant decode as nil — also rejected)
        if let expected = expectedVariant, composition.variant != expected {
            return nil
        }
        return composition
    }

    func save(_ composition: HomeComposition) throws {
        let data = try JSONEncoder().encode(composition)
        try data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
