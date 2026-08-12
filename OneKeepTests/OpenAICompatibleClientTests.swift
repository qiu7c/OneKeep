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
}
