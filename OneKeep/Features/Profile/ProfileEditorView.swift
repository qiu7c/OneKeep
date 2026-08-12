import SwiftUI

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var profile = UserProfilePreferences.load()
    @State private var hasBirthday = UserProfilePreferences.load().birthday != nil
    @State private var birthday = UserProfilePreferences.load().birthday ?? Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now
    @State private var height = UserProfilePreferences.load().heightCentimeters.map { String($0) } ?? ""
    @State private var weight = UserProfilePreferences.load().weightKilograms.map(WeightUnit.preferred.string(fromKilograms:)) ?? ""
    @State private var errorMessage: String?
    private let weightUnit = WeightUnit.preferred

    var body: some View {
        Form {
            Section("基本信息") {
                TextField("昵称", text: $profile.nickname)

                Picker("性别", selection: $profile.gender) {
                    ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                        Text(gender.title).tag(gender)
                    }
                }

                Toggle("填写生日", isOn: $hasBirthday)
                if hasBirthday {
                    DatePicker("生日", selection: $birthday, in: ...Date.now, displayedComponents: .date)
                }
            }

            Section("身体数据") {
                HStack {
                    TextField("身高", text: $height)
                        .keyboardType(.decimalPad)
                    Text("cm")
                        .foregroundStyle(OKColor.secondaryText)
                }
                HStack {
                    TextField("体重", text: $weight)
                        .keyboardType(.decimalPad)
                    Text(weightUnit.symbol)
                        .foregroundStyle(OKColor.secondaryText)
                }
            }

            Section("备注") {
                TextEditor(text: $profile.notes)
                    .frame(minHeight: 100)
            }

            Section {
                Label("资料只保存在此设备，可通过完整备份导出。", systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
            }
        }
    }

    private func save() {
        let parsedHeight = Double(height)
        let parsedWeight = weight.isEmpty ? nil : weightUnit.parseKilograms(weight)

        if let parsedHeight, !(50...300).contains(parsedHeight) {
            errorMessage = "身高需要在 50～300 cm 之间"
            return
        }
        if !weight.isEmpty, parsedWeight == nil {
            errorMessage = "请输入有效体重（\(weightUnit.symbol)）"
            return
        }
        if let parsedWeight, !(10...500).contains(parsedWeight) {
            errorMessage = "体重需要在 \(weightUnit.formatted(kilograms: 10))～\(weightUnit.formatted(kilograms: 500)) 之间"
            return
        }

        profile.birthday = hasBirthday ? birthday : nil
        profile.heightCentimeters = parsedHeight
        profile.weightKilograms = parsedWeight

        do {
            try UserProfilePreferences.save(profile)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
