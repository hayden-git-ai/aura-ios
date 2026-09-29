//
//  Theme.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// Single source of truth for color, spacing, and radius tokens.
/// Screens should always reach for `Theme.*` rather than hardcoding values.
enum Theme {

    enum Color {
        static let background = SwiftUI.Color(hex: "0B0B0E")
        static let surface = SwiftUI.Color(hex: "16161B")
        static let surfaceAlt = SwiftUI.Color(hex: "1B1B20")
        static let hairline = SwiftUI.Color(hex: "26262B")

        /// Just barely lighter than `background` — a smaller step up than
        /// `surface`, for elements that should read as subtly present (the
        /// Apps screen's count pill and category cards) rather than as a
        /// fully raised surface.
        static let surfaceRecessed = SwiftUI.Color(hex: "0C0C0F")
        /// One small step up from `surfaceRecessed` — for content that sits
        /// on top of a recessed surface and needs to read as barely
        /// distinct from it (the Apps screen's placeholder squares), well
        /// short of the jump to `surface`.
        static let surfaceRecessedAlt = SwiftUI.Color(hex: "101013")

        static let textPrimary = SwiftUI.Color.white
        static let textSecondary = SwiftUI.Color(hex: "8A8A90")
        static let textTertiary = SwiftUI.Color(hex: "5C5C61")

        /// Reserved for earn/unlock moments only (countdown, streak pulse). Never a generic accent.
        static let signalUnlock = SwiftUI.Color(hex: "00BFFF")

        /// Reserved for warning/blocked/consequential moments only (Emergency
        /// Unlock, the Apps screen's blocked-app ring). Deliberately deep, not
        /// a bright coral — a lighter first pass read as too loud.
        static let signalWarning = SwiftUI.Color(hex: "DF152D")
        /// Darkest stop in the warning gradient family — bottom of the
        /// Emergency Unlock pill, outer edge of the blocked-app ring.
        static let signalWarningDeep = SwiftUI.Color(hex: "FF0000")

        /// The earn bar, on Home and in the store.
        ///
        /// One colour, not a ramp. This was a red→amber→green sweep
        /// interpolated in RGB, and the whole amber→green leg came out muddy:
        /// at 74% it resolved to #9DBC2B, olive, with saturation down to 0.77
        /// and brightness to 0.74. Straight RGB interpolation pulls red down
        /// while green comes up, and everything between is a dull middle — no
        /// value in that stretch was any good.
        ///
        /// `signalGain` rather than `signalGood`: this is a positive-gain stat
        /// bar, which is exactly what that token is for. The fill's length
        /// already says how close you are; the colour was saying it twice and
        /// was the only reason there was a problem to solve.
        static let earnBar = signalGain
        static let earnTrack = SwiftUI.Color.black.opacity(0.45)

        /// Reserved for qualitative "good" judgments on the Insights sheet's
        /// usage-pattern rows (e.g. "Great" / "OK") — never a generic accent.
        static let signalGood = SwiftUI.Color(hex: "34C77B")
        /// Reserved for "this went up" / positive-gain stat visualizations —
        /// the same association crypto/stock charts use for gains (e.g. the
        /// Wins strip's screen-time-earned icon). Distinct from `signalGood`,
        /// which is a qualitative judgment label, not a stat glyph color.
        static let signalGain = SwiftUI.Color(hex: "21C55E")
        /// Reserved for qualitative "needs attention" judgments on the same
        /// rows (e.g. "Slow Down" / "Too Much") — distinct from `signalWarning`,
        /// which is reserved for blocked/consequential moments.
        static let signalCaution = SwiftUI.Color(hex: "E8A33D")

