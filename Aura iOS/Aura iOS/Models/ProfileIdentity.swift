import Foundation

/// Shared rules for profile recovery, editing and the avatar fallback.
enum ProfileIdentity {
    static func normalizedName(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func isValidName(_ name: String) -> Bool {
        name.filter(\.isLetter).count >= 2
    }

    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
            .map { $0.filter(\.isLetter) }.filter { !$0.isEmpty }
        let letters: String
        if words.count > 1, let first = words.first?.first, let last = words.last?.first {
            letters = String(first) + String(last)
        } else {
            letters = String(words.first?.prefix(2) ?? "")
        }
        let initials = String(letters.uppercased().prefix(2))
        // Keep the fallback neutral when the profile has no usable initials.
        return initials.count == 2 ? initials : "AU"
    }
}
