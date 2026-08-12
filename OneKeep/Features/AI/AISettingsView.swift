import SwiftUI

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var provider = AIProviderPreferences.load() ?? AIProviderConfiguration()
    @State private var apiKey = ""
    @State private var errorMessage: String?
    @State private var hasLoadedKey = false
    @State private var isTesting = false
    @State private var connectionMessage: String?
    @State private var isLoadingModels = false
    @State private var availableModels: [OpenAICompatibleClient.AvailableModel] = []

    private let keyStore = KeychainAPIKeyStore()

    var body: some View {
        Form {
            Section("服务预设") {
                ForEach(AIProviderPreset.allCases) { preset in
                    Button { apply(preset) } label: {
                        HStack {
                            Image(systemName: presetIcon(preset)).frame(width: 28)
                            Text(preset.title).foregroundStyle(.primary)
                            Spacer()
                            if AIProviderPreset.matching(provider) == preset {
                                Image(systemName: "checkmark").foregroundStyle(OKColor.accent)
                            }
                        }
                    }
                }
                Text("切换预设会自动填写对应 Base URL，并读取该服务单独保存在钥匙串中的 API Key。")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
            }

            Section("服务") {
                TextField("名称", text: $provider.name)
                TextField("Base URL", text: $provider.baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("API Key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Toggle("请求 JSON 模式", isOn: $provider.usesJSONMode)

                HStack {
                    Text("模型")
                    Spacer()
                    Text(provider.model.isEmpty ? "未选择" : provider.model)
                        .foregroundStyle(OKColor.secondaryText)
                        .lineLimit(1)
                }

                if availableModels.isEmpty {
                    TextField("手动填写模型名称", text: $provider.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    NavigationLink {
                        AIModelSelectionView(models: availableModels, selection: $provider.model)
                    } label: {
                        Label("从 \(availableModels.count) 个可用模型中选择", systemImage: "list.bullet")
                    }
                }

                Button(action: fetchModels) {
                    HStack {
                        if isLoadingModels { ProgressView().controlSize(.small) }
                        Text(isLoadingModels ? "正在获取模型列表…" : "获取可用模型")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(isLoadingModels || isTesting)

                Button(action: testConnection) {
                    HStack {
                        if isTesting { ProgressView().controlSize(.small) }
                        Text(isTesting ? "正在连接并等待模型响应…" : "测试 API 连接")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(isTesting)

                if let connectionMessage {
                    Label(connectionMessage, systemImage: "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                }
            }

            Section {
                Text("系统提示词由 OneKeep 内部维护。API Key 只保存在本机 Keychain，不会进入 Core Data、日志或备份文件。部分兼容服务不支持 JSON 模式，遇到请求错误时可以关闭。")
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

    private func apply(_ preset: AIProviderPreset) {
        let previousKey = apiKey
        let wasSameService = AIProviderPreset.matching(provider) == preset
        provider = preset.configuration
        availableModels = []
        connectionMessage = nil
        errorMessage = nil
        do {
            apiKey = try keyStore.read(providerID: provider.id) ?? (wasSameService ? previousKey : "")
        } catch {
            apiKey = ""
            errorMessage = error.localizedDescription
        }
    }

    private func fetchModels() {
        errorMessage = nil
        connectionMessage = nil
        isLoadingModels = true
        Task {
            defer { isLoadingModels = false }
            do {
                let models = try await OpenAICompatibleClient().listModels(baseURL: provider.baseURL, apiKey: apiKey)
                guard !models.isEmpty else { throw PresentedValidationError(message: "服务没有返回任何模型") }
                availableModels = models
                if !models.contains(where: { $0.id == provider.model }) {
                    provider.model = models[0].id
                }
                connectionMessage = "已获取 \(models.count) 个可用模型"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func testConnection() {
        errorMessage = nil
        connectionMessage = nil
        isTesting = true
        Task {
            defer { isTesting = false }
            do {
                let configuration = try validatedConfiguration()
                let result = try await OpenAICompatibleClient().testConnection(configuration: configuration)
                connectionMessage = "连接成功 · \(result.model) · \(result.latencyMilliseconds) ms"
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func save() {
        do {
            _ = try validatedConfiguration()

            try AIProviderPreferences.save(provider)
            try keyStore.save(apiKey, providerID: provider.id)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func validatedConfiguration() throws -> OpenAICompatibleClient.Configuration {
        _ = try OpenAICompatibleClient.endpoint(baseURL: provider.baseURL)
        guard !provider.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAICompatibleClient.ClientError.invalidModel
        }
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PresentedValidationError(message: "API Key 不能为空")
        }
        return .init(
            baseURL: provider.baseURL,
            model: provider.model,
            apiKey: apiKey,
            usesJSONMode: provider.usesJSONMode
        )
    }

    private func presetIcon(_ preset: AIProviderPreset) -> String {
        switch preset {
        case .deepSeek: return "brain"
        case .openAI: return "sparkles"
        case .qwen: return "cloud"
        case .gemini: return "diamond"
        }
    }
}

private struct AIModelSelectionView: View {
    let models: [OpenAICompatibleClient.AvailableModel]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        List(filteredModels) { model in
            Button {
                selection = model.id
                dismiss()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.id).foregroundStyle(.primary)
                        if let owner = model.ownedBy, !owner.isEmpty {
                            Text(owner).font(.caption).foregroundStyle(OKColor.secondaryText)
                        }
                    }
                    Spacer()
                    if selection == model.id { Image(systemName: "checkmark").foregroundStyle(OKColor.accent) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("选择模型")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索模型 ID")
    }

    private var filteredModels: [OpenAICompatibleClient.AvailableModel] {
        let value = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? models : models.filter { $0.id.localizedCaseInsensitiveContains(value) }
    }
}

private struct PresentedValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
