import SwiftUI

struct AIPlanReviewView: View {
    @Binding var plan: TrainingPlan

    var body: some View {
        Form {
            Section("计划") {
                TextField("名称", text: $plan.title)
                DatePicker("开始日期", selection: $plan.startDate, displayedComponents: .date)
                Toggle("设置结束日期", isOn: hasEndDate)
                if plan.endDate != nil {
                    DatePicker("结束日期", selection: endDate, in: plan.startDate..., displayedComponents: .date)
                }
            }

            ForEach($plan.days) { $day in
                Section {
                    TextField("训练日名称", text: $day.title)
                    Picker("日程方式", selection: $day.recurrence.kind) {
                        ForEach(ScheduleRule.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    DatePicker("日程基准日", selection: $day.recurrence.anchorDate, displayedComponents: .date)
                    if day.recurrence.kind != .specificDate {
                        WeekdayPicker(selection: $day.recurrence.weekdays)
                    }

                    ForEach($day.blocks) { $block in
                        DisclosureGroup {
                            Picker("阶段类型", selection: $block.kind) {
                                ForEach(WorkoutBlock.Kind.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            Stepper("循环 \(block.rounds) 轮", value: $block.rounds, in: 1...100)
                            Stepper("动作间休息 \(block.restBetweenExercisesSeconds) 秒", value: $block.restBetweenExercisesSeconds, in: 0...1800, step: 15)
                            Stepper("轮间休息 \(block.restBetweenRoundsSeconds) 秒", value: $block.restBetweenRoundsSeconds, in: 0...1800, step: 15)

                            ForEach($block.exercises) { $exercise in
                                DisclosureGroup {
                                    Picker("记录方式", selection: $exercise.trackingMode) {
                                        ForEach(PlannedExercise.TrackingMode.allCases, id: \.self) { Text($0.title).tag($0) }
                                    }
                                    Stepper("组数 \(exercise.sets)", value: $exercise.sets, in: 1...100)
                                    TextField("次数或区间", text: optionalString($exercise.repetitions))
                                    TextField("计划重量 kg", text: optionalDouble($exercise.plannedWeightKilograms))
                                        .keyboardType(.decimalPad)
                                    TextField("动作时长（秒）", text: optionalInt($exercise.durationSeconds))
                                        .keyboardType(.numberPad)
                                    Stepper("组间休息 \(exercise.restSeconds) 秒", value: $exercise.restSeconds, in: 0...1800, step: 15)
                                    TextField("动作要点", text: optionalString($exercise.notes), axis: .vertical)
                                    TextField("视频链接", text: optionalURL($exercise.videoURL))
                                        .keyboardType(.URL)
                                        .textInputAutocapitalization(.never)
                                    Button("删除此动作", role: .destructive) {
                                        block.exercises.removeAll { $0.id == exercise.id }
                                    }
                                } label: {
                                    TextField("动作名称", text: $exercise.name)
                                }
                            }

                            Button {
                                block.exercises.append(PlannedExercise(name: "新动作", sets: 1))
                            } label: {
                                Label("添加动作", systemImage: "plus")
                            }
                        } label: {
                            HStack {
                                TextField("阶段名称", text: $block.title)
                                Text("\(block.exercises.count) 个动作")
                                    .font(.caption)
                                    .foregroundStyle(OKColor.secondaryText)
                            }
                        }
                    }
                    .onDelete { day.blocks.remove(atOffsets: $0) }

                    Button {
                        day.blocks.append(WorkoutBlock(title: "新阶段", kind: .standard, exercises: []))
                    } label: {
                        Label("添加训练阶段", systemImage: "plus")
                    }
                } header: {
                    Text(day.title)
                }
            }
            .onDelete { plan.days.remove(atOffsets: $0) }

            Section {
                Button(action: addDay) { Label("添加训练日", systemImage: "plus") }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("完整编辑器")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasEndDate: Binding<Bool> {
        Binding(
            get: { plan.endDate != nil },
            set: { enabled in
                plan.endDate = enabled ? (Calendar.current.date(byAdding: .month, value: 1, to: plan.startDate) ?? plan.startDate) : nil
                for index in plan.days.indices { plan.days[index].recurrence.endDate = plan.endDate }
            }
        )
    }

    private var endDate: Binding<Date> {
        Binding(
            get: { plan.endDate ?? plan.startDate },
            set: { value in
                plan.endDate = value
                for index in plan.days.indices { plan.days[index].recurrence.endDate = value }
            }
        )
    }

    private func optionalString(_ value: Binding<String?>) -> Binding<String> {
        Binding(get: { value.wrappedValue ?? "" }, set: { value.wrappedValue = $0.isEmpty ? nil : $0 })
    }

    private func optionalDouble(_ value: Binding<Double?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue.map { String($0) } ?? "" },
            set: { value.wrappedValue = $0.isEmpty ? nil : Double($0) }
        )
    }

    private func optionalInt(_ value: Binding<Int?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue.map { String($0) } ?? "" },
            set: { value.wrappedValue = $0.isEmpty ? nil : Int($0) }
        )
    }

    private func optionalURL(_ value: Binding<URL?>) -> Binding<String> {
        Binding(
            get: { value.wrappedValue?.absoluteString ?? "" },
            set: { value.wrappedValue = $0.isEmpty ? nil : URL(string: $0) }
        )
    }

    private func addDay() {
        plan.days.append(TrainingDay(
            title: "新训练日",
            recurrence: ScheduleRule(
                kind: .weekly,
                anchorDate: plan.startDate,
                weekdays: [Calendar.current.component(.weekday, from: plan.startDate)],
                endDate: plan.endDate
            ),
            blocks: []
        ))
    }
}
