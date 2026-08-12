import SwiftUI

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var provider = AIProviderPreferences.load() ?? AIProviderConfiguration()
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @State private var hasLoadedKey = false

    private let keyStore = KeychainAPIKeyStore()

    var body: some View {
        Form {
            Section("服务") {
                TextField("名称", text: $provider.name)
                TextField("Base URL", text: $provider.baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("模型名称", text: $provider.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("请求 JSON 模式", isOn: $provider.usesJSONMode)
            }

            Section {
                Text("API Key 只保存在本机 Keychain，不会进入 Core Data、日志或备份文件。部分兼容服务不支持 JSON 模式，遇到请求错误时可以关闭。")
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
        .navigationTitle("AI 服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
            }
        }
        .onAppear(perform: loadKeyIfNeeded)
    }

    private func loadKeyIfNeeded() {
        guard !hasLoadedKey else { return }
        hasLoadedKey = true
        do {
            apiKey = try keyStore.read(providerID: provider.id) ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        do {
            _ = try OpenAICompatibleClient.endpoint(baseURL: provider.baseURL)
            guard !provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw OpenAICompatibleClient.ClientError.invalidModel
            }
            guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PresentedValidationError(message: "API Key 不能为空")
            }

            try AIProviderPreferences.save(provider)
            try keyStore.save(apiKey, providerID: provider.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct PresentedValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
