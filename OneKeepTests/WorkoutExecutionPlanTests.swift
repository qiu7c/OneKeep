import XCTest
@testable import OneKeep

final class WorkoutExecutionPlanTests: XCTestCase {
    func testCircuitExpandsRoundsAndSets() {
        let day = TrainingDay(
            title: "循环训练",
            recurrence: ScheduleRule(kind: .weekly, anchorDate: .now, weekdays: [2], endDate: nil),
            blocks: [
                WorkoutBlock(
                    title: "核心循环",
                    kind: .circuit,
                    rounds: 3,
                    restBetweenExercisesSeconds: 15,
                    restBetweenRoundsSeconds: 45,
                    exercises: [
                        PlannedExercise(name: "鸟狗式", sets: 1, repetitions: "每侧10"),
                        PlannedExercise(name: "登山跑", sets: 1, durationSeconds: 30, trackingMode: .countdown)
                    ]
                )
            ]
        )

        let steps = WorkoutExecutionPlan.makeSteps(from: day)

        XCTAssertEqual(steps.count, 6)
        XCTAssertEqual(steps[0].restAfterSeconds, 15)
        XCTAssertEqual(steps[1].restAfterSeconds, 45)
        XCTAssertEqual(steps[5].restAfterSeconds, 0)
        XCTAssertEqual(steps[4].roundIndex, 3)
    }

    func testExerciseSetsUseExerciseRest() {
        let day = TrainingDay(
            title: "力量",
            recurrence: ScheduleRule(kind: .specificDate, anchorDate: .now, weekdays: [], endDate: nil),
            blocks: [
                WorkoutBlock(
                    title: "普通组",
                    kind: .standard,
                    exercises: [
                        PlannedExercise(name: "平板支撑", sets: 3, durationSeconds: 40, restSeconds: 30, trackingMode: .countdown)
                    ]
                )
            ]
        )

        let steps = WorkoutExecutionPlan.makeSteps(from: day)

        XCTAssertEqual(steps.map(\.restAfterSeconds), [30, 30, 0])
        XCTAssertEqual(steps.map(\.setIndex), [1, 2, 3])
    }
}
