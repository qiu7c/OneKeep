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
            case .missingContent: return "AI 返回了空内容。DeepSeek 的 JSON 模式偶尔会出现此问题"
            case .truncated: return "AI 输出达到长度限制，计划 JSON 不完整"
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
        if choice.finishReason == "length" { throw ClientError.truncated }
        guard let content = choice.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw ClientError.missingContent
        }
        return CompletionResult(content: content, model: completion.model, finishReason: choice.finishReason)
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
        struct Message: Decodable { let content: String? }
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
