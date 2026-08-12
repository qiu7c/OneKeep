import SwiftUI

struct WorkoutSettingsView: View {
    @State private var preferences = WorkoutPreferencesStore.load()
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("单位") {
                Picker("重量单位", selection: $preferences.weightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text("\(unit.title)（\(unit.symbol)）").tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                Text("切换只改变显示和输入单位，训练计划、历史记录和备份仍统一按公斤保存，不会改变原始重量。")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
            }

            Section("计时与反馈") {
                Toggle("计时结束通知", isOn: $preferences.timerNotifications)
                Toggle("完成动作时振动", isOn: $preferences.hapticFeedback)
                Toggle("完成一组后自动开始休息", isOn: $preferences.autoStartRest)
            }

            Section {
                Text("关闭自动休息后，应用仍会显示计划休息时长，由你手动开始。所有设置仅保存在本机，并包含在完整 ZIP 备份中。")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("训练设置")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: preferences) { value in
            do {
                try WorkoutPreferencesStore.save(value)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
