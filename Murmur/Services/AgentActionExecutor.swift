import Foundation
import SwiftData
import MurmurCore

/// Executes agent actions against SwiftData entries, producing an undoable transaction.
/// Best-effort: each action is independent. Failures are reported but don't block others.
@MainActor
struct AgentActionExecutor {

    struct ExecutionContext {
        let entries: [Entry]
        let transcript: String
        let source: EntrySource
        let modelContext: ModelContext
        let preferences: NotificationPreferences
    }

    struct ExecutionResult {
        let applied: [AppliedAction]
        let failures: [ActionFailure]
        let undo: UndoTransaction
    }

    struct AppliedAction {
        let action: AgentAction
        let entry: Entry
    }

    struct ActionFailure {
        let action: AgentAction
        let reason: String
    }

    /// Execute agent actions against entries in the given context.
    static func execute(actions: [AgentAction], context ctx: ExecutionContext) -> ExecutionResult {
        var applied: [AppliedAction] = []
        var failures: [ActionFailure] = []
        var undoItems: [UndoItem] = []

        // IDs being completed — skip updates targeting the same entry
        let completedIDs = Set(actions.compactMap { action -> String? in
            if case .complete(let a) = action { return a.id }
            return nil
        })

        for action in actions {
            let result = executeOne(action, context: ctx, completedIDs: completedIDs)
            switch result {
            case .applied(let entry, let undo):
                applied.append(AppliedAction(action: action, entry: entry))
                undoItems.append(undo)
            case .skipped:
                break
            case .failed(let reason):
                failures.append(ActionFailure(action: action, reason: reason))
            }
        }

        do { try ctx.modelContext.save() } catch {
            print("Failed to save after agent actions: \(error.localizedDescription)")
        }

        return ExecutionResult(applied: applied, failures: failures, undo: UndoTransaction(items: undoItems))
    }

    // MARK: - Single Action Dispatch

    private enum ActionResult {
        case applied(Entry, UndoItem)
        case skipped
        case failed(String)
    }

    private static func executeOne(
        _ action: AgentAction,
        context ctx: ExecutionContext,
        completedIDs: Set<String>
    ) -> ActionResult {
        switch action {
        case .create(let a):
            return executeCreate(a, context: ctx)
        case .update(let a):
            if completedIDs.contains(a.id) { return .skipped }
            return executeMutation(id: a.id, entries: ctx.entries) { entry in
                let snapshot = FieldSnapshot(entry: entry, fields: a.fields)
                applyFieldUpdates(a.fields, to: entry)
                applyStatusUpdate(a.fields, to: entry, context: ctx)
                return .updated(entryID: entry.id, previousFields: snapshot)
            }
        case .complete(let a):
            return executeMutation(id: a.id, entries: ctx.entries) { entry in
                guard entry.status != .completed else { return nil }
                let prev = entry.status
                entry.perform(.complete, in: ctx.modelContext, preferences: ctx.preferences)
                return .completed(entryID: entry.id, previousStatus: prev)
            }
        case .archive(let a):
            return executeMutation(id: a.id, entries: ctx.entries) { entry in
                guard entry.status != .archived else { return nil }
                let prev = entry.status
                entry.perform(.archive, in: ctx.modelContext, preferences: ctx.preferences)
                return .archived(entryID: entry.id, previousStatus: prev)
            }
        }
    }

    private static func executeCreate(_ action: CreateAction, context ctx: ExecutionContext) -> ActionResult {
        let entry = Entry(
            transcript: ctx.transcript,
            content: action.content,
            category: action.category,
            sourceText: action.sourceText,
            summary: action.summary,
            priority: action.priority,
            dueDateDescription: action.dueDateDescription,
            dueDate: Entry.resolveDate(from: action.dueDateDescription),
            cadenceRawValue: action.cadence?.rawValue,
            source: ctx.source
        )
        ctx.modelContext.insert(entry)
        NotificationService.shared.sync(entry, preferences: ctx.preferences)
        return .applied(entry, .created(entryID: entry.id))
    }

    private static func executeMutation(
        id: String,
        entries: [Entry],
        apply: (Entry) -> UndoItem?
    ) -> ActionResult {
        guard let entry = Entry.resolve(shortID: id, in: entries) else {
            return .failed("Entry \(id) not found")
        }
        guard let undoItem = apply(entry) else {
            return .skipped
        }
        return .applied(entry, undoItem)
    }

    // MARK: - Field Updates

