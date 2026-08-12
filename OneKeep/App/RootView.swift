import SwiftUI

struct RootView: View {
    @EnvironmentObject private var planLibrary: PlanLibraryStore
    @Environment(\.scenePhase) private var scenePhase

    private enum Tab: Hashable {
        case today
        case plans
        case records
    }

    @State private var selection: Tab = .today

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("今日", systemImage: "figure.strengthtraining.traditional")
            }
            .tag(Tab.today)

            NavigationStack {
                PlansView()
            }
            .tabItem {
                Label("计划", systemImage: "calendar")
            }
            .tag(Tab.plans)

            NavigationStack {
                RecordsView()
            }
            .tabItem {
                Label("我的", systemImage: "person.crop.circle")
            }
            .tag(Tab.records)
        }
        .task {
            planLibrary.loadIfNeeded()
            await ExerciseVideoHealthService.shared.checkCatalogIfNeeded(ExerciseLibraryCatalog.allItems())
        }
        .onChange(of: scenePhase) { phase in
            guard phase == .active else { return }
            Task { await ExerciseVideoHealthService.shared.checkCatalogIfNeeded(ExerciseLibraryCatalog.allItems()) }
        }
        .alert(item: $planLibrary.presentedError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("知道了"))
            )
        }
    }
}

#Preview {
    RootView()
        .environmentObject(PlanLibraryStore(repository: InMemoryPlanRepository(plans: [.preview])))
}
