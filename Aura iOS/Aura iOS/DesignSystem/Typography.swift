//
//  Typography.swift
//  Aura iOS
//

import SwiftUI
import UIKit
import CoreText

/// Font tokens. Two families (both bundled variable fonts — see
/// FontRegistration.swift):
/// - **Montserrat** — headers / display: titles, statistics, big numbers,
///   headlines, the streak count.
/// - **Rubik** — body copy, labels, captions.
///
/// Call sites keep using SwiftUI's named `Font.Weight`; `wght(for:)` maps those
/// onto each family's `wght` axis (`.regular`→400, `.medium`→500, `.semibold`→
/// 600, `.bold`→700, `.heavy`→800, `.black`→900).
enum Typography {

    private static let wghtAxisTag = 0x77676874 // OpenType 'wght' axis tag ('w','g','h','t')

    /// Both bundled variable files expose a single PostScript name locked to
    /// their default instance; every other weight is dialed in via the `wght`
    /// variation axis, not by referencing a different name.
    private static let rubikPostScriptName = "Rubik-Light"

    private static func variableUIFont(psName: String, size: CGFloat, weight: CGFloat) -> UIFont {
        let base = UIFontDescriptor(name: psName, size: size)
        let varied = base.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: "NSCTFontVariationAttribute"): [wghtAxisTag: weight]
        ])
        return UIFont(descriptor: varied, size: size)
    }

    private static func rubikUIFont(size: CGFloat, weight: CGFloat) -> UIFont {
        variableUIFont(psName: rubikPostScriptName, size: size, weight: weight)
    }

    /// Maps SwiftUI's named weights onto the shared `wght` axis. Floored at 400
    /// (Regular) since the brand's lightest role is body copy.
    private static func wght(for weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight, .thin, .light, .regular: return 400
        case .medium: return 500
        case .semibold: return 600
        case .bold: return 700
        case .heavy: return 800
        case .black: return 900
        default: return 400
        }
    }

    // MARK: - Headers / display (Rubik — the app uses one family)

    /// Feature titles, statistics, headlines. Bold (700) is the ceiling for
    /// the whole app — nothing gets set heavier, however big it is. The only
    /// three exceptions, all sticker-style outlined type: the streak number in
    /// the Gate header, the streak number on the celebration screen, and the
    /// earn-grid card labels (`StrokedLabel`).
    static func display(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        Font(rubikUIFont(size: size, weight: wght(for: weight)))
    }


    /// UIKit variant of `display` — for the sticker-outlined streak numeral,
    /// drawn via an `NSAttributedString` (SwiftUI `Text` has no outline).
    /// Pass `tabular: true` for numbers that change (timer, streak, balance)
    /// so the digits keep a fixed width and don't jitter as they update.
    /// Leave it off for stroked wordmarks (AURA / Apps / Settings / the name).
    static func displayUIFont(size: CGFloat, weight: Font.Weight = .bold, tabular: Bool = false) -> UIFont {
        let font = rubikUIFont(size: size, weight: wght(for: weight))
        guard tabular else { return font }
        let feature: [UIFontDescriptor.FeatureKey: Any] = [
            .type: kNumberSpacingType,
            .selector: kMonospacedNumbersSelector,
        ]
        let desc = font.fontDescriptor.addingAttributes([.featureSettings: [feature]])
        return UIFont(descriptor: desc, size: size)
    }

    // MARK: - Body / UI text (Rubik)

    /// Body copy and UI labels. Defaults to Medium (500) — the label/name role;
    /// pass `.regular` for 400 running body copy.
    static func body(size: CGFloat = 15, weight: Font.Weight = .medium) -> Font {
        Font(rubikUIFont(size: size, weight: wght(for: weight)))
    }

    static func caption(size: CGFloat = 12.5, weight: Font.Weight = .medium) -> Font {
        Font(rubikUIFont(size: size, weight: wght(for: weight)))
    }

    // MARK: - Dynamic Type

    /// Which family a role belongs to, and which of Apple's text styles its
    /// growth curve should follow.
    ///
    /// The curve matters: `.body` grows steeply and keeps growing through the
    /// accessibility sizes, `.caption1` grows gently, `.title2` barely moves at
    /// the top. Picking per role is what stops a 34pt figure and an 11pt
    /// caption from converging.
    enum Role {
        /// Montserrat — titles, figures, headlines.
        case display
        /// Rubik — body copy, labels.
        case body
        /// Rubik — captions and sub-labels.
        case caption

        var textStyle: UIFont.TextStyle {
            switch self {
            case .display: .title2
            case .body: .body
            case .caption: .caption1
            }
        }

        func font(size: CGFloat, weight: Font.Weight) -> Font {
            switch self {
            case .display: Typography.display(size: size, weight: weight)
            case .body, .caption: Typography.body(size: size, weight: weight)
            }
        }
    }

    /// OFF. Every size renders exactly as designed, at every text setting.
    ///
    /// The plumbing below works and the call sites are migrated, but supporting
    /// Dynamic Type properly means auditing 221 fixed frame heights for clipping
    /// across every screen, and that isn't the job right now. Flip this to
    /// `true` to turn it on — nothing else has to change.
    static let scalesWithDynamicType = false

    /// The design size, grown for the user's text setting.
    ///
    /// `UIFontMetrics` rather than a multiplier of our own: it's the same curve
    /// the system fonts use, so Aura's type grows at the rate the rest of iOS
    /// does.
    static func scaledSize(_ size: CGFloat, role: Role, for typeSize: DynamicTypeSize) -> CGFloat {
        guard scalesWithDynamicType else { return size }
        return UIFontMetrics(forTextStyle: role.textStyle).scaledValue(
            for: size,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: typeSize.contentSizeCategory)
        )
    }
}

private extension DynamicTypeSize {
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: .extraSmall
        case .small: .small
        case .medium: .medium
        case .large: .large
        case .xLarge: .extraLarge
        case .xxLarge: .extraExtraLarge
        case .xxxLarge: .extraExtraExtraLarge
        case .accessibility1: .accessibilityMedium
        case .accessibility2: .accessibilityLarge
        case .accessibility3: .accessibilityExtraLarge
        case .accessibility4: .accessibilityExtraExtraLarge
        case .accessibility5: .accessibilityExtraExtraExtraLarge
        @unknown default: .large
        }
    }
}

/// Applies an Aura font that grows with the user's text setting.
///
/// This is a modifier rather than a `Font`, and it has to be: a `Font` is a
/// value, so a size baked into one at creation never hears about the setting
/// changing. Reading `dynamicTypeSize` from the environment here is what makes
/// the font rebuild when the user moves the slider.
private struct AuraFont: ViewModifier {
    @Environment(\.dynamicTypeSize) private var typeSize
    let role: Typography.Role
    let size: CGFloat
    let weight: Font.Weight

    func body(content: Content) -> some View {
        content.font(role.font(
            size: Typography.scaledSize(size, role: role, for: typeSize),
            weight: weight
        ))
    }
}

extension View {
    /// `.auraFont(.body, 13, .medium)` — the Dynamic Type replacement for
    /// `.font(Typography.body(size: 13, weight: .medium))`.
    func auraFont(_ role: Typography.Role, _ size: CGFloat,
                  _ weight: Font.Weight = .medium) -> some View {
        modifier(AuraFont(role: role, size: size, weight: weight))
    }
}
