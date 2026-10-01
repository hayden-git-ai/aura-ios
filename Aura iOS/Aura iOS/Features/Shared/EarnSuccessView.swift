//
//  EarnSuccessView.swift
//  Aura iOS
//

import SwiftUI

/// The screen every earn method lands on when it works.
///
/// Photo Proof and Camera Reps had this layout written out twice, and Passive
/// Income was about to make three. Everything that has been duplicated in this
/// app has drifted: two chrome tokens for one disc, two earn animations where
/// only one was ever tuned, a `photoHalo` private to one camera so the other
/// grew bare buttons. A third hand-typed copy of a screen would have gone the
/// same way, and the divergence never shows up until someone puts two of them
/// side by side.
///
/// So the shape lives here and the methods bring their own words. What varies
/// between them is genuinely only the art, the copy, and whether there are
/// coins to show yet.
///
/// Terminal by design: no back, no close. There is one thing to do from here
/// and the button does it.
struct EarnSuccessView<Art: View>: View {
    @ViewBuilder var art: () -> Art
    let title: String
    let blurb: String
    /// Shown on the CTA as a coin and a number. Nil when nothing has actually
    /// been earned yet — a focus habit has bought the right to start a timer,
    /// and a button promising coins it doesn't have is a lie.
    var coins: Int? = nil
    /// The method's own colour, so the button belongs to the quest you just
    /// finished. Colour is the app's wayfinding: the FAB card, the method
    /// screen's field and every habit header inside it already carry it, and
    /// this was the one screen at the end of the trail still painted blue
    /// whichever way you came in.
    let method: HabitCategory
    var ctaTitle: String
    /// Only for the one case where the button does something whose result isn't
    /// visible yet.
    var footnote: String? = nil
    /// An extra block between the copy and the button, for a method with more
    /// to say than a number.
    ///
    /// Only Lock In uses it: a focus session has a shape the others don't (how
    /// long, when, how it ranks), and none of that fits on a button. `AnyView`
    /// rather than a second generic because this renders once at the end of a
    /// session and the alternative is a generic parameter every other call site
    /// has to name `EmptyView` to ignore.
    var detail: AnyView? = nil
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            art()
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Text(title)
                .auraFont(.display, SheetType.hero, .bold)
                .foregroundStyle(SheetType.titleColor)
                .multilineTextAlignment(.center)
                .padding(.top, Theme.Spacing.xxl)

            Text(blurb)
                .auraFont(.body, SheetType.banner, .regular)
                .foregroundStyle(SheetType.subtitleColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.l)
                .padding(.horizontal, Theme.Spacing.xl)

            // With a detail block the spacer moves BELOW it, so the tiles hang
            // off the copy they belong to instead of floating up from the
            // button. Either way there is one spacer above the art and one
            // below the block, so the whole thing still centres.
            if let detail {
                detail
                    .padding(.top, Theme.Spacing.xl)
                Spacer(minLength: Theme.Spacing.xl)
            } else {
                Spacer(minLength: 0)
            }

            // `coins` is nil for a focus habit, which is exactly right: nothing
            // has been earned yet there, so the button says only what it does
            // and the footnote names the number it will pay.
            LightPrimaryButton(title: ctaTitle,
                               coins: coins,
                               face: method.accent,
                               shade: method.accentShade,
                               action: onContinue)

            if let footnote {
                Text(footnote)
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(LightSheet.controlIdle)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.m)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LightSheet.bg.ignoresSafeArea())
        .preferredColorScheme(.light)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            Haptics.notify(.success)
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { appeared = true }
        }
    }
}

/// The art slot, sized once so three methods can't each pick their own.
///
/// TODO: placeholder — the celebrating fox goes here. Each method's own fox
/// stands in for now rather than a grey box: right shape, right weight, so the
/// spacing around it is being tuned against something honest.
struct EarnSuccessArt: View {
    let asset: String

    var body: some View {
        Image(asset)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: 180)
    }
}

/// The frosted panel every success detail card wears — a shade deeper than the
/// Stats token so white text reads over the light sunbursts.
private struct EarnPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            .fill(Color.black.opacity(0.24))
    }
}

/// One frosted stat tile — an icon over a value and a label. The four success
/// screens build their tile rows from these, so a quest with two stats and one
/// with three still read as the same kind of screen.
struct EarnStatTile<Icon: View>: View {
    @ViewBuilder var icon: () -> Icon
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            icon()
                .frame(height: 44)

