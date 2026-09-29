//
//  SuccessCelebrationArt.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// The celebrating fox on every success screen — a run of short clips played in
/// order and looped: cute → flexing → smile.
///
/// One shared view so all four earn methods land on the same celebration, sized
/// and shadowed to match the failure screen's fox exactly.
struct SuccessCelebrationArt: View {
    /// Extra vertical nudge for the FOX ONLY (not its shadow), so a caller can
    /// centre the fox on the contact shadow without dragging the shadow along.
    /// Defaults to 0 — success screens are unaffected.
    var foxYOffset: CGFloat = 0

    /// The failure screen's fox size, so success and failure land the fox at the
    /// same scale.
    private static let foxSize: CGFloat = 248

    /// Measured off the keyed source and identical across all three poses: the
    /// fox's feet/body sit at 0.477 across the frame — the bushy tail on the
    /// right pulls the body left of centre. Nudge the video right by that gap so
    /// the body lands dead-centre over the shadow and centred on screen, the way
    /// the streak fox's centred body does.
    private static let bodyCentreNudge: CGFloat = Self.foxSize * (0.5 - 0.477)

    var body: some View {
        // Set up like StreakFoxHero — a dead-centre contact shadow the fox stands
        // in — but with the body nudged to the shadow's centre (the shadow is a
        // fixed sibling so the nudge doesn't drag it along).
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(0.12))
                .frame(width: 260 * 0.51, height: 260 * 0.136)
                .offset(y: -Self.foxSize * 0.05 - 2)

            // The clips keyed and stitched into one looping HEVC-alpha clip, in
            // order, by tools/chromakey. Lifted 12px so the fox stands a touch
            // above the fixed shadow.
            LoopingVideoView(resource: "SuccessCelebration")
                .frame(width: Self.foxSize, height: Self.foxSize)
                .offset(x: Self.bodyCentreNudge, y: -12 + foxYOffset)
        }
        .frame(width: Self.foxSize, height: Self.foxSize)
    }
}

/// The looping earn-state fox used while a habit is being configured. The
/// converted HEVC-alpha clip stays hardware-decoded and pauses when its host
/// leaves the window or the scene becomes inactive; reduced motion gets a still.
struct EarnFoxPlaybackView: View {
    static let defaultSize: CGFloat = 260
    var size: CGFloat = Self.defaultSize
    var shadowOpacity: Double = 0.12
    var shadowWidthRatio: CGFloat = 0.51
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            Ellipse()
                .fill(Color.black.opacity(shadowOpacity))
                .frame(width: size * shadowWidthRatio, height: size * 0.136)
                .offset(y: -size * 0.05 - 2)

            if reduceMotion {
                if let path = Bundle.main.path(forResource: "EarnEntryPoster", ofType: "png"),
                   let poster = UIImage(contentsOfFile: path) {
                    Image(uiImage: poster)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: size, height: size)
                }
            } else {
                LoopingVideoView(resource: "EarnEntryLoop", ext: "mov",
                                 isPlaying: scenePhase == .active)
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct EarnMethodHero: View {
    let title: String
    let subtitle: String
    var foxOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            EarnFoxPlaybackView()
                .offset(y: foxOffset)
            Text(title)
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(.white)
            Text(subtitle)
                .auraFont(.body, SheetType.subtitle, .regular)
                .foregroundStyle(LightSheet.onColour)
                .multilineTextAlignment(.center)
        }
        .padding(.top, FocusHero.chromeClearance)
    }
}

/// Shared with the illustrated Earn cards: black display lettering, white
/// sticker outline and the achievement numeral shadow.
struct EarnOutlinedTitle: View {
    let text: String
    let font: UIFont

    var body: some View {
        StrokedNumber(text: text, font: font, fill: .black, stroke: .white,
                      outlineWidth: font.pointSize * StrokedNumeral.outlineRatio)
            .fixedSize()
            .shadow(color: .black.opacity(LightSheet.Achievement.numeralShadowOpacity),
                    radius: LightSheet.Achievement.numeralShadowRadius,
                    y: LightSheet.Achievement.numeralShadowDrop)
    }
}
