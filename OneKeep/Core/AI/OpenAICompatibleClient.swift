import Foundation

struct OpenAICompatibleClient {
    struct Configuration {
        var baseURL: String
        var model: String
        var apiKey: String
        var usesJSONMode: Bool
    }

    enum ClientError: LocalizedError {
        case invalidBaseURL
        case invalidModel
        case invalidResponse
        case requestFailed(status: Int, message: String)
        case missingContent

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL: return "AI 服务地址无效"
            case .invalidModel: return "模型名称不能为空"
            case .invalidResponse: return "AI 服务返回了无法识别的数据"
            case .requestFailed(let status, let message): return "AI 请求失败（\(status)）：\(message)"
            case .missingContent: return "AI 响应中没有计划内容"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func complete(
        configuration: Configuration,
        developerMessage: String,
        userMessage: String
    ) async throws -> String {
        guard !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.invalidModel
        }

        let endpoint = try Self.endpoint(baseURL: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: configuration.model,
            messages: [
                .init(role: "system", content: developerMessage),
                .init(role: "user", content: userMessage)
            ],
            responseFormat: configuration.usesJSONMode ? .init(type: "json_object") : nil
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let error = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            let fallback = String(data: data.prefix(1_000), encoding: .utf8) ?? "未知错误"
            throw ClientError.requestFailed(
                status: httpResponse.statusCode,
                message: error?.error.message ?? fallback
            )
        }

        let completion = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = completion.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ClientError.missingContent
        }
        return content
    }

    static func endpoint(baseURL: String) throws -> URL {
        let value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host != nil else {
            throw ClientError.invalidBaseURL
        }

        var path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.hasSuffix("chat/completions") {
            path = path.isEmpty ? "chat/completions" : path + "/chat/completions"
        }
        components.path = "/" + path

        guard let url = components.url else {
            throw ClientError.invalidBaseURL
        }
        return url
    }
}

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct ResponseFormat: Encodable {
        let type: String
    }

    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case responseFormat = "response_format"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct APIErrorEnvelope: Decodable {
    struct APIError: Decodable {
        let message: String
    }
    let error: APIError
}