            Text(value)
                .auraFont(.body, SheetType.banner, .bold)
                .foregroundStyle(.white)
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                // A fixed box so a two-line value doesn't drop its label below
                // the neighbouring tiles' labels.
                .frame(height: 44)

            Text(label)
                .auraFont(.body, RowType.subLabel, .medium)
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.vertical, Theme.Spacing.l)
        .padding(.horizontal, Theme.Spacing.s)
        // All tiles take the height of the tallest, so a two-line value doesn't
        // leave the others sitting short.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(EarnPanelBackground())
    }
}

/// The frosted highlight card under the tile row — an icon and a line, the same
/// shape on every success screen.
struct EarnHighlightCard<Icon: View>: View {
    @ViewBuilder var icon: () -> Icon
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            icon()
            Text(text)
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(EarnPanelBackground())
    }
}

/// The diamond gem used on every success screen's highlight card, so the four
/// read as one family. (Lock In's, adopted across the set.)
struct EarnHighlightGem: View {
    var body: some View {
        EarnTileIcon(asset: "CameraRepsHard")
    }
}

/// A stat sticker with the same visible height, independent of transparent PNG padding.
struct EarnTileIcon: View {
    let asset: String
    private var contourWidth: CGFloat {
        switch asset {
        case "StreakFlame": 0
        case "FoxAppleHealth": 0.25
        case "EarnCardIcon": 0.4
        case "CameraRepsHard": 0
        default: 0.6
        }
    }
    var body: some View {
        let geometry = SuccessStickerGeometry.geometry(for: asset)
        // Include the additional white contour in the shared 32pt visible height.
        let scale = (32 - 2 * contourWidth) / geometry.ink.height
        Image(asset)
            .resizable()
            .interpolation(.high)
            .frame(width: geometry.size.width * scale, height: geometry.size.height * scale)
            .modifier(SuccessStickerContour(width: contourWidth))
            .offset(x: (geometry.size.width / 2 - geometry.ink.midX) * scale,
                    y: (geometry.size.height / 2 - geometry.ink.midY) * scale)
            .frame(width: 40, height: 40)
    }
}

/// Measure once per named asset. Alpha >= 128 captures the sticker and white rim,
/// excluding its soft shadow. This also covers legacy and newly added habit stickers.
@MainActor
private enum SuccessStickerGeometry {
    struct Geometry {
        let size: CGSize
        let ink: CGRect
    }
    private static var cache: [String: Geometry] = [:]

