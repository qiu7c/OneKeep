import Combine
import Foundation

@MainActor
final class PlanLibraryStore: ObservableObject {
    @Published private(set) var plans: [TrainingPlan] = []
    @Published var presentedError: PresentedError?

    private let repository: PlanRepository
    private var hasLoaded = false

    init(repository: PlanRepository) {
        self.repository = repository
    }

    func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        reload()
    }

    func reload() {
        do {
            plans = try repository.fetchAll()
        } catch {
            present(error)
        }
    }

    func save(_ plan: TrainingPlan) {
        do {
            try repository.upsert(plan)
            reload()
        } catch {
            present(error)
        }
    }

    func delete(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            plans.indices.contains(index) ? plans[index].id : nil
        }

        do {
            try ids.forEach(repository.delete)
            reload()
        } catch {
            present(error)
        }
    }

    func delete(_ plan: TrainingPlan) {
        do {
            try repository.delete(id: plan.id)
            reload()
        } catch {
            present(error)
        }
    }

    func importPlanDocument(_ data: Data) {
        do {
            let document = try PlanDocumentCodec.decode(data)
            var existingIDs = Set(plans.map(\.id))
            for sourcePlan in document.plans {
                var importedPlan = sourcePlan
                if existingIDs.contains(importedPlan.id) {
                    importedPlan = TrainingPlan(
                        title: importedPlan.title + " 副本",
                        startDate: importedPlan.startDate,
                        endDate: importedPlan.endDate,
                        days: importedPlan.days
                    )
                }
                try repository.upsert(importedPlan)
                existingIDs.insert(importedPlan.id)
            }
            reload()
        } catch {
            present(error)
        }
    }

    func exportURL(for plan: TrainingPlan) throws -> URL {
        let data = try PlanDocumentCodec.encode(plans: [plan])
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneKeep-Exports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let safeTitle = plan.title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("\(safeTitle).onekeep-plan.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func present(_ error: Error) {
        presentedError = PresentedError(
            title: "操作失败",
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        )
    }
}

struct PresentedError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
