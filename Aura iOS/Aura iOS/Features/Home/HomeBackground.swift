//
//  HomeBackground.swift
//  Aura iOS
//

import SwiftUI

/// Single source of truth for the Home day/night decision, shared by the
/// background and the card material so they always agree.
enum HomeDaylight {
    /// Local hours counted as "day" — 7am up to (not including) 7pm.
    static let dayHours = 7..<19

    static func isDay(_ date: Date = Date()) -> Bool {
        return dayHours.contains(Calendar.current.component(.hour, from: date))
    }
}

/// Home background — a full-bleed mountain illustration, aspect-filled over
/// black. Swaps between a Day and Night variant based on the user's local time,
/// re-checked each minute so it flips automatically at the boundary. Shared with
/// the "Talk to Aura" intervention so the conversation happens on the same scene.
struct HomeBackground: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let isDay = HomeDaylight.isDay(context.date)
            let asset = isDay ? "AuraHomeBackgroundDay" : "AuraHomeBackgroundNight"
            Color.black
                .overlay(
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                )
                // Day only: a subtle top scrim so the logo + streak read against
                // the bright sky. Night is already dark, so it's skipped.
                .overlay(alignment: .top) {
                    if isDay {
                        LinearGradient(
                            colors: [Color.black.opacity(0.35), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                    }
                }
                .ignoresSafeArea()
        }
    }
}
