import Foundation
import UserNotifications

/// Manages local notification scheduling for laundry reminders.
@Observable
final class NotificationService {
    var isAuthorized = false
    var error: NotificationError?

    enum NotificationError: LocalizedError {
        case notAuthorized
        case schedulingFailed(String)

        var errorDescription: String? {
            switch self {
            case .notAuthorized: return "Notifications not authorized. Please enable them in System Settings > Notifications."
            case .schedulingFailed(let reason): return "Failed to schedule notification: \(reason)"
            }
        }
    }

    /// Notification categories for ThreadTrack.
    enum ThreadTrackCategory: String {
        case laundryDue = "LAUNDRY_DUE"
        case laundryReminder = "LAUNDRY_REMINDER"
        case dailyOutfit = "DAILY_OUTFIT_REMINDER"
    }

    init() {
        setupCategories()
    }

    /// Request notification authorization from the user.
    @MainActor
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
        } catch {
            isAuthorized = false
        }
    }

    /// Schedule a laundry-due notification for a clothing item.
    func scheduleLaundryDueNotification(for itemName: String, after delay: TimeInterval = 3600) {
        let content = UNMutableNotificationContent()
        content.title = "Laundry Due"
        content.body = "\(itemName) needs to be washed!"
        content.sound = .default
        content.categoryIdentifier = ThreadTrackCategory.laundryDue.rawValue

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "laundry-\(itemName)-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.error = .schedulingFailed(error.localizedDescription)
                }
            }
        }
    }

    /// Schedule a daily outfit reminder notification.
    func scheduleDailyOutfitReminder(at date: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = "Time for Today's Outfit!"
        content.body = "Don't forget to snap your daily outfit photo."
        content.sound = .default
        content.categoryIdentifier = ThreadTrackCategory.dailyOutfit.rawValue

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily-outfit-reminder",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error {
                DispatchQueue.main.async {
                    self?.error = .schedulingFailed(error.localizedDescription)
                }
            }
        }
    }

    /// Remove all pending notifications.
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Private

    private func setupCategories() {
        let laundryAction = UNNotificationAction(identifier: "MARK_DONE", title: "Mark Done", options: [])
        let laterAction = UNNotificationAction(identifier: "REMIND_LATER", title: "Remind Later", options: [])
        let category = UNNotificationCategory(
            identifier: ThreadTrackCategory.laundryDue.rawValue,
            actions: [laundryAction, laterAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
