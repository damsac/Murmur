import UserNotifications
import Foundation
import os.log

private let notifLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "murmur", category: "Notifications")

/// Central service for scheduling, rescheduling, and canceling entry-triggered notifications.
/// Pure logic — no SwiftData dependency, no UI coupling.
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var hasRequestedPermission = false

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            notifLog.error("Notification permission error: \(error.localizedDescription)")
        }
    }

    /// Request permission only if the user hasn't been asked yet.
    /// Safe to call repeatedly — the flag prevents duplicate prompts from rapid syncs.
    func requestPermissionIfNeeded() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true
        Task {
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else { return }
            await requestPermission()
        }
    }

    // MARK: - Sync

    /// Evaluate an entry's state and atomically cancel/reschedule all notification slots.
    /// Safe to call on every save — idempotent.
    /// Lazily requests notification permission the first time a notification-eligible entry is synced.
    func sync(_ entry: Entry, preferences: NotificationPreferences) {
        let isNotificationEligible =
            entry.category == .reminder ||
            (entry.category == .todo && preferences.dueSoonEnabled) ||
            (entry.category == .habit && preferences.habitsEnabled) ||
            entry.status == .snoozed
        if isNotificationEligible {
            requestPermissionIfNeeded()
        }
        syncReminder(entry, preferences: preferences)
        syncDueSoon(entry, preferences: preferences)
        syncSnoozeWakeUp(entry, preferences: preferences)
        // Habit daily reminders are scheduled globally — see scheduleHabitReminder / cancelHabitReminder
    }

    private func syncReminder(_ entry: Entry, preferences: NotificationPreferences) {
        let id = reminderID(entry)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard
            preferences.remindersEnabled,
            entry.status == .active,
            entry.category == .reminder,
            let dueDate = entry.dueDate,
            dueDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = entry.summary
        content.body = "Reminder"
        content.sound = .default
        content.userInfo = ["entryID": entry.id.uuidString]
        content.threadIdentifier = entry.id.uuidString

        let leadMinutes = preferences.remindersLeadTime
        let fireDate = leadMinutes > 0
            ? Calendar.current.date(byAdding: .minute, value: -leadMinutes, to: dueDate) ?? dueDate
            : dueDate
        guard fireDate > Date() else { return }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func syncDueSoon(_ entry: Entry, preferences: NotificationPreferences) {
        let id = dueSoonID(entry)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard
            preferences.dueSoonEnabled,
            entry.status == .active,
            entry.category == .todo,
            let dueDate = entry.dueDate,
            dueDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = entry.summary
        content.body = "Due soon"
        content.sound = .default
        content.userInfo = ["entryID": entry.id.uuidString]
        content.threadIdentifier = entry.id.uuidString

        let leadMinutes = preferences.dueSoonLeadTime
        let fireDate = leadMinutes > 0
            ? Calendar.current.date(byAdding: .minute, value: -leadMinutes, to: dueDate) ?? dueDate
            : dueDate
        guard fireDate > Date() else { return }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func syncSnoozeWakeUp(_ entry: Entry, preferences: NotificationPreferences) {
        let id = snoozeID(entry)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard
            preferences.snoozeWakeUpEnabled,
            entry.status == .snoozed,
            let snoozeUntil = entry.snoozeUntil,
            snoozeUntil > Date()
        else { return }

        let content = UNMutableNotificationContent()
        content.title = entry.summary
        content.body = "Ready when you are"
        content.sound = .default
        content.userInfo = ["entryID": entry.id.uuidString]
        content.threadIdentifier = entry.id.uuidString

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: snoozeUntil)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - Habit Daily Reminder

    /// Schedule (or reschedule) the single global daily habit reminder.
    /// Call whenever habitsEnabled, habitHour, or habitMinute changes.
    func scheduleHabitReminder(preferences: NotificationPreferences) {
        center.removePendingNotificationRequests(withIdentifiers: [habitDailyID])
        guard preferences.habitsEnabled else { return }

        requestPermissionIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Time for your habits"
        content.body = "Check in on today's habits"
        content.sound = .default

        var comps = DateComponents()
        comps.hour = preferences.habitHour
        comps.minute = preferences.habitMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        center.add(UNNotificationRequest(identifier: habitDailyID, content: content, trigger: trigger))
    }

    func cancelHabitReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [habitDailyID])
    }

    // MARK: - Cancel

    /// Cancel all pending and delivered notifications for this entry (archive, delete).
    func cancel(_ entry: Entry) {
        let ids = [reminderID(entry), dueSoonID(entry), snoozeID(entry)]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Identifiers

    private func reminderID(_ entry: Entry) -> String { "reminder-\(entry.id.uuidString)" }
    private func dueSoonID(_ entry: Entry) -> String { "duesoon-\(entry.id.uuidString)" }
    private func snoozeID(_ entry: Entry) -> String { "snooze-\(entry.id.uuidString)" }
    private let habitDailyID = "habit-daily-reminder"
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Show banners even when the app is in the foreground — calm, not modal.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Deep link: extract entryID and post to NotificationCenter so RootView can navigate.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let idString = response.notification.request.content.userInfo["entryID"] as? String,
           let uuid = UUID(uuidString: idString) {
            NotificationCenter.default.post(
                name: .murmurOpenEntry,
                object: nil,
                userInfo: ["entryID": uuid]
            )
        }
        completionHandler()
    }
}

extension Notification.Name {
    static let murmurOpenEntry = Notification.Name("murmurOpenEntry")
    static let murmurShowError = Notification.Name("murmurShowError")
}
