import XCTest
@testable import OneKeep

final class AIPlanImportServiceTests: XCTestCase {
    func testParsesMarkdownWrappedPlanJSON() throws {
        let json = """
        ```json
        {
          "title": "测试计划",
          "startDate": "2026-08-12",
          "endDate": "2026-09-12",
          "days": [{
            "title": "训练日",
            "scheduleKind": "biweekly",
            "anchorDate": "2026-08-12",
            "weekdays": [2, 4, 6],
            "blocks": [{
              "title": "间歇",
              "kind": "interval",
              "rounds": 8,
              "restBetweenExercisesSeconds": 15,
              "restBetweenRoundsSeconds": 60,
              "exercises": [{
                "name": "空气跳绳",
                "sets": 1,
                "repetitions": null,
                "weightKilograms": null,
                "durationSeconds": 120,
                "restSeconds": 60,
                "notes": "落地要轻",
                "videoURL": "https://example.com/rope.mp4",
                "trackingMode": "countdown"
              }]
            }]
          }]
        }
        ```
        """

        let plan = try AIPlanImportService.parse(json)

        XCTAssertEqual(plan.title, "测试计划")
        XCTAssertEqual(plan.days[0].recurrence.kind, .biweekly)
        XCTAssertEqual(plan.days[0].blocks[0].kind, .interval)
        XCTAssertEqual(plan.days[0].blocks[0].rounds, 8)
        XCTAssertEqual(plan.days[0].exercises[0].durationSeconds, 120)
    }

    func testRejectsInvalidWeekday() {
        let json = """
        {
          "title": "错误计划",
          "startDate": "2026-08-12",
          "endDate": null,
          "days": [{
            "title": "训练日",
            "scheduleKind": "weekly",
            "anchorDate": "2026-08-12",
            "weekdays": [9],
            "blocks": []
          }]
        }
        """

        XCTAssertThrowsError(try AIPlanImportService.parse(json))
    }
}
