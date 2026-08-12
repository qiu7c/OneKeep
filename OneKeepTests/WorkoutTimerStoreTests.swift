import XCTest
@testable import OneKeep

@MainActor
final class WorkoutTimerStoreTests: XCTestCase {
    func testTimerUsesTargetEndDate() {
        let timer = WorkoutTimerStore()
        let start = Date(timeIntervalSince1970: 1_000)

        timer.start(seconds: 90, now: start)
        timer.update(now: start.addingTimeInterval(30.2))

        XCTAssertEqual(timer.remainingSeconds, 60)
        XCTAssertEqual(timer.phase, .running)
    }

    func testTimerFinishesAfterBackgroundGap() {
        let timer = WorkoutTimerStore()
        let start = Date(timeIntervalSince1970: 1_000)

        timer.start(seconds: 30, now: start)
        timer.update(now: start.addingTimeInterval(45))

        XCTAssertEqual(timer.remainingSeconds, 0)
        XCTAssertEqual(timer.phase, .finished)
    }

    func testPauseAndResumePreserveRemainingTime() {
        let timer = WorkoutTimerStore()
        let start = Date(timeIntervalSince1970: 1_000)

        timer.start(seconds: 60, now: start)
        timer.pause(now: start.addingTimeInterval(20))
        XCTAssertEqual(timer.remainingSeconds, 40)

        timer.resume(now: start.addingTimeInterval(120))
        timer.update(now: start.addingTimeInterval(130))
        XCTAssertEqual(timer.remainingSeconds, 30)
    }

    func testStopwatchUsesElapsedWallClockTime() {
        let timer = WorkoutTimerStore()
        let start = Date(timeIntervalSince1970: 1_000)

        timer.startStopwatch(now: start)
        timer.update(now: start.addingTimeInterval(12.8))

        XCTAssertEqual(timer.elapsedSeconds, 12)
        XCTAssertEqual(timer.formattedTime, "00:12")
    }

    func testStopwatchPauseAndResume() {
        let timer = WorkoutTimerStore()
        let start = Date(timeIntervalSince1970: 1_000)

        timer.startStopwatch(now: start)
        timer.pause(now: start.addingTimeInterval(10.9))
        timer.resume(now: start.addingTimeInterval(100))
        timer.update(now: start.addingTimeInterval(105.2))

        XCTAssertEqual(timer.elapsedSeconds, 15)
    }
}
