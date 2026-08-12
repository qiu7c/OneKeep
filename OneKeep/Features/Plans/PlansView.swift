import SwiftUI
import UniformTypeIdentifiers

struct PlansView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @State private var showsImporter = false
    @State private var showsComposer = false
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
                    NavigationLink {
                        PlanEditorView(plan: plan)
                    } label: {
                        Label("编辑计划", systemImage: "pencil")
                    }

                    Button {
                        planLibrary.save(plan.duplicated())
                    } label: {
                        Label("复制计划", systemImage: "doc.on.doc")
                    }

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
                HStack {
                    Image(systemName: "calendar.day.timeline.left")
                        .frame(width: 28)
                    Text(day.title)
                    Spacer()
                    Text("\(day.exercises.count) 个动作")
                        .foregroundStyle(OKColor.secondaryText)
                }
                .font(.subheadline)
                .padding(12)
                .background(OKColor.background)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            }

            NavigationLink {
                PlanEditorView(plan: plan)
            } label: {
                HStack {
                    Label("查看全部并编辑", systemImage: "list.bullet")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .okCard()
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("导入计划")
                .font(.headline)

            NavigationLink {
                AIPlanImportView()
            } label: {
                importLabel(
                    title: "AI 计划助手",
                    detail: "粘贴计划、多轮讨论、改善建议与导入",
                    icon: "bubble.left.and.bubble.right"
                )
            }
            .buttonStyle(.plain)
            NavigationLink {
                ExerciseLibraryView()
            } label: {
                importLabel(
                    title: "动作库",
                    detail: "查看动作步骤、常见错误和视频链接",
                    icon: "figure.mixed.cardio"
                )
            }
            .buttonStyle(.plain)
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
            importLabel(title: title, detail: detail, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func importLabel(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundStyle(.primary)
                Text(detail).font(.footnote).foregroundStyle(OKColor.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(OKColor.secondaryText)
        }
        .contentShape(Rectangle())
        .padding(10)
        .background(OKColor.background)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
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
