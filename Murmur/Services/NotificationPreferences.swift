import Foundation
import Observation

/// Notification preferences — persisted to UserDefaults, injected via SwiftUI environment.
@Observable
final class NotificationPreferences {
    private enum Keys {
        static let reminders   = "notif.remindersEnabled"
        static let dueSoon     = "notif.dueSoonEnabled"
        static let snoozeWakeUp = "notif.snoozeWakeUpEnabled"
    }

    /// Explicit reminders — ON by default (user explicitly asked for it).
    var remindersEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersEnabled, forKey: Keys.reminders) }
    }

    /// Due-soon notifications for todos — OFF by default (opt-in).
    var dueSoonEnabled: Bool {
        didSet { UserDefaults.standard.set(dueSoonEnabled, forKey: Keys.dueSoon) }
    }

    /// Snooze wake-up notifications — OFF by default (conservative).
    var snoozeWakeUpEnabled: Bool {
        didSet { UserDefaults.standard.set(snoozeWakeUpEnabled, forKey: Keys.snoozeWakeUp) }
    }

    init() {
        let d = UserDefaults.standard
        // remindersEnabled defaults to true on first launch
        if d.object(forKey: Keys.reminders) == nil { d.set(true, forKey: Keys.reminders) }
        self.remindersEnabled    = d.bool(forKey: Keys.reminders)
        self.dueSoonEnabled      = d.bool(forKey: Keys.dueSoon)
        self.snoozeWakeUpEnabled = d.bool(forKey: Keys.snoozeWakeUp)
    }
}
