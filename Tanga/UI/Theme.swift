import SwiftUI
import UIKit

/// Палитра «Самарканд»: бирюза изразцов, лазурит и золото.
enum Theme {
    static let background = Color.dynamic(light: 0xF2F4F7, dark: 0x15161A)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x1D1E23)
    static let rowActive = Color.dynamic(light: 0xDDEFF3, dark: 0x1D2A33)
    static let key = Color.dynamic(light: 0xF1F3F6, dark: 0x2A2B31)
    static let keyPressed = Color.dynamic(light: 0xDDE2E9, dark: 0x3A3B43)
    static let keyBorder = Color.dynamic(light: 0xE1E4EA, dark: 0x34353C)
    static let separator = Color.dynamic(light: 0xE2E5EA, dark: 0x2A2B31)
    static let textPrimary = Color.dynamic(light: 0x14161A, dark: 0xEEEFF1)
    static let textSecondary = Color.dynamic(light: 0x6B6F78, dark: 0x8E919A)
    static let accent = Color.dynamic(light: 0x0E93A6, dark: 0x22C3D6)
    static let gold = Color.dynamic(light: 0xD08612, dark: 0xF2B441)
    static let danger = Color.dynamic(light: 0xD8392F, dark: 0xF0625B)
    static let positive = Color.dynamic(light: 0x1C9A57, dark: 0x3DD68C)
}

extension Color {
    nonisolated static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    nonisolated init(rgb: UInt32) {
        self.init(uiColor: UIColor(rgb: rgb))
    }

    /// `#F7931A` → Color.
    nonisolated init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(rgb: value)
    }
}

extension UIColor {
    nonisolated convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum Haptics {
    private static let generator = UIImpactFeedbackGenerator(style: .light)

    static func tap(_ enabled: Bool) {
        guard enabled else { return }
        generator.impactOccurred(intensity: 0.7)
    }
}
