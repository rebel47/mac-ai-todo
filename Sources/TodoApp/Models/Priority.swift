import SwiftUI

enum Priority: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No Priority"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var order: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        case .none: return 0
        }
    }

    var color: Color {
        switch self {
        case .none: return .secondary.opacity(0.6)
        case .low: return Color.blue
        case .medium: return Color.orange
        case .high: return Color.red
        }
    }

    var iconName: String {
        switch self {
        case .none: return "flag"
        case .low: return "flag.fill"
        case .medium: return "flag.fill"
        case .high: return "flag.fill"
        }
    }
}
