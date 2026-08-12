import Foundation

struct PlanDocument: Codable, Equatable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var exportedAt: Date
    var plans: [TrainingPlan]

    init(
        formatVersion: Int = Self.currentFormatVersion,
        exportedAt: Date = .now,
        plans: [TrainingPlan]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.plans = plans
    }
}

enum PlanDocumentError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case emptyPlanTitle
    case invalidDateRange
    case emptyTrainingDay
    case emptyExerciseName
    case invalidSetCount
    case invalidWeight
    case invalidDuration
    case invalidRestDuration

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "不支持计划文件版本 \(version)"
        case .emptyPlanTitle:
            return "计划名称不能为空"
        case .invalidDateRange:
            return "计划结束日期不能早于开始日期"
        case .emptyTrainingDay:
            return "训练日必须至少包含一个动作"
        case .emptyExerciseName:
            return "动作名称不能为空"
        case .invalidSetCount:
            return "动作组数必须在 1 到 100 之间"
        case .invalidWeight:
            return "动作重量不能为负数"
        case .invalidDuration:
            return "计时动作必须设置有效时长"
        case .invalidRestDuration:
            return "休息时间必须在 0 到 86400 秒之间"
        }
    }
}

enum PlanDocumentCodec {
    static func encode(plans: [TrainingPlan], exportedAt: Date = .now) throws -> Data {
        try validate(plans: plans)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(PlanDocument(exportedAt: exportedAt, plans: plans))
    }

    static func decode(_ data: Data) throws -> PlanDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(PlanDocument.self, from: data)

        guard document.formatVersion == PlanDocument.currentFormatVersion else {
            throw PlanDocumentError.unsupportedVersion(document.formatVersion)
        }

        try validate(plans: document.plans)
        return document
    }

    static func validate(plans: [TrainingPlan]) throws {
        for plan in plans {
            guard !plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PlanDocumentError.emptyPlanTitle
            }

            if let endDate = plan.endDate, endDate < plan.startDate {
                throw PlanDocumentError.invalidDateRange
            }

            for day in plan.days {
                guard !day.blocks.isEmpty, !day.exercises.isEmpty else {
                    throw PlanDocumentError.emptyTrainingDay
                }

                for block in day.blocks {
                    guard (1...100).contains(block.rounds) else {
                        throw PlanDocumentError.invalidSetCount
                    }
                    guard (0...86_400).contains(block.restBetweenExercisesSeconds),
                          (0...86_400).contains(block.restBetweenRoundsSeconds) else {
                        throw PlanDocumentError.invalidRestDuration
                    }

                    for exercise in block.exercises {
                        guard !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            throw PlanDocumentError.emptyExerciseName
                        }
                        guard (1...100).contains(exercise.sets) else {
                            throw PlanDocumentError.invalidSetCount
                        }
                        if let weight = exercise.plannedWeightKilograms, weight < 0 {
                            throw PlanDocumentError.invalidWeight
                        }
                        if exercise.trackingMode == .countdown,
                           (exercise.durationSeconds ?? 0) <= 0 {
                            throw PlanDocumentError.invalidDuration
                        }
                        guard (0...86_400).contains(exercise.restSeconds) else {
                            throw PlanDocumentError.invalidRestDuration
                        }
                    }
                }
            }
        }
    }
}
