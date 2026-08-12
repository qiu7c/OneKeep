import Foundation

enum VideoSource: Equatable {
    case native(URL)
    case web(URL)

    var isNative: Bool {
        if case .native = self { return true }
        return false
    }

    var supportsOfflineCache: Bool {
        guard case .native(let url) = self else { return false }
        return ["mp4", "mov", "m4v"].contains(url.pathExtension.lowercased())
    }

    var playbackURL: URL {
        switch self {
        case .native(let url), .web(let url): return url
        }
    }

    init?(urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme) else {
            return nil
        }

        let pathExtension = url.pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "m3u8"].contains(pathExtension) {
            self = .native(url)
            return
        }

        if let embedURL = Self.youtubeEmbedURL(from: url) ?? Self.bilibiliMobileURL(from: url) {
            self = .web(embedURL)
            return
        }

        self = .web(url)
    }

    private static func youtubeEmbedURL(from url: URL) -> URL? {
        guard let host = url.host?.lowercased() else { return nil }
        var videoID: String?

        if host == "youtu.be" {
            videoID = url.pathComponents.dropFirst().first
        } else if host.hasSuffix("youtube.com") {
            if url.path == "/watch" {
                videoID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "v" })?
                    .value
            } else {
                let components = url.pathComponents
                if let marker = components.firstIndex(where: { ["shorts", "embed"].contains($0) }), components.indices.contains(marker + 1) {
                    videoID = components[marker + 1]
                }
            }
        }

        guard let videoID, !videoID.isEmpty else { return nil }
        return URL(string: "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&rel=0")
    }

    static func bilibiliVideoID(from url: URL) -> String? {
        guard let host = url.host?.lowercased(), host.hasSuffix("bilibili.com") else { return nil }
        return url.pathComponents.first(where: { $0.uppercased().hasPrefix("BV") })
    }

    static func isBilibiliURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.hasSuffix("bilibili.com") || host == "b23.tv" || host.hasSuffix(".b23.tv")
    }

    private static func bilibiliMobileURL(from url: URL) -> URL? {
        guard let bvid = bilibiliVideoID(from: url) else { return nil }
        let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "p" }?.value
        var components = URLComponents()
        components.scheme = "https"
        components.host = "m.bilibili.com"
        components.path = "/video/\(bvid)"
        if let page, page != "1" {
            components.queryItems = [URLQueryItem(name: "p", value: page)]
        }
        return components.url
    }
}
