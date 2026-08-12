import SwiftUI

struct AIPlanImportView: View {
    private enum RequestState: Equatable {
        case idle
        case chatting
        case generating

        var text: String? {
            switch self {
            case .idle: return nil
            case .chatting: return "正在等待 AI 回复，DeepSeek 忙时可能需要一段时间…"
            case .generating: return "正在整理完整对话并生成计划预览…"
            }
        }
    }

    private enum FailedAction: Equatable {
        case chat(String)
        case generatePlan

        var buttonTitle: String {
            switch self {
            case .chat: return "重新发送"
            case .generatePlan: return "重新生成计划预览"
            }
        }
    }

    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var messages = AIConversationPreferences.load()
    @State private var draft = ""
    @State private var generatedPlan: TrainingPlan?
    @State private var requestState = RequestState.idle
    @State private var errorMessage: String?
    @State private var provider = AIProviderPreferences.load()
    @State private var includesProfile = false
    @State private var failedAction: FailedAction?
    @FocusState private var isComposerFocused: Bool

    private let keyStore = KeychainAPIKeyStore()
    private let conversationService = AIConversationService()
    private let importService = AIPlanImportService()

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    introduction

                    ForEach(messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }

                    if let stateText = requestState.text {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text(stateText)
                                .font(.footnote)
                                .foregroundStyle(OKColor.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(OKColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .id("request-state")
                    }

                    if let errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("请求没有完成", systemImage: "exclamationmark.circle")
                                .font(.headline)
                            Text(errorMessage)
                                .font(.footnote)
                            if let failedAction {
                                Button(failedAction.buttonTitle, action: retryFailedAction)
                            }
                        }
                        .foregroundStyle(.red)
                        .okCard()
                    }

