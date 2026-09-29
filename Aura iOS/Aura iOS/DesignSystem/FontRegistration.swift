//
//  FontRegistration.swift
//  Aura iOS
//

import CoreText
import Foundation

/// Registers bundled custom fonts at runtime via Core Text, instead of the
/// "Fonts provided by application" Info.plist key — this project uses Xcode's
/// auto-generated Info.plist (GENERATE_INFOPLIST_FILE = YES), which doesn't
/// cleanly support array-valued keys like UIAppFonts. Runtime registration
/// sidesteps that entirely and needs no plist entry.
enum FontRegistration {
    static func registerBundledFonts() {
        let fontFiles = [
            "Rubik-Variable",
            "LilitaOne-Regular"
        ]

        for name in fontFiles {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                assertionFailure("Font file \(name).ttf not found in bundle.")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                assertionFailure("Failed to register font \(name): \(String(describing: error))")
            }
        }
    }
}
