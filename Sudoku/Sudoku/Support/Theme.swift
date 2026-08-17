import SwiftUI
import UIKit

/// Semantic colors only — everything adapts to light/dark automatically.
/// Highlights resolve per-trait: dark mode needs a brighter, more opaque blue
/// to read against black; light mode wants a slightly stronger tint than the
/// accent's default.
enum Theme {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let boardBackground = Color(.systemBackground)
    static let cellSelected = adaptive(
        light: UIColor.systemBlue.withAlphaComponent(0.40),
        dark: UIColor(red: 0.45, green: 0.62, blue: 1.0, alpha: 0.60)
    )
    static let cellPeer = adaptive(
        light: UIColor.systemBlue.withAlphaComponent(0.16),
        dark: UIColor(red: 0.45, green: 0.62, blue: 1.0, alpha: 0.28)
    )
    static let cellSameDigit = adaptive(
        light: UIColor.systemBlue.withAlphaComponent(0.26),
        dark: UIColor(red: 0.45, green: 0.62, blue: 1.0, alpha: 0.42)
    )
    static let cellMistake = adaptive(
        light: UIColor.systemRed.withAlphaComponent(0.18),
        dark: UIColor.systemRed.withAlphaComponent(0.32)
    )
    static let givenText = Color.primary
    static let playerText = Color.accentColor
    static let mistakeText = Color.red
    static let pencilText = Color.secondary
    // Chain-layer diffs: trial digits and marks added/removed/forced relative
    // to the sheet underneath. Purple for the hypothesis line (orange reads
    // too much like an error next to mistake red); removed marks fade and
    // strike through rather than turn red — an elimination is progress.
    static let trialText = Color(.systemPurple)
    static let pencilAddedText = Color(.systemGreen)
    static let pencilRemovedText = Color.secondary.opacity(0.45)
    static let pencilForcedText = Color(.systemPurple)
    static let gridLineMajor = Color.primary.opacity(0.8)
    static let gridLineMinor = Color.primary.opacity(0.22)
}

extension TimeInterval {
    /// mm:ss, or h:mm:ss past an hour.
    var timerString: String {
        let total = Int(self)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
