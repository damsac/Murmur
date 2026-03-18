import Foundation
import Observation

/// Notification preferences — persisted to UserDefaults, injected via SwiftUI environment.
@Observable
final class NotificationPreferences {
    private enum Keys {
        static let reminders          = "notif.remindersEnabled"
        static let remindersLeadTime  = "notif.remindersLeadTime"
        static let dueSoon            = "notif.dueSoonEnabled"
        static let dueSoonLeadTime    = "notif.dueSoonLeadTime"
        static let habits             = "notif.habitsEnabled"
        static let habitHour          = "notif.habitHour"
        static let habitMinute        = "notif.habitMinute"
        static let snoozeWakeUp       = "notif.snoozeWakeUpEnabled"
    }

    // MARK: - Reminders (time-specific, minute-scale lead times)

    /// Explicit reminders — ON by default.
    var remindersEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: Keys.reminders) }
    }

    /// Minutes before due time to fire reminder notification (0 = at due time).
    /// Options: 0, 5, 15, 30
    var remindersLeadTime: Int {
        didSet { UserDefaults.standard.set(remindersLeadTime, forKey: Keys.remindersLeadTime) }
    }

    // MARK: - Due Soon (deadline-scale lead times, hour/day)

    /// Due-soon notifications for todos — OFF by default (opt-in).
    var dueSoonEnabled: Bool {
        didSet { UserDefaults.standard.set(dueSoonEnabled, forKey: Keys.dueSoon) }
    }

    /// Minutes before due time to fire due-soon notification (0 = at due time).
    /// Options: 0, 60 (1 hour), 180 (3 hours), 1440 (1 day)
    var dueSoonLeadTime: Int {
        didSet { UserDefaults.standard.set(dueSoonLeadTime, forKey: Keys.dueSoonLeadTime) }
    }

    // MARK: - Habits (daily nudge at a set time)

    /// Daily habit reminder — OFF by default.
    var habitsEnabled: Bool {
        didSet { UserDefaults.standard.set(habitsEnabled, forKey: Keys.habits) }
    }

    /// Hour (0–23) for the daily habit nudge. Default: 9.
    var habitHour: Int {
        didSet { UserDefaults.standard.set(habitHour, forKey: Keys.habitHour) }
    }

    /// Minute (0–59) for the daily habit nudge. Default: 0.
    var habitMinute: Int {
        didSet { UserDefaults.standard.set(habitMinute, forKey: Keys.habitMinute) }
    }

    // MARK: - Snooze (no config — fires at exact snooze-until time)

    /// Snooze wake-up notifications — OFF by default.
    var snoozeWakeUpEnabled: Bool {
        didSet { UserDefaults.standard.set(snoozeWakeUpEnabled, forKey: Keys.snoozeWakeUp) }
    }

    // MARK: - Init

    init() {
        let d = UserDefaults.standard

        // Migrate old shared lead time key → per-type key (one-time, safe to run on every launch)
        let legacyLeadTimeKey = "notif.reminderLeadTime"
        if d.object(forKey: Keys.remindersLeadTime) == nil,
           let legacyValue = d.object(forKey: legacyLeadTimeKey) as? Int {
            d.set(legacyValue, forKey: Keys.remindersLeadTime)
        }
        d.removeObject(forKey: legacyLeadTimeKey)

        // remindersEnabled defaults to true on first launch
        if d.object(forKey: Keys.reminders) == nil { d.set(true, forKey: Keys.reminders) }
        self.remindersEnabled     = d.bool(forKey: Keys.reminders)
        self.remindersLeadTime    = d.object(forKey: Keys.remindersLeadTime) != nil ? d.integer(forKey: Keys.remindersLeadTime) : 15

        self.dueSoonEnabled       = d.bool(forKey: Keys.dueSoon)
        self.dueSoonLeadTime      = d.object(forKey: Keys.dueSoonLeadTime) != nil ? d.integer(forKey: Keys.dueSoonLeadTime) : 60

        self.habitsEnabled        = d.bool(forKey: Keys.habits)
        self.habitHour            = d.object(forKey: Keys.habitHour) != nil ? d.integer(forKey: Keys.habitHour) : 9
        self.habitMinute          = d.object(forKey: Keys.habitMinute) != nil ? d.integer(forKey: Keys.habitMinute) : 0

        // snoozeWakeUpEnabled defaults to true on first launch — snooze is useless without a wake-up notification
        if d.object(forKey: Keys.snoozeWakeUp) == nil { d.set(true, forKey: Keys.snoozeWakeUp) }
        self.snoozeWakeUpEnabled  = d.bool(forKey: Keys.snoozeWakeUp)
    }
}
