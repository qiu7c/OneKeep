import SwiftUI

struct AIPlanReviewView: View {
    @Binding var plan: TrainingPlan

    var body: some View {
        Form {
            Section("计划") {
                TextField("名称", text: $plan.title)
                DatePicker("开始日期", selection: $plan.startDate, displayedComponents: .date)
            }

            ForEach($plan.days) { $day in
                Section {
                    TextField("训练日名称", text: $day.title)

                    ForEach($day.blocks) { $block in
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("阶段名称", text: $block.title)
                                .font(.headline)

                            Stepper("循环：\(block.rounds) 轮", value: $block.rounds, in: 1...100)

                            ForEach($block.exercises) { $exercise in
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("动作名称", text: $exercise.name)
                                    Stepper("\(exercise.sets) 组", value: $exercise.sets, in: 1...100)
                                    Stepper("休息 \(exercise.restSeconds) 秒", value: $exercise.restSeconds, in: 0...600, step: 15)
                                }
                                .padding(.vertical, 6)
                            }
                            .onDelete { offsets in
                                block.exercises.remove(atOffsets: offsets)
                            }
                        }
                    }
                } header: {
                    Text(day.title)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("编辑预览")
        .navigationBarTitleDisplayMode(.inline)
    }
}
