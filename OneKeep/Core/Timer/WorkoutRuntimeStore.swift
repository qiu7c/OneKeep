import Foundation

struct WorkoutRuntimeSnapshot: Codable {
    let stepIndex: Int
    let timerPurpose: String
    let pendingRestSeconds: Int
    let timer: WorkoutTimerStore.Snapshot
}

enum WorkoutRuntimeStore {
    private static func key(_ sessionID: UUID) -> String {
        "onekeep.workout.runtime.\(sessionID.uuidString)"
    }

    static func load(sessionID: UUID, defaults: UserDefaults = .standard) -> WorkoutRuntimeSnapshot? {
        guard let data = defaults.data(forKey: key(sessionID)) else { return nil }
        return try? JSONDecoder().decode(WorkoutRuntimeSnapshot.self, from: data)
    }

    static func save(_ snapshot: WorkoutRuntimeSnapshot, sessionID: UUID, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key(sessionID))
    }

    static func clear(sessionID: UUID, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(sessionID))
    }
}
