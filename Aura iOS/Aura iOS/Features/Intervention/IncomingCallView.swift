//
//  IncomingCallView.swift
//  Aura iOS
//

import SwiftUI

/// Mirror Check's opening: Aura appears to be calling you, and the "caller" is
/// your own face.
///
/// The mirror isn't a screen of its own — it's the self-view of a call that
/// carries on into the conversation, so you're looking at yourself while the
/// fox asks whether you need this. That's a harder thing to tap past than a
/// sentence.
///
/// Dressed as an incoming video call, wording included. Declining closes the
/// whole thing and puts you back where you were: no lecture, no follow-up beat.
/// Saying no is allowed to be free.
struct IncomingCallView: View {
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // No scrim. A lit room shows the reference is the raw camera feed
            // top to bottom, and darkening it was the single biggest thing
            // making this screen look like an app rather than a call.
            SelfMirrorCameraView()
                .ignoresSafeArea()

            // Positions measured off the reference, as fractions of the
            // screen rather than paddings: the name block starts 17.4% down and
            // the answer row's circles sit between 77.7% and 86%. Paddings from
            // the safe area put everything ~4% too high, which is most of what
            // made the screen read wrong.
            GeometryReader { screen in
                VStack(spacing: 0) {
                    caller
                        .padding(.top, screen.size.height * 0.166)

                    Spacer(minLength: 0)

                    answers
                        .padding(.bottom, screen.size.height * 0.115)
                }
                .frame(width: screen.size.width, height: screen.size.height)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        // Rings until the view goes away. The task is cancelled on disappear,
        // which also covers answering and declining.
        .task { await Haptics.ring() }
        .onDisappear { Haptics.stopRumble() }
    }

    /// System font and system metrics, deliberately — this screen is pretending
    /// to be a call, and Aura's display face would give it away instantly.
    ///
    /// Measured off the reference rather than guessed. The name's cap height is
    /// 36px in a 620-wide frame (22.8pt), and SF's cap is 0.70 of its size, so
    /// 32. Its stems run 6–7px against that cap — a ratio of 0.18, which is
    /// **bold**; regular would be nearer 0.11. The status line's stems are 2–3px
    /// on a smaller cap, so that one really is regular.
    private var caller: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text("Aura")
                .font(.system(size: 33, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)

            Text("FaceTime Video")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
        }
    }

    private var answers: some View {
        // systemRed and systemGreen, dark-mode variants, stated outright.
        // `Color.red` resolves against the environment's colour scheme, and
        // relying on `preferredColorScheme` to pick the dark pair is a guess —
        // these are the published values.
        //
        // Each answer takes half the width and centres in it, which puts the
        // circles at 25% and 75%; the reference measures 25.7%.
        HStack(spacing: 0) {
            answer(symbol: "xmark", label: "Decline", tint: Self.systemRed, action: onDecline)
                .frame(maxWidth: .infinity)
            answer(symbol: "video.fill", label: "Accept", tint: Self.systemGreen, action: onAccept)
                .frame(maxWidth: .infinity)
        }
    }

    private func answer(symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.impact(.medium)
            action()
        } label: {
            VStack(spacing: Theme.Spacing.s) {
                Image(systemName: symbol)
                    // Heavier: the X was drawing thinner than the video glyph
                    // beside it, which made the pair look mismatched.
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: Self.answerSide, height: Self.answerSide)
                    .background(tint, in: Circle())
                    // The call buttons sit above the camera feed rather than in
                    // it, and a soft drop is what separates them from whatever
                    // the room is doing.
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 5)

                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
            }
        }
        .buttonStyle(PressBounceStyle())
    }

    private static let answerSide: CGFloat = 64

    /// Published dark-mode system colours, not `Color.red` / `Color.green`.
    /// https://sarunw.com/posts/dark-color-cheat-sheet/
    private static let systemRed = Color(hex: "FF453A")
    private static let systemGreen = Color(hex: "30D158")
}

#Preview {
    IncomingCallView(onAccept: {}, onDecline: {})
}
