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

    var body: some View {
        Form {
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
                TextField("计划重量（kg，可选）", text: $weight)
                    .keyboardType(.decimalPad)
                Stepper("组间休息：\(restSeconds) 秒", value: $restSeconds, in: 0...600, step: 15)
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
        (videoURL.isEmpty || VideoSource(urlString: videoURL) != nil)
    }

    private func save() {
        let exercise = PlannedExercise(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            sets: sets,
            repetitions: repetitions.trimmingCharacters(in: .whitespacesAndNewlines),
            plannedWeightKilograms: Double(weight),
            durationSeconds: trackingMode == .countdown ? durationSeconds : nil,
            restSeconds: restSeconds,
            videoURL: videoURL.isEmpty ? nil : URL(string: videoURL),
            trackingMode: trackingMode
        )
        onSave(exercise)
        dismiss()
    }
}
