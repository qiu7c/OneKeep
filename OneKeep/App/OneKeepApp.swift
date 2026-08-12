import SwiftUI

@main
struct OneKeepApp: App {
    private let persistenceController: PersistenceController
    @StateObject private var planLibrary: PlanLibraryStore

    init() {
        let persistenceController = PersistenceController.shared
        self.persistenceController = persistenceController
        _planLibrary = StateObject(
            wrappedValue: PlanLibraryStore(
                repository: CoreDataPlanRepository(context: persistenceController.container.viewContext)
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(planLibrary)
                .tint(OKColor.accent)
        }
    }
}
