import Foundation

struct WorkoutStep: Identifiable, Hashable {
    let id: UUID
    let blockTitle: String
    let blockKind: WorkoutBlock.Kind
    let roundIndex: Int
    let roundCount: Int
    let exercise: PlannedExercise
    let setIndex: Int
    let setCount: Int
    let restAfterSeconds: Int
}

enum WorkoutExecutionPlan {
    static func makeSteps(from day: TrainingDay) -> [WorkoutStep] {
        var steps: [WorkoutStep] = []

        for block in day.blocks {
            guard block.rounds > 0 else { continue }

            for roundIndex in 1...block.rounds {
                for (exerciseOffset, exercise) in block.exercises.enumerated() {
                    guard exercise.sets > 0 else { continue }

                    for setIndex in 1...exercise.sets {
                        let isLastSet = setIndex == exercise.sets
                        let isLastExercise = exerciseOffset == block.exercises.count - 1
                        let isLastRound = roundIndex == block.rounds

                        let restAfter: Int
                        if !isLastSet {
                            restAfter = exercise.restSeconds
                        } else if !isLastExercise {
                            restAfter = block.restBetweenExercisesSeconds > 0
                                ? block.restBetweenExercisesSeconds
                                : exercise.restSeconds
                        } else if !isLastRound {
                            restAfter = block.restBetweenRoundsSeconds
                        } else {
                            restAfter = 0
                        }

                        steps.append(
                            WorkoutStep(
                                id: UUID(),
                                blockTitle: block.title,
                                blockKind: block.kind,
                                roundIndex: roundIndex,
                                roundCount: block.rounds,
                                exercise: exercise,
                                setIndex: setIndex,
                                setCount: exercise.sets,
                                restAfterSeconds: restAfter
                            )
                        )
                    }
                }
            }
        }

        return steps
    }
}
