import CoreData
import XCTest
@testable import OneKeep

@MainActor
final class WorkoutSessionRepositoryTests: XCTestCase {
    func testStartsRecordsAndFinishesSession() throws {
        let persistence = PersistenceController(inMemory: true)
        let context = persistence.container.viewContext
        let repository = WorkoutSessionRepository(context: context)
        let sessionID = UUID()
        let day = TrainingPlan.preview.days[0]
        let step = try XCTUnwrap(WorkoutExecutionPlan.makeSteps(from: day).first)

        try repository.start(id: sessionID, trainingDay: day)
        try repository.recordSet(
            sessionID: sessionID,
            stepIndex: 0,
            step: step,
            repetitions: 10,
            weightKilograms: 20,
            durationSeconds: nil
        )
        try repository.finish(id: sessionID)

        let sessionRequest = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        let setRequest = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        let session = try XCTUnwrap(context.fetch(sessionRequest).first)
        let performedSet = try XCTUnwrap(context.fetch(setRequest).first)

        XCTAssertEqual(session.value(forKey: "status") as? String, "completed")
        XCTAssertEqual(performedSet.value(forKey: "repetitions") as? Int64, 10)
        XCTAssertEqual(performedSet.value(forKey: "weightKilograms") as? Double, 20)
    }
}
