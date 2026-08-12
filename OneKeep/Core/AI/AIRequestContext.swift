import Foundation

enum AIRequestContext {
    static func currentDateMessage(
        now: Date = .now,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss EEEE"

        let offset = timeZone.secondsFromGMT(for: now)
        let sign = offset >= 0 ? "+" : "-"
        let absoluteOffset = abs(offset)
        let hours = absoluteOffset / 3_600
        let minutes = (absoluteOffset % 3_600) / 60
        let utcOffset = String(format: "UTC%@%02d:%02d", sign, hours, minutes)

        return """
        设备当前本地时间：\(formatter.string(from: now))（时区：\(timeZone.identifier)，\(utcOffset)）。
        “今天、明天、本周、下周”等相对日期必须以此时间为准；用户明确写出的日期优先，禁止自行猜测当前日期或星期。
        """
    }
}
