import SwiftUI

struct ProfileEditorView: View {
    private enum Field: Hashable { case nickname, height, weight, notes }

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var profile: UserProfile
    @State private var hasBirthday: Bool
    @State private var birthday: Date
    @State private var height: String
    @State private var weight: String
    @State private var errorMessage: String?

    private let weightUnit = WeightUnit.preferred

    init() {
        let saved = UserProfilePreferences.load()
        _profile = State(initialValue: saved)
        _hasBirthday = State(initialValue: saved.birthday != nil)
        _birthday = State(initialValue: saved.birthday ?? Calendar.current.date(byAdding: .year, value: -18, to: .now) ?? .now)
        _height = State(initialValue: saved.heightCentimeters.map { String($0) } ?? "")
        _weight = State(initialValue: saved.weightKilograms.map(WeightUnit.preferred.string(fromKilograms:)) ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("基本信息", detail: "这些资料只用于你主动允许的 AI 请求和本地记录。")
                VStack(alignment: .leading, spacing: 16) {
                    fieldLabel("昵称")
                    TextField("怎么称呼你", text: $profile.nickname)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .nickname)
                        .profileInputBackground()

                    fieldLabel("性别")
                    Picker("性别", selection: $profile.gender) {
                        ForEach(UserProfile.Gender.allCases, id: \.self) { gender in
                            Text(gender.title).tag(gender)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("填写生日", isOn: $hasBirthday)
                        .font(.subheadline.weight(.semibold))
                        .tint(OKColor.accent)

                    if hasBirthday {
                        HStack(spacing: 12) {
                            Text("生日").font(.subheadline.weight(.semibold))
                            Spacer()
                            DatePicker(
                                "生日",
                                selection: $birthday,
                                in: ...Date.now,
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "zh_CN"))
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 48)
                        .background(OKColor.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .okCard()

                sectionHeader("身体数据", detail: "均为可选项，可以随时回来修改。")
                HStack(spacing: 12) {
                    measurementField(title: "身高", value: $height, unit: "cm", focus: .height)
                    measurementField(title: "体重", value: $weight, unit: weightUnit.symbol, focus: .weight)
                }

                sectionHeader("备注", detail: "例如训练偏好或希望 AI 注意的信息。")
                ZStack(alignment: .topLeading) {
                    if profile.notes.isEmpty {
                        Text("可选，不需要填写饮食或睡眠记录")
                            .font(.subheadline)
                            .foregroundStyle(OKColor.secondaryText)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $profile.notes)
                        .focused($focusedField, equals: .notes)
                        .frame(minHeight: 110, maxHeight: 150)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                }
                .okCard()

                Label("资料仅保存在此设备，可通过完整备份导出。", systemImage: "lock")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .okCard()

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .okCard()
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(OKColor.background)
        .navigationTitle("个人资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save).fontWeight(.semibold)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { focusedField = nil }
            }
        }
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.footnote).foregroundStyle(OKColor.secondaryText)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.semibold))
    }

    private func measurementField(
        title: String,
        value: Binding<String>,
        unit: String,
        focus: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                TextField("未填写", text: value)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: focus)
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(OKColor.secondaryText)
            }
            .profileInputBackground()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .okCard()
    }

    private func save() {
        focusedField = nil
        errorMessage = nil
        let heightText = height.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightText = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedHeight = heightText.isEmpty ? nil : Double(heightText)
        let parsedWeight = weightText.isEmpty ? nil : weightUnit.parseKilograms(weightText)

        if !heightText.isEmpty, parsedHeight == nil {
            errorMessage = "请输入有效身高"
            return
        }
        if let parsedHeight, !(50...300).contains(parsedHeight) {
            errorMessage = "身高需要在 50～300 cm 之间"
            return
        }
        if !weightText.isEmpty, parsedWeight == nil {
            errorMessage = "请输入有效体重（\(weightUnit.symbol)）"
            return
        }
        if let parsedWeight, !(10...500).contains(parsedWeight) {
            errorMessage = "体重需要在 \(weightUnit.formatted(kilograms: 10))～\(weightUnit.formatted(kilograms: 500)) 之间"
            return
        }

        profile.nickname = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
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

private extension View {
    func profileInputBackground() -> some View {
        self
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(OKColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
