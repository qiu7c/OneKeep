import CoreData
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @Environment(\.managedObjectContext) private var managedObjectContext
    @FetchRequest private var sessionObjects: FetchedResults<NSManagedObject>
    @FetchRequest private var setObjects: FetchedResults<NSManagedObject>
    @State private var cleanupError: String?

    init() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        _sessionObjects = FetchRequest(fetchRequest: request, animation: .default)

        let sets = NSFetchRequest<NSManagedObject>(entityName: "PerformedSetEntity")
        sets.sortDescriptors = [NSSortDescriptor(key: "completedAt", ascending: true)]
        _setObjects = FetchRequest(fetchRequest: sets, animation: .default)
    }

    private var todayItem: (plan: TrainingPlan, day: TrainingDay)? {
        ScheduleResolver.trainingDays(in: planLibrary.plans, on: .now).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if let activeSession {
                    if let activeDay = trainingDay(id: activeSession.trainingDayID) {
                        continueWorkoutCard(activeSession, day: activeDay)
                    } else {
                        unavailableWorkoutCard(activeSession)
                    }
                }
                if !isTodayWorkoutActive {
                    todayWorkout
                }
                quickWorkoutCard
                weeklyProgress
            }
            .padding(20)
        }
        .background(OKColor.background)
        .navigationTitle("今日")
        .alert("无法更新训练记录", isPresented: Binding(
            get: { cleanupError != nil },
            set: { if !$0 { cleanupError = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(cleanupError ?? "未知错误")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateFormatter.string(from: .now))
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)

            Text(activeSession == nil ? "准备好就开始" : "训练正在进行")
                .font(.system(size: 30, weight: .bold, design: .rounded))
        }
    }

    private var todayWorkout: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(todayItem?.day.title ?? "今天没有安排")
                        .font(.title3.bold())
                    Text(workoutSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(OKColor.secondaryText)
                }

                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.title2)
                    .accessibilityHidden(true)
            }

            if let day = todayItem?.day, !day.exercises.isEmpty {
                NavigationLink {
                    WorkoutView(trainingDay: day)
                } label: {
                    Label("开始训练", systemImage: "play.fill")
                }
                .buttonStyle(OKPrimaryButtonStyle())
            } else {
                NavigationLink {
                    PlansView()
                } label: {
                    Label("新建或导入计划", systemImage: "plus")
                }
                .buttonStyle(OKPrimaryButtonStyle())
            }
        }
        .okCard()
    }

    private var workoutSubtitle: String {
        guard let exercises = todayItem?.day.exercises, !exercises.isEmpty else {
            return planLibrary.plans.isEmpty ? "先建立一个训练计划" : "可以休息或开始临时训练"
        }
        return "\(exercises.count) 个动作"
    }

    private var weeklyProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("本周")
                    .font(.headline)
                Spacer()
                Text("\(completedThisWeek) / \(scheduledThisWeek)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(OKColor.secondaryText)
            }

            ProgressView(value: Double(completedThisWeek), total: Double(max(1, scheduledThisWeek)))
                .tint(OKColor.accent)

            Text(scheduledThisWeek == 0 ? "本周暂无计划安排" : "仅统计已完成并保存的训练")
                .font(.footnote)
                .foregroundStyle(OKColor.secondaryText)
        }
        .okCard()
    }

    private var quickWorkoutCard: some View {
        NavigationLink {
            QuickWorkoutComposerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt")
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text("临时训练").font(.headline).foregroundStyle(.primary)
                    Text("从动作库选动作，不改动现有计划")
                        .font(.footnote)
                        .foregroundStyle(OKColor.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OKColor.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .okCard()
    }

    private struct ActiveSession {
        let id: UUID
        let trainingDayID: UUID
        let title: String
        let startedAt: Date
        let progressedSets: Int
        let completedSets: Int
        let skippedSets: Int
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private var activeSession: ActiveSession? {
        guard let object = sessionObjects.first(where: {
            ($0.value(forKey: "status") as? String) == WorkoutSessionRepository.Status.active.rawValue
        }),
        let id = object.value(forKey: "id") as? UUID,
        let dayID = object.value(forKey: "trainingDayID") as? UUID,
        let startedAt = object.value(forKey: "startedAt") as? Date else { return nil }
        let sessionSets = setObjects.filter { ($0.value(forKey: "sessionID") as? UUID) == id }
        let skippedSets = sessionSets.filter { ($0.value(forKey: "isSkipped") as? NSNumber)?.boolValue ?? false }.count
        return ActiveSession(
            id: id,
            trainingDayID: dayID,
            title: object.value(forKey: "title") as? String ?? "未完成训练",
            startedAt: startedAt,
            progressedSets: sessionSets.count,
            completedSets: sessionSets.count - skippedSets,
            skippedSets: skippedSets
        )
    }

    private var isTodayWorkoutActive: Bool {
        guard let activeSession, let todayItem else { return false }
        return activeSession.trainingDayID == todayItem.day.id
    }

    private func trainingDay(id: UUID) -> TrainingDay? {
        planLibrary.plans.lazy.flatMap(\.days).first { $0.id == id }
    }

    private func continueWorkoutCard(_ session: ActiveSession, day: TrainingDay) -> some View {
        let totalSets = WorkoutExecutionPlan.makeSteps(from: day).count
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text("训练进行中")
                        .font(.headline)
                    Text(session.title)
                        .font(.title3.bold())
                }
                Spacer()
                Text("\(min(session.progressedSets, totalSets)) / \(totalSets)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(OKColor.secondaryText)
            }

            ProgressView(
                value: Double(min(session.progressedSets, totalSets)),
                total: Double(max(1, totalSets))
            )
            .tint(OKColor.accent)

            Text(progressDescription(session))
                .font(.footnote)
                .foregroundStyle(OKColor.secondaryText)
            NavigationLink {
                WorkoutView(
                    trainingDay: day,
                    resumeSessionID: session.id,
                    completedStepCount: session.progressedSets
                )
            } label: {
                Label("返回训练", systemImage: "play.fill")
            }
            .buttonStyle(OKPrimaryButtonStyle())
        }
        .okCard()
    }

    private func progressDescription(_ session: ActiveSession) -> String {
        var values = ["完成 \(session.completedSets) 组"]
        if session.skippedSets > 0 { values.append("跳过 \(session.skippedSets) 组") }
        values.append("开始于 \(session.startedAt.formatted(date: .omitted, time: .shortened))")
        return values.joined(separator: " · ")
    }

    private func unavailableWorkoutCard(_ session: ActiveSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("未完成训练的原计划已不存在", systemImage: "exclamationmark.circle")
                .font(.headline)
            Text(session.title)
                .font(.title3.bold())
            Text("可能是计划被删除或由备份替换。可以结束这条进行中记录，不会计入完成次数。")
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)
            Button(role: .destructive) {
                do {
                    try WorkoutSessionRepository(context: managedObjectContext).cancel(id: session.id)
                } catch {
                    cleanupError = error.localizedDescription
                }
            } label: {
                Label("结束这条记录", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        }
        .okCard()
    }

    private var weekInterval: DateInterval? {
        Calendar.current.dateInterval(of: .weekOfYear, for: .now)
    }

    private var scheduledThisWeek: Int {
        guard let interval = weekInterval else { return 0 }
        var date = interval.start
        var count = 0
        while date < interval.end {
            count += ScheduleResolver.trainingDays(in: planLibrary.plans, on: date).count
            date = Calendar.current.date(byAdding: .day, value: 1, to: date) ?? interval.end
        }
        return count
    }

    private var completedThisWeek: Int {
        guard let interval = weekInterval else { return 0 }
        return sessionObjects.filter { session in
            guard (session.value(forKey: "status") as? String) == WorkoutSessionRepository.Status.completed.rawValue,
                  let date = session.value(forKey: "startedAt") as? Date else { return false }
            return interval.contains(date)
        }.count
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(PlanLibraryStore(repository: InMemoryPlanRepository(plans: [.preview])))
    .environment(\.managedObjectContext, PersistenceController(inMemory: true).container.viewContext)
}
