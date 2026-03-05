import Foundation
import Testing
@testable import MurmurCore

@Suite("HomeComposition")
struct HomeCompositionTests {
    // MARK: - Round-trip Encoding/Decoding

    @Test("Round-trip encode/decode HomeComposition")
    func roundTripHomeComposition() throws {
        let composition = HomeComposition(
            sections: [
                ComposedSection(
                    title: "Needs attention",
                    density: .relaxed,
                    items: [
                        .entry(ComposedEntry(id: "a3f2c1", emphasis: .hero, badge: "Overdue")),
                        .entry(ComposedEntry(id: "b7e4d2", emphasis: .standard)),
                        .message("Two things need your attention today."),
                    ]
                ),
                ComposedSection(
                    title: "Keep in mind",
                    density: .compact,
                    items: [
                        .entry(ComposedEntry(id: "c9a1b3", emphasis: .compact, badge: "Stale")),
                    ]
                ),
            ],
            composedAt: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(composition)
        let decoded = try JSONDecoder().decode(HomeComposition.self, from: data)

        #expect(decoded.sections.count == 2)

        // First section
        #expect(decoded.sections[0].title == "Needs attention")
        #expect(decoded.sections[0].density == .relaxed)
        #expect(decoded.sections[0].items.count == 3)

        // Second section
        #expect(decoded.sections[1].title == "Keep in mind")
        #expect(decoded.sections[1].density == .compact)
        #expect(decoded.sections[1].items.count == 1)
    }

    // MARK: - ComposedItem Custom Codable

    @Test("Decodes entry item with type discriminator")
    func decodesEntryItem() throws {
        let json = """
        {"type":"entry","id":"a3f2c1","emphasis":"hero","badge":"Overdue"}
        """
        let data = json.data(using: .utf8)!
        let item = try JSONDecoder().decode(ComposedItem.self, from: data)

        if case .entry(let entry) = item {
            #expect(entry.id == "a3f2c1")
            #expect(entry.emphasis == .hero)
            #expect(entry.badge == "Overdue")
        } else {
            Issue.record("Expected entry item")
        }
    }

    @Test("Decodes message item with type discriminator")
    func decodesMessageItem() throws {
        let json = """
        {"type":"message","text":"Quiet morning."}
        """
        let data = json.data(using: .utf8)!
        let item = try JSONDecoder().decode(ComposedItem.self, from: data)

        if case .message(let text) = item {
            #expect(text == "Quiet morning.")
        } else {
            Issue.record("Expected message item")
        }
    }

    @Test("Encodes entry item with type discriminator")
    func encodesEntryItem() throws {
        let item = ComposedItem.entry(ComposedEntry(id: "abc123", emphasis: .standard, badge: "Today"))
        let data = try JSONEncoder().encode(item)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["type"] as? String == "entry")
        #expect(json?["id"] as? String == "abc123")
        #expect(json?["emphasis"] as? String == "standard")
        #expect(json?["badge"] as? String == "Today")
        #expect(json?["text"] == nil)
    }

