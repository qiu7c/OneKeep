import SwiftUI

struct ExerciseEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (PlannedExercise) -> Void

    @State private var name = ""
    @State private var sets = 3
    @State private var repetitions = "10"
    @State private var weight = ""
    @State private var restSeconds = 60
    @State private var videoURL = ""
    @State private var trackingMode: PlannedExercise.TrackingMode = .repetitions
    @State private var durationSeconds = 30
    @State private var notes = ""
    @State private var libraryID: String?
    private let weightUnit = WeightUnit.preferred

    var body: some View {
        Form {
            Section("动作库") {
                NavigationLink {
                    ExerciseLibraryView(onSelect: applyLibraryItem)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(libraryID == nil ? "从动作库选择" : "已关联动作库")
                            Text(libraryID.flatMap { ExerciseLibraryCatalog.item(id: $0)?.name } ?? "自动填写动作要点和默认记录方式")
                                .font(.footnote)
                                .foregroundStyle(OKColor.secondaryText)
                        }
                        Spacer()
                    }
                }
            }

            Section("动作") {
                TextField("动作名称", text: $name)
                Picker("记录方式", selection: $trackingMode) {
                    ForEach(PlannedExercise.TrackingMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Stepper("组数：\(sets)", value: $sets, in: 1...100)
                if trackingMode == .repetitions {
                    TextField("次数或区间", text: $repetitions)
                } else if trackingMode == .countdown {
                    Stepper("每组时长：\(durationSeconds) 秒", value: $durationSeconds, in: 5...3600, step: 5)
                }
                TextField("计划重量（\(weightUnit.symbol)，可选）", text: $weight)
                    .keyboardType(.decimalPad)
                if !weight.isEmpty, weightUnit.parseKilograms(weight) == nil {
                    Label("请输入有效的重量", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                Stepper("组间休息：\(restSeconds) 秒", value: $restSeconds, in: 0...600, step: 15)
                TextField("动作要点（可选）", text: $notes, axis: .vertical)
            }

            Section("视频链接") {
                TextField("https://", text: $videoURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !videoURL.isEmpty, VideoSource(urlString: videoURL) == nil {
                    Label("链接格式无效", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if let source = VideoSource(urlString: videoURL) {
                    ExerciseVideoView(source: source)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("添加动作")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("添加", action: save)
                    .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (videoURL.isEmpty || VideoSource(urlString: videoURL) != nil) &&
        (weight.isEmpty || weightUnit.parseKilograms(weight) != nil)
    }

    private func save() {
        let exercise = PlannedExercise(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sets: sets,
            repetitions: repetitions.trimmingCharacters(in: .whitespacesAndNewlines),
            plannedWeightKilograms: weight.isEmpty ? nil : weightUnit.parseKilograms(weight),
            durationSeconds: trackingMode == .countdown ? durationSeconds : nil,
            restSeconds: restSeconds,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
            videoURL: videoURL.isEmpty ? nil : URL(string: videoURL),
            trackingMode: trackingMode,
            libraryID: libraryID
        )
        onSave(exercise)
        dismiss()
    }

    private func applyLibraryItem(_ item: ExerciseLibraryItem) {
        libraryID = item.id
        name = item.name
        trackingMode = item.defaultTrackingMode
        durationSeconds = item.defaultDurationSeconds ?? 30
        restSeconds = item.defaultRestSeconds
        notes = item.instructions.joined(separator: "；")
        videoURL = item.videoURL?.absoluteString ?? ""
    }
}
