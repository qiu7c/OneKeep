import Foundation

struct AIProviderConfiguration: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var baseURL: String
    var model: String
    var usesJSONMode: Bool
    var customPrompt: String?

    var effectivePrompt: String {
        let value = customPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? AIPlanImportService.recommendedPrompt : value
    }

    init(
        id: UUID = UUID(),
        name: String = "OpenAI 兼容服务",
        baseURL: String = "https://api.openai.com/v1",
        model: String = "",
        usesJSONMode: Bool = true,
        customPrompt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.model = model
        self.usesJSONMode = usesJSONMode
        self.customPrompt = customPrompt
    }
}

enum AIProviderPreferences {
    private static let key = "onekeep.ai-provider.configuration"

    static func load(defaults: UserDefaults = .standard) -> AIProviderConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(AIProviderConfiguration.self, from: data)
    }

    static func save(_ configuration: AIProviderConfiguration, defaults: UserDefaults = .standard) throws {
        defaults.set(try JSONEncoder().encode(configuration), forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
