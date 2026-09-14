//
//  HabitPickerRow.swift
//  Aura iOS
//

import SwiftUI

/// One habit or exercise in a method sheet's list, built on the Apple Health
/// metric row: sticker, name over its coin rate, and a trailing control. Here
/// that control is the favourite heart rather than a payout badge — the payout
/// moved onto the rate line, and hearting is what someone does from this list
/// besides picking.
struct HabitPickerRow<Icon: View>: View {
    let title: String
    /// The coin line under the name, without the coin itself ("1 / min").
    let rate: String
    let isFavorite: Bool
    /// The exercise foxes are wide and letterbox badly in a square slot, so
    /// their lists widen it to keep the art the same visual size as the
    /// squarer habit stickers.
    var iconWidth: CGFloat = 52
    /// Optional external trigger so a row tap can play the heart pop (onboarding only).
    var popTrigger: Int = 0
    var onTap: () -> Void
    var onFavorite: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            icon
                .frame(width: iconWidth, height: 52)

            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(title)
                    .auraFont(.body, RowType.label, .semibold)
                    .foregroundStyle(RowType.labelColor)
                HStack(spacing: 4) {
                    Image("AuraCoinIcon")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                    Text(rate)
                        .auraFont(.body, RowType.subLabel, .medium)
                        .foregroundStyle(LightSheet.subtitle)
                }
            }

            Spacer(minLength: Theme.Spacing.s)

            FavoriteHeart(isOn: isFavorite, action: onFavorite, popTrigger: popTrigger)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .bottomDropCard(radius: Theme.Radius.card, shade: LightSheet.whiteShadeOnColour)
        // The row opens the habit; the heart keeps its own hit area inside it.
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .onTapGesture(perform: onTap)
    }
}

/// Outline heart that fills red. Favouriting throws a filled heart up out of the
/// slot at ~2x, then drops it back in as the outline fades out underneath —
/// the reference's motion, about 0.4s end to end. Unfavouriting just swaps back;
/// the celebration belongs to the yes, not the no.
struct FavoriteHeart: View {
    let isOn: Bool
    var action: () -> Void
    /// Bump this to play the favourite pop from outside the heart (the onboarding
    /// pickers do it on a row tap). The app leaves it at 0, so nothing changes there.
    var popTrigger: Int = 0
    /// The empty outline heart's colour. Onboarding passes a lighter one for the
    /// translucent cards; the app keeps its default.
    var idleTint: Color = LightSheet.controlIdle.opacity(0.55)

    @State private var flying = false
    @State private var lift: CGFloat = 0
    @State private var pop: CGFloat = 0.6
    @State private var flyerFade: Double = 0
    @State private var baseScale: CGFloat = 1
    /// Drives the outline's exit declaratively. `withAnimation` fired from a
    /// dispatched block wasn't taking on this property; `.animation(value:)`
    /// animates whenever the flag flips, whoever flips it.
    @State private var outlineGone = false

    private let red = Color(hex: "FF2D4E")

    /// Instant, un-animated state changes (arming and handing off).
    private var immediate: Transaction {
        var t = Transaction()
        t.disablesAnimations = true
        return t
    }

    var body: some View {
        Button {
            Haptics.impact(.light)
            if !isOn { playPop() }
            action()
        } label: {
            ZStack {
                // While the flyer is in the air the slot keeps showing the
                // outline, so the heart reads as leaving and coming back rather
                // than two hearts existing at once. Favourited shows the
                // `FavoriteHeart` art; unselected keeps the SF outline.
                Group {
                    if isOn && !flying {
                        filledHeart
                    } else {
                        Image(systemName: "heart")
                            .foregroundStyle(idleTint)
                    }
                }
                .scaleEffect(baseScale * (outlineGone ? 0.5 : 1))
                .opacity(outlineGone ? 0 : 1)
                // easeOut, not easeIn: an ease-in curve is back-loaded, so
                // it held full opacity and then collapsed inside a single
                // frame — a cut, not a fade.
                .animation(.easeOut(duration: 0.20), value: outlineGone)

                if flying {
                    filledHeart
                        .scaleEffect(pop)
                        .offset(y: lift)
                        .opacity(flyerFade)
                }
            }
            .font(.system(size: 19, weight: .bold))
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: popTrigger) { _, _ in playPop() }
    }

    /// The filled state's art, sized to sit where the SF heart did.
    private var filledHeart: some View {
        Image("FavoriteHeart")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 30, height: 30)
    }

    private func playPop() {
        withTransaction(immediate) {
            flying = true
            outlineGone = false
            lift = 0
            pop = 0.6
            flyerFade = 0
            baseScale = 1
        }

        // Out and up.
        withAnimation(.easeOut(duration: 0.20)) {
            lift = -46
            pop = 2.1
            flyerFade = 1
        }
        // The outline's whole life happens during the rise: it dips as if it
        // launched the thing, springs back, then dissolves. Gone by ~0.32s,
        // while the filled heart is still at its peak.
        withAnimation(.easeOut(duration: 0.08)) { baseScale = 0.72 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.spring(response: 0.16, dampingFraction: 0.6)) { baseScale = 1 }
        }
        // Starts dissolving on the way up and is gone by ~0.30s, ahead of the
        // filled heart landing at ~0.34s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            outlineGone = true
        }
        // Back down into an empty slot.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                lift = 0
                pop = 1
            }
        }
        // Hand back to the resting icon once it has landed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            withTransaction(immediate) {
                flying = false
                outlineGone = false
                baseScale = 1
            }
        }
    }
}

/// The "Create your own" action, as a FAB floating over the list: blue disc,
/// white plus, the same bottom-only drop edge the CTAs wear.
struct CreateHabitButton: View {
    /// The method's colour, worn by the plus rather than the disc.
    var color: Color = LightSheet.blue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(LightSheet.blue)
                .frame(width: 62, height: 62)
                // The app's off-white ground, not pure white.
                .background(LightSheet.ground, in: Circle())
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
                // Tap stays the disc — the halo behind it is decoration.
                .contentShape(Circle())
                // A capsule behind the plus — the nav bar's highlight shape —
                // wider than it is tall, so the ends round off while the top and
                // bottom stay near-straight. Same translucent material as before.
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.vertical, Theme.Spacing.s)
                .background(Capsule().fill(.black.opacity(0.12)))
        }
        .buttonStyle(PressBounceStyle())
    }
}
