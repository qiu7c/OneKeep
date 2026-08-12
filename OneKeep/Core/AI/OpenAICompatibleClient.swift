import Foundation

struct OpenAICompatibleClient {
    struct Configuration {
        var baseURL: String
        var model: String
        var apiKey: String
        var usesJSONMode: Bool
    }

    struct Message: Codable, Hashable {
        let role: String
        let content: String
    }

    struct CompletionResult {
        let content: String
        let model: String?
        let finishReason: String?
    }

    struct ConnectionResult {
        let model: String
        let latencyMilliseconds: Int
    }

    struct AvailableModel: Decodable, Identifiable, Hashable {
        let id: String
        let ownedBy: String?

        enum CodingKeys: String, CodingKey {
            case id
            case ownedBy = "owned_by"
        }
    }

    enum ClientError: LocalizedError, Equatable {
        case invalidBaseURL
        case invalidModel
        case invalidResponse
        case timedOut
        case network(String)
        case requestFailed(status: Int, message: String)
        case missingContent
        case truncated

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL: return "AI 服务地址无效"
            case .invalidModel: return "模型名称不能为空"
            case .invalidResponse: return "AI 服务返回了无法识别的数据"
            case .timedOut: return "连接超时，请检查网络、Base URL 或服务状态"
            case .network(let message): return "网络连接失败：\(message)"
            case .requestFailed(let status, let message): return "AI 请求失败（HTTP \(status)）：\(message)"
            case .missingContent: return "AI 服务返回了空内容"
            case .truncated: return "AI 多次自动续写后仍未完成，请缩短对话或更换支持更长输出的模型"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func complete(
        configuration: Configuration,
        messages: [Message],
        forceJSONMode: Bool? = nil,
        acceptReasoningContentFallback: Bool = false,
        timeout: TimeInterval = 90
    ) async throws -> CompletionResult {
        try validate(configuration)
        let endpoint = try Self.endpoint(baseURL: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let jsonMode = forceJSONMode ?? configuration.usesJSONMode
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: configuration.model,
            messages: messages,
            responseFormat: jsonMode ? .init(type: "json_object") : nil,
            maxTokens: jsonMode ? 8_192 : 2_048
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClientError.timedOut
        } catch let error as URLError {
            throw ClientError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            let fallback = String(data: data.prefix(2_000), encoding: .utf8) ?? "未知错误"
            throw ClientError.requestFailed(status: httpResponse.statusCode, message: envelope?.error.message ?? fallback)
        }

        let completion: ChatResponse
        do {
            completion = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            throw ClientError.invalidResponse
        }
        guard let choice = completion.choices.first else { throw ClientError.missingContent }
        let directContent = choice.message.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        let reasoningContent = choice.message.reasoningContent?.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedContent = directContent?.isEmpty == false
            ? directContent
            : (acceptReasoningContentFallback && reasoningContent?.contains("{") == true ? reasoningContent : nil)
        guard let content = selectedContent, !content.isEmpty else {
            throw ClientError.missingContent
        }
        return CompletionResult(content: content, model: completion.model, finishReason: choice.finishReason)
    }

    func completeContinuing(
        configuration: Configuration,
        messages: [Message],
        forceJSONMode: Bool? = nil,
        acceptReasoningContentFallback: Bool = false,
        timeout: TimeInterval = 90,
        maximumContinuations: Int = 4
    ) async throws -> CompletionResult {
        var result = try await complete(
            configuration: configuration,
            messages: messages,
            forceJSONMode: forceJSONMode,
            acceptReasoningContentFallback: acceptReasoningContentFallback,
            timeout: timeout
        )
        guard result.finishReason == "length" else { return result }

        var combined = result.content
        var latestModel = result.model
        for _ in 0..<maximumContinuations {
            let continuationMessages = messages + [
                .init(role: "assistant", content: combined),
                .init(
                    role: "user",
                    content: "上一条输出被服务截断。请从最后一个字符之后精确续写，只输出缺失的后半部分；不要重头开始，不要解释，不要添加 Markdown 代码块。"
                )
            ]
            result = try await complete(
                configuration: configuration,
                messages: continuationMessages,
                forceJSONMode: false,
                acceptReasoningContentFallback: acceptReasoningContentFallback,
                timeout: timeout
            )
            combined = Self.join(prefix: combined, continuation: result.content)
            latestModel = result.model ?? latestModel
            if result.finishReason != "length" {
                return CompletionResult(content: combined, model: latestModel, finishReason: result.finishReason)
            }
        }
        throw ClientError.truncated
    }

