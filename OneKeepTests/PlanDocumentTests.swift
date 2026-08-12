import XCTest
@testable import OneKeep

final class PlanDocumentTests: XCTestCase {
    func testRoundTripPreservesPlan() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let data = try PlanDocumentCodec.encode(plans: [.preview], exportedAt: date)
        let document = try PlanDocumentCodec.decode(data)

        XCTAssertEqual(document.exportedAt, date)
        XCTAssertEqual(document.plans.count, 1)
        XCTAssertEqual(document.plans.first?.id, TrainingPlan.preview.id)
        XCTAssertEqual(document.plans.first?.title, TrainingPlan.preview.title)
        XCTAssertEqual(document.plans.first?.days.count, TrainingPlan.preview.days.count)
    }

    func testRejectsInvalidSetCount() {
        var plan = TrainingPlan.preview
        plan.days[0].blocks[0].exercises[0].sets = 0

        XCTAssertThrowsError(try PlanDocumentCodec.encode(plans: [plan])) { error in
            XCTAssertEqual(error as? PlanDocumentError, .invalidSetCount)
        }
    }

    func testRejectsUnknownFormatVersion() throws {
        let data = try PlanDocumentCodec.encode(plans: [.preview])
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["formatVersion"] = 999
        let unsupportedData = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try PlanDocumentCodec.decode(unsupportedData)) { error in
            XCTAssertEqual(error as? PlanDocumentError, .unsupportedVersion(999))
        }
    }
}
