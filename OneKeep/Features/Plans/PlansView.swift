import SwiftUI
import UniformTypeIdentifiers

struct PlansView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @State private var showsImporter = false
    @State private var showsComposer = false
    @State private var showsAIImporter = false
    @State private var exportedFile: ExportedFile?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if planLibrary.plans.isEmpty {
                    emptyState
                } else {
                    ForEach(planLibrary.plans) { plan in
                        planCard(plan)
                    }
                }

                importCard
            }
            .padding(20)
        }
        .background(OKColor.background)
        .navigationTitle("计划")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showsComposer = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建计划")
            }
        }
        .sheet(isPresented: $showsComposer) {
            NavigationStack {
                PlanComposerView()
            }
        }
        .sheet(isPresented: $showsAIImporter) {
            NavigationStack {
                AIPlanImportView()
            }
        }
        .sheet(item: $exportedFile) { file in
            ShareSheet(items: [file.url])
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            importFile(result)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 34, weight: .medium))
                .accessibilityHidden(true)
            Text("还没有计划")
                .font(.title3.bold())
            Text("手动创建，或导入已有 JSON 计划。")
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)
                .multilineTextAlignment(.center)

            Button("新建计划") {
                showsComposer = true
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .okCard()
    }

    private func planCard(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.title)
                        .font(.title3.bold())
                    Text(planSummary(plan))
                        .font(.subheadline)
                        .foregroundStyle(OKColor.secondaryText)
                }

                Spacer()

                Menu {
                    Button {
                        export(plan)
                    } label: {
                        Label("导出 JSON", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        planLibrary.delete(plan)
                    } label: {
                        Label("删除计划", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("计划操作")
            }

            if let day = plan.days.first {
                Divider()
                HStack {
                    Image(systemName: "calendar.day.timeline.left")
                        .frame(width: 28)
                    Text(day.title)
                    Spacer()
                    Text("\(day.exercises.count) 个动作")
                        .foregroundStyle(OKColor.secondaryText)
                }
                .font(.subheadline)
            }
        }
        .okCard()
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("导入计划")
                .font(.headline)

            importRow(title: "粘贴文本", detail: "整理已有训练内容", icon: "doc.on.clipboard") {}
            importRow(title: "使用 AI", detail: "连接兼容接口并预览", icon: "sparkles") {
                showsAIImporter = true
            }
            importRow(title: "导入 JSON", detail: "打开 OneKeep 计划文件", icon: "arrow.down.doc") {
                showsImporter = true
            }
        }
        .okCard()
    }

    private func importRow(
        title: String,
        detail: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(OKColor.secondaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func planSummary(_ plan: TrainingPlan) -> String {
        let exerciseCount = plan.days.reduce(0) { $0 + $1.exercises.count }
        return "\(plan.days.count) 个训练日 · \(exerciseCount) 个动作"
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            planLibrary.importPlanDocument(try Data(contentsOf: url))
        } catch {
            planLibrary.presentedError = PresentedError(title: "导入失败", message: error.localizedDescription)
        }
    }

    private func export(_ plan: TrainingPlan) {
        do {
            exportedFile = ExportedFile(url: try planLibrary.exportURL(for: plan))
        } catch {
            planLibrary.presentedError = PresentedError(title: "导出失败", message: error.localizedDescription)
        }
    }
}

private struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    NavigationStack {
        PlansView()
    }
    .environmentObject(PlanLibraryStore(repository: InMemoryPlanRepository(plans: [.preview])))
}
