import Foundation
import AppKit
import UserNotifications

/// Due-date reminders and the "time's up" notification.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private let taskCategory = "FOCUS_TASK"
    private let doneAction = "FOCUS_DONE"
    private let snoozeAction = "FOCUS_SNOOZE"
    private let taskPrefix = "task-"

    private weak var store: Store?
    private var pending: DispatchWorkItem?

    /// Notifications only work inside the installed .app (not when run from Xcode as a bare binary).
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier != nil ? UNUserNotificationCenter.current() : nil
    }

    var isAvailable: Bool { center != nil }

    func setup(store: Store) {
        self.store = store
        guard let center else { return }
        center.delegate = self
        let done = UNNotificationAction(identifier: doneAction, title: "Mark as Done", options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Snooze 10 min", options: [])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: taskCategory, actions: [done, snooze], intentIdentifiers: [], options: [])
        ])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        sync(store.data)
    }

    private var chimeSound: UNNotificationSound {
        Bundle.main.url(forResource: "chime", withExtension: "wav") != nil
            ? UNNotificationSound(named: UNNotificationSoundName("chime.wav"))
            : .default
    }

    // MARK: Task reminders

    func scheduleSync(_ data: AppData) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.sync(data) }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func sync(_ data: AppData) {
        guard let center else { return }
        let now = Date()
        var requests: [UNNotificationRequest] = []

        if data.settings.notificationsEnabled {
            let offset = TimeInterval(data.settings.reminder.rawValue * 60)
            for task in data.tasks where task.completedAt == nil {
                guard let due = task.due else { continue }
                let fire = due.addingTimeInterval(-offset)
                guard fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                content.body = "Due " + DueFormat.label(due) + " · \(task.priority.label) priority"
                content.sound = chimeSound
                content.categoryIdentifier = taskCategory
                content.userInfo = ["taskID": task.id.uuidString]

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
                requests.append(UNNotificationRequest(
                    identifier: taskPrefix + task.id.uuidString,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            }
        }

        let prefix = taskPrefix
        let newRequests = requests
        center.getPendingNotificationRequests { existing in
            let old = existing.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)
            for r in newRequests { center.add(r) }
        }
    }

    func sendTest() {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = "Focus"
        content.body = "Reminders are working."
        content.sound = chimeSound
        center.add(UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    // MARK: Timer

    func timerFinished(wasFocus: Bool) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = wasFocus ? "Focus session done" : "Break is over"
        content.body = wasFocus ? "Nice work. Time for a break." : "Ready for the next focus session?"
        content.sound = nil   // the app plays its own chime
        center.add(UNNotificationRequest(identifier: "timer-\(UUID().uuidString)", content: content, trigger: nil))
    }

    // MARK: Delegate

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        let idString = content.userInfo["taskID"] as? String
        let action = response.actionIdentifier
        let snoozeAction = self.snoozeAction
        let doneAction = self.doneAction

        DispatchQueue.main.async { [weak self] in
            if action == doneAction, let idString, let id = UUID(uuidString: idString),
               let store = self?.store, store.task(id)?.completedAt == nil {
                store.toggle(id)
            } else if action == snoozeAction, let idString {
                let again = (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
                center.add(UNNotificationRequest(identifier: "snooze-\(idString)", content: again,
                                                 trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false)))
            } else {
                AppDelegate.shared?.showWindow()
            }
            completionHandler()
        }
    }
}
