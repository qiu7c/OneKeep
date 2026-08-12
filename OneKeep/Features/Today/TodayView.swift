import CoreData
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @FetchRequest private var sessionObjects: FetchedResults<NSManagedObject>

    init() {
        let request = NSFetchRequest<NSManagedObject>(entityName: "WorkoutSessionEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        _sessionObjects = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var todayItem: (plan: TrainingPlan, day: TrainingDay)? {
        ScheduleResolver.trainingDays(in: planLibrary.plans, on: .now).first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                todayWorkout
                weeklyProgress
            }
            .padding(20)
        }
        .background(OKColor.background)
        .navigationTitle("今日")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now, format: .dateTime.month().day().weekday(.wide))
                .font(.subheadline)
                .foregroundStyle(OKColor.secondaryText)

            Text("准备好就开始")
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
