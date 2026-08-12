import XCTest
@testable import OneKeep

final class BilibiliPlaybackResolverTests: XCTestCase {
    func testProgressiveQueryRequestsHTML5MergedStream() {
        let values = Dictionary(uniqueKeysWithValues: BilibiliPlaybackResolver
            .playQuery(bvid: "BV1Example", cid: 123, fnval: 1)
            .compactMap { item in item.value.map { (item.name, $0) } })

        XCTAssertEqual(values["bvid"], "BV1Example")
        XCTAssertEqual(values["cid"], "123")
        XCTAssertEqual(values["fnval"], "1")
        XCTAssertEqual(values["platform"], "html5")
    }

    func testDASHQueryDoesNotForceHTML5ProgressiveResponse() {
        let values = Dictionary(uniqueKeysWithValues: BilibiliPlaybackResolver
            .playQuery(bvid: "BV1Example", cid: 123, fnval: 4048)
            .compactMap { item in item.value.map { (item.name, $0) } })

        XCTAssertEqual(values["fnval"], "4048")
        XCTAssertNil(values["platform"])
    }

    func testMediaHeadersAllowBilibiliCDNPlayback() {
        let headers = BilibiliPlaybackResolver.mediaHeaders(referer: "https://www.bilibili.com/video/BV1Example/")

        XCTAssertNotNil(headers["User-Agent"])
        XCTAssertEqual(headers["Referer"], "https://www.bilibili.com/video/BV1Example/")
        XCTAssertEqual(headers["Origin"], "https://www.bilibili.com")
    }
}
