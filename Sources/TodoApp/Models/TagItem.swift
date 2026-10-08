import SwiftUI

struct TagItem: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String

    var color: Color {
        Color(hex: colorHex)
    }

    static let defaultTags: [TagItem] = [
        TagItem(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, name: "Work", colorHex: "#3B82F6"),
        TagItem(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "Personal", colorHex: "#8B5CF6"),
        TagItem(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, name: "Urgent", colorHex: "#EF4444"),
        TagItem(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, name: "Ideas", colorHex: "#10B981")
    ]
}

extension Color {
    /// Soft pastel palette used for accents and highlights.
    static let pastelSky = Color(hex: "#9CCDF2")
    static let pastelMint = Color(hex: "#7FD3B8")
    static let pastelBlush = Color(hex: "#F4C6D2")
    static let pastelLavender = Color(hex: "#CFC3EF")
    static let pastelButter = Color(hex: "#F3DFA8")

    init(hex: String) {
        let hexClean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexClean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexClean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }

    func toHex() -> String {
        guard let components = NSColor(self).usingColorSpace(.deviceRGB) else {
            return "#808080"
        }
        let r = Int(components.redComponent * 255.0)
        let g = Int(components.greenComponent * 255.0)
        let b = Int(components.blueComponent * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
