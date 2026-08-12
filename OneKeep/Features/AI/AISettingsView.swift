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
    @State private var showsClearConfirmation = false

    private let keyStore = KeychainAPIKeyStore()
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionTitle("服务预设", detail: "切换后会填写接口地址，并读取该服务保存在本机的 API Key。")
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(AIProviderPreset.allCases) { preset in
                        presetButton(preset)
                    }
                }

                sectionTitle("连接配置", detail: "所有内容仅保存在本机；API Key 不会进入备份文件。")
                VStack(spacing: 16) {
                    inputField(title: "服务名称", prompt: "例如 DeepSeek", text: $provider.name)
                    inputField(title: "Base URL", prompt: "https://api.example.com/v1", text: $provider.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    VStack(alignment: .leading, spacing: 7) {
                        Text("API Key").font(.subheadline.weight(.semibold))
                        SecureField("请输入 API Key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 12)
                            .frame(minHeight: 46)
                            .background(OKColor.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if availableModels.isEmpty {
                        inputField(title: "模型", prompt: "填写模型 ID", text: $provider.model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        NavigationLink {
                            AIModelSelectionView(models: availableModels, selection: $provider.model)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("模型").font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                                    Text(provider.model.isEmpty ? "请选择模型" : provider.model)
                                        .font(.subheadline)
                                        .foregroundStyle(OKColor.secondaryText)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(availableModels.count) 个")
                                    .font(.caption)
                                    .foregroundStyle(OKColor.secondaryText)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(OKColor.secondaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Toggle("请求 JSON 模式", isOn: $provider.usesJSONMode)
                        .tint(OKColor.accent)
                }
                .okCard()

                HStack(spacing: 10) {
                    actionButton(
                        title: isLoadingModels ? "正在获取…" : "获取模型",
                        icon: "list.bullet",
                        isLoading: isLoadingModels,
                        action: fetchModels
                    )
                    .disabled(isLoadingModels || isTesting)

                    actionButton(
                        title: isTesting ? "正在测试…" : "测试连接",
                        icon: "network",
                        isLoading: isTesting,
                        action: testConnection
                    )
                    .disabled(isTesting || isLoadingModels)
                }

                if let connectionMessage {
                    statusCard(connectionMessage, icon: "checkmark.circle.fill", color: .green)
                }
                if let errorMessage {
                    statusCard(errorMessage, icon: "exclamationmark.circle.fill", color: .red)
                }

                Text("系统提示词由 OneKeep 内部维护。部分兼容服务不支持 JSON 模式，遇到请求格式错误时可关闭此选项。")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)

                Button(role: .destructive) {
                    showsClearConfirmation = true
                } label: {
                    Label("清空 AI 配置", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(OKColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(OKColor.border, lineWidth: 0.5)
                        }
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(OKColor.background)
        .navigationTitle("AI 服务")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save).fontWeight(.semibold)
            }
        }
        .confirmationDialog("清空 AI 配置？", isPresented: $showsClearConfirmation, titleVisibility: .visible) {
            Button("清空配置和全部 API Key", role: .destructive, action: clearConfiguration)
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除当前配置以及所有预设服务保存在本机钥匙串中的 API Key，此操作无法撤销。")
        }
        .onAppear(perform: loadKeyIfNeeded)
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(detail).font(.footnote).foregroundStyle(OKColor.secondaryText)
        }
    }

    private func presetButton(_ preset: AIProviderPreset) -> some View {
        let isSelected = AIProviderPreset.matching(provider) == preset
        return Button { apply(preset) } label: {
            HStack(spacing: 10) {
                Image(systemName: presetIcon(preset)).frame(width: 22)
                Text(preset.title).font(.subheadline.weight(.medium)).lineLimit(1)
                Spacer(minLength: 4)
                if isSelected { Image(systemName: "checkmark.circle.fill").font(.caption) }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? OKColor.border.opacity(0.55) : OKColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? OKColor.accent.opacity(0.55) : OKColor.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func inputField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .padding(.horizontal, 12)
                .frame(minHeight: 46)
                .background(OKColor.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func actionButton(
        title: String,
        icon: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().controlSize(.small) }
                else { Image(systemName: icon) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(.primary)
            .background(OKColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(OKColor.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func statusCard(_ text: String, icon: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(OKColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                if !models.contains(where: { $0.id == provider.model }) { provider.model = models[0].id }
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
                let result = try await OpenAICompatibleClient().testConnection(configuration: try validatedConfiguration())
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

    private func clearConfiguration() {
        errorMessage = nil
        do {
            try keyStore.deleteAll()
            AIProviderPreferences.clear()
            provider = AIProviderConfiguration()
            apiKey = ""
            availableModels = []
            connectionMessage = "AI 配置和本机 API Key 已清空"
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
        return .init(baseURL: provider.baseURL, model: provider.model, apiKey: apiKey, usesJSONMode: provider.usesJSONMode)
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
            .listRowSeparator(.hidden)
            .listRowBackground(OKColor.surface)
        }
        .listStyle(.plain)
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
