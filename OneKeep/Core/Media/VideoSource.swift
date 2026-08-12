import Foundation

enum VideoSource: Equatable {
    case native(URL)
    case web(URL)

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

        if let embedURL = Self.youtubeEmbedURL(from: url) ?? Self.bilibiliEmbedURL(from: url) {
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

    private static func bilibiliEmbedURL(from url: URL) -> URL? {
        guard let host = url.host?.lowercased(), host.hasSuffix("bilibili.com") else { return nil }
        guard let bvid = url.pathComponents.first(where: { $0.uppercased().hasPrefix("BV") }) else { return nil }
        return URL(string: "https://player.bilibili.com/player.html?bvid=\(bvid)&high_quality=1&danmaku=0")
    }
}
