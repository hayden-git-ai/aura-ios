//
//  EmergencyUnlockSheet.swift
//  Aura iOS
//

import SwiftUI

/// The confrontation screen: a live self-mirror with cycling encouragement,
/// scarcity framing, and an Opal-style hold-to-commit button. Replaces the
/// earlier confirm-dialog flow entirely — the hold itself is the commit,
/// there's no separate confirm step, and staying locked is a single tap on
/// the X. Camera-first by design; `SelfMirrorCameraView` falls back to a
/// generic silhouette if camera access is denied, so this never blocks.
///
/// Redeeming the pass doesn't dismiss the sheet — it swaps in-place to
/// `usedStateView`, the next step of the same flow (not a separate sheet).
/// That state is also what reappears if the sheet is reopened later in the
/// week, so there's only ever one place this logic lives.
struct EmergencyUnlockSheet: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var glowPulse = false
    // Mirrors `store.emergencyUnlockUsed`, but flips a beat after the hold
    // completes rather than instantly — so `HoldToUnlockButton`'s own
    // "Pass Redeemed" checkmark state is visible before the sheet swaps in
    // the used-state view underneath it.
    @State private var showUsedState = false

    // Kept short and similar in length so the caption pill doesn't resize
    // much as phrases cycle — the personalized one is the exception, since
    // name length isn't ours to control.
    private var encouragements: [String] {
        [
            "Focus, \(store.displayName)",
            "Put the phone down",
            "It's not worth it",
            "Less scrolling, more life",
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            FocusSheetGrabber()
            Group {
                if showUsedState {
                    usedStateView
                } else {
                    activeStateView
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .onAppear { showUsedState = store.emergencyUnlockUsed }
        .focusSheetMaterial()
        .presentationDetents([.fraction(0.93)])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Active state

    private var activeStateView: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 0)

            mirror

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.m) {
                actionArea
                Text("Bypass all rules and unblock all apps for 1 \nhour. This can be used once per week.")
                    .font(Typography.body(size: 12.5))
                    .foregroundStyle(Theme.Color.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Header

    // The logo is only here for marketing capture (TikTok/Instagram clips of
    // this exact screen) — the used state isn't part of that footage, so it
    // skips the logo and keeps just the close button.
    private var header: some View {
        ZStack {
            Image("AuraLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 28)

            HStack {
                Spacer()
                closeButton
            }
        }
        .frame(height: 44)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            WoodButtonArtwork(role: .close)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mirror

    /// The caption is an `.overlay`, not a VStack sibling — an overlay never
    /// contributes to its parent's reported size, so this block's height is
    /// ALWAYS just the camera's fixed aspect-ratio height, regardless of
    /// whether the caption is one line or two. That keeps the camera's
    /// position perfectly stable as phrases cycle — a VStack-with-negative-
    /// spacing approach (tried previously) reports its true combined height,
    /// which re-centers the whole block — and the camera along with it —
    /// every time the caption's line count changes.
    ///
    /// The trade-off: since the caption's overflow is no longer counted, the
    /// overall camera+caption block isn't perfectly centered for every
    /// possible caption height — the fixed bottom padding below splits the
    /// difference between a 1-line and 2-line caption instead.
    private var mirror: some View {
        cameraBlock
            .overlay(alignment: .bottom) {
                captionPill
                    .padding(.horizontal, Theme.Spacing.l)
                    .offset(y: 22)
            }
            .padding(.bottom, 48)
    }

    private var cameraBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Theme.Color.signalWarning)
                .blur(radius: 28)
                .opacity(glowPulse ? 1 : 0.5)
                .scaleEffect(glowPulse ? 1.015 : 0.995)

            SelfMirrorCameraView()
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)
                )
        }
        .aspectRatio(1 / 1.24, contentMode: .fit)
        .onAppear {
            guard !reduceMotion else {
                glowPulse = true
                return
            }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    private var captionPill: some View {
        TypewriterCaptionView(phrases: encouragements)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.l)
            .frame(maxWidth: .infinity)
            // Flat and dark — deliberately not glass here; the glass on the
            // capsule nav/header buttons is for floating chrome, this card
            // reads more like a title card sitting on the mirror.
            .background(Theme.Color.surfaceRecessed, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }

    // MARK: - Action

    private var actionArea: some View {
        HoldToUnlockButton {
            store.useEmergencyUnlock()
            // A short beat so the button's own "Pass Redeemed" checkmark
            // state is seen before the sheet swaps to usedStateView.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showUsedState = true
                }
            }
        }
    }

    // MARK: - Used state

    private var usedStateView: some View {
        VStack(spacing: 0) {
            usedHeader

            Spacer(minLength: 0)

            VStack(spacing: Theme.Spacing.l) {
                usedBadge

                VStack(spacing: Theme.Spacing.s) {
                    Text("Scroll Pass Used")
                        .font(Typography.display(size: 26))
                        .foregroundStyle(Theme.Color.textPrimary)

                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        Text("Resets in \(countdownString(until: nextResetDate(from: timeline.date), from: timeline.date))")
                            .font(Typography.body(size: 15))
                            .foregroundStyle(Theme.Color.textTertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    // Close button only — no wordmark. The logo's sole purpose is marketing
    // capture of the active state, which this screen isn't part of.
    private var usedHeader: some View {
        HStack {
            Spacer()
            closeButton
        }
        .frame(height: 44)
    }

    private var usedBadge: some View {
        ZStack {
            Circle()
                .fill(Theme.Color.signalWarning)
                .blur(radius: 40)
                .opacity(glowPulse ? 0.9 : 0.5)
                .scaleEffect(glowPulse ? 1.05 : 0.95)

            Circle()
                .fill(Theme.Color.surfaceRecessed)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

            Image(systemName: "hourglass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 96, height: 96)
        .onAppear {
            guard !reduceMotion else {
                glowPulse = true
                return
            }
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }

    // Calendar-based, not usage-timestamp-based: the pass always resets at
    // the next Monday 12:00am regardless of when in the week it was used.
    // TODO: replace with the real weekly-reset date once Screen Time
    // entitlements exist — this recomputes "next Monday" fresh every time
    // rather than reading a stored reset date.
    private func nextResetDate(from date: Date = .now) -> Date {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: date)
        let daysUntilMonday = ((9 - weekday) % 7 + 7) % 7
        let daysAhead = daysUntilMonday == 0 ? 7 : daysUntilMonday
        return calendar.date(byAdding: .day, value: daysAhead, to: startOfToday) ?? date
    }

    private func countdownString(until resetDate: Date, from now: Date) -> String {
        let remaining = max(0, resetDate.timeIntervalSince(now))
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    EmergencyUnlockSheet()
        .environment(HabitStore())
        .preferredColorScheme(.dark)
}