                    if let generatedPlan { previewCard(generatedPlan) }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: requestState) { _ in
                withAnimation { proxy.scrollTo("request-state", anchor: .bottom) }
            }
        }
        .background(OKColor.background)
        .navigationTitle("AI 计划助手")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive, action: clearConversation) {
                        Label("清空本地对话", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                NavigationLink {
                    AISettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("AI 服务设置")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("收起键盘") { isComposerFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) { composer }
        .onAppear { provider = AIProviderPreferences.load() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.title2)
                Text("先粘贴计划，再继续讨论")
                    .font(.headline)
            }
            Text("可以让 AI 检查遗漏、解释动作安排或提出改善建议。只有你明确确认的修改，才会进入最终计划预览。")
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)

            Toggle("允许本次请求参考个人资料", isOn: $includesProfile)
                .font(.subheadline)

            if messages.isEmpty {
                HStack(spacing: 8) {
                    suggestion("请检查这份计划有没有遗漏")
                    suggestion("请给出改善建议")
                }
            }

            if provider == nil {
                NavigationLink {
                    AISettingsView()
                } label: {
                    Label("先配置并测试 AI 服务", systemImage: "gearshape")
                }
                .buttonStyle(OKPrimaryButtonStyle())
            }
        }
        .okCard()
    }

    private func suggestion(_ text: String) -> some View {
        Button(text) {
            draft = text
            isComposerFocused = true
        }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(OKColor.accent)
    }

    private func messageBubble(_ message: AIChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 42) }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.role == .user ? "你" : "AI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OKColor.secondaryText)
                Text(message.content)
                    .font(.body)
                    .textSelection(.enabled)
            }
            .padding(14)
            .background(message.role == .user ? OKColor.accent.opacity(0.12) : OKColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(OKColor.border, lineWidth: 0.5)
            }
            if message.role == .assistant { Spacer(minLength: 42) }
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if !messages.isEmpty {
                Button(action: generatePlan) {
                    HStack {
                        if requestState == .generating { ProgressView().controlSize(.small) }
                        Label(requestState == .generating ? "正在生成计划预览" : "根据已确认内容生成计划预览", systemImage: "doc.badge.gearshape")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(OKColor.accent)
                .disabled(requestState != .idle)
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("粘贴计划或继续提问", text: $draft, axis: .vertical)
                    .lineLimit(1...6)
                    .focused($isComposerFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(OKColor.background)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(OKColor.border, lineWidth: 0.5) }

                Button(action: sendMessage) {
                    Image(systemName: requestState == .chatting ? "hourglass" : "arrow.up")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .foregroundStyle(OKColor.background)
                        .background(OKColor.accent)
                        .clipShape(Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || requestState != .idle || provider == nil)
                .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func previewCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("计划预览已生成", systemImage: "checkmark.circle")
                .font(.headline)
            Text(plan.title).font(.title3.bold())
            Text("\(plan.days.count) 个训练日 · \(plan.days.reduce(0) { $0 + $1.blocks.count }) 个阶段 · \(plan.days.reduce(0) { $0 + $1.exercises.count }) 个动作")
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)
            if unresolvedExerciseCount(in: plan) > 0 {
                Label("有 \(unresolvedExerciseCount(in: plan)) 个动作需要在编辑器中确认", systemImage: "questionmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            } else {
                Label("全部动作已关联动作库", systemImage: "checkmark.seal")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
            }
            NavigationLink {
                if let binding = generatedPlanBinding { AIPlanReviewView(plan: binding) }
            } label: {
                Label("打开完整编辑器", systemImage: "pencil")
            }
            .frame(minHeight: 44)
            Button {
                do {
                    planLibrary.save(try importService.finalizeForSaving(plan))
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            } label: {
                Label("确认并填入计划", systemImage: "checkmark")
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .okCard()
    }

    private func unresolvedExerciseCount(in plan: TrainingPlan) -> Int {
        plan.days.flatMap(\.exercises).filter { ExerciseLibraryCatalog.item(id: $0.libraryID) == nil }.count
    }

    private var generatedPlanBinding: Binding<TrainingPlan>? {
        guard generatedPlan != nil else { return nil }
        return Binding(get: { generatedPlan! }, set: { generatedPlan = $0 })
    }

    private func sendMessage() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, requestState == .idle else { return }
        isComposerFocused = false
        draft = ""
        errorMessage = nil
        failedAction = nil
        generatedPlan = nil
        messages.append(AIChatMessage(role: .user, content: content))
        persistMessages()
        requestState = .chatting

        Task {
            defer { requestState = .idle }
            do {
                let credentials = try loadCredentials()
                let reply = try await conversationService.reply(
                    history: messages,
                    provider: credentials.provider,
                    apiKey: credentials.key,
                    profile: includesProfile ? UserProfilePreferences.load() : nil
                )
                messages.append(AIChatMessage(role: .assistant, content: reply))
                persistMessages()
            } catch {
                errorMessage = error.localizedDescription
                draft = content
                failedAction = .chat(content)
            }
        }
    }

    private func generatePlan() {
        guard !messages.isEmpty, requestState == .idle else { return }
        isComposerFocused = false
        errorMessage = nil
        failedAction = nil
        requestState = .generating
        Task {
            defer { requestState = .idle }
            do {
                let credentials = try loadCredentials()
                generatedPlan = try await importService.importPlan(
                    conversation: messages,
                    provider: credentials.provider,
                    apiKey: credentials.key
                )
            } catch {
                errorMessage = error.localizedDescription
                failedAction = .generatePlan
            }
        }
    }

    private func retryFailedAction() {
        guard requestState == .idle, let failedAction else { return }
        switch failedAction {
        case .chat(let content):
            draft = content
            sendMessage()
        case .generatePlan:
            generatePlan()
        }
    }

    private func loadCredentials() throws -> (provider: AIProviderConfiguration, key: String) {
        guard let provider = AIProviderPreferences.load() else {
            throw AIImportValidationError(message: "请先配置 AI 服务")
        }
        guard let key = try keyStore.read(providerID: provider.id), !key.isEmpty else {
            throw AIImportValidationError(message: "请先保存 API Key")
        }
        return (provider, key)
    }

    private func persistMessages() {
        AIConversationPreferences.save(messages)
    }

    private func clearConversation() {
        isComposerFocused = false
        messages = []
        draft = ""
        generatedPlan = nil
        errorMessage = nil
        failedAction = nil
        AIConversationPreferences.clear()
    }
}

private struct AIImportValidationError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
