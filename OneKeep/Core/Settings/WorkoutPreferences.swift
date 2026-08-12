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
    var weightUnit: WeightUnit = .kilograms

    private enum CodingKeys: String, CodingKey {
        case timerNotifications, hapticFeedback, autoStartRest, weightUnit
    }

    init(
        timerNotifications: Bool = true,
        hapticFeedback: Bool = true,
        autoStartRest: Bool = true,
        weightUnit: WeightUnit = .kilograms
    ) {
        self.timerNotifications = timerNotifications
        self.hapticFeedback = hapticFeedback
        self.autoStartRest = autoStartRest
        self.weightUnit = weightUnit
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        timerNotifications = try values.decodeIfPresent(Bool.self, forKey: .timerNotifications) ?? true
        hapticFeedback = try values.decodeIfPresent(Bool.self, forKey: .hapticFeedback) ?? true
        autoStartRest = try values.decodeIfPresent(Bool.self, forKey: .autoStartRest) ?? true
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
