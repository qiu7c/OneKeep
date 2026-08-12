import CoreData
import SwiftUI

struct RecordsView: View {
    @FetchRequest private var sessionObjects: FetchedResults<NSManagedObject>
    @FetchRequest private var setObjects: FetchedResults<NSManagedObject>

    init() {
        let sessions = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        sessions.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        _sessionObjects = FetchRequest(fetchRequest: sessions, animation: .default)

        let sets = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        sets.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: false)]
        _setObjects = FetchRequest(fetchRequest: sets, animation: .default)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryCard
                if !completedSessions.isEmpty {
                    historyCard
                }
                quickLogsCard
                backupCard
            }
            .padding(20)
        }
        .background(OKColor.background)
        .navigationTitle("记录")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练记录")
                .font(.headline)

            HStack(spacing: 0) {
                metric(value: String(weeklySessions.count), label: "本周训练")
                Divider().frame(height: 42)
                metric(value: String(weeklySets.count), label: "完成组数")
                Divider().frame(height: 42)
                metric(value: String(weeklyMinutes), label: "训练分钟")
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
                        .accessibilityHidden(true)
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
                .padding(.vertical, 4)
            }
        }
        .okCard()
    }

    private var quickLogsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("简短记录")
                .font(.headline)

            HStack(spacing: 10) {
                quickLogButton(title: "饮食", icon: "fork.knife")
                quickLogButton(title: "睡眠", icon: "bed.double")
                quickLogButton(title: "身体", icon: "ruler")
            }
        }
        .okCard()
    }

    private var backupCard: some View {
        Button(action: {}) {
            HStack(spacing: 14) {
                Image(systemName: "externaldrive")
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text("备份与恢复")
                        .foregroundStyle(.primary)
                    Text("导出完整 ZIP 数据")
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(OKColor.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .okCard()
    }

    private var completedSessions: [NSManagedObject] {
        sessionObjects.filter { ($0.value(forKey: "status") as? String) == WorkoutSessionRepository.Status.completed.rawValue }
    }

    private var weekInterval: DateInterval? {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)
    }

    private var weeklySessions: [NSManagedObject] {
        guard let weekInterval else { return [] }
        return completedSessions.filter { session in
            guard let date = session.value(forKey: "startedAt") as? Date else { return false }
            return weekInterval.contains(date)
        }
    }

    private var weeklySets: [NSManagedObject] {
        guard let weekInterval else { return [] }
        return setObjects.filter { set in
            guard let date = set.value(forKey: "completedAt") as? Date else { return false }
            return weekInterval.contains(date)
        }
    }

    private var weeklyMinutes: Int {
        let seconds = weeklySessions.reduce(0.0) { partial, session in
            guard let start = session.value(forKey: "startedAt") as? Date,
                  let end = session.value(forKey: "endedAt") as? Date else {
                return partial
            }
            return partial + max(0, end.timeIntervalSince(start))
        }
        return Int(seconds / 60)
    }

    private func durationText(_ session: NSManagedObject) -> String {
        guard let start = session.value(forKey: "startedAt") as? Date,
              let end = session.value(forKey: "endedAt") as? Date else {
            return "--"
        }
        return "\(max(0, Int(end.timeIntervalSince(start) / 60))) 分钟"
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(OKColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private func quickLogButton(title: String, icon: String) -> some View {
        Button(action: {}) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(OKColor.background)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(OKColor.border, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        RecordsView()
    }
    .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
}
