import CoreData
import SwiftUI

struct RecordsView: View {
    @FetchRequest private var sessionObjects: FetchedResults<NSManagedObject>
    @FetchRequest private var setObjects: FetchedResults<NSManagedObject>
    @FetchRequest private var quickLogObjects: FetchedResults<NSManagedObject>

    @State private var selectedQuickLogKind: QuickLogKind?
    @State private var showsProfile = false
    @State private var showsAISettings = false
    @State private var profile = UserProfilePreferences.load()

    init() {
        let sessions = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        sessions.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        _sessionObjects = FetchRequest(fetchRequest: sessions, animation: .default)

        let sets = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        sets.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        _setObjects = FetchRequest(fetchRequest: sets, animation: .default)

        let logs = NSFetchRequest<NSManagedObject>(entityName: "QuickLogEntity")
        logs.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        _quickLogObjects = FetchRequest(fetchRequest: logs, animation: .default)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileCard
                summaryCard
                quickLogsCard
                if !quickLogObjects.isEmpty { recentLogsCard }
                if !completedSessions.isEmpty { historyCard }
                settingsCard
            }
            .padding(20)
        }
        .background(OKColor.background)
        .navigationTitle("我的")
        .sheet(isPresented: $showsProfile, onDismiss: { profile = UserProfilePreferences.load() }) {
            NavigationStack { ProfileEditorView() }
        }
        .sheet(item: $selectedQuickLogKind) { kind in
            NavigationStack { QuickLogEditorView(kind: kind) }
        }
        .sheet(isPresented: $showsAISettings) {
            NavigationStack { AISettingsView() }
        }
    }

    private var profileCard: some View {
        Button { showsProfile = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nickname.isEmpty ? "填写个人资料" : profile.nickname)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(profileSummary)
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
        .okCard()
    }

    private var profileSummary: String {
        var values: [String] = []
        if let height = profile.heightCentimeters { values.append("\(height.formatted()) cm") }
        if let weight = profile.weightKilograms { values.append("\(weight.formatted()) kg") }
        return values.isEmpty ? "资料仅保存在此设备" : values.joined(separator: " · ")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("本周训练")
                .font(.headline)
            HStack(spacing: 0) {
                metric(value: String(weeklySessions.count), label: "训练次数")
                Divider().frame(height: 42)
                metric(value: String(weeklySets.count), label: "完成组数")
                Divider().frame(height: 42)
                metric(value: String(weeklyMinutes), label: "训练分钟")
            }
        }
        .okCard()
    }

    private var quickLogsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("快捷记录")
                .font(.headline)
            HStack(spacing: 10) {
                quickLogButton(.food)
                quickLogButton(.sleep)
                quickLogButton(.body)
                quickLogButton(.note)
            }
        }
        .okCard()
    }

    private var recentLogsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近记录")
                .font(.headline)
            ForEach(Array(quickLogObjects.prefix(5)), id: \.objectID) { item in
                let kind = QuickLogKind(rawValue: item.value(forKey: "kind") as? String ?? "") ?? .note
                HStack(spacing: 12) {
                    Image(systemName: kind.icon).frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(quickLogTitle(item, kind: kind))
                            .lineLimit(1)
                        if let date = item.value(forKey: "createdAt") as? Date {
                            Text(date, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(OKColor.secondaryText)
                        }
                    }
                    Spacer()
                }
            }
        }
        .okCard()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近训练")
                .font(.headline)
            ForEach(Array(completedSessions.prefix(5)), id: \.objectID) { session in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.value(forKey: "title") as? String ?? "训练")
                        if let date = session.value(forKey: "startedAt") as? Date {
                            Text(date, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(OKColor.secondaryText)
                        }
                    }
                    Spacer()
                    Text(durationText(session))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(OKColor.secondaryText)
                }
            }
        }
        .okCard()
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            settingsLink(title: "AI 接口与提示词", detail: "API Key 仅存钥匙串", icon: "slider.horizontal.3") {
                showsAISettings = true
            }
            Divider().padding(.leading, 42)
            NavigationLink {
                BackupView()
            } label: {
                settingsLabel(title: "备份与恢复", detail: "完整 ZIP 导入导出", icon: "externaldrive")
            }
            .buttonStyle(.plain)
        }
        .okCard()
    }

    private func settingsLink(title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { settingsLabel(title: title, detail: detail, icon: icon) }
            .buttonStyle(.plain)
    }

    private func settingsLabel(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).foregroundStyle(.primary)
                Text(detail).font(.footnote).foregroundStyle(OKColor.secondaryText)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(OKColor.secondaryText)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }

    private var completedSessions: [NSManagedObject] {
        sessionObjects.filter { ($0.value(forKey: "status") as? String) == WorkoutSessionRepository.Status.completed.rawValue }
    }

    private var weekInterval: DateInterval? { Calendar.current.dateInterval(of: .weekOfYear, for: .now) }

    private var weeklySessions: [NSManagedObject] {
        guard let weekInterval else { return [] }
        return completedSessions.filter { ($0.value(forKey: "startedAt") as? Date).map(weekInterval.contains) ?? false }
    }

    private var weeklySets: [NSManagedObject] {
        guard let weekInterval else { return [] }
        return setObjects.filter { ($0.value(forKey: "completedAt") as? Date).map(weekInterval.contains) ?? false }
    }

    private var weeklyMinutes: Int {
        let seconds = weeklySessions.reduce(0.0) { result, session in
            guard let start = session.value(forKey: "startedAt") as? Date,
                  let end = session.value(forKey: "endedAt") as? Date else { return result }
            return result + max(0, end.timeIntervalSince(start))
        }
        return Int(seconds / 60)
    }

    private func quickLogButton(_ kind: QuickLogKind) -> some View {
        Button { selectedQuickLogKind = kind } label: {
            VStack(spacing: 9) {
                Image(systemName: kind.icon).font(.title3)
                Text(kind.title).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(OKColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OKColor.border, lineWidth: 0.5) }
        }
        .buttonStyle(.plain)
    }

    private func quickLogTitle(_ item: NSManagedObject, kind: QuickLogKind) -> String {
        if kind == .body, let value = (item.value(forKey: "value") as? NSNumber)?.doubleValue {
            return "体重 \(value.formatted()) kg"
        }
        let note = (item.value(forKey: "note") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return note.isEmpty ? kind.title : note
    }

    private func durationText(_ session: NSManagedObject) -> String {
        guard let start = session.value(forKey: "startedAt") as? Date,
              let end = session.value(forKey: "endedAt") as? Date else { return "--" }
        return "\(max(0, Int(end.timeIntervalSince(start) / 60))) 分钟"
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value).font(.title2.bold().monospacedDigit())
            Text(label).font(.caption).foregroundStyle(OKColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack { RecordsView() }
        .environmentObject(PlanLibraryStore(repository: InMemoryPlanRepository(plans: [.preview])))
        .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
}
