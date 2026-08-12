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

    func testBilibiliURLBecomesMobilePlaybackURL() throws {
        let source = try XCTUnwrap(VideoSource(urlString: "https://www.bilibili.com/video/BV1Example"))

        guard case .web(let url) = source else {
            return XCTFail("Expected web video source")
        }
        XCTAssertEqual(url.host, "m.bilibili.com")
        XCTAssertTrue(url.absoluteString.contains("BV1Example"))
    }

    func testBilibiliMultiPartURLKeepsSelectedPage() throws {
        let source = try XCTUnwrap(VideoSource(urlString: "https://www.bilibili.com/video/BV1Rb411a7cQ/?p=2"))
        guard case .web(let url) = source else { return XCTFail("Expected web video") }
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "p" }?.value, "2")
    }

    func testRecognizesBilibiliShortLinkAsBilibiliSource() throws {
        let source = try XCTUnwrap(VideoSource(urlString: "https://b23.tv/example"))
        XCTAssertTrue(VideoSource.isBilibiliURL(source.playbackURL))
    }

    func testRejectsNonHTTPURL() {
        XCTAssertNil(VideoSource(urlString: "file:///private/video.mp4"))
    }
}
