import CoreData
import Foundation

@MainActor
final class WorkoutSessionRepository {
    enum Status: String {
        case active
        case completed
        case cancelled
    }

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func start(id: UUID, trainingDay: TrainingDay, at date: Date = .now) throws {
        guard try session(id: id) == nil else { return }

        let object = NSEntityDescription.insertNewObject(forEntityName: "WorkoutSessionEntity", into: context)
        object.setValue(id, forKey: "id")
        object.setValue(trainingDay.id, forKey: "trainingDayID")
        object.setValue(trainingDay.title, forKey: "title")
        object.setValue(date, forKey: "startedAt")
        object.setValue(date, forKey: "updatedAt")
        object.setValue(Status.active.rawValue, forKey: "status")
        try context.save()
    }

    func recordSet(
        sessionID: UUID,
        stepIndex: Int,
        step: WorkoutStep,
        repetitions: Int?,
        weightKilograms: Double?,
        durationSeconds: Int?,
        at date: Date = .now
    ) throws {
        let object = NSEntityDescription.insertNewObject(forEntityName: "PerformedSetEntity", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue(sessionID, forKey: "sessionID")
        object.setValue(step.exercise.id, forKey: "exerciseID")
        object.setValue(step.exercise.name, forKey: "exerciseName")
        object.setValue(Int64(stepIndex), forKey: "stepIndex")
        object.setValue(Int64(step.setIndex), forKey: "setIndex")
        object.setValue(repetitions.map { Int64($0) }, forKey: "repetitions")
        object.setValue(step.exercise.plannedWeightKilograms, forKey: "plannedWeightKilograms")
        object.setValue(weightKilograms, forKey: "weightKilograms")
        object.setValue(durationSeconds.map { Int64($0) }, forKey: "durationSeconds")
        object.setValue(date, forKey: "completedAt")

        if let session = try session(id: sessionID) {
            session.setValue(date, forKey: "updatedAt")
        }
        try context.save()
    }

    func finish(id: UUID, at date: Date = .now) throws {
        guard let session = try session(id: id) else { return }
        session.setValue(Status.completed.rawValue, forKey: "status")
        session.setValue(date, forKey: "endedAt")
        session.setValue(date, forKey: "updatedAt")
        try context.save()
    }

    func cancel(id: UUID, at date: Date = .now) throws {
        guard let session = try session(id: id) else { return }
        session.setValue(Status.cancelled.rawValue, forKey: "status")
        session.setValue(date, forKey: "endedAt")
        session.setValue(date, forKey: "updatedAt")
        try context.save()
    }

    private func session(id: UUID) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        return try context.fetch(request).first
    }
}
