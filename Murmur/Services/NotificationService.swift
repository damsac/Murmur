import UserNotifications
import Foundation

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
            print("Notification permission error: \(error)")
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

    /// Evaluate an entry's state and atomically cancel/reschedule both notification slots.
    /// Safe to call on every save — idempotent.
    /// Lazily requests notification permission the first time a reminder is synced.
    /// Note: notifications are scheduled immediately — iOS queues them and delivers once authorized.
    func sync(_ entry: Entry, preferences: NotificationPreferences) {
        let isNotificationEligible =
            entry.category == .reminder ||
            (entry.category == .todo && preferences.dueSoonEnabled) ||
            entry.status == .snoozed
        if isNotificationEligible {
            requestPermissionIfNeeded()
        }
        syncReminder(entry, preferences: preferences)
        syncSnoozeWakeUp(entry, preferences: preferences)
    }

    private func syncReminder(_ entry: Entry, preferences: NotificationPreferences) {
        let id = reminderID(entry)
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard
            preferences.remindersEnabled,
            entry.status == .active,
            let dueDate = entry.dueDate,
            dueDate > Date(),
            entry.category == .reminder || (entry.category == .todo && preferences.dueSoonEnabled)
        else { return }

        let content = UNMutableNotificationContent()
        content.title = entry.summary
        content.body = entry.category == .reminder ? "Reminder" : "Due soon"
        content.sound = .default
        content.userInfo = ["entryID": entry.id.uuidString]
        content.threadIdentifier = entry.id.uuidString

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
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

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: snoozeUntil
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    // MARK: - Cancel

    /// Cancel all pending and delivered notifications for this entry (archive, delete).
    func cancel(_ entry: Entry) {
        let ids = [reminderID(entry), snoozeID(entry)]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    // MARK: - Identifiers

    private func reminderID(_ entry: Entry) -> String { "reminder-\(entry.id.uuidString)" }
    private func snoozeID(_ entry: Entry) -> String { "snooze-\(entry.id.uuidString)" }
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
}
