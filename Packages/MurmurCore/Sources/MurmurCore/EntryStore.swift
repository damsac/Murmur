import Foundation
import SwiftData

/// Storage service for managing Entry persistence with SwiftData
@MainActor
public final class EntryStore {
    private let modelContainer: ModelContainer?
    private let modelContext: ModelContext

    /// Primary initializer — accepts an externally-owned ModelContext (e.g. from SwiftUI app)
    public init(context: ModelContext) {
        self.modelContainer = nil
        self.modelContext = context
    }

    /// Convenience initializer — creates its own container (tests / standalone usage)
    public init(inMemory: Bool = false) throws {
        let schema = Schema([Entry.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        self.modelContainer = container
        self.modelContext = ModelContext(container)
    }

    /// Save a new entry
    public func save(_ entry: Entry) throws {
        modelContext.insert(entry)
        try modelContext.save()
    }

    /// Save multiple entries at once
    public func save(_ entries: [Entry]) throws {
        for entry in entries {
            modelContext.insert(entry)
        }
        try modelContext.save()
    }

    /// Fetch all entries, sorted by creation date (newest first)
    public func fetchAll() throws -> [Entry] {
        let descriptor = FetchDescriptor<Entry>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch entries by category
    public func fetch(category: EntryCategory) throws -> [Entry] {
        let rawValue = category.rawValue
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.categoryRawValue == rawValue },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch entries by status
    public func fetch(status: EntryStatus) throws -> [Entry] {
        let rawValue = status.rawValue
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.statusRawValue == rawValue },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetch entries by source
    public func fetch(source: EntrySource) throws -> [Entry] {
        let rawValue = source.rawValue
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.sourceRawValue == rawValue },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Update an entry's status
    public func updateStatus(_ entry: Entry, to status: EntryStatus) throws {
        entry.status = status
        entry.updatedAt = Date()
        if status == .completed {
            entry.completedAt = Date()
        }
        try modelContext.save()
    }

    /// Delete an entry
    public func delete(_ entry: Entry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }

    /// Delete all entries
    public func deleteAll() throws {
        try modelContext.delete(model: Entry.self)
        try modelContext.save()
    }

    /// Count total entries
    public func count() throws -> Int {
        let descriptor = FetchDescriptor<Entry>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Count entries by category
    public func count(category: EntryCategory) throws -> Int {
        let rawValue = category.rawValue
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.categoryRawValue == rawValue }
        )
        return try modelContext.fetchCount(descriptor)
    }

    /// Count entries by status
    public func count(status: EntryStatus) throws -> Int {
        let rawValue = status.rawValue
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.statusRawValue == rawValue }
        )
        return try modelContext.fetchCount(descriptor)
    }

    /// Count entries by source
    public func count(source: EntrySource) throws -> Int {
        let rawValue = source.rawValue
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate<Entry> { $0.sourceRawValue == rawValue }
        )
        return try modelContext.fetchCount(descriptor)
    }
}
