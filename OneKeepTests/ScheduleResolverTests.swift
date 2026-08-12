import XCTest
@testable import OneKeep

final class ScheduleResolverTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        value.firstWeekday = 2
        return value
    }

    func testSpecificDateOnlyMatchesAnchorDay() throws {
        let anchor = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12)))
        let rule = ScheduleRule(kind: .specificDate, anchorDate: anchor, weekdays: [], endDate: nil)

        XCTAssertTrue(ScheduleResolver.matches(rule, date: anchor, calendar: calendar))
        XCTAssertFalse(ScheduleResolver.matches(rule, date: anchor.addingTimeInterval(86_400), calendar: calendar))
    }

    func testBiweeklyMatchesEveryOtherAnchorWeek() throws {
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let rule = ScheduleRule(kind: .biweekly, anchorDate: monday, weekdays: [2], endDate: nil)

        XCTAssertTrue(ScheduleResolver.matches(rule, date: monday, calendar: calendar))
        XCTAssertFalse(ScheduleResolver.matches(rule, date: calendar.date(byAdding: .weekOfYear, value: 1, to: monday)!, calendar: calendar))
        XCTAssertTrue(ScheduleResolver.matches(rule, date: calendar.date(byAdding: .weekOfYear, value: 2, to: monday)!, calendar: calendar))
    }

    func testEndDateIsInclusive() throws {
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: monday))
        let rule = ScheduleRule(kind: .weekly, anchorDate: monday, weekdays: [2], endDate: end)

        XCTAssertTrue(ScheduleResolver.matches(rule, date: end, calendar: calendar))
        XCTAssertFalse(ScheduleResolver.matches(rule, date: calendar.date(byAdding: .weekOfYear, value: 2, to: monday)!, calendar: calendar))
    }
}
