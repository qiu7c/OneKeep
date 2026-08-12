import XCTest
@testable import OneKeep

final class AIRequestContextTests: XCTestCase {
    func testCurrentDateMessageContainsLocalDateWeekdayAndTimeZone() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 12, hour: 16, minute: 41, second: 5
        )))

        let message = AIRequestContext.currentDateMessage(now: date, timeZone: timeZone)

        XCTAssertTrue(message.contains("2026-08-12 16:41:05"))
        XCTAssertTrue(message.contains("星期三"))
        XCTAssertTrue(message.contains("Asia/Shanghai"))
        XCTAssertTrue(message.contains("UTC+08:00"))
    }
}
