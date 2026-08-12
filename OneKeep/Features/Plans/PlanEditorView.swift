import SwiftUI

struct PlanEditorView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var plan: TrainingPlan
    @State private var validationMessage: String?

    init(plan: TrainingPlan) {
        _plan = State(initialValue: plan)
    }

    var body: some View {
        AIPlanReviewView(plan: $plan)
            .navigationTitle("编辑计划")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                }
            }
            .alert("无法保存", isPresented: Binding(
                get: { validationMessage != nil },
                set: { if !$0 { validationMessage = nil } }
            )) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "计划内容无效")
            }
    }

    private func save() {
        do {
            try PlanDocumentCodec.validate(plans: [plan])
            planLibrary.save(plan)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
