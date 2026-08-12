import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }
    var title: String { self == .kilograms ? "公斤" : "磅" }
    var symbol: String { self == .kilograms ? "kg" : "lb" }

    static var preferred: WeightUnit { WorkoutPreferencesStore.load().weightUnit }

    func displayValue(fromKilograms kilograms: Double) -> Double {
        self == .kilograms ? kilograms : kilograms * 2.204_622_621_8
    }

    func kilograms(fromDisplayValue value: Double) -> Double {
        self == .kilograms ? value : value / 2.204_622_621_8
    }

    func string(fromKilograms kilograms: Double) -> String {
        displayValue(fromKilograms: kilograms).formatted(
            .number.precision(.fractionLength(0...2))
        )
    }

    func formatted(kilograms: Double) -> String {
        "\(string(fromKilograms: kilograms)) \(symbol)"
    }

    func parseKilograms(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return nil }
        return kilograms(fromDisplayValue: value)
    }
}

struct WorkoutPreferences: Codable, Equatable {
    var timerNotifications = true
    var hapticFeedback = true
    var autoStartRest = true
    var voicePrompts = true
    var automaticWorkoutFlow = true
    var voiceVolume = 1.0
    var muteExerciseVideos = false
    var wifiOnlyVideo = false
    var weightUnit: WeightUnit = .kilograms

    private enum CodingKeys: String, CodingKey {
        case timerNotifications, hapticFeedback, autoStartRest, voicePrompts, automaticWorkoutFlow
        case voiceVolume, muteExerciseVideos, wifiOnlyVideo, weightUnit
    }

    init(
        timerNotifications: Bool = true,
        hapticFeedback: Bool = true,
        autoStartRest: Bool = true,
        voicePrompts: Bool = true,
        automaticWorkoutFlow: Bool = true,
        voiceVolume: Double = 1,
        muteExerciseVideos: Bool = false,
        wifiOnlyVideo: Bool = false,
        weightUnit: WeightUnit = .kilograms
    ) {
        self.timerNotifications = timerNotifications
        self.hapticFeedback = hapticFeedback
        self.autoStartRest = autoStartRest
        self.voicePrompts = voicePrompts
        self.automaticWorkoutFlow = automaticWorkoutFlow
        self.voiceVolume = voiceVolume
        self.muteExerciseVideos = muteExerciseVideos
        self.wifiOnlyVideo = wifiOnlyVideo
        self.weightUnit = weightUnit
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        timerNotifications = try values.decodeIfPresent(Bool.self, forKey: .timerNotifications) ?? true
        hapticFeedback = try values.decodeIfPresent(Bool.self, forKey: .hapticFeedback) ?? true
        autoStartRest = try values.decodeIfPresent(Bool.self, forKey: .autoStartRest) ?? true
        voicePrompts = try values.decodeIfPresent(Bool.self, forKey: .voicePrompts) ?? true
        automaticWorkoutFlow = try values.decodeIfPresent(Bool.self, forKey: .automaticWorkoutFlow) ?? true
        voiceVolume = min(max(try values.decodeIfPresent(Double.self, forKey: .voiceVolume) ?? 1, 0), 1)
        muteExerciseVideos = try values.decodeIfPresent(Bool.self, forKey: .muteExerciseVideos) ?? false
        wifiOnlyVideo = try values.decodeIfPresent(Bool.self, forKey: .wifiOnlyVideo) ?? false
        weightUnit = try values.decodeIfPresent(WeightUnit.self, forKey: .weightUnit) ?? .kilograms
    }
}

enum WorkoutPreferencesStore {
    private static let key = "onekeep.workout.preferences"

    static func load(defaults: UserDefaults = .standard) -> WorkoutPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(WorkoutPreferences.self, from: data) else {
            return WorkoutPreferences()
        }
        return preferences
    }

    static func save(_ preferences: WorkoutPreferences, defaults: UserDefaults = .standard) throws {
        defaults.set(try JSONEncoder().encode(preferences), forKey: key)
    }
}
