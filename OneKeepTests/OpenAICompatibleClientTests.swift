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
}