    static func join(prefix: String, continuation: String) -> String {
        var suffix = continuation.trimmingCharacters(in: .whitespacesAndNewlines)
        if suffix.hasPrefix("```json") { suffix.removeFirst(7) }
        else if suffix.hasPrefix("```") { suffix.removeFirst(3) }
        if suffix.hasSuffix("```") { suffix.removeLast(3) }
        suffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)

        let maximumOverlap = min(1_024, min(prefix.count, suffix.count))
        if maximumOverlap > 0 {
            for length in stride(from: maximumOverlap, through: 1, by: -1) {
                if prefix.suffix(length) == suffix.prefix(length) {
                    return prefix + String(suffix.dropFirst(length))
                }
            }
        }
        return prefix + suffix
    }

    func complete(
        configuration: Configuration,
        developerMessage: String,
        userMessage: String
    ) async throws -> String {
        try await complete(configuration: configuration, messages: [
            .init(role: "system", content: developerMessage),
            .init(role: "user", content: userMessage)
        ]).content
    }

    func testConnection(configuration: Configuration) async throws -> ConnectionResult {
        let started = Date.now
        let result = try await complete(
            configuration: configuration,
            messages: [
                .init(role: "system", content: "这是连接测试。请只回复 OK。"),
                .init(role: "user", content: "OK")
            ],
            forceJSONMode: false,
            timeout: 25
        )
        return ConnectionResult(
            model: result.model ?? configuration.model,
            latencyMilliseconds: max(1, Int(Date.now.timeIntervalSince(started) * 1_000))
        )
    }

    func listModels(baseURL: String, apiKey: String) async throws -> [AvailableModel] {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.requestFailed(status: 0, message: "API Key 不能为空")
        }
        var request = URLRequest(url: try Self.modelsEndpoint(baseURL: baseURL))
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ClientError.timedOut
        } catch let error as URLError {
            throw ClientError.network(error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else { throw ClientError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            let fallback = String(data: data.prefix(2_000), encoding: .utf8) ?? "未知错误"
            throw ClientError.requestFailed(status: httpResponse.statusCode, message: envelope?.error.message ?? fallback)
        }
        guard let response = try? JSONDecoder().decode(ModelListResponse.self, from: data) else {
            throw ClientError.invalidResponse
        }
        return response.data.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    private func validate(_ configuration: Configuration) throws {
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ClientError.invalidModel }
        guard !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.requestFailed(status: 0, message: "API Key 不能为空")
        }
    }

    static func endpoint(baseURL: String) throws -> URL {
        let value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else { throw ClientError.invalidBaseURL }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.hasSuffix("chat/completions") {
            path = path.isEmpty ? "chat/completions" : path + "/chat/completions"
        }
        components.path = "/" + path
        guard let url = components.url else { throw ClientError.invalidBaseURL }
        return url
    }

    static func modelsEndpoint(baseURL: String) throws -> URL {
        let chatURL = try endpoint(baseURL: baseURL)
        guard var components = URLComponents(url: chatURL, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidBaseURL
        }
        var parts = components.path.split(separator: "/").map(String.init)
        if parts.suffix(2).elementsEqual(["chat", "completions"]) {
            parts.removeLast(2)
        }
        parts.append("models")
        components.path = "/" + parts.joined(separator: "/")
        guard let url = components.url else { throw ClientError.invalidBaseURL }
        return url
    }
}

private struct ChatRequest: Encodable {
    struct ResponseFormat: Encodable { let type: String }
    let model: String
    let messages: [OpenAICompatibleClient.Message]
    let responseFormat: ResponseFormat?
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            struct ContentPart: Decodable {
                let type: String?
                let text: String?
                let content: String?
            }

            let content: String?
            let reasoningContent: String?

            enum CodingKeys: String, CodingKey {
                case content
                case reasoningContent = "reasoning_content"
            }

            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                if let text = try? values.decode(String.self, forKey: .content) {
                    content = text
                } else if let parts = try? values.decode([ContentPart].self, forKey: .content) {
                    content = parts.compactMap { $0.text ?? $0.content }.joined()
                } else {
                    content = nil
                }
                reasoningContent = try? values.decode(String.self, forKey: .reasoningContent)
            }
        }
        let message: Message
        let finishReason: String?
        enum CodingKeys: String, CodingKey { case message; case finishReason = "finish_reason" }
    }
    let model: String?
    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable { let message: String }
    let error: APIError
}

private struct ModelListResponse: Decodable {
    let data: [OpenAICompatibleClient.AvailableModel]
}
