import Foundation

struct UserProfile: Codable, Equatable {
    enum Gender: String, Codable, CaseIterable {
        case unspecified
        case male
        case female

        var title: String {
            switch self {
            case .unspecified: return "不填写"
            case .male: return "男"
            case .female: return "女"
            }
        }
    }

    var nickname: String
    var gender: Gender
    var birthday: Date?
    var heightCentimeters: Double?
    var weightKilograms: Double?
    var notes: String

    static let empty = UserProfile(
        nickname: "",
        gender: .unspecified,
        birthday: nil,
        heightCentimeters: nil,
        weightKilograms: nil,
        notes: ""
    )
}

enum UserProfilePreferences {
    private static let key = "onekeep.user-profile"

    static func load(defaults: UserDefaults = .standard) -> UserProfile {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return .empty
        }
        return value
    }

    static func save(_ profile: UserProfile, defaults: UserDefaults = .standard) throws {
        defaults.set(try JSONEncoder().encode(profile), forKey: key)
    }
}

