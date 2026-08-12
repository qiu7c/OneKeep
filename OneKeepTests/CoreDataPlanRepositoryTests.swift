import XCTest
@testable import OneKeep

@MainActor
final class CoreDataPlanRepositoryTests: XCTestCase {
    func testPlanPersistsAndDeletes() throws {
        let persistence = PersistenceController(inMemory: true)
        let repository = CoreDataPlanRepository(context: persistence.container.viewContext)

        try repository.upsert(.preview)
        XCTAssertEqual(try repository.fetchAll().map(\.id), [TrainingPlan.preview.id])

        try repository.delete(id: TrainingPlan.preview.id)
        XCTAssertTrue(try repository.fetchAll().isEmpty)
    }
}
