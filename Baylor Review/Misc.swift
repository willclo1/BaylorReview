import SwiftUI

extension Color {
    /// Create a Color from a hex string, e.g. "#RRGGBB" or "RRGGBB".
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                      .replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r, g, b: Double
        switch hex.count {
        case 6: // RRGGBB
            r = Double((rgbValue & 0xFF0000) >> 16) / 255
            g = Double((rgbValue & 0x00FF00) >> 8 ) / 255
            b = Double( rgbValue & 0x0000FF       ) / 255

        case 8: // AARRGGBB
            // If you want to support alpha too, you could extract it here.
            let a = Double((rgbValue & 0xFF000000) >> 24) / 255
            r     = Double((rgbValue & 0x00FF0000) >> 16) / 255
            g     = Double((rgbValue & 0x0000FF00) >> 8 ) / 255
            b     = Double( rgbValue & 0x000000FF       ) / 255
            self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
            return

        default:
            // Fallback to gray if the string is malformed
            r = 0; g = 0; b = 0
        }

        self = Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
