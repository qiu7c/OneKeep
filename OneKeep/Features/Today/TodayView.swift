import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("快速新增")
            }
        }
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
                Text("2 / 5")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(OKColor.secondaryText)
            }

            ProgressView(value: 2, total: 5)
                .tint(OKColor.accent)

            Text("完成记录将在这里汇总")
                .font(.footnote)
                .foregroundStyle(OKColor.secondaryText)
        }
        .okCard()
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .environmentObject(PlanLibraryStore(repository: InMemoryPlanRepository(plans: [.preview])))
}
