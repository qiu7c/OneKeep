import AVKit
import SwiftUI
import WebKit

struct ExerciseVideoView: View {
    let source: VideoSource

    var body: some View {
        Group {
            switch source {
            case .native(let url):
                NativeVideoPlayer(url: url)
            case .web(let url):
                if VideoSource.isBilibiliURL(url) {
                    BilibiliNativeVideoPlayer(url: url)
                } else {
                    WebVideoPlayer(url: url)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OKColor.border, lineWidth: 0.5)
                .allowsHitTesting(false)
        }
    }
}

private struct BilibiliNativeVideoPlayer: View {
    let url: URL
    @StateObject private var model: BilibiliPlayerModel

    init(url: URL) {
        self.url = url
        _model = StateObject(wrappedValue: BilibiliPlayerModel(pageURL: url))
    }

    var body: some View {
        ZStack {
            Color.black
            if model.isReady {
                NativePlayerController(player: model.player)
            } else if let errorMessage = model.errorMessage {
                VStack(spacing: 11) {
                    Image(systemName: "exclamationmark.circle")
                    Text(errorMessage).font(.caption).multilineTextAlignment(.center)
                    HStack(spacing: 16) {
                        Button("重试") { Task { await model.load(force: true) } }
                        Link("网页备用", destination: url)
                    }
                    .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(16)
            } else {
                VStack(spacing: 9) {
                    ProgressView().tint(.white)
                    Text("正在获取原生视频流…").font(.caption)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .task(id: url) { await model.load() }
        .onDisappear { model.player.pause() }
    }
}

@MainActor
private final class BilibiliPlayerModel: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var errorMessage: String?
    let player = AVPlayer()

    private let pageURL: URL
    private var hasLoaded = false

    init(pageURL: URL) {
        self.pageURL = pageURL
    }

    func load(force: Bool = false) async {
        guard force || !hasLoaded else { return }
        hasLoaded = true
        isReady = false
        errorMessage = nil
        player.pause()
        do {
            let source = try await BilibiliPlaybackResolver.shared.resolve(pageURL)
            let item = try await Self.makeItem(source)
            guard try await item.asset.load(.isPlayable) else {
                throw BilibiliPlaybackResolver.ResolverError.noPlayableStream
            }
            guard !Task.isCancelled else { return }
            player.replaceCurrentItem(with: item)
            isReady = true
            player.play()
        } catch is CancellationError {
            hasLoaded = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeItem(_ source: BilibiliPlaybackSource) async throws -> AVPlayerItem {
        switch source.stream {
        case .progressive(let urls):
            guard let first = urls.first else { throw BilibiliPlaybackResolver.ResolverError.noPlayableStream }
            if urls.count == 1 {
                return AVPlayerItem(asset: asset(url: first, headers: source.headers))
            }
            let assets = urls.map { asset(url: $0, headers: source.headers) }
            return AVPlayerItem(asset: try await concatenate(assets))

        case .dash(let videoURL, let audioURL):
            let videoAsset = asset(url: videoURL, headers: source.headers)
            guard let audioURL else { return AVPlayerItem(asset: videoAsset) }
            return AVPlayerItem(asset: try await combine(
                video: videoAsset,
                audio: asset(url: audioURL, headers: source.headers)
            ))
        }
    }

    private static func asset(url: URL, headers: [String: String]) -> AVURLAsset {
        AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
    }

    private static func concatenate(_ assets: [AVURLAsset]) async throws -> AVMutableComposition {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw BilibiliPlaybackResolver.ResolverError.noPlayableStream
        }
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        var cursor = CMTime.zero
        for asset in assets {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration)
            guard let sourceVideo = videoTracks.first, duration.isNumeric else {
                throw BilibiliPlaybackResolver.ResolverError.noPlayableStream
            }
            try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceVideo, at: cursor)
            if let sourceAudio = audioTracks.first {
                try audioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceAudio, at: cursor)
            }
            cursor = CMTimeAdd(cursor, duration)
        }
        return composition
    }

    private static func combine(video: AVURLAsset, audio: AVURLAsset) async throws -> AVMutableComposition {
        let videoTracks = try await video.loadTracks(withMediaType: .video)
        let audioTracks = try await audio.loadTracks(withMediaType: .audio)
        let videoDuration = try await video.load(.duration)
        let audioDuration = try await audio.load(.duration)
        guard let sourceVideo = videoTracks.first, let sourceAudio = audioTracks.first,
              videoDuration.isNumeric, audioDuration.isNumeric else {
            throw BilibiliPlaybackResolver.ResolverError.noPlayableStream
        }
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw BilibiliPlaybackResolver.ResolverError.noPlayableStream
        }
        let duration = CMTimeCompare(videoDuration, audioDuration) <= 0 ? videoDuration : audioDuration
        try videoTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceVideo, at: .zero)
        try audioTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceAudio, at: .zero)
        return composition
    }
}

private struct NativePlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player { controller.player = player }
    }
}

private struct WebVideoPlayer: View {
    let url: URL
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var reloadID = UUID()

    var body: some View {
        ZStack {
            EmbeddedWebVideo(url: url, isLoading: $isLoading, errorMessage: $errorMessage)
                .id(reloadID)
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("正在加载在线视频…")
                        .font(.caption)
                        .foregroundStyle(OKColor.secondaryText)
                }
                .allowsHitTesting(false)
            }
            if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.circle")
                    Text(errorMessage).font(.caption).multilineTextAlignment(.center)
                    Button("重新加载") {
                        self.errorMessage = nil
                        isLoading = true
                        reloadID = UUID()
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(16)
                .background(OKColor.surface)
            }
        }
    }
}

private struct NativeVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        NativePlayerController(player: player)
            .task(id: url) {
                let playbackURL = await ExerciseVideoOfflineStore.shared.localURL(for: url) ?? url
                player.replaceCurrentItem(with: AVPlayerItem(url: playbackURL))
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}

private struct EmbeddedWebVideo: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var errorMessage: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self, initialHost: url.host)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.scrollView.isScrollEnabled = isBilibili(url)
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.isOpaque = false
        view.backgroundColor = .clear
        view.customUserAgent = Self.mobileSafariUserAgent
        view.load(request(for: url))
        return view
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard webView.url != url else { return }
        webView.scrollView.isScrollEnabled = isBilibili(url)
        webView.load(request(for: url))
    }

    private func request(for url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 30)
        request.setValue("zh-CN,zh;q=0.9,en;q=0.7", forHTTPHeaderField: "Accept-Language")
        if isBilibili(url) {
            request.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
        }
        return request
    }

    private func isBilibili(_ url: URL) -> Bool {
        url.host?.lowercased().hasSuffix("bilibili.com") == true
    }

    private static let mobileSafariUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EmbeddedWebVideo
        private let initialHost: String?

        init(parent: EmbeddedWebVideo, initialHost: String?) {
            self.parent = parent
            self.initialHost = initialHost
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.errorMessage = "视频加载失败：\(error.localizedDescription)"
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.errorMessage = "视频连接失败：\(error.localizedDescription)"
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated else {
                decisionHandler(.allow)
                return
            }

            let targetHost = navigationAction.request.url?.host
            decisionHandler(targetHost == initialHost ? .allow : .cancel)
        }
    }
}
