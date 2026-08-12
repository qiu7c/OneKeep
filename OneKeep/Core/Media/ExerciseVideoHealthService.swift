import Foundation

struct ExerciseVideoHealthRecord: Codable, Equatable {
    enum Status: String, Codable {
        case available
        case unavailable
        case unknown
    }

    let url: URL
    let status: Status
    let checkedAt: Date
    let title: String?
    let author: String?
    let thumbnailURL: URL?
    let message: String?
}

enum ExerciseVideoHealthStore {
    private static let recordsKey = "onekeep.exercise-video.health-records"
    private static let fullCheckKey = "onekeep.exercise-video.last-full-check"

    static func records(defaults: UserDefaults = .standard) -> [String: ExerciseVideoHealthRecord] {
        guard let data = defaults.data(forKey: recordsKey) else { return [:] }
        return (try? JSONDecoder().decode([String: ExerciseVideoHealthRecord].self, from: data)) ?? [:]
    }

    static func record(for url: URL, defaults: UserDefaults = .standard) -> ExerciseVideoHealthRecord? {
        records(defaults: defaults)[url.absoluteString]
    }

    static func save(_ record: ExerciseVideoHealthRecord, defaults: UserDefaults = .standard) {
        var values = records(defaults: defaults)
        values[record.url.absoluteString] = record
        defaults.set(try? JSONEncoder().encode(values), forKey: recordsKey)
    }

    static func needsFullCheck(now: Date = .now, defaults: UserDefaults = .standard) -> Bool {
        guard let lastCheck = defaults.object(forKey: fullCheckKey) as? Date else { return true }
        return now.timeIntervalSince(lastCheck) >= 7 * 24 * 60 * 60
    }

    static func markFullCheck(now: Date = .now, defaults: UserDefaults = .standard) {
        defaults.set(now, forKey: fullCheckKey)
    }
}

enum ExerciseMediaResolver {
    static func candidates(for item: ExerciseLibraryItem) -> [URL] {
        var seen = Set<String>()
        return ([item.videoURL].compactMap { $0 } + (item.alternateVideoURLs ?? [])).filter {
            seen.insert($0.absoluteString).inserted
        }
    }

    static func playableURL(for item: ExerciseLibraryItem, defaults: UserDefaults = .standard) -> URL? {
        let candidates = candidates(for: item)
        return candidates.first {
            ExerciseVideoHealthStore.record(for: $0, defaults: defaults)?.status != .unavailable
        }
    }
}

