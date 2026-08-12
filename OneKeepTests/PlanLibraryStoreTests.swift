import XCTest
@testable import OneKeep

@MainActor
final class PlanLibraryStoreTests: XCTestCase {
    func testSaveReloadAndDelete() {
        let repository = InMemoryPlanRepository()
        let store = PlanLibraryStore(repository: repository)

        store.save(.preview)
        XCTAssertEqual(store.plans.count, 1)

        store.delete(store.plans[0])
        XCTAssertTrue(store.plans.isEmpty)
    }

    func testImportDuplicatesExistingPlanAsCopy() throws {
        let existing = TrainingPlan.preview
        let repository = InMemoryPlanRepository(plans: [existing])
        let store = PlanLibraryStore(repository: repository)
        store.loadIfNeeded()

        let data = try PlanDocumentCodec.encode(plans: [existing])
        store.importPlanDocument(data)

        XCTAssertEqual(store.plans.count, 2)
        XCTAssertTrue(store.plans.contains(where: { $0.title.hasSuffix("副本") }))
    }
}
