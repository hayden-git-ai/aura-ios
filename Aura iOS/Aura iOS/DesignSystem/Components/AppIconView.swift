//
//  AppIconView.swift
//  Aura iOS
//

import FamilyControls
import SwiftUI

/// One app's icon, at a size we choose.
///
/// The token case is `Label(token)` with its text thrown away. That's the only
/// way to draw a chosen app — the system owns the artwork and hands it over as
/// a label, never as an image — and it's why the app never shows app *names*
/// anywhere in Blocks: taking the icon means taking the name too, in the
/// system's own type at the system's own size, which nothing here is laid out
/// for.
///
/// Sizing goes through `.font`, since the icon scales with the label's type
/// rather than to a frame. The frame is there to reserve the space, not to
/// resize the glyph.
struct AppIconView: View {
    let source: AppIconSource
    let side: CGFloat

    var body: some View {
        switch source {
        case .asset(let name):
            Image(name)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)

        case .token(let token):
            Label(token)
                .labelStyle(.iconOnly)
                .font(.system(size: side))
                .frame(width: side, height: side)
        }
    }
}

/// An app as a list row: icon and name.
///
/// The name is the reason this exists separately from `AppIconView`. A real
/// app's name only ever arrives welded to its icon inside a `Label`, so the two
/// can't be laid out independently — a custom `LabelStyle` is the seam that
/// lets the icon keep Aura's chrome and the name keep Aura's type, instead of
/// the row wearing the system's.
struct AppRowLabel: View {
    let source: AppIconSource
    let side: CGFloat

    var body: some View {
        switch source {
        case .asset(let name):
            HStack(spacing: Theme.Spacing.m) {
                AppIconView(source: source, side: side)
                    .appIconChrome(side: side)
                title(AppCatalog.displayName(for: name))
            }

        case .token(let token):
            Label(token).labelStyle(AppRowLabelStyle(side: side))
        }
    }

    @ViewBuilder
    private func title(_ text: String) -> some View {
        Text(text)
            .auraFont(.body, SheetType.cardTitle, .semibold)
            .foregroundStyle(SheetType.titleColor)
    }
}

private struct AppRowLabelStyle: LabelStyle {
    let side: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            configuration.icon
                // The icon scales with type, not to a frame, so the size is set
                // in points of font and the frame only reserves the space.
                .font(.system(size: side))
                .frame(width: side, height: side)
                .appIconChrome(side: side)

            configuration.title
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(SheetType.titleColor)
                .lineLimit(1)
        }
    }
}

/// An app as a grid tile: icon *above* its name, centred. The same seam as
/// `AppRowLabel` — a real app's name arrives welded to its icon in a `Label`, so
/// a custom `LabelStyle` is the only way to stack them and keep Aura's chrome and
/// type. The mock-asset case builds the same stack by hand.
struct AppTileLabel: View {
    let source: AppIconSource
    let side: CGFloat

    var body: some View {
        switch source {
        case .asset(let name):
            VStack(spacing: Theme.Spacing.s) {
                AppIconView(source: source, side: side)
                    .appIconChrome(side: side)
                title(AppCatalog.displayName(for: name))
            }
        case .token(let token):
            Label(token).labelStyle(AppTileLabelStyle(side: side))
        }
    }

    @ViewBuilder
    private func title(_ text: String) -> some View {
        Text(text)
            .auraFont(.body, 13, .semibold)
            .foregroundStyle(SheetType.titleColor)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

private struct AppTileLabelStyle: LabelStyle {
    let side: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            configuration.icon
                .font(.system(size: side))
                .frame(width: side, height: side)
                .appIconChrome(side: side)

            configuration.title
                .auraFont(.body, 13, .semibold)
                .foregroundStyle(SheetType.titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}
