import CoreData
import SwiftUI

struct WorkoutHistoryDetailView: View {
    let sessionID: UUID
    let title: String
    let startedAt: Date
    let endedAt: Date?

    @FetchRequest private var sets: FetchedResults<NSManagedObject>
    private let weightUnit = WeightUnit.preferred

    init(sessionID: UUID, title: String, startedAt: Date, endedAt: Date?) {
        self.sessionID = sessionID
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        let request = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        request.predicate = NSPredicate(format: "sessionID == %@", sessionID as NSUUID)
        request.sortDescriptors = [
            NSSortDescriptor(key: "stepIndex", ascending: true),
            NSSortDescriptor(key: "setIndex", ascending: true)
        ]
        _sets = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        List {
            Section("训练摘要") {
                LabeledContent("开始", value: startedAt.formatted(date: .abbreviated, time: .shortened))
                if let endedAt {
                    LabeledContent("结束", value: endedAt.formatted(date: .omitted, time: .shortened))
                    LabeledContent("总时长", value: durationText(startedAt, endedAt))
                }
                LabeledContent("完成组数", value: String(completedSets.count))
                if skippedSets.count > 0 {
                    LabeledContent("跳过组数", value: String(skippedSets.count))
                }
            }

            ForEach(exerciseNames, id: \.self) { name in
                Section(name) {
                    ForEach(Array(setsForExercise(name).enumerated()), id: \.element.objectID) { index, set in
                        HStack {
                            Text("第 \((set.value(forKey: "setIndex") as? NSNumber)?.intValue ?? index + 1) 组")
                            Spacer()
                            Text(isSkipped(set) ? "已跳过" : setDescription(set))
                                .foregroundStyle(OKColor.secondaryText)
                        }
                    }
                    if setsForExercise(name).contains(where: { !isSkipped($0) }) {
                        NavigationLink {
                            ExerciseHistoryView(exerciseName: name)
                        } label: {
                            Label("查看这个动作的历史趋势", systemImage: "chart.xyaxis.line")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var exerciseNames: [String] {
        var seen = Set<String>()
        return sets.compactMap { $0.value(forKey: "exerciseName") as? String }.filter { seen.insert($0).inserted }
    }

    private var completedSets: [NSManagedObject] { sets.filter { !isSkipped($0) } }
    private var skippedSets: [NSManagedObject] { sets.filter { isSkipped($0) } }

    private func isSkipped(_ set: NSManagedObject) -> Bool {
        (set.value(forKey: "isSkipped") as? NSNumber)?.boolValue ?? false
    }

    private func setsForExercise(_ name: String) -> [NSManagedObject] {
        sets.filter { ($0.value(forKey: "exerciseName") as? String) == name }
    }

    private func setDescription(_ set: NSManagedObject) -> String {
        var values: [String] = []
        if let reps = (set.value(forKey: "repetitions") as? NSNumber)?.intValue { values.append("\(reps) 次") }
        if let weight = (set.value(forKey: "weightKilograms") as? NSNumber)?.doubleValue { values.append(weightUnit.formatted(kilograms: weight)) }
        if let duration = (set.value(forKey: "durationSeconds") as? NSNumber)?.intValue { values.append("\(duration) 秒") }
        return values.isEmpty ? "已完成" : values.joined(separator: " · ")
    }

    private func durationText(_ start: Date, _ end: Date) -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        return "\(seconds / 60) 分 \(seconds % 60) 秒"
    }
}

struct ExerciseHistoryView: View {
    let exerciseName: String
    @FetchRequest private var sets: FetchedResults<NSManagedObject>
    private let weightUnit = WeightUnit.preferred

    init(exerciseName: String) {
        self.exerciseName = exerciseName
        let request = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        request.predicate = NSPredicate(format: "exerciseName == %@ AND isSkipped == NO", exerciseName)
        request.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        _sets = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        List {
            Section("个人记录") {
                LabeledContent("最高重量", value: bestWeight.map(weightUnit.formatted(kilograms:)) ?? "暂无")
                LabeledContent("最高次数", value: bestRepetitions.map { "\($0) 次" } ?? "暂无")
                LabeledContent("累计完成", value: "\(sets.count) 组")
            }
            Section("最近表现") {
                ForEach(sets, id: \.objectID) { set in
                    HStack {
                        if let date = set.value(forKey: "completedAt") as? Date {
                            Text(date, format: .dateTime.month().day().year())
                        }
                        Spacer()
                        Text(historyDescription(set))
                            .foregroundStyle(OKColor.secondaryText)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bestWeight: Double? {
        sets.compactMap { ($0.value(forKey: "weightKilograms") as? NSNumber)?.doubleValue }.max()
    }

    private var bestRepetitions: Int? {
        sets.compactMap { ($0.value(forKey: "repetitions") as? NSNumber)?.intValue }.max()
    }

    private func historyDescription(_ set: NSManagedObject) -> String {
        var values: [String] = []
        if let weight = (set.value(forKey: "weightKilograms") as? NSNumber)?.doubleValue { values.append(weightUnit.formatted(kilograms: weight)) }
        if let reps = (set.value(forKey: "repetitions") as? NSNumber)?.intValue { values.append("\(reps) 次") }
        if let duration = (set.value(forKey: "durationSeconds") as? NSNumber)?.intValue { values.append("\(duration) 秒") }
        return values.isEmpty ? "已完成" : values.joined(separator: " · ")
    }
}
