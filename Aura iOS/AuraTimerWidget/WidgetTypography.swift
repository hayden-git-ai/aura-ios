//
//  WidgetTypography.swift
//  AuraTimerWidget
//

import CoreText
import SwiftUI
import UIKit

/// Montserrat and Rubik for the widget extension.
///
/// A deliberate copy of the app's `Typography`, not a shared file: this target
/// needs only two of its accessors, and the app's version reaches for Dynamic
/// Type roles and tokens that don't exist inside a Live Activity. The two
/// `.ttf` files are duplicated into this folder for the same reason the fox is
/// duplicated into its asset catalogue — an extension has its own bundle and
/// can't read the app's.
enum WidgetType {
    private static let wghtAxisTag = 0x77676874 // OpenType 'wght'

    /// Both bundled files are variable fonts whose PostScript name is locked to
    /// their default instance; every other weight comes off the `wght` axis.
    private static let montserrat = "Montserrat-Thin"
    private static let rubik = "Rubik-Light"

    /// Registration runs once, on whichever font is asked for first.
    ///
    /// A widget extension has no launch hook of its own — WidgetKit can wake
    /// the process straight into a render — so hanging this off first use is
    /// the only placement that's reliably early enough.
    private static let registered: Bool = {
        for name in ["Montserrat-Variable", "Rubik-Variable"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    /// Display type: the countdown. Black (900) here rather than the app's
    /// usual Bold ceiling, because these are the sticker-outlined numerals —
    /// the same exception the streak count gets.
    static func display(size: CGFloat, weight: CGFloat = 900) -> Font {
        Font(uiFont(montserrat, size: size, weight: weight)).monospacedDigit()
    }

    /// Labels underneath the numerals.
    static func label(size: CGFloat, weight: CGFloat = 600) -> Font {
        Font(uiFont(rubik, size: size, weight: weight))
    }

    private static func uiFont(_ psName: String, size: CGFloat, weight: CGFloat) -> UIFont {
        _ = registered
        let descriptor = UIFontDescriptor(name: psName, size: size)
            .addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: "NSCTFontVariationAttribute"): [wghtAxisTag: weight]
            ])
        return UIFont(descriptor: descriptor, size: size)
    }
}

/// A sticker outline around live text.
///
/// The app draws these with `StrokedNumber`, a UIKit label — but a widget can't
/// host a `UIViewRepresentable`, and the countdown has to stay a
/// `Text(timerInterval:)` for the system to tick it without updates, so it
/// can't be pre-rendered into an image either. Four hard shadows, one per
/// compass point, dilate the glyph by `width` in every direction; each falls
/// behind what came before, so the fill stays on top.
private struct StickerOutline: ViewModifier {
    let width: CGFloat
    let color: Color

    func body(content: Content) -> some View {
        content
            .shadow(color: color, radius: 0, x: width, y: 0)
            .shadow(color: color, radius: 0, x: -width, y: 0)
            .shadow(color: color, radius: 0, x: 0, y: width)
            .shadow(color: color, radius: 0, x: 0, y: -width)
    }
}

extension View {
    /// The app's own sticker numerals run about a twelfth of the type size
    /// (84pt/6, 34pt/3), but that ratio is drawn as a true outline. This one is
    /// built from dilation, which reads heavier at the same width, so it takes
    /// an explicit value rather than a ratio.
    func stickerOutline(width: CGFloat, color: Color = .black) -> some View {
        modifier(StickerOutline(width: width, color: color))
    }
}
