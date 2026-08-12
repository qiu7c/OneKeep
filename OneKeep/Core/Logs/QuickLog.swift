import Foundation

enum QuickLogKind: String, CaseIterable, Identifiable {
    case food
    case sleep
    case body
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "饮食"
        case .sleep: return "睡眠"
        case .body: return "身体"
        case .note: return "备注"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .sleep: return "bed.double"
        case .body: return "ruler"
        case .note: return "note.text"
        }
    }
}