    private static func applyFieldUpdates(_ fields: UpdateFields, to entry: Entry) {
        if let content = fields.content { entry.content = content }
        if let summary = fields.summary { entry.summary = summary }
        if let category = fields.category { entry.category = category }
        if let priority = fields.priority { entry.priority = priority }
        if let cadence = fields.cadence { entry.cadence = cadence }
        if let dueDesc = fields.dueDateDescription {
            entry.dueDateDescription = dueDesc
            entry.dueDate = Entry.resolveDate(from: dueDesc)
        }
        entry.updatedAt = Date()
    }

    private static func applyStatusUpdate(
        _ fields: UpdateFields,
        to entry: Entry,
        context ctx: ExecutionContext
    ) {
        guard let status = fields.status else {
            NotificationService.shared.sync(entry, preferences: ctx.preferences)
            return
        }
        switch status {
        case .snoozed:
            let until = Entry.resolveDate(from: fields.snoozeUntilDescription)
            entry.perform(.snooze(until: until), in: ctx.modelContext, preferences: ctx.preferences)
        case .completed:
            entry.perform(.complete, in: ctx.modelContext, preferences: ctx.preferences)
        case .archived:
            entry.perform(.archive, in: ctx.modelContext, preferences: ctx.preferences)
        case .active:
            entry.status = .active
            entry.snoozeUntil = nil
            NotificationService.shared.sync(entry, preferences: ctx.preferences)
        }
    }
}

// MARK: - Undo Support

struct UndoTransaction {
    let items: [UndoItem]

    var isEmpty: Bool { items.isEmpty }

    /// Reverse all applied actions.
    @MainActor
    func execute(entries: [Entry], context: ModelContext, preferences: NotificationPreferences) {
        for item in items.reversed() {
            item.undo(entries: entries, context: context, preferences: preferences)
        }
        do { try context.save() } catch {
            print("Failed to save undo: \(error.localizedDescription)")
        }
    }
}

enum UndoItem {
    case created(entryID: UUID)
    case updated(entryID: UUID, previousFields: FieldSnapshot)
    case completed(entryID: UUID, previousStatus: EntryStatus)
    case archived(entryID: UUID, previousStatus: EntryStatus)

    @MainActor
    func undo(entries: [Entry], context: ModelContext, preferences: NotificationPreferences) {
        switch self {
        case .created(let entryID):
            if let entry = entries.first(where: { $0.id == entryID }) {
                NotificationService.shared.cancel(entry)
                context.delete(entry)
            }
        case .updated(let entryID, let snapshot):
            if let entry = entries.first(where: { $0.id == entryID }) {
                snapshot.restore(to: entry)
                entry.updatedAt = Date()
                NotificationService.shared.sync(entry, preferences: preferences)
            }
        case .completed(let entryID, let previousStatus):
            if let entry = entries.first(where: { $0.id == entryID }) {
                entry.status = previousStatus
                entry.completedAt = nil
                entry.updatedAt = Date()
                NotificationService.shared.sync(entry, preferences: preferences)
            }
        case .archived(let entryID, let previousStatus):
            if let entry = entries.first(where: { $0.id == entryID }) {
                entry.status = previousStatus
                entry.updatedAt = Date()
                NotificationService.shared.sync(entry, preferences: preferences)
            }
        }
    }
}

/// Captures the pre-mutation state of fields that will be changed.
struct FieldSnapshot {
    let content: String?
    let summary: String?
    let category: EntryCategory?
    let priority: Int?
    let dueDateDescription: String?
    let dueDate: Date?
    let cadence: HabitCadence?
    let status: EntryStatus?
    let snoozeUntil: Date?

    init(entry: Entry, fields: UpdateFields) {
        self.content = fields.content != nil ? entry.content : nil
        self.summary = fields.summary != nil ? entry.summary : nil
        self.category = fields.category != nil ? entry.category : nil
        self.priority = fields.priority != nil ? entry.priority : nil
        self.dueDateDescription = fields.dueDateDescription != nil ? entry.dueDateDescription : nil
        self.dueDate = fields.dueDateDescription != nil ? entry.dueDate : nil
        self.cadence = fields.cadence != nil ? entry.cadence : nil
        self.status = fields.status != nil ? entry.status : nil
        self.snoozeUntil = fields.status != nil ? entry.snoozeUntil : nil
    }

    func restore(to entry: Entry) {
        if let content { entry.content = content }
        if let summary { entry.summary = summary }
        if let category { entry.category = category }
        if let priority { entry.priority = priority }
        if let dueDateDescription { entry.dueDateDescription = dueDateDescription }
        if let dueDate { entry.dueDate = dueDate }
        if let cadence { entry.cadence = cadence }
        if let status {
            entry.status = status
            entry.snoozeUntil = snoozeUntil
        }
    }
}