    @Test("Encodes message item with type discriminator")
    func encodesMessageItem() throws {
        let item = ComposedItem.message("Good morning!")
        let data = try JSONEncoder().encode(item)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["type"] as? String == "message")
        #expect(json?["text"] as? String == "Good morning!")
        #expect(json?["id"] == nil)
    }

    @Test("Round-trip encode/decode ComposedItem entry")
    func roundTripEntryItem() throws {
        let original = ComposedItem.entry(ComposedEntry(id: "x1y2z3", emphasis: .compact, badge: nil))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ComposedItem.self, from: data)

        if case .entry(let entry) = decoded {
            #expect(entry.id == "x1y2z3")
            #expect(entry.emphasis == .compact)
            #expect(entry.badge == nil)
        } else {
            Issue.record("Expected entry item after round-trip")
        }
    }

    @Test("Round-trip encode/decode ComposedItem message")
    func roundTripMessageItem() throws {
        let original = ComposedItem.message("All clear today.")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ComposedItem.self, from: data)

        if case .message(let text) = decoded {
            #expect(text == "All clear today.")
        } else {
            Issue.record("Expected message item after round-trip")
        }
    }

    @Test("Throws on unknown ComposedItem type")
    func unknownItemType() throws {
        let json = """
        {"type":"unknown","data":"something"}
        """
        let data = json.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ComposedItem.self, from: data)
        }
    }

    // MARK: - ComposedSection id exclusion from Codable

    @Test("ComposedSection id is not encoded to JSON")
    func sectionIdNotEncoded() throws {
        let section = ComposedSection(
            title: "Test",
            density: .relaxed,
            items: [.message("Hi")]
        )
        let data = try JSONEncoder().encode(section)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["id"] == nil)
        #expect(json?["title"] as? String == "Test")
        #expect(json?["density"] as? String == "relaxed")
    }

    @Test("ComposedSection gets fresh UUID on decode")
    func sectionFreshIdOnDecode() throws {
        let json = """
        {"title":"Test","density":"compact","items":[{"type":"message","text":"Hi"}]}
        """
        let data = json.data(using: .utf8)!
        let section1 = try JSONDecoder().decode(ComposedSection.self, from: data)
        let section2 = try JSONDecoder().decode(ComposedSection.self, from: data)

        // Each decode should produce a different UUID
        #expect(section1.id != section2.id)
    }

    // MARK: - isFromToday

    @Test("isFromToday returns true for today's composition")
    func isFromTodayTrue() {
        let composition = HomeComposition(sections: [], composedAt: Date())
        #expect(composition.isFromToday)
    }

    @Test("isFromToday returns false for yesterday's composition")
    func isFromTodayFalse() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let composition = HomeComposition(sections: [], composedAt: yesterday)
        #expect(!composition.isFromToday)
    }

    // MARK: - Edge Cases

    @Test("Empty sections array decodes correctly")
    func emptySections() throws {
        let composition = HomeComposition(sections: [], composedAt: Date())
        let data = try JSONEncoder().encode(composition)
        let decoded = try JSONDecoder().decode(HomeComposition.self, from: data)

        #expect(decoded.sections.isEmpty)
    }

    @Test("Section with empty items array decodes correctly")
    func emptyItems() throws {
        let section = ComposedSection(title: "Empty", density: .relaxed, items: [])
        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(ComposedSection.self, from: data)

        #expect(decoded.items.isEmpty)
        #expect(decoded.title == "Empty")
    }

    @Test("Section without title decodes correctly")
    func sectionWithoutTitle() throws {
        let json = """
        {"density":"compact","items":[{"type":"message","text":"Hi"}]}
        """
        let data = json.data(using: .utf8)!
        let section = try JSONDecoder().decode(ComposedSection.self, from: data)

        #expect(section.title == nil)
        #expect(section.density == .compact)
        #expect(section.items.count == 1)
    }

    @Test("Section without density defaults to relaxed")
    func sectionDefaultDensity() throws {
        let json = """
        {"items":[{"type":"message","text":"Hi"}]}
        """
        let data = json.data(using: .utf8)!
        let section = try JSONDecoder().decode(ComposedSection.self, from: data)

        #expect(section.density == .relaxed)
    }

    @Test("Entry without emphasis defaults to standard")
    func entryDefaultEmphasis() throws {
        let json = """
        {"type":"entry","id":"abc123"}
        """
        let data = json.data(using: .utf8)!
        let item = try JSONDecoder().decode(ComposedItem.self, from: data)

        if case .entry(let entry) = item {
            #expect(entry.emphasis == .standard)
            #expect(entry.badge == nil)
        } else {
            Issue.record("Expected entry item")
        }
    }

    @Test("Entry without badge decodes with nil badge")
    func entryWithoutBadge() throws {
        let json = """
        {"type":"entry","id":"abc123","emphasis":"hero"}
        """
        let data = json.data(using: .utf8)!
        let item = try JSONDecoder().decode(ComposedItem.self, from: data)

        if case .entry(let entry) = item {
            #expect(entry.badge == nil)
        } else {
            Issue.record("Expected entry item")
        }
    }

    @Test("ComposedItem Identifiable ids are stable")
    func identifiableIds() {
        let entry = ComposedItem.entry(ComposedEntry(id: "abc123"))
        let message = ComposedItem.message("Hello")

        #expect(entry.id == "entry-abc123")
        #expect(message.id.hasPrefix("msg-"))
    }

    // MARK: - Full JSON from tool call shape

    @Test("Decodes full compose_view tool call output")
    func decodesFullToolOutput() throws {
        let json = """
        {
            "sections": [
                {
                    "title": "Act now",
                    "density": "relaxed",
                    "items": [
                        {"type": "entry", "id": "a1b2c3", "emphasis": "hero", "badge": "Overdue"},
                        {"type": "entry", "id": "d4e5f6", "emphasis": "standard", "badge": "Today"},
                        {"type": "message", "text": "Two items need attention."}
                    ]
                },
                {
                    "title": "Coming up",
                    "density": "compact",
                    "items": [
                        {"type": "entry", "id": "g7h8i9", "emphasis": "compact"},
                        {"type": "entry", "id": "j0k1l2", "emphasis": "compact", "badge": "Stale"}
                    ]
                }
            ]
        }
        """

        // Decode the sections array from the tool output structure
        struct ToolOutput: Decodable {
            let sections: [ComposedSection]
        }

        let data = json.data(using: .utf8)!
        let output = try JSONDecoder().decode(ToolOutput.self, from: data)

        #expect(output.sections.count == 2)

        // First section
        let first = output.sections[0]
        #expect(first.title == "Act now")
        #expect(first.density == .relaxed)
        #expect(first.items.count == 3)

        if case .entry(let entry) = first.items[0] {
            #expect(entry.id == "a1b2c3")
            #expect(entry.emphasis == .hero)
            #expect(entry.badge == "Overdue")
        } else {
            Issue.record("Expected entry item")
        }

        if case .message(let text) = first.items[2] {
            #expect(text == "Two items need attention.")
        } else {
            Issue.record("Expected message item")
        }

        // Second section
        let second = output.sections[1]
        #expect(second.title == "Coming up")
        #expect(second.density == .compact)
        #expect(second.items.count == 2)

        if case .entry(let entry) = second.items[1] {
            #expect(entry.id == "j0k1l2")
            #expect(entry.emphasis == .compact)
            #expect(entry.badge == "Stale")
        } else {
            Issue.record("Expected entry item")
        }
    }
}
