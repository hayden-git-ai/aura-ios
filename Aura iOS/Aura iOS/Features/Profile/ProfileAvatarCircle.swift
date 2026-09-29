//
//  ProfileAvatarCircle.swift
//  Aura iOS
//

import SwiftUI

/// The circular profile avatar — the user's picked picture if set, else their
/// initials on a soft blue gradient. A thin white ring + soft shadow lift it off
/// the cover and the identity band.
struct ProfileAvatarCircle: View {
    @Environment(HabitStore.self) private var store
    var size: CGFloat = 92

    /// Up to two initials from the display name (first + last). A single-name
    /// identity uses its first two graphemes; setup validation normally ensures
    /// this fallback is only reached for legacy, incomplete profiles.
    private var initials: String { ProfileIdentity.initials(for: store.displayName) }

    var body: some View {
        Group {
            if let data = store.profileImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "5E8BFF"), Color(hex: "2F5FE0")],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size)
                    .overlay(
                        Text(initials)
                            .auraFont(.display, size * 0.34, .bold)
                            .foregroundStyle(.white)
                    )
            }
        }
        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }
}
