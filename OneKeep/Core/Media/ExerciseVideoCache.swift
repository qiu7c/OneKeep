import CryptoKit
import Foundation
import SwiftUI
import UIKit

struct CachedVideoThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Rectangle().fill(OKColor.background)
                ProgressView()
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: url) { image = await VideoThumbnailCache.shared.image(for: url) }
    }
}

actor VideoThumbnailCache {
    static let shared = VideoThumbnailCache()
    private let memory = NSCache<NSURL, UIImage>()
    private let diskLimitBytes: Int64 = 100 * 1_024 * 1_024

    init() {
        memory.countLimit = 40
        memory.totalCostLimit = 30 * 1_024 * 1_024
    }

    func image(for url: URL) async -> UIImage? {
        if let value = memory.object(forKey: url as NSURL) { return value }
        let localURL = cacheDirectory.appendingPathComponent(cacheKey(url) + ".image")
        if let data = try? Data(contentsOf: localURL), let image = UIImage(data: data) {
            memory.setObject(image, forKey: url as NSURL, cost: data.count)
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: localURL.path)
            return image
        }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode),
                  data.count <= 10 * 1_024 * 1_024,
                  let image = UIImage(data: data) else { return nil }
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            try data.write(to: localURL, options: .atomic)
            memory.setObject(image, forKey: url as NSURL, cost: data.count)
            trimDiskCacheIfNeeded()
            return image
        } catch {
            return nil
        }
    }

    func removeAll() throws {
        memory.removeAllObjects()
        if FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try FileManager.default.removeItem(at: cacheDirectory)
        }
    }

    private var cacheDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExerciseVideoThumbnails", isDirectory: true)
    }

    private func trimDiskCacheIfNeeded() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return }
        let values = files.compactMap { url -> (URL, Int64, Date)? in
            guard let value = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, Int64(value.fileSize ?? 0), value.contentModificationDate ?? .distantPast)
        }
        var total = values.reduce(Int64(0)) { $0 + $1.1 }
        guard total > diskLimitBytes else { return }
        for value in values.sorted(by: { $0.2 < $1.2 }) where total > diskLimitBytes {
            do {
                try FileManager.default.removeItem(at: value.0)
                total -= value.1
            } catch {
                continue
            }
        }
    }
}

actor ExerciseVideoOfflineStore {
    static let shared = ExerciseVideoOfflineStore()

    func localURL(for remoteURL: URL) -> URL? {
        let value = destination(for: remoteURL)
        return FileManager.default.fileExists(atPath: value.path) ? value : nil
    }

    func download(_ remoteURL: URL) async throws -> URL {
        guard VideoSource(urlString: remoteURL.absoluteString)?.supportsOfflineCache == true else {
            throw OfflineVideoError.unsupportedSource
        }
        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw OfflineVideoError.downloadFailed
        }
        let folder = destination(for: remoteURL).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = destination(for: remoteURL)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    func remove(_ remoteURL: URL) throws {
        let value = destination(for: remoteURL)
        if FileManager.default.fileExists(atPath: value.path) { try FileManager.default.removeItem(at: value) }
    }

    func storageSize() -> Int64 {
        guard let values = try? FileManager.default.contentsOfDirectory(
            at: videoDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return values.reduce(0) { result, url in
            result + Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    func removeAll() throws {
        if FileManager.default.fileExists(atPath: videoDirectory.path) {
            try FileManager.default.removeItem(at: videoDirectory)
        }
    }

    private func destination(for url: URL) -> URL {
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        return videoDirectory
            .appendingPathComponent(cacheKey(url) + "." + ext)
    }

    private var videoDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ExerciseVideos", isDirectory: true)
    }
}

enum OfflineVideoError: LocalizedError {
    case unsupportedSource
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSource: return "该平台只提供网页播放，不能合法缓存为离线文件"
        case .downloadFailed: return "视频文件下载失败"
        }
    }
}

private func cacheKey(_ url: URL) -> String {
    SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
}
