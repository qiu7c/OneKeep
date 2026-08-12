import SwiftUI

struct PlanComposerView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var dayTitle = "训练日"
    @State private var startDate = Date.now
    @State private var hasEndDate = false
    @State private var endDate = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now
    @State private var exercises: [PlannedExercise] = []
    @State private var showsExerciseEditor = false
    @State private var recurrenceKind: ScheduleRule.Kind = .weekly
    @State private var selectedWeekdays: Set<Int> = [Calendar.current.component(.weekday, from: .now)]

    private var canSave: Bool {
        let hasValidSchedule = recurrenceKind == .specificDate || !selectedWeekdays.isEmpty
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !exercises.isEmpty &&
            hasValidSchedule
    }

    var body: some View {
        Form {
            Section("计划") {
                TextField("计划名称", text: $title)
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)

                Picker("日程方式", selection: $recurrenceKind) {
                    ForEach(ScheduleRule.Kind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }

                if recurrenceKind != .specificDate {
                    WeekdayPicker(selection: $selectedWeekdays)
                }

                Toggle("设置结束日期", isOn: $hasEndDate)
                if hasEndDate {
                    DatePicker("结束日期", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
            }

            Section("训练日") {
                TextField("训练日名称", text: $dayTitle)

                ForEach(exercises) { exercise in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                            Text("\(exercise.sets) 组 · 休息 \(exercise.restSeconds) 秒")
                                .font(.caption)
                                .foregroundStyle(OKColor.secondaryText)
                        }
                        Spacer()
                    }
                }
                .onDelete { offsets in
                    exercises.remove(atOffsets: offsets)
                }

                Button {
                    showsExerciseEditor = true
                } label: {
                    Label("添加动作", systemImage: "plus")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("新建计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .disabled(!canSave)
            }
        }
        .sheet(isPresented: $showsExerciseEditor) {
            NavigationStack {
                ExerciseEditorView { exercise in
                    exercises.append(exercise)
                }
            }
        }
    }

    private func save() {
        let plan = TrainingPlan(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            days: [
                TrainingDay(
                    title: dayTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "训练日" : dayTitle,
                    recurrence: ScheduleRule(
                        kind: recurrenceKind,
                        anchorDate: startDate,
                        weekdays: recurrenceKind == .specificDate ? [] : selectedWeekdays,
                        endDate: hasEndDate ? endDate : nil
                    ),
                    blocks: [
                        WorkoutBlock(
                            title: "训练",
                            kind: .standard,
                            exercises: exercises
                        )
                    ]
                )
            ]
        )
        planLibrary.save(plan)
        dismiss()
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    private let weekdays: [(value: Int, title: String)] = [
        (2, "一"), (3, "二"), (4, "三"), (5, "四"), (6, "五"), (7, "六"), (1, "日")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("训练星期")
                .font(.subheadline)

            HStack(spacing: 8) {
                ForEach(weekdays, id: \.value) { weekday in
                    Button {
                        if selection.contains(weekday.value) {
                            selection.remove(weekday.value)
                        } else {
                            selection.insert(weekday.value)
                        }
                    } label: {
                        Text(weekday.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selection.contains(weekday.value) ? OKColor.background : .primary)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background(selection.contains(weekday.value) ? OKColor.accent : OKColor.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("星期\(weekday.title)")
                    .accessibilityAddTraits(selection.contains(weekday.value) ? .isSelected : [])
                }
            }
        }
    }
}
