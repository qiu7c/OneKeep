import SwiftUI

struct AIPlanImportView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var sourceText = ""
    @State private var generatedPlan: TrainingPlan?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showsSettings = false
    @State private var provider = AIProviderPreferences.load()

    private let keyStore = KeychainAPIKeyStore()
    private let service = AIPlanImportService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sourceEditor

                if let generatedPlan {
                    previewCard(generatedPlan)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .okCard()
                }
            }
            .padding(20)
        }
        .background(OKColor.background)
        .navigationTitle("AI 整理计划")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("AI 服务设置")
            }
        }
        .sheet(isPresented: $showsSettings, onDismiss: reloadProvider) {
            NavigationStack {
                AISettingsView()
            }
        }
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("粘贴你的计划")
                .font(.headline)

            TextEditor(text: $sourceText)
                .frame(minHeight: 220)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(OKColor.background)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(OKColor.border, lineWidth: 0.5)
                }

            if provider == nil {
                Button("先配置 AI 服务") {
                    showsSettings = true
                }
                .buttonStyle(OKPrimaryButtonStyle())
            } else {
                Button {
                    generate()
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("整理并预览", systemImage: "sparkles")
                    }
                }
                .buttonStyle(OKPrimaryButtonStyle())
                .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
        }
        .okCard()
    }

    private func previewCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("导入预览")
                .font(.headline)
            Text(plan.title)
                .font(.title3.bold())
            Text("\(plan.days.count) 个训练日 · \(plan.days.reduce(0) { $0 + $1.blocks.count }) 个阶段 · \(plan.days.reduce(0) { $0 + $1.exercises.count }) 个动作")
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)

            NavigationLink {
                if let binding = generatedPlanBinding {
                    AIPlanReviewView(plan: binding)
                }
            } label: {
                Label("编辑预览", systemImage: "pencil")
            }
            .frame(minHeight: 44)

            Button {
                planLibrary.save(plan)
                dismiss()
            } label: {
                Label("一键填入计划", systemImage: "checkmark")
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .okCard()
    }

    private var generatedPlanBinding: Binding<TrainingPlan>? {
        guard generatedPlan != nil else { return nil }
        return Binding(
            get: { generatedPlan! },
            set: { generatedPlan = $0 }
        )
    }

    private func reloadProvider() {
        provider = AIProviderPreferences.load()
    }

    private func generate() {
        guard let provider else { return }
        errorMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }
            do {
                guard let key = try keyStore.read(providerID: provider.id), !key.isEmpty else {
                    throw AIImportValidationError(message: "请先保存 API Key")
                }
                generatedPlan = try await service.importPlan(
                    sourceText: sourceText,
                    provider: provider,
                    apiKey: key
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct AIImportValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
