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

// MARK: - Layout Operation Tests

@Suite("LayoutOperations")
// swiftlint:disable:next type_body_length
struct LayoutOperationTests {

    /// Helper: build a composition with two sections and some entries for testing.
    private func twoSectionComposition() -> HomeComposition {
        HomeComposition(sections: [
            ComposedSection(title: "Urgent", density: .relaxed, items: [
                .entry(ComposedEntry(id: "aaa111", emphasis: .hero, badge: "Overdue")),
                .entry(ComposedEntry(id: "bbb222", emphasis: .standard)),
            ]),
            ComposedSection(title: "Later", density: .compact, items: [
                .entry(ComposedEntry(id: "ccc333", emphasis: .compact)),
                .message("Keep these in mind."),
            ]),
        ])
    }

    // MARK: - Section Operations

    @Test("add_section appends to end when no position")
    func addSectionAppend() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .addSection(title: "New", density: .relaxed, position: nil),
        ])

        #expect(comp.sections.count == 3)
        #expect(comp.sections[2].title == "New")
        #expect(comp.sections[2].density == .relaxed)
        #expect(comp.sections[2].items.isEmpty)
        #expect(diff.addedSections == ["New"])
    }

    @Test("add_section inserts at position")
    func addSectionAtPosition() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .addSection(title: "Middle", density: .compact, position: 1),
        ])

        #expect(comp.sections.count == 3)
        #expect(comp.sections[0].title == "Urgent")
        #expect(comp.sections[1].title == "Middle")
        #expect(comp.sections[2].title == "Later")
        #expect(diff.addedSections == ["Middle"])
    }

    @Test("remove_section removes section and reports removed entries")
    func removeSection() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .removeSection(title: "Urgent"),
        ])

        #expect(comp.sections.count == 1)
        #expect(comp.sections[0].title == "Later")
        #expect(diff.removedSections == ["Urgent"])
        // Should report the 2 entries that were in the removed section
        #expect(diff.removedEntries.count == 2)
        #expect(diff.removedEntries.contains("aaa111"))
        #expect(diff.removedEntries.contains("bbb222"))
    }

    @Test("remove_section is no-op for unknown title")
    func removeSectionUnknown() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .removeSection(title: "Nonexistent"),
        ])

        #expect(comp.sections.count == 2)
        #expect(diff.isEmpty)
    }

    @Test("update_section changes density")
    func updateSectionDensity() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .updateSection(title: "Urgent", density: .compact, newTitle: nil),
        ])

        #expect(comp.sections[0].density == .compact)
        #expect(comp.sections[0].title == "Urgent")
        #expect(diff.updatedSections == ["Urgent"])
    }

    @Test("update_section renames title")
    func updateSectionRename() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .updateSection(title: "Urgent", density: nil, newTitle: "Critical"),
        ])

        #expect(comp.sections[0].title == "Critical")
        #expect(comp.sections[0].density == .relaxed) // unchanged
        #expect(diff.updatedSections == ["Critical"])
    }

    // MARK: - Entry Operations

    @Test("insert_entry appends when no position")
    func insertEntryAppend() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .insertEntry(entryID: "ddd444", section: "Urgent", position: nil,
                         emphasis: .standard, badge: "New"),
        ])

        #expect(comp.sections[0].items.count == 3)
        if case .entry(let e) = comp.sections[0].items[2] {
            #expect(e.id == "ddd444")
            #expect(e.emphasis == .standard)
            #expect(e.badge == "New")
        } else {
            Issue.record("Expected entry at position 2")
        }
        #expect(diff.insertedEntries.count == 1)
        #expect(diff.insertedEntries[0].id == "ddd444")
        #expect(diff.insertedEntries[0].section == "Urgent")
    }

    @Test("insert_entry at position 0")
    func insertEntryAtZero() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .insertEntry(entryID: "ddd444", section: "Urgent", position: 0,
                         emphasis: .hero, badge: nil),
        ])

        #expect(comp.sections[0].items.count == 3)
        if case .entry(let e) = comp.sections[0].items[0] {
            #expect(e.id == "ddd444")
        } else {
            Issue.record("Expected new entry at position 0")
        }
        #expect(diff.insertedEntries.count == 1)
    }

    @Test("insert_entry into nonexistent section is silent no-op")
    func insertEntryBadSection() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .insertEntry(entryID: "ddd444", section: "Nonexistent", position: nil,
                         emphasis: .standard, badge: nil),
        ])

        // Total items unchanged
        let totalItems = comp.sections.flatMap(\.items).count
        #expect(totalItems == 4) // original count
        #expect(diff.isEmpty)
    }

    @Test("remove_entry removes from any section")
    func removeEntry() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .removeEntry(entryID: "ccc333"),
        ])

        // ccc333 was in "Later" section
        #expect(comp.sections[1].items.count == 1) // message remains
        #expect(diff.removedEntries == ["ccc333"])
    }

    @Test("remove_entry is no-op for unknown entry")
    func removeEntryUnknown() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .removeEntry(entryID: "zzz999"),
        ])

        let totalItems = comp.sections.flatMap(\.items).count
        #expect(totalItems == 4)
        #expect(diff.isEmpty)
    }

    @Test("move_entry between sections")
    func moveEntry() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .moveEntry(entryID: "aaa111", toSection: "Later", toPosition: nil),
        ])

        // Removed from Urgent
        #expect(comp.sections[0].items.count == 1)
        // Added to Later (at end, after message)
        #expect(comp.sections[1].items.count == 3)
        if case .entry(let e) = comp.sections[1].items[2] {
            #expect(e.id == "aaa111")
        } else {
            Issue.record("Expected moved entry at end of Later")
        }
        #expect(diff.movedEntries.count == 1)
        #expect(diff.movedEntries[0].id == "aaa111")
        #expect(diff.movedEntries[0].fromSection == "Urgent")
        #expect(diff.movedEntries[0].toSection == "Later")
    }

    @Test("move_entry to position")
    func moveEntryWithPosition() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .moveEntry(entryID: "aaa111", toSection: "Later", toPosition: 0),
        ])

        if case .entry(let e) = comp.sections[1].items[0] {
            #expect(e.id == "aaa111")
        } else {
            Issue.record("Expected moved entry at position 0")
        }
        #expect(diff.movedEntries.count == 1)
    }

    @Test("update_entry changes emphasis")
    func updateEntryEmphasis() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .updateEntry(entryID: "aaa111", emphasis: .compact, badge: nil),
        ])

        if case .entry(let e) = comp.sections[0].items[0] {
            #expect(e.emphasis == .compact)
            #expect(e.badge == "Overdue") // badge preserved
        } else {
            Issue.record("Expected entry at position 0")
        }
        #expect(diff.updatedEntries == ["aaa111"])
    }

    @Test("update_entry changes badge")
    func updateEntryBadge() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .updateEntry(entryID: "bbb222", emphasis: nil, badge: "Today"),
        ])

        if case .entry(let e) = comp.sections[0].items[1] {
            #expect(e.badge == "Today")
            #expect(e.emphasis == .standard) // emphasis preserved
        } else {
            Issue.record("Expected entry at position 1")
        }
        #expect(diff.updatedEntries == ["bbb222"])
    }

    // MARK: - Batch Operations

    @Test("batch operations applied in order")
    func batchOrder() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .addSection(title: "Tomorrow", density: .relaxed, position: 1),
            .moveEntry(entryID: "bbb222", toSection: "Tomorrow", toPosition: nil),
            .insertEntry(entryID: "eee555", section: "Tomorrow", position: 0,
                         emphasis: .hero, badge: "New"),
        ])

        #expect(comp.sections.count == 3)
        #expect(comp.sections[1].title == "Tomorrow")
        #expect(comp.sections[1].items.count == 2)

        // eee555 inserted at 0, bbb222 moved and appended
        if case .entry(let e) = comp.sections[1].items[0] {
            #expect(e.id == "eee555")
        }
        if case .entry(let e) = comp.sections[1].items[1] {
            #expect(e.id == "bbb222")
        }

        #expect(diff.addedSections.count == 1)
        #expect(diff.movedEntries.count == 1)
        #expect(diff.insertedEntries.count == 1)
    }

    @Test("cold start: add sections + insert entries from empty")
    func coldStartBatch() {
        var comp = HomeComposition(sections: [])
        let diff = comp.apply(operations: [
            .addSection(title: "Needs attention", density: .relaxed, position: nil),
            .addSection(title: "On the radar", density: .compact, position: nil),
            .insertEntry(entryID: "abc123", section: "Needs attention", position: nil,
                         emphasis: .hero, badge: "Overdue"),
            .insertEntry(entryID: "def456", section: "Needs attention", position: nil,
                         emphasis: .standard, badge: "Today"),
            .insertEntry(entryID: "ghi789", section: "On the radar", position: nil,
                         emphasis: .compact, badge: nil),
        ])

        #expect(comp.sections.count == 2)
        #expect(comp.sections[0].items.count == 2)
        #expect(comp.sections[1].items.count == 1)
        #expect(diff.addedSections.count == 2)
        #expect(diff.insertedEntries.count == 3)
    }

    @Test("LayoutDiff reports all changes correctly")
    func diffAccuracy() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .addSection(title: "New", density: .relaxed, position: nil),
            .removeEntry(entryID: "aaa111"),
            .moveEntry(entryID: "bbb222", toSection: "Later", toPosition: nil),
            .updateEntry(entryID: "ccc333", emphasis: .hero, badge: nil),
            .insertEntry(entryID: "ddd444", section: "New", position: nil,
                         emphasis: .standard, badge: nil),
        ])

        #expect(diff.addedSections == ["New"])
        #expect(diff.removedEntries == ["aaa111"])
        #expect(diff.movedEntries.count == 1)
        #expect(diff.movedEntries[0].id == "bbb222")
        #expect(diff.updatedEntries == ["ccc333"])
        #expect(diff.insertedEntries.count == 1)
        #expect(diff.insertedEntries[0].id == "ddd444")
    }

    // MARK: - Edge Cases

    @Test("position beyond bounds clamps to end")
    func positionClamping() {
        var comp = twoSectionComposition()
        _ = comp.apply(operations: [
            .addSection(title: "Far", density: .relaxed, position: 100),
        ])
        #expect(comp.sections.count == 3)
        #expect(comp.sections[2].title == "Far") // clamped to end

        _ = comp.apply(operations: [
            .insertEntry(entryID: "xxx", section: "Far", position: 999,
                         emphasis: .standard, badge: nil),
        ])
        #expect(comp.sections[2].items.count == 1) // clamped to end
    }

    @Test("section title matching is case-insensitive")
    func caseInsensitiveTitle() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .insertEntry(entryID: "ddd444", section: "URGENT", position: nil,
                         emphasis: .standard, badge: nil),
        ])

        #expect(comp.sections[0].items.count == 3) // matched case-insensitively
        #expect(diff.insertedEntries.count == 1)
    }

    @Test("removing last entry from section leaves section intact")
    func removeLastEntry() {
        var comp = HomeComposition(sections: [
            ComposedSection(title: "Solo", density: .relaxed, items: [
                .entry(ComposedEntry(id: "only1")),
            ]),
        ])
        let diff = comp.apply(operations: [.removeEntry(entryID: "only1")])

        #expect(comp.sections.count == 1) // section still exists
        #expect(comp.sections[0].items.isEmpty)
        #expect(diff.removedEntries == ["only1"])
    }

    @Test("composedAt is updated after apply")
    func composedAtUpdated() {
        let old = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        var comp = HomeComposition(sections: [], composedAt: old)
        #expect(!comp.isFromToday)

        _ = comp.apply(operations: [
            .addSection(title: "New", density: .relaxed, position: nil),
        ])
        #expect(comp.isFromToday)
    }

    @Test("move entry to nonexistent section is no-op — entry preserved")
    func moveEntryBadTarget() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .moveEntry(entryID: "aaa111", toSection: "Nonexistent", toPosition: nil),
        ])

        // Entry must still be in Urgent
        if case .entry(let e) = comp.sections[0].items[0] {
            #expect(e.id == "aaa111")
        } else {
            Issue.record("Entry aaa111 should still be at original position")
        }
        #expect(diff.isEmpty) // no-op
    }

    @Test("rename section then insert into new name works")
    func renameThenInsert() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .updateSection(title: "Urgent", density: nil, newTitle: "Critical"),
            .insertEntry(entryID: "ddd444", section: "Critical", position: nil,
                         emphasis: .standard, badge: nil),
        ])

        #expect(comp.sections[0].title == "Critical")
        #expect(comp.sections[0].items.count == 3) // 2 original + 1 new
        #expect(diff.insertedEntries.count == 1)
    }

    @Test("add section with duplicate title creates second section")
    func duplicateSectionTitle() {
        var comp = twoSectionComposition()
        _ = comp.apply(operations: [
            .addSection(title: "Urgent", density: .compact, position: nil),
        ])

        #expect(comp.sections.count == 3)
        // findSection returns first match, so the original is still targetable
        #expect(comp.sections[0].title == "Urgent")
        #expect(comp.sections[2].title == "Urgent")
    }

    @Test("insert entry that already exists in another section duplicates it")
    func duplicateEntryID() {
        var comp = twoSectionComposition()
        _ = comp.apply(operations: [
            .insertEntry(entryID: "aaa111", section: "Later", position: nil,
                         emphasis: .compact, badge: nil),
        ])

        // aaa111 now in both sections
        let allEntryIDs = comp.sections.flatMap(\.items).compactMap { item -> String? in
            if case .entry(let e) = item { return e.id }
            return nil
        }
        #expect(allEntryIDs.filter { $0 == "aaa111" }.count == 2)
    }

    @Test("remove section that was just added in same batch")
    func addThenRemoveSection() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .addSection(title: "Temp", density: .relaxed, position: nil),
            .insertEntry(entryID: "temp1", section: "Temp", position: nil,
                         emphasis: .standard, badge: nil),
            .removeSection(title: "Temp"),
        ])

        #expect(comp.sections.count == 2) // back to original count
        #expect(diff.addedSections == ["Temp"])
        #expect(diff.removedSections == ["Temp"])
        #expect(diff.insertedEntries.count == 1)
        #expect(diff.removedEntries.contains("temp1"))
    }

    @Test("empty operations array returns empty diff")
    func emptyOperations() {
        let before = Date()
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [])

        #expect(diff.isEmpty)
        #expect(comp.sections.count == 2) // unchanged
        // composedAt still updated (timestamped on every apply)
        #expect(comp.composedAt >= before)
    }

    @Test("update_entry with both emphasis and badge")
    func updateEntryBoth() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .updateEntry(entryID: "aaa111", emphasis: .standard, badge: "Today"),
        ])

        if case .entry(let e) = comp.sections[0].items[0] {
            #expect(e.emphasis == .standard)
            #expect(e.badge == "Today")
        }
        #expect(diff.updatedEntries == ["aaa111"])
    }

    @Test("update_entry for unknown entry is no-op")
    func updateEntryUnknown() {
        var comp = twoSectionComposition()
        let diff = comp.apply(operations: [
            .updateEntry(entryID: "zzz999", emphasis: .hero, badge: nil),
        ])

        #expect(diff.isEmpty)
    }

    @Test("mutable composition still round-trips through Codable")
    func mutableCompositionCodable() throws {
        var comp = twoSectionComposition()
        _ = comp.apply(operations: [
            .addSection(title: "New", density: .compact, position: nil),
            .insertEntry(entryID: "new1", section: "New", position: nil,
                         emphasis: .hero, badge: "Fresh"),
        ])

        let data = try JSONEncoder().encode(comp)
        let decoded = try JSONDecoder().decode(HomeComposition.self, from: data)

        #expect(decoded.sections.count == 3)
        #expect(decoded.sections[2].title == "New")
        #expect(decoded.sections[2].items.count == 1)
    }
}

