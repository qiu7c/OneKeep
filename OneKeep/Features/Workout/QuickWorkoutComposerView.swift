import SwiftUI

struct QuickWorkoutComposerView: View {
    @State private var title = "临时训练"
    @State private var exercises: [PlannedExercise] = []

    var body: some View {
        Form {
            Section("训练") {
                TextField("名称", text: $title)
                if exercises.isEmpty {
                    Text("从动作库添加动作，不会修改现有计划。训练完成后仍会保存历史记录。")
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                }
                ForEach($exercises) { $exercise in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(exercise.name).font(.headline)
                        Stepper("\(exercise.sets) 组", value: $exercise.sets, in: 1...20)
                        Stepper("休息 \(exercise.restSeconds) 秒", value: $exercise.restSeconds, in: 0...600, step: 15)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { exercises.remove(atOffsets: $0) }
            }

            Section {
                NavigationLink {
                    ExerciseLibraryView { item in exercises.append(plannedExercise(item)) }
                } label: {
                    Label("从动作库添加", systemImage: "plus")
                }
            }

            if !exercises.isEmpty {
                Section {
                    NavigationLink {
                        WorkoutView(trainingDay: trainingDay)
                    } label: {
                        Label("开始临时训练", systemImage: "play.fill")
                    }
                    .buttonStyle(OKPrimaryButtonStyle())
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("临时训练")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trainingDay: TrainingDay {
        TrainingDay(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "临时训练" : title,
            recurrence: ScheduleRule(kind: .specificDate, anchorDate: .now, weekdays: [], endDate: .now),
            blocks: [WorkoutBlock(title: "临时训练", kind: .standard, exercises: exercises)]
        )
    }

    private func plannedExercise(_ item: ExerciseLibraryItem) -> PlannedExercise {
        PlannedExercise(
            name: item.name,
            sets: 1,
            repetitions: item.defaultTrackingMode == .repetitions ? "10" : nil,
            durationSeconds: item.defaultDurationSeconds,
            restSeconds: item.defaultRestSeconds,
            notes: item.instructions.joined(separator: "；"),
            videoURL: item.videoURL,
            trackingMode: item.defaultTrackingMode,
            libraryID: item.id
        )
    }
}
