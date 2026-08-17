import SwiftUI

/// Converts Unixgram's real server-side `profilePalette` into a native SwiftUI color.
/// Non-Premium users and Premium users without a recognized palette keep the
/// app's existing colors instead of receiving a fabricated selection.
enum UnixgramPremiumPalette {
    static func accent(premium: Bool?, palette: String?) -> Color? {
        guard premium == true,
              let raw = palette?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }

        let key = raw
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")

        switch key {
        case "default", "classic":
            return .white
        case "champagne":
            return Color(red: 0.78, green: 0.70, blue: 0.56)
        case "ice_blue", "iceblue", "ice":
            return Color(red: 0.55, green: 0.84, blue: 1.00)
        case "blue":
            return Color(red: 0.31, green: 0.58, blue: 1.00)
        case "violet", "purple":
            return .purple
        case "cyan":
            return .cyan
        case "emerald", "green":
            return Color(red: 0.20, green: 0.92, blue: 0.42)
        case "pink":
            return .pink
        case "orange":
            return .orange
        case "gold", "yellow":
            return Color(red: 1.00, green: 0.80, blue: 0.18)
        case "platinum", "silver":
            return Color(red: 0.80, green: 0.83, blue: 0.89)
        case "red":
            return .red
        default:
            // Tolerate Unixgram builds that return a CSS-like hex palette.
            return Color(unixgramHex: raw)
        }
    }
}

private extension Color {
    init?(unixgramHex raw: String) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }

        guard value.count == 6 || value.count == 8,
              let hex = UInt64(value, radix: 16)
        else { return nil }

        let r: Double
        let g: Double
        let b: Double
        let a: Double

        if value.count == 8 {
            r = Double((hex >> 24) & 0xFF) / 255.0
            g = Double((hex >> 16) & 0xFF) / 255.0
            b = Double((hex >> 8) & 0xFF) / 255.0
            a = Double(hex & 0xFF) / 255.0
        } else {
            r = Double((hex >> 16) & 0xFF) / 255.0
            g = Double((hex >> 8) & 0xFF) / 255.0
            b = Double(hex & 0xFF) / 255.0
            a = 1.0
        }

        self = Color(red: r, green: g, blue: b, opacity: a)
    }
}