// MARK: - CompositionVariant + Unified Fields

@Suite("CompositionVariant")
struct CompositionVariantTests {

    @Test("CompositionVariant Codable round-trip — scanner")
    func variantScannerRoundTrip() throws {
        let variant = CompositionVariant.scanner
        let data = try JSONEncoder().encode(variant)
        let decoded = try JSONDecoder().decode(CompositionVariant.self, from: data)
        #expect(decoded == .scanner)
        #expect(String(data: data, encoding: .utf8) == "\"scanner\"")
    }

    @Test("CompositionVariant Codable round-trip — navigator")
    func variantNavigatorRoundTrip() throws {
        let variant = CompositionVariant.navigator
        let data = try JSONEncoder().encode(variant)
        let decoded = try JSONDecoder().decode(CompositionVariant.self, from: data)
        #expect(decoded == .navigator)
        #expect(String(data: data, encoding: .utf8) == "\"navigator\"")
    }

    @Test("HomeComposition with briefing + variant round-trip")
    func compositionWithBriefingAndVariant() throws {
        let composition = HomeComposition(
            sections: [
                ComposedSection(
                    title: "todo",
                    density: .relaxed,
                    items: [
                        .entry(ComposedEntry(id: "abc123", emphasis: .standard, badge: "Due today")),
                    ]
                ),
            ],
            composedAt: Date(),
            briefing: "You have one thing due today.",
            variant: .navigator
        )

        let data = try JSONEncoder().encode(composition)
        let decoded = try JSONDecoder().decode(HomeComposition.self, from: data)

        #expect(decoded.briefing == "You have one thing due today.")
        #expect(decoded.variant == .navigator)
        #expect(decoded.sections.count == 1)
    }

    @Test("Backward compat — JSON without briefing/variant decodes to nil")
    func backwardCompatMissingFields() throws {
        // Simulate old cached JSON without briefing or variant fields
        let json = Data("""
        {
            "sections": [],
            "composedAt": 0
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(HomeComposition.self, from: json)
        #expect(decoded.briefing == nil)
        #expect(decoded.variant == nil)
        #expect(decoded.sections.isEmpty)
    }

    @Test("Scanner composition has nil briefing")
    func scannerNilBriefing() throws {
        let composition = HomeComposition(
            sections: [],
            composedAt: Date(),
            variant: .scanner
        )

        let data = try JSONEncoder().encode(composition)
        let decoded = try JSONDecoder().decode(HomeComposition.self, from: data)

        #expect(decoded.briefing == nil)
        #expect(decoded.variant == .scanner)
    }

    @Test("Variant comparison is type-safe enum")
    func variantComparison() {
        let scanner = CompositionVariant.scanner
        let navigator = CompositionVariant.navigator

        #expect(scanner != navigator)
        #expect(scanner == .scanner)
        #expect(navigator == .navigator)
    }
}
