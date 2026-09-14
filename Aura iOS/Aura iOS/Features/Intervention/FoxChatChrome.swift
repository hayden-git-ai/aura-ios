//
//  FoxChatChrome.swift
//  Aura iOS
//
//  The shared visual language of "a text thread with the fox": the day/night
//  texting background, the avatar-on-a-glass-pill header, the dark-glass wash,
//  and the typing indicator. Extracted from the intervention thread so the
//  onboarding fox chat wears the exact same design instead of a lookalike.
//

import SwiftUI

/// The "Text From Aura" background: the day/night texting scene, softly blurred so
/// the thread reads on top of it. Flips at the same 7am/7pm boundary as Home.
struct TextAuraBackground: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            let isDay = HomeDaylight.isDay(context.date)
            Color.black
                .overlay(
                    Image(isDay ? "Text Aura_Day View" : "Text Aura_Night View")
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 1)
                        .clipped()
                )
                .ignoresSafeArea()
        }
    }
}

/// The dark glass the Aura chat wears: a day/night wash with a white sheen. Used
/// by the name pill, the user's reply bubbles, and the typing indicator.
@ViewBuilder
func foxChatGlass<S: Shape>(_ shape: S) -> some View {
    shape
        .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.58 : 0.45))
        .overlay(shape.fill(Color.white.opacity(0.08)))
}

/// The contact header: the Aura app icon avatar sitting on the "Aura" name pill.
struct FoxChatHeader: View {
    var body: some View {
        VStack(spacing: -Theme.Spacing.xs) {
            Image("AuraAppIcon")
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(LightSheet.divider, lineWidth: 1))
                .zIndex(1)

            Text("Aura")
                .auraFont(.body, 17, .bold)
                .foregroundStyle(.white)
                .frame(width: 100)
                .padding(.vertical, Theme.Spacing.xs)
                .background {
                    Capsule()
                        .fill(Color.black.opacity(HomeDaylight.isDay() ? 0.58 : 0.45))
                        .overlay(Capsule().fill(Color.white.opacity(0.08)))
                }
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
    }
}

/// A back chevron that reads on the texting background: white on dark glass.
struct FoxChatBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background { foxChatGlass(Circle()) }
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(PressBounceStyle())
    }
}

/// The three-dot "typing" indicator, each dot lifting in turn.
struct TypingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.white)
                    .frame(width: 7, height: 7)
                    .opacity(phase == index ? 1 : 0.35)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(280))
                withAnimation(.easeInOut(duration: 0.2)) { phase = (phase + 1) % 3 }
            }
        }
    }
}
