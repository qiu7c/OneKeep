import XCTest
@testable import OneKeep

final class AIPlanImportRecognitionTests: XCTestCase {
    func testParserAcceptsLibraryIDAndMissingOptionalExerciseFields() throws {
        let json = """
        {
          "title":"测试计划","startDate":"2026-08-12","endDate":null,
          "days":[{
            "title":"第一天","scheduleKind":"specificDate","anchorDate":"2026-08-12",
            "blocks":[{"kind":"standard","exercises":[{
              "libraryID":"plank","name":"平板支撑","sets":"2组","weightKilograms":"5 kg","durationSeconds":"40秒","trackingMode":"countdown"
            }]}]
          }]
        }
        """
        let plan = try AIPlanImportService.parse(json)
        let exercise = try XCTUnwrap(plan.days.first?.blocks.first?.exercises.first)
        XCTAssertEqual(exercise.libraryID, "plank")
        XCTAssertEqual(exercise.sets, 2)
        XCTAssertEqual(exercise.durationSeconds, 40)
        XCTAssertEqual(exercise.plannedWeightKilograms, 5)
        XCTAssertEqual(exercise.restSeconds, 30)
    }

    func testParserAcceptsNumericRepetitions() throws {
        let json = """
        {
          "title":"测试计划","startDate":"2026-08-12","days":[{
            "title":"第一天","scheduleKind":"specificDate","anchorDate":"2026-08-12","weekdays":[],
            "blocks":[{"title":"训练","kind":"standard","exercises":[{
              "libraryID":"bodyweight-squat","name":"徒手深蹲","sets":3,"repetitions":12
            }]}]
          }]
        }
        """
        let plan = try AIPlanImportService.parse(json)
        XCTAssertEqual(plan.days.first?.blocks.first?.exercises.first?.repetitions, "12")
    }

    func testOlderPlannedExerciseDecodesWithoutRecognitionMetadata() throws {
        let original = PlannedExercise(name: "平板支撑", sets: 1, libraryID: "plank")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        object.removeValue(forKey: "libraryID")
        object.removeValue(forKey: "libraryMatchCandidates")
        object.removeValue(forKey: "libraryMatchConfidence")
        let restored = try JSONDecoder().decode(
            PlannedExercise.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertNil(restored.libraryID)
        XCTAssertNil(restored.libraryMatchCandidates)
        XCTAssertNil(restored.libraryMatchConfidence)
    }
}
