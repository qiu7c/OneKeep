import Foundation

struct TrainingPlan: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var days: [TrainingDay]

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        days: [TrainingDay]
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.days = days
    }
}

struct TrainingDay: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var recurrence: ScheduleRule
    var blocks: [WorkoutBlock]

    var exercises: [PlannedExercise] {
        blocks.flatMap(\.exercises)
    }

    init(
        id: UUID = UUID(),
        title: String,
        recurrence: ScheduleRule,
        blocks: [WorkoutBlock]
    ) {
        self.id = id
        self.title = title
        self.recurrence = recurrence
        self.blocks = blocks
    }
}

struct WorkoutBlock: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case warmup
        case standard
        case interval
        case circuit
        case cooldown

        var title: String {
            switch self {
            case .warmup: return "热身"
            case .standard: return "普通训练"
            case .interval: return "间歇训练"
            case .circuit: return "循环训练"
            case .cooldown: return "拉伸放松"
            }
        }
    }

    let id: UUID
    var title: String
    var kind: Kind
    var rounds: Int
    var restBetweenExercisesSeconds: Int
    var restBetweenRoundsSeconds: Int
    var exercises: [PlannedExercise]

    init(
        id: UUID = UUID(),
        title: String,
        kind: Kind,
        rounds: Int = 1,
        restBetweenExercisesSeconds: Int = 0,
        restBetweenRoundsSeconds: Int = 0,
        exercises: [PlannedExercise]
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.rounds = rounds
        self.restBetweenExercisesSeconds = restBetweenExercisesSeconds
        self.restBetweenRoundsSeconds = restBetweenRoundsSeconds
        self.exercises = exercises
    }
}

struct ScheduleRule: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable {
        case specificDate
        case weekly
        case biweekly

        var title: String {
            switch self {
            case .specificDate: return "指定日期"
            case .weekly: return "每周"
            case .biweekly: return "隔周"
            }
        }
    }

    var kind: Kind
    var anchorDate: Date
    var weekdays: Set<Int>
    var endDate: Date?
}

struct PlannedExercise: Identifiable, Codable, Hashable {
    enum TrackingMode: String, Codable, CaseIterable {
        case repetitions
        case countdown
        case stopwatch

        var title: String {
            switch self {
            case .repetitions: return "次数"
            case .countdown: return "倒计时"
            case .stopwatch: return "正计时"
            }
        }
    }

    let id: UUID
    var name: String
    var sets: Int
    var repetitions: String?
    var plannedWeightKilograms: Double?
    var durationSeconds: Int?
    var restSeconds: Int
    var notes: String?
    var videoURL: URL?
    var trackingMode: TrackingMode
    var libraryID: String?
    var libraryMatchCandidates: [String]?
    var libraryMatchConfidence: Double?

    init(
        id: UUID = UUID(),
        name: String,
        sets: Int,
        repetitions: String? = nil,
        plannedWeightKilograms: Double? = nil,
        durationSeconds: Int? = nil,
        restSeconds: Int = 60,
        notes: String? = nil,
        videoURL: URL? = nil,
        trackingMode: TrackingMode = .repetitions,
        libraryID: String? = nil,
        libraryMatchCandidates: [String]? = nil,
        libraryMatchConfidence: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.repetitions = repetitions
        self.plannedWeightKilograms = plannedWeightKilograms
        self.durationSeconds = durationSeconds
        self.restSeconds = restSeconds
        self.notes = notes
        self.videoURL = videoURL
        self.trackingMode = trackingMode
        self.libraryID = libraryID
        self.libraryMatchCandidates = libraryMatchCandidates
        self.libraryMatchConfidence = libraryMatchConfidence
    }
}

extension TrainingPlan {
    func duplicated(titleSuffix: String = " 副本") -> TrainingPlan {
        TrainingPlan(
            title: title + titleSuffix,
            startDate: startDate,
            endDate: endDate,
            days: days.map { day in
                TrainingDay(
                    title: day.title,
                    recurrence: day.recurrence,
                    blocks: day.blocks.map { block in
                        WorkoutBlock(
                            title: block.title,
                            kind: block.kind,
                            rounds: block.rounds,
                            restBetweenExercisesSeconds: block.restBetweenExercisesSeconds,
                            restBetweenRoundsSeconds: block.restBetweenRoundsSeconds,
                            exercises: block.exercises.map { exercise in
                                PlannedExercise(
                                    name: exercise.name,
                                    sets: exercise.sets,
                                    repetitions: exercise.repetitions,
                                    plannedWeightKilograms: exercise.plannedWeightKilograms,
                                    durationSeconds: exercise.durationSeconds,
                                    restSeconds: exercise.restSeconds,
                                    notes: exercise.notes,
                                    videoURL: exercise.videoURL,
                                    trackingMode: exercise.trackingMode,
                                    libraryID: exercise.libraryID,
                                    libraryMatchCandidates: exercise.libraryMatchCandidates,
                                    libraryMatchConfidence: exercise.libraryMatchConfidence
                                )
                            }
                        )
                    }
                )
            }
        )
    }

    static let preview = TrainingPlan(
        title: "本周训练",
        startDate: .now,
        days: [
            TrainingDay(
                title: "完整训练",
                recurrence: ScheduleRule(
                    kind: .weekly,
                    anchorDate: .now,
                    weekdays: [2, 3, 4, 5, 6],
                    endDate: nil
                ),
                blocks: [
                    WorkoutBlock(
                        title: "动态热身",
                        kind: .warmup,
                        restBetweenExercisesSeconds: 15,
                        exercises: [
                            PlannedExercise(name: "靠墙站立", sets: 1, durationSeconds: 60, restSeconds: 15, trackingMode: .countdown),
                            PlannedExercise(name: "猫式伸展", sets: 1, repetitions: "10", restSeconds: 15),
                            PlannedExercise(name: "高抬腿", sets: 2, durationSeconds: 30, restSeconds: 15, trackingMode: .countdown)
                        ]
                    ),
                    WorkoutBlock(
                        title: "力量训练",
                        kind: .standard,
                        exercises: [
                            PlannedExercise(name: "平板支撑", sets: 3, durationSeconds: 40, restSeconds: 30, trackingMode: .countdown)
                        ]
                    )
                ]
            )
        ]
    )
}