actor ExerciseVideoHealthService {
    static let shared = ExerciseVideoHealthService()

    func check(_ url: URL) async -> ExerciseVideoHealthRecord {
        let record: ExerciseVideoHealthRecord
        if let bvid = VideoSource.bilibiliVideoID(from: url) {
            record = await checkBilibili(url: url, bvid: bvid)
        } else {
            record = await checkGeneric(url)
        }
        ExerciseVideoHealthStore.save(record)
        return record
    }

    func checkCatalogIfNeeded(_ items: [ExerciseLibraryItem]) async {
        guard ExerciseVideoHealthStore.needsFullCheck() else { return }
        await checkCatalog(items)
    }

    func checkCatalog(_ items: [ExerciseLibraryItem]) async {
        var seen = Set<String>()
        let urls = items.flatMap { ExerciseMediaResolver.candidates(for: $0) }
            .filter { seen.insert($0.absoluteString).inserted }
        for start in stride(from: 0, to: urls.count, by: 6) {
            let batch = Array(urls[start..<min(start + 6, urls.count)])
            await withTaskGroup(of: Void.self) { group in
                for url in batch {
                    group.addTask { _ = await self.check(url) }
                }
            }
        }
        ExerciseVideoHealthStore.markFullCheck()
    }

    private func checkBilibili(url: URL, bvid: String) async -> ExerciseVideoHealthRecord {
        guard var components = URLComponents(string: "https://api.bilibili.com/x/web-interface/view") else {
            return unavailable(url, "无法创建检查请求")
        }
        components.queryItems = [URLQueryItem(name: "bvid", value: bvid)]
        guard let apiURL = components.url else { return unavailable(url, "视频编号无效") }
        do {
            var request = URLRequest(url: apiURL)
            request.timeoutInterval = 15
            request.setValue("OneKeep/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return unavailable(url, "视频信息接口连接失败")
            }
            let envelope = try JSONDecoder().decode(BilibiliEnvelope.self, from: data)
            guard envelope.code == 0, let value = envelope.data else {
                return unavailable(url, envelope.message ?? "视频已失效或不可公开访问")
            }
            let requestedPage = Int(URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "p" }?.value ?? "1") ?? 1
            if let pages = value.pages, !pages.contains(where: { $0.page == requestedPage }) {
                return unavailable(url, "视频分集已失效")
            }
            let displayTitle = value.pages?.first(where: { $0.page == requestedPage })?.part ?? value.title
            if let playerURL = VideoSource(urlString: url.absoluteString)?.playbackURL {
                var playerRequest = URLRequest(url: playerURL)
                playerRequest.timeoutInterval = 15
                playerRequest.setValue("OneKeep/1.0", forHTTPHeaderField: "User-Agent")
                let (_, playerResponse) = try await URLSession.shared.data(for: playerRequest)
                guard let playerHTTP = playerResponse as? HTTPURLResponse,
                      (200...399).contains(playerHTTP.statusCode) else {
                    return unavailable(url, "内嵌播放器当前不可访问")
                }
            }
            return ExerciseVideoHealthRecord(
                url: url, status: .available, checkedAt: .now, title: displayTitle,
                author: value.owner?.name, thumbnailURL: secureURL(value.pic), message: nil
            )
        } catch {
            return ExerciseVideoHealthRecord(
                url: url, status: .unknown, checkedAt: .now, title: nil, author: nil,
                thumbnailURL: nil, message: "网络检查未完成：\(error.localizedDescription)"
            )
        }
    }

    private func checkGeneric(_ url: URL) async -> ExerciseVideoHealthRecord {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 15
            let initialResult = try await URLSession.shared.data(for: request)
            var response = initialResult.1
            if (response as? HTTPURLResponse)?.statusCode == 405 {
                request.httpMethod = "GET"
                request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
                let retryResult = try await URLSession.shared.data(for: request)
                response = retryResult.1
            }
            guard let http = response as? HTTPURLResponse else { return unavailable(url, "服务器响应无效") }
            let status: ExerciseVideoHealthRecord.Status = (200...399).contains(http.statusCode) ? .available : .unavailable
            return ExerciseVideoHealthRecord(url: url, status: status, checkedAt: .now, title: nil, author: nil,
                                             thumbnailURL: nil, message: status == .available ? nil : "HTTP \(http.statusCode)")
        } catch {
            return ExerciseVideoHealthRecord(url: url, status: .unknown, checkedAt: .now, title: nil, author: nil,
                                             thumbnailURL: nil, message: error.localizedDescription)
        }
    }

    private func unavailable(_ url: URL, _ message: String) -> ExerciseVideoHealthRecord {
        ExerciseVideoHealthRecord(url: url, status: .unavailable, checkedAt: .now, title: nil, author: nil,
                                  thumbnailURL: nil, message: message)
    }

    private func secureURL(_ value: String?) -> URL? {
        guard let value else { return nil }
        if value.hasPrefix("http://") { return URL(string: "https://" + String(value.dropFirst(7))) }
        return URL(string: value)
    }
}

private struct BilibiliEnvelope: Decodable {
    struct Video: Decodable {
        struct Owner: Decodable { let name: String }
        struct Page: Decodable {
            let page: Int
            let part: String
        }
        let title: String
        let pic: String?
        let owner: Owner?
        let pages: [Page]?
    }
    let code: Int
    let message: String?
    let data: Video?
}
