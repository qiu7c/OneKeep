import SwiftUI
import UniformTypeIdentifiers

struct BackupView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var planLibrary: PlanLibraryStore

    @State private var showsImporter = false
    @State private var exportedURL: URL?
    @State private var pendingImportURL: URL?
    @State private var showsReplaceConfirmation = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Label("训练计划、训练记录、快捷记录、个人资料和 AI 配置均只保存在本机。", systemImage: "iphone")
                Label("完整备份是唯一的数据迁移方式，不包含 API Key。", systemImage: "key")
            } header: {
                Text("本地数据")
            }

            Section("完整 ZIP 备份") {
                Button(action: exportBackup) {
                    Label("导出完整备份", systemImage: "square.and.arrow.up")
                }
                Button {
                    showsImporter = true
                } label: {
                    Label("导入完整备份", systemImage: "square.and.arrow.down")
                }
            }

            Section {
                Text("导入会先校验备份，然后替换此设备上的全部 OneKeep 数据。API Key 始终留在钥匙串中，不会导出，也不会被备份覆盖。")
                    .font(.footnote)
                    .foregroundStyle(OKColor.secondaryText)
            }

            if let statusMessage {
                Section {
                    Label(statusMessage, systemImage: "checkmark.circle")
                        .foregroundStyle(OKColor.secondaryText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(OKColor.background)
        .navigationTitle("备份与恢复")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { exportedURL != nil },
            set: { if !$0 { exportedURL = nil } }
        )) {
            if let exportedURL {
                ShareSheet(items: [exportedURL])
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.zip], allowsMultipleSelection: false) { result in
            prepareImport(result)
        }
        .confirmationDialog(
            "替换本机全部数据？",
            isPresented: $showsReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("导入并替换", role: .destructive, action: restoreBackup)
            Button("取消", role: .cancel) { pendingImportURL = nil }
        } message: {
            Text("建议先导出当前数据。替换后只能使用已有备份恢复。")
        }
        .alert("操作失败", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "未知错误")
        }
    }

    private func exportBackup() {
        do {
            exportedURL = try CompleteBackupService(context: context).exportArchive()
            statusMessage = "完整备份已生成"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareImport(_ result: Result<[URL], Error>) {
        do {
            guard let source = try result.get().first else { return }
            let accessed = source.startAccessingSecurityScopedResource()
            defer { if accessed { source.stopAccessingSecurityScopedResource() } }
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent("OneKeep-Import-\(UUID().uuidString).zip")
            try Data(contentsOf: source).write(to: destination, options: .atomic)
            pendingImportURL = destination
            showsReplaceConfirmation = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func restoreBackup() {
        guard let pendingImportURL else { return }
        do {
            try CompleteBackupService(context: context).restoreArchive(from: pendingImportURL)
            planLibrary.reload()
            statusMessage = "备份已恢复"
            self.pendingImportURL = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

