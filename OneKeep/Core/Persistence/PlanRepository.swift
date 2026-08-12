import CoreData
import Foundation

protocol PlanRepository {
    func fetchAll() throws -> [TrainingPlan]
    func upsert(_ plan: TrainingPlan) throws
    func delete(id: UUID) throws
}

@MainActor
final class CoreDataPlanRepository: PlanRepository {
    private let context: NSManagedObjectContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(context: NSManagedObjectContext) {
        self.context = context

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func fetchAll() throws -> [TrainingPlan] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TrainingPlanEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        return try context.fetch(request).compactMap { object in
            guard let payload = object.value(forKey: "payload") as? Data else { return nil }
            return try decoder.decode(TrainingPlan.self, from: payload)
        }
    }

    func upsert(_ plan: TrainingPlan) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TrainingPlanEntity")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", plan.id as NSUUID)

        let now = Date.now
        let object: NSManagedObject

        if let existing = try context.fetch(request).first {
            object = existing
        } else {
            object = NSEntityDescription.insertNewObject(forEntityName: "TrainingPlanEntity", into: context)
            object.setValue(plan.id, forKey: "id")
            object.setValue(now, forKey: "createdAt")
        }

        object.setValue(plan.title, forKey: "title")
        object.setValue(plan.startDate, forKey: "startDate")
        object.setValue(plan.endDate, forKey: "endDate")
        object.setValue(try encoder.encode(plan), forKey: "payload")
        object.setValue(now, forKey: "updatedAt")
        try context.save()
    }

    func delete(id: UUID) throws {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TrainingPlanEntity")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        try context.fetch(request).forEach(context.delete)

        if context.hasChanges {
            try context.save()
        }
    }
}

final class InMemoryPlanRepository: PlanRepository {
    private var plans: [UUID: TrainingPlan]

    init(plans: [TrainingPlan] = []) {
        self.plans = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
    }

    func fetchAll() throws -> [TrainingPlan] {
        plans.values.sorted { $0.startDate > $1.startDate }
    }

    func upsert(_ plan: TrainingPlan) throws {
        plans[plan.id] = plan
    }

    func delete(id: UUID) throws {
        plans[id] = nil
    }
}
