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
                WebVideoPlayer(url: url)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OKColor.border, lineWidth: 0.5)
        }
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
                    Text("正在加载移动播放页…")
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
        VideoPlayer(player: player)
            .task(id: url) {
                let playbackURL = await ExerciseVideoOfflineStore.shared.localURL(for: url) ?? url
                player.replaceCurrentItem(with: AVPlayerItem(url: playbackURL))
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
