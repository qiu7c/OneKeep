import Foundation

struct AIChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date

    init(id: UUID = UUID(), role: Role, content: String, createdAt: Date = .now) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

enum AIConversationPreferences {
    private static let key = "onekeep.ai-conversation"

    static func load(defaults: UserDefaults = .standard) -> [AIChatMessage] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([AIChatMessage].self, from: data)) ?? []
    }

    static func save(_ messages: [AIChatMessage], defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(Array(messages.suffix(60))) {
            defaults.set(data, forKey: key)
        }
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

struct AIConversationService {
    private let client: OpenAICompatibleClient

    init(client: OpenAICompatibleClient = OpenAICompatibleClient()) {
        self.client = client
    }

    func reply(
        history: [AIChatMessage],
        provider: AIProviderConfiguration,
        apiKey: String,
        profile: UserProfile?
    ) async throws -> String {
        var messages = [OpenAICompatibleClient.Message(role: "system", content: Self.conversationPrompt)]
        if let profile {
            messages.append(.init(role: "system", content: "用户主动允许本次对话参考以下资料：\n\(Self.profileText(profile))"))
        }
        messages.append(contentsOf: history.suffix(30).map {
            .init(role: $0.role == .user ? "user" : "assistant", content: $0.content)
        })
        var configuration = configuration(provider, apiKey: apiKey)
        configuration.usesJSONMode = false
        return try await client.complete(configuration: configuration, messages: messages).content
    }

    private func configuration(_ provider: AIProviderConfiguration, apiKey: String) -> OpenAICompatibleClient.Configuration {
        .init(baseURL: provider.baseURL, model: provider.model, apiKey: apiKey, usesJSONMode: provider.usesJSONMode)
    }

    private static func profileText(_ profile: UserProfile) -> String {
        var values: [String] = []
        if !profile.nickname.isEmpty { values.append("昵称：\(profile.nickname)") }
        if profile.gender != .unspecified { values.append("性别：\(profile.gender.title)") }
        if let birthday = profile.birthday {
            values.append("年龄：\(Calendar.current.dateComponents([.year], from: birthday, to: .now).year ?? 0)")
        }
        if let height = profile.heightCentimeters { values.append("身高：\(height.formatted()) cm") }
        if let weight = profile.weightKilograms { values.append("体重：\(weight.formatted()) kg") }
        if !profile.notes.isEmpty { values.append("备注：\(profile.notes)") }
        return values.joined(separator: "；")
    }

    static let conversationPrompt = """
    你是 OneKeep 内的训练计划讨论助手。请使用简洁中文与用户多轮对话。
    你可以检查用户提供的计划是否缺少日期、组数、动作时长、休息、记录方式或视频链接，也可以提出改善建议。
    必须区分“建议”和“用户已经确认的修改”：未经用户明确同意，不得把建议当作最终计划决定。
    用户说数据无误时先确认已理解，再针对用户提出的目标继续；不要反复质疑已经确认的数据。
    不要声称已写入日程。只有 OneKeep 页面中的“生成计划预览”按钮会执行结构化和写入。
    涉及明显疼痛、伤病或危险信号时，提醒停止动作并寻求专业帮助。不要输出 Markdown 表格。
    """
}