        static let ctaFill = SwiftUI.Color.white
        static let ctaText = SwiftUI.Color.black
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    /// Corner radii, by what the shape IS rather than by how round it looked
    /// on the day it was written.
    ///
    /// This enum used to hold three values and be used three times, while 68
    /// shapes hardcoded fifteen different numbers between 5 and 38 — including
    /// 16 and 18 for the same card, and 14, 16, 18 and 20 for the same recessed
    /// field. The rungs below are far enough apart to be choices.
    ///
    /// Nesting reads outward: a `field` sits inside a `card`, a `card` inside a
    /// `panel`. It used to read inward — the recessed field was 18 inside a
    /// 16 card, so the inner corner bulged past the outer one it sat in.
    enum Radius {
        /// Tiny clipped chips — a receipt stub, a legend swatch.
        static let micro: CGFloat = 6
        /// A small tile or thumbnail, under about 48pt.
        static let tile: CGFloat = 8
        /// A recessed input or tile INSIDE a card. Always below `card`.
        static let field: CGFloat = 12
        /// Every content card, light or glass.
        static let card: CGFloat = 16
        /// A large tile or feature block — the app grid's tiles, the tab bar,
        /// the bank card.
        static let hero: CGFloat = 24
        /// A full-width surface: the self-mirror, the verification dropdown.
        static let panel: CGFloat = 32
        /// The top-corner sweep where a sheet or tab card meets the screen.
        static let sheet: CGFloat = 38
        static let pill: CGFloat = 999
    }

    enum Layout {
        /// The app-standard control height: text fields, tappable field-rows, and
        /// the primary button all stand this tall so a form reads as one stack.
        /// (Adopted by the Profile forms; the older method screens still inline 56
        /// and should migrate to this.)
        static let fieldHeight: CGFloat = 56

        /// Space to reserve above the pinned nav for any other bottom-pinned
        /// element (e.g. the Unblock Apps pill) so it sits just above the bar
        /// rather than overlapping it.
        ///
        /// Back at 92 after briefly going to 120 to track the bar moving up.
        /// That was arithmetically right and wrong in practice: this value is
        /// the bottom padding on Home's whole column, so raising it lifted the
        /// fox, the Unblock pill and all three cards off their tuned positions
        /// to protect against an overlap that doesn't happen. The bar's top
        /// edge now sits 78 off the screen bottom, so 92 still clears it.
        static let navBarClearance: CGFloat = 92

        /// Bottom padding for a scrolling tab screen's content.
        ///
        /// The content scrolls to the safe-area bottom, above which the tab bar
        /// floats — so from the content's own bottom the bar's top sits ~70pt up,
        /// not the 128 measured off the screen bottom. Reserving the full 128
        /// left the last section ~90pt clear of the bar, far looser than the
        /// Blocks screen sits above its Emergency Pass bar. 70 to reach the bar,
        /// plus a gap that matches Blocks (~44pt total), so every scrolling tab
        /// screen bottoms out the same.
        static let scrollBottomClearance: CGFloat = 70 + 44

        /// Where anything pinned to the bottom of a screen sits: the primary
        /// CTA on every method screen, and the tab bar.
        ///
        /// The bar used to carry `-12` — a negative inset that pushed it *past*
        /// the safe area to land 22pt off the screen edge, while every Hold to
        /// Commit / Lock In button sat 16pt above the safe area. Two different
        /// ideas of the bottom of the screen, 28pt apart.
        static let bottomInset: CGFloat = Theme.Spacing.l
    }
}

extension SwiftUI.Color {
    /// Convenience initializer for hex strings like "0B0B0E" (RGB, no alpha).
    init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// A lighter/darker variant of this color, shifting HSB brightness by
    /// `delta` (-1...1) — lets a single token generate its own tonal range
    /// (e.g. for an icon-glyph gradient) instead of hand-picking a second hex.
    /// Has no effect on colors already at max HSB brightness (e.g. `#00BFFF`,
    /// whose blue channel is 255) — use `lightened(by:)` for those instead.
    func brightnessAdjusted(by delta: CGFloat) -> SwiftUI.Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return SwiftUI.Color(hue: h, saturation: s, brightness: min(max(b + delta, 0), 1), opacity: a)
    }

    /// Blends this color toward white by `amount` (0...1) — works regardless
    /// of the color's own HSB brightness, unlike `brightnessAdjusted`.
    func lightened(by amount: CGFloat) -> SwiftUI.Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SwiftUI.Color(red: r + (1 - r) * amount, green: g + (1 - g) * amount, blue: b + (1 - b) * amount, opacity: a)
    }

    /// Blends this color toward black by `amount` (0...1).
    func darkened(by amount: CGFloat) -> SwiftUI.Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SwiftUI.Color(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount), opacity: a)
    }
}
