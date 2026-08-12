import AVFoundation
import Foundation

struct BilibiliPlaybackSource {
    enum Stream {
        case progressive([URL])
        case dash(video: URL, audio: URL?)
    }

    let stream: Stream
    let headers: [String: String]
}

actor BilibiliPlaybackResolver {
    enum ResolverError: LocalizedError {
        case invalidVideo
        case invalidPage
        case api(String)
        case noPlayableStream
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidVideo: return "无法识别哔哩哔哩视频编号"
            case .invalidPage: return "视频分集不存在或已经失效"
            case .api(let message): return "哔哩哔哩接口返回错误：\(message)"
            case .noPlayableStream: return "没有找到可供系统播放器使用的视频流"
            case .invalidResponse: return "哔哩哔哩返回了无法识别的数据"
            }
        }
    }

    static let shared = BilibiliPlaybackResolver()
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func resolve(_ pageURL: URL) async throws -> BilibiliPlaybackSource {
        let resolvedPageURL = try await resolveShortLinkIfNeeded(pageURL)
        guard let bvid = VideoSource.bilibiliVideoID(from: resolvedPageURL) else {
            throw ResolverError.invalidVideo
        }
        let selectedPage = Int(URLComponents(url: resolvedPageURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "p" }?.value ?? "1") ?? 1
        let detail: ViewEnvelope = try await request(
            endpoint: "https://api.bilibili.com/x/web-interface/view",
            queryItems: [URLQueryItem(name: "bvid", value: bvid)],
            referer: "https://www.bilibili.com/video/\(bvid)/"
        )
        guard detail.code == 0, let page = detail.data?.pages.first(where: { $0.page == selectedPage }) else {
            throw detail.code == 0 ? ResolverError.invalidPage : ResolverError.api(detail.message ?? "视频信息不可用")
        }

        let play: PlayEnvelope = try await request(
            endpoint: "https://api.bilibili.com/x/player/playurl",
            queryItems: Self.playQuery(bvid: bvid, cid: page.cid, fnval: 1),
            referer: "https://www.bilibili.com/video/\(bvid)/?p=\(selectedPage)"
        )
        guard play.code == 0, let playData = play.data else {
            throw ResolverError.api(play.message ?? "播放地址不可用")
        }

        let headers = Self.mediaHeaders(referer: "https://www.bilibili.com/video/\(bvid)/")
        let progressiveURLs = playData.durl.compactMap { URL(string: $0.url) }
        if !progressiveURLs.isEmpty {
            return BilibiliPlaybackSource(stream: .progressive(progressiveURLs), headers: headers)
        }

        let dash: PlayEnvelope = try await request(
            endpoint: "https://api.bilibili.com/x/player/playurl",
            queryItems: Self.playQuery(bvid: bvid, cid: page.cid, fnval: 4048),
            referer: "https://www.bilibili.com/video/\(bvid)/?p=\(selectedPage)"
        )
        guard dash.code == 0, let dashData = dash.data?.dash else {
            throw ResolverError.noPlayableStream
        }
        let compatibleVideos = dashData.video.filter { $0.codecid == 7 }
        guard let video = (compatibleVideos.isEmpty ? dashData.video : compatibleVideos)
            .max(by: { $0.bandwidth < $1.bandwidth })?.preferredURL else {
            throw ResolverError.noPlayableStream
        }
        let audio = dashData.audio.max(by: { $0.bandwidth < $1.bandwidth })?.preferredURL
        return BilibiliPlaybackSource(stream: .dash(video: video, audio: audio), headers: headers)
    }

    private func resolveShortLinkIfNeeded(_ url: URL) async throws -> URL {
        guard url.host?.lowercased().hasSuffix("b23.tv") == true else { return url }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (_, response) = try await session.data(for: request)
        guard let resolvedURL = response.url else { throw ResolverError.invalidVideo }
        return resolvedURL
    }

    static func playQuery(bvid: String, cid: Int64, fnval: Int) -> [URLQueryItem] {
        var items = [
            URLQueryItem(name: "bvid", value: bvid),
            URLQueryItem(name: "cid", value: String(cid)),
            URLQueryItem(name: "qn", value: "64"),
            URLQueryItem(name: "fnver", value: "0"),
            URLQueryItem(name: "fnval", value: String(fnval)),
            URLQueryItem(name: "fourk", value: "0"),
            URLQueryItem(name: "high_quality", value: "1")
        ]
        if fnval == 1 { items.append(URLQueryItem(name: "platform", value: "html5")) }
        return items
    }

    static func mediaHeaders(referer: String) -> [String: String] {
        ["User-Agent": userAgent, "Referer": referer, "Origin": "https://www.bilibili.com"]
    }

    private func request<Response: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem],
        referer: String
    ) async throws -> Response {
        guard var components = URLComponents(string: endpoint) else { throw ResolverError.invalidResponse }
        components.queryItems = queryItems
        guard let url = components.url else { throw ResolverError.invalidResponse }
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 20)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ResolverError.invalidResponse
        }
        do { return try JSONDecoder().decode(Response.self, from: data) }
        catch { throw ResolverError.invalidResponse }
    }
}

private struct ViewEnvelope: Decodable {
    struct DataValue: Decodable {
        struct Page: Decodable { let cid: Int64; let page: Int }
        let pages: [Page]
    }
    let code: Int
    let message: String?
    let data: DataValue?
}

private struct PlayEnvelope: Decodable {
    struct DataValue: Decodable {
        struct Progressive: Decodable { let url: String }
        struct DASH: Decodable {
            struct Media: Decodable {
                let baseURL: String?
                let backupURL: [String]?
                let bandwidth: Int64
                let codecid: Int?

                enum CodingKeys: String, CodingKey {
                    case baseURL = "baseUrl"
                    case backupURL = "backupUrl"
                    case bandwidth, codecid
                }

                var preferredURL: URL? {
                    ([baseURL].compactMap { $0 } + (backupURL ?? [])).compactMap(URL.init(string:)).first
                }
            }
            let video: [Media]
            let audio: [Media]
        }
        let durl: [Progressive]
        let dash: DASH?

        enum CodingKeys: String, CodingKey { case durl, dash }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            durl = try values.decodeIfPresent([Progressive].self, forKey: .durl) ?? []
            dash = try values.decodeIfPresent(DASH.self, forKey: .dash)
        }
    }
    let code: Int
    let message: String?
    let data: DataValue?
}
