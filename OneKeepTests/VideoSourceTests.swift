import XCTest
@testable import OneKeep

final class VideoSourceTests: XCTestCase {
    func testMP4UsesNativePlayer() throws {
        let source = try XCTUnwrap(VideoSource(urlString: "https://cdn.example.com/squat.mp4"))

        guard case .native(let url) = source else {
            return XCTFail("Expected native video source")
        }
        XCTAssertEqual(url.pathExtension, "mp4")
    }

    func testYouTubeShareURLBecomesEmbedURL() throws {
        let source = try XCTUnwrap(VideoSource(urlString: "https://youtu.be/abc123"))

        guard case .web(let url) = source else {
            return XCTFail("Expected web video source")
        }
        XCTAssertEqual(url.host, "www.youtube-nocookie.com")
        XCTAssertTrue(url.path.contains("abc123"))
    }

    func testBilibiliURLBecomesEmbedURL() throws {
        let source = try XCTUnwrap(VideoSource(urlString: "https://www.bilibili.com/video/BV1Example"))

        guard case .web(let url) = source else {
            return XCTFail("Expected web video source")
        }
        XCTAssertEqual(url.host, "player.bilibili.com")
        XCTAssertTrue(url.absoluteString.contains("BV1Example"))
    }

    func testRejectsNonHTTPURL() {
        XCTAssertNil(VideoSource(urlString: "file:///private/video.mp4"))
    }
}
