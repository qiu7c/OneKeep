import SwiftUI

struct VideoMediaSettingsView: View {
    @State private var records = ExerciseVideoHealthStore.records()
    @State private var isChecking = false
    @State private var offlineBytes: Int64 = 0
    @State private var message: String?
    @State private var showsClearConfirmation = false

    var body: some View {
        Form {
            Section("视频目录") {
                LabeledContent("动作专项视频", value: "\(ExerciseLibraryCatalog.builtInItems.count)")
                LabeledContent("分类备用源", value: "8")
                LabeledContent("已检测链接", value: "\(records.count)")
                LabeledContent("发现失效", value: "\(unavailableCount)")
                Button {
                    checkAll()
                } label: {
                    Label(isChecking ? "正在检测全部链接" : "立即检测全部链接", systemImage: "checkmark.shield")
                }
                .disabled(isChecking)
            }

            Section("缓存") {
                LabeledContent("离线视频", value: ByteCountFormatter.string(fromByteCount: offlineBytes, countStyle: .file))
                Text("封面自动缓存，最多占用约 100 MB 并优先清理最久未使用的文件。只有 MP4、MOV、M4V 文件直链支持离线缓存；哔哩哔哩网页视频保持在线播放。")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
                Button(role: .destructive) {
                    showsClearConfirmation = true
                } label: {
                    Label("清理视频与封面缓存", systemImage: "trash")
                }
            }

            if let message {
                Section { Text(message).font(.footnote).foregroundStyle(OKColor.secondaryText) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("视频与缓存")
        .navigationBarTitleDisplayMode(.inline)
        .task { offlineBytes = await ExerciseVideoOfflineStore.shared.storageSize() }
        .confirmationDialog("清理全部媒体缓存？", isPresented: $showsClearConfirmation, titleVisibility: .visible) {
            Button("清理缓存", role: .destructive) { clearCaches() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只删除可重新下载的封面和离线视频，不删除动作资料或视频链接。")
        }
    }

    private var unavailableCount: Int {
        records.values.filter { $0.status == .unavailable }.count
    }

    private func checkAll() {
        isChecking = true
        message = nil
        Task {
            await ExerciseVideoHealthService.shared.checkCatalog(ExerciseLibraryCatalog.allItems())
            records = ExerciseVideoHealthStore.records()
            isChecking = false
            message = unavailableCount == 0 ? "全部链接检测完成，当前未发现失效视频。" : "检测完成，失效主链接会自动切换到备用源。"
        }
    }

    private func clearCaches() {
        Task {
            do {
                try await VideoThumbnailCache.shared.removeAll()
                try await ExerciseVideoOfflineStore.shared.removeAll()
                offlineBytes = 0
                message = "媒体缓存已清理。"
            } catch {
                message = error.localizedDescription
            }
        }
    }
}