    static func geometry(for asset: String) -> Geometry {
        if let cached = cache[asset] { return cached }
        guard let image = UIImage(named: asset)?.cgImage else {
            return Geometry(size: CGSize(width: 40, height: 40),
                            ink: CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let width = image.width, height = image.height
        let size = CGSize(width: width, height: height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        var minX = width, minY = height, maxX = -1, maxY = -1
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return }
            context.draw(image, in: CGRect(origin: .zero, size: size))
            let pixels = buffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width where pixels[(y * width + x) * 4 + 3] >= 128 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        let ink = maxX >= minX
            ? CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            : CGRect(origin: .zero, size: size)
        let result = Geometry(size: size, ink: ink)
        cache[asset] = result
        return result
    }
}

/// Complements each baked contour to match the flame at its rendered size.
private struct SuccessStickerContour: ViewModifier {
    let width: CGFloat
    func body(content: Content) -> some View {
        content.background {
            if width > 0 {
                ZStack {
                    ForEach(0..<8) { step in
                        let angle = Double(step) * .pi / 4
                        content.shadow(color: .white, radius: 0,
                                       x: width * CGFloat(cos(angle)), y: width * CGFloat(sin(angle)))
                    }
                }
                .accessibilityHidden(true)
            }
        }
    }
}

/// The all-time ranking highlight — where this habit/exercise sits among its
/// kind by how often you do it. A real rank, the way Lock In ranks a session.
func earnRankHighlight(rank: Int, total: Int, noun: String) -> String {
    if total <= 1 { return "Your go-to \(noun)!" }
    if rank == 1 { return "Your top \(noun)!" }
    return "One of your top \(noun)s!"
}

/// The sunburst sibling of `EarnSuccessView`: the same shell, but wearing the
/// streak screen's treatment — a slowly rotating `SunburstBackground` (in the
/// quest's own hue) with the same progressive blur, the icon sitting where the
/// streak fox does with the rays fanning out from behind it, then the copy, an
/// optional detail block, the Claim Reward button, and an optional footnote.
///
/// A screen picks the flat-white base or this one; neither hand-rolls the layout.
/// Terminal by design: no back, no close.
struct SunburstSuccessView<Art: View>: View {
    /// Where the icon (and the rays behind it) sit, as a fraction of the screen —
    /// the streak fox's spot. A screen with a detail block nudges it up to make
    /// room for the tiles.
    var iconCentre: CGFloat = 0.36
    /// Half the art's box height, so the top spacer centres the art on
    /// `iconCentre` (the sunburst's bright spot) whatever size the art is. The
    /// default suits a ~180pt art; the celebration screens pass a taller box.
    var artHalfHeight: CGFloat = 90
    @ViewBuilder var art: () -> Art
    let title: String
    let blurb: String
    var coins: Int? = nil
    let method: HabitCategory
    var ctaTitle: String = "Claim Reward"
    var footnote: String? = nil
    var detail: AnyView? = nil
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var successAccent: Color {
        method == .healthSync ? LightSheet.passiveIncomeSuccessPink : method.accent
    }
    private var successRays: (darker: Color, lighter: Color) {
        switch method {
        case .photoTask: LightSheet.healthySuccessRays
        case .exercise: LightSheet.exerciseSuccessRays
        case .focus: LightSheet.focusSuccessRays
        case .healthSync: LightSheet.passiveSuccessRays
        }
    }
    private var successShade: Color {
        method == .healthSync ? LightSheet.passiveIncomeSuccessPinkShade : method.accentShade
    }

    var body: some View {
        ZStack {
            // The rays stay centred behind the fox: the fox's block drops 24pt and
            // its own art lifts 8pt, so the sunburst's centre follows by that net
            // 16pt (as a fraction of the screen height).
            SunburstBackground(lighter: successRays.lighter, darker: successRays.darker,
                               centre: iconCentre + 16.0 / 874.0)
                .ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 0) {
                    // The icon where the streak fox sits, rays radiating from
                    // behind it — the whole block dropped 24pt (the flexible spacer
                    // below the cards absorbs it, so the button doesn't move).
                    Color.clear.frame(height: max(0, geo.size.height * iconCentre - artHalfHeight + 24))

                    art()
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)

                    // Smaller than the flat-white shell's, and held to one line
                    // each — the title and the fox's line shouldn't wrap.
                    Text(title)
                        .auraFont(.display, 26, .bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, Theme.Spacing.l)

                    Text(blurb)
                        .auraFont(.body, 16, .regular)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.top, Theme.Spacing.m)

                    if let detail {
                        detail.padding(.top, Theme.Spacing.xl)
                    }

                    // Everything above stays where it is; the slack falls here so
                    // the button lands at the bottom in the SAME place as the
                    // streak celebration's button (Spacer(xl) → button → reserved
                    // footnote line → l inset).
                    Spacer(minLength: Theme.Spacing.xl)

                    LightPrimaryButton(title: ctaTitle,
                                       face: successAccent,
                                       textColor: .white,
                                       shade: successShade,
                                       action: onContinue)

                    // Reserved whether or not there's a footnote, so the button
                    // lands in the same spot on every flow — matching streak.
                    Text(footnote ?? " ")
                        .auraFont(.body, SheetType.subtitle, .regular)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(footnote == nil ? 0 : 1)
                        .accessibilityHidden(footnote == nil)
                        .padding(.top, Theme.Spacing.m)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                // `l` above the home bar — the SAME bottom inset the streak
                // celebration uses, so the button lands in the exact same spot.
                // The bottom safe area is respected (only the top is ignored),
                // which is why this is a plain `l` and not a safe-area sum.
                .padding(.bottom, Theme.Spacing.l)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // Ignore only the TOP safe area: the fox lines up with the full-height
            // sunburst behind it, while the bottom stays inside the safe area so
            // the button clears the home bar (matching the streak celebration).
            .ignoresSafeArea(edges: .top)
            .opacity(appeared ? 1 : 0)
        }
        .preferredColorScheme(.light)
        .onAppear {
            Haptics.notify(.success)
            guard !reduceMotion else { appeared = true; return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62)) { appeared = true }
        }
    }
}
