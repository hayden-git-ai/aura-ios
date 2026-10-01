//
//  InfoCard.swift
//  Aura iOS
//

import SwiftUI

/// A blue-wash panel that explains something rather than doing something.
///
/// Three places were building this separately — Help's tip blocks, the habit
/// sheet's "Tip from Aura", and the Focus vs Quick Habit cards — at three
/// corner radii and two paddings. They all say "here's how this works", so
/// they're one component.
///
/// No control ever goes on one. If it needs a switch it's a `SettingToggleCard`.
struct InfoCard<Leading: View>: View {
    let title: String
    let copy: String
    var borderColor: Color? = nil
    /// A glyph or sticker before the title. Nothing by default.
    @ViewBuilder var leading: Leading

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                leading
                Text(title)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(SheetType.titleColor)
                Spacer(minLength: 0)
            }

            Text(copy)
                .auraFont(.body, SheetType.cardBlurb, .regular)
                .foregroundStyle(SheetType.subtitleColor)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        // The recessed grey, not the blue wash. With the method screens now
        // white, a blue panel read as a third colour competing with the field
        // above it; grey reads as a note set into the page.
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .fill(borderColor == nil ? LightSheet.chromeOnLight : Color.clear)
                .overlay {
                    if let borderColor {
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: 2)
                    }
                }
        )
    }
}

extension InfoCard where Leading == EmptyView {
    init(title: String, copy: String) {
        self.init(title: title, copy: copy) { EmptyView() }
    }
}
