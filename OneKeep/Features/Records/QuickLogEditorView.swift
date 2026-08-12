import CoreData
import SwiftUI

struct QuickLogEditorView: View {
    let kind: QuickLogKind

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date.now
    @State private var note = ""
    @State private var value = ""
    @State private var sleepStart = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: .now) ?? .now
    @State private var sleepEnd = Calendar.current.date(byAdding: .hour, value: 8, to: .now) ?? .now
    @State private var errorMessage: String?
    private let weightUnit = WeightUnit.preferred

    var body: some View {
        Form {
            Section(kind.title) {
                DatePicker("记录时间", selection: $date)

                switch kind {
                case .food:
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                    Text("简短写下吃了什么即可，不计算热量。")
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                case .sleep:
                    DatePicker("入睡", selection: $sleepStart)
                    DatePicker("起床", selection: $sleepEnd)
                    TextField("备注（可选）", text: $note)
                case .body:
                    HStack {
                        TextField("体重", text: $value)
                            .keyboardType(.decimalPad)
                        Text(weightUnit.symbol)
                            .foregroundStyle(OKColor.secondaryText)
                    }
                    TextField("围度、体态等备注（可选）", text: $note)
                case .note:
                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                }
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
        .navigationTitle("记录\(kind.title)")
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
        let normalizedNote: String
        let numericValue: Double?

        switch kind {
        case .food, .note:
            normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            numericValue = nil
            guard !normalizedNote.isEmpty else {
                errorMessage = "请输入记录内容"
                return
            }
        case .sleep:
            guard sleepEnd > sleepStart else {
                errorMessage = "起床时间需要晚于入睡时间"
                return
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let extra = note.trimmingCharacters(in: .whitespacesAndNewlines)
            normalizedNote = "\(formatter.string(from: sleepStart))–\(formatter.string(from: sleepEnd))" + (extra.isEmpty ? "" : " · \(extra)")
            numericValue = sleepEnd.timeIntervalSince(sleepStart) / 3600
        case .body:
            guard let parsed = weightUnit.parseKilograms(value), (10...500).contains(parsed) else {
                errorMessage = "请输入有效体重"
                return
            }
            normalizedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            numericValue = parsed
        }

        let object = NSEntityDescription.insertNewObject(forEntityName: "QuickLogEntity", into: context)
        object.setValue(UUID(), forKey: "id")
        object.setValue(kind.rawValue, forKey: "kind")
        object.setValue(date, forKey: "createdAt")
        object.setValue(normalizedNote, forKey: "note")
        object.setValue(numericValue, forKey: "value")

        do {
            try context.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
