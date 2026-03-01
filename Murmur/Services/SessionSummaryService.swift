import Foundation
import SwiftData

/// Computed summary of entry state at app open. No LLM call — pure SwiftData query.
struct SessionSummary {
    let dueToday: Int
    let overdue: Int
    let completedSinceLastOpen: Int
    let expiredSnoozes: Int

    var isEmpty: Bool {
        dueToday == 0 && overdue == 0 && completedSinceLastOpen == 0 && expiredSnoozes == 0
    }
}

enum SessionSummaryService {
    private static let lastOpenKey = "SessionSummaryService.lastOpenDate"

    /// Record the current timestamp as the last app open.
    static func recordAppOpen() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastOpenKey)
    }

    /// The last recorded app open date, or nil if never recorded.
    static var lastOpenDate: Date? {
        let value = UserDefaults.standard.double(forKey: lastOpenKey)
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    /// Compute a session summary from the given entries.
    static func compute(entries: [Entry], now: Date = Date()) -> SessionSummary {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        var dueToday = 0
        var overdue = 0
        var completedSinceLastOpen = 0
        var expiredSnoozes = 0

        let lastOpen = lastOpenDate

        for entry in entries {
            // Due today: active entries with dueDate within today
            if let due = entry.dueDate, entry.status == .active {
                if due < startOfToday {
                    overdue += 1
                } else if due < endOfToday {
                    dueToday += 1
                }
            }

            // Completed since last open
            if entry.status == .completed, let completedAt = entry.completedAt, let lastOpen {
                if completedAt > lastOpen {
                    completedSinceLastOpen += 1
                }
            }

            // Expired snoozes: snoozed entries whose snoozeUntil has passed
            if entry.status == .snoozed, let snoozeUntil = entry.snoozeUntil {
                if snoozeUntil <= now {
                    expiredSnoozes += 1
                }
            }
        }

        return SessionSummary(
            dueToday: dueToday,
            overdue: overdue,
            completedSinceLastOpen: completedSinceLastOpen,
            expiredSnoozes: expiredSnoozes
        )
    }
}
