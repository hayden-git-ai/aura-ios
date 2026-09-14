//
//  SuccessCelebrationArt.swift
//  Aura iOS
//

import SwiftUI

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
