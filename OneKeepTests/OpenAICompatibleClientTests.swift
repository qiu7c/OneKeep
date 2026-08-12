import Foundation
import XCTest
@testable import OneKeep

final class OpenAICompatibleClientTests: XCTestCase {
    func testAppendsChatCompletionsToVersionedBaseURL() throws {
        let url = try OpenAICompatibleClient.endpoint(baseURL: "https://api.example.com/v1")
        XCTAssertEqual(url.absoluteString, "https://api.example.com/v1/chat/completions")
    }

    func testPreservesCompleteEndpoint() throws {
        let url = try OpenAICompatibleClient.endpoint(baseURL: "https://api.example.com/v1/chat/completions")
        XCTAssertEqual(url.absoluteString, "https://api.example.com/v1/chat/completions")
    }

    func testRejectsNonHTTPURL() {
        XCTAssertThrowsError(try OpenAICompatibleClient.endpoint(baseURL: "file:///tmp/api"))
    }

    func testBuildsModelsEndpointFromBaseURL() throws {
        XCTAssertEqual(
            try OpenAICompatibleClient.modelsEndpoint(baseURL: "https://api.deepseek.com").absoluteString,
            "https://api.deepseek.com/models"
        )
        XCTAssertEqual(
            try OpenAICompatibleClient.modelsEndpoint(baseURL: "https://api.openai.com/v1/chat/completions").absoluteString,
            "https://api.openai.com/v1/models"
        )
        XCTAssertEqual(
            try OpenAICompatibleClient.modelsEndpoint(baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/").absoluteString,
            "https://generativelanguage.googleapis.com/v1beta/openai/models"
        )
    }

    func testProviderPresetsResolveChatEndpoints() throws {
        for preset in AIProviderPreset.allCases {
            let configuration = preset.configuration
            XCTAssertTrue(try OpenAICompatibleClient.endpoint(baseURL: configuration.baseURL)
                .absoluteString.hasSuffix("/chat/completions"))
            XCTAssertFalse(configuration.model.isEmpty)
        }
    }

    func testJoinsContinuationWithoutDuplicatingOverlap() {
        XCTAssertEqual(
            OpenAICompatibleClient.join(prefix: "{\"days\":[{\"title\":\"周一", continuation: "周一\",\"blocks\":[]}]}"),
            "{\"days\":[{\"title\":\"周一\",\"blocks\":[]}]}"
        )
    }

    func testJoinsContinuationAfterRemovingMarkdownFence() {
        XCTAssertEqual(
            OpenAICompatibleClient.join(prefix: "{\"title\":", continuation: "```json\n\"计划\"}\n```"),
            "{\"title\":\"计划\"}"
        )
    }

    func testDecodesArrayBasedMessageContent() async throws {
        TestURLProtocol.handler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "model": "test-model",
                "choices": [[
                    "message": ["content": [
                        ["type": "text", "text": "前半段"],
                        ["type": "text", "text": "后半段"]
                    ]],
                    "finish_reason": "stop"
                ]]
            ])
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        defer { TestURLProtocol.handler = nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let client = OpenAICompatibleClient(session: URLSession(configuration: configuration))

        let result = try await client.complete(
            configuration: .init(baseURL: "https://api.example.com/v1", model: "test", apiKey: "key", usesJSONMode: false),
            messages: [.init(role: "user", content: "test")]
        )

        XCTAssertEqual(result.content, "前半段后半段")
    }

    func testCanUseJSONFromReasoningContentWhenFinalContentIsEmpty() async throws {
        TestURLProtocol.handler = { request in
            let data = try JSONSerialization.data(withJSONObject: [
                "model": "test-model",
                "choices": [[
                    "message": ["content": NSNull(), "reasoning_content": "{\"title\":\"计划\"}"],
                    "finish_reason": "stop"
                ]]
            ])
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }
        defer { TestURLProtocol.handler = nil }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TestURLProtocol.self]
        let client = OpenAICompatibleClient(session: URLSession(configuration: configuration))

        let result = try await client.complete(
            configuration: .init(baseURL: "https://api.example.com/v1", model: "test", apiKey: "key", usesJSONMode: true),
            messages: [.init(role: "user", content: "生成 JSON")],
            acceptReasoningContentFallback: true
        )

        XCTAssertEqual(result.content, "{\"title\":\"计划\"}")
    }
}

final class TestURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
