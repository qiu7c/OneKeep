import Foundation
import UserNotifications

enum WorkoutNotificationService {
    private static let finishIdentifier = "onekeep.workout.timer.finish"
    private static let warningIdentifier = "onekeep.workout.timer.warning"

    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    static func scheduleTimerFinished(after seconds: Int, title: String) {
        cancel()
        guard seconds > 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "返回 OneKeep 继续下一组"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: finishIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
        if seconds > 10 {
            let warning = UNMutableNotificationContent()
            warning.title = "还剩 10 秒"
            warning.body = title
            warning.sound = .default
            UNUserNotificationCenter.current().add(UNNotificationRequest(
                identifier: warningIdentifier,
                content: warning,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds - 10), repeats: false)
            ))
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [finishIdentifier, warningIdentifier]
        )
    }
}
