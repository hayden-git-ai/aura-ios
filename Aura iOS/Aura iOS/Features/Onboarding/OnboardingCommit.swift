//
//  OnboardingCommit.swift
//  Aura iOS
//
//  Phase 6 (cont.): the daily habit-goal picker, then the hold-to-commit ritual
//  (adapted from Brainrot's "ready to take control?" hold screen) — the fox
//  breathes on the blue ground while a ring fills as you hold the button.
//

import SwiftUI
import AudioToolbox

// MARK: - Daily time commitment (single-select cards)

struct OnbDailyGoalView: View {
    @Environment(OnboardingFlow.self) private var flow

    private let options: [(minutes: Int, tier: String, icon: String)] = [
        (30, "Casual", "tortoise.fill"),
        (60, "Regular", "figure.walk"),
        (90, "Serious", "figure.run"),
        (120, "Hardcore", "flame.fill"),
    ]

    var body: some View {
        OnbQuestionLayout(
            progress: 0.97,
            headerText: "how much time do you want to spend on these habits daily?",
            content: {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(options, id: \.minutes) { opt in
                        timeCard(opt.minutes, opt.tier, opt.icon)
                    }
                }
                .padding(.top, Theme.Spacing.m)
            },
            bottom: {
                onbContinue(enabled: flow.dailyMinutes != nil) { flow.advance() }
            }
        )
    }

    private func timeCard(_ minutes: Int, _ tier: String, _ icon: String) -> some View {
        let on = flow.dailyMinutes == minutes
        return Button {
            Haptics.impact(.light)
            AudioServicesPlaySystemSound(1104)
            flow.dailyMinutes = minutes
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24)
                Text("\(minutes) minutes")
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
                Text(tier)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, Theme.Spacing.l)
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.16),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(on ? Color.white : Color.clear, lineWidth: 2.5))
        }
        .buttonStyle(PressBounceStyle())
    }
}

// MARK: - Hold to commit (ritual)

struct OnbCommitView: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: true, progress: 0.99, onSky: true)

                Spacer().frame(height: Theme.Spacing.xl)

                VStack(spacing: Theme.Spacing.s) {
                    Text("ready to take your life back?")
                        .auraFont(.display, SheetType.heroCompact, .bold)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("hold the button to commit")
                        .auraFont(.body, SheetType.cardTitle, .semibold)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, Theme.Spacing.xl)

                Spacer()

                // The fox, calm, over soft ripples.
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Ellipse()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                            .frame(width: 180 + CGFloat(i) * 70, height: 60 + CGFloat(i) * 24)
                    }
                    LoopingVideoView(resource: "LockInFox")
                        .frame(height: 200)
                }

                Spacer()

                OnbHoldCommit { flow.advance() }
                    .padding(.bottom, Theme.Spacing.xxl)
            }
        }
    }
}

/// White disc with the Aura coin, ringed by a track that fills as the finger
/// stays down — a commit ritual, matching the reference.
private struct OnbHoldCommit: View {
    var duration: Double = 2.5
    var onDone: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var done = false
    @State private var commit: DispatchWorkItem?

    private let size: CGFloat = 88
    private let ring: CGFloat = 6
    private let gap: CGFloat = 8
    private var ringD: CGFloat { size + 2 * gap + ring }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.30), lineWidth: ring)
            Circle().trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: ring, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: ringD, height: ringD)
        .overlay {
            Circle().fill(.white).frame(width: size, height: size)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
                .overlay {
                    Image("CameraRepsHard").resizable().interpolation(.high).scaledToFit()
                        .frame(width: 46, height: 46)
                        // The sticker sits high in its own canvas; nudge down to visually centre.
                        .offset(y: 3)
                }
        }
        .scaleEffect(holding ? 0.95 : 1)
        .animation(.snappy(duration: 0.2), value: holding)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in begin() }
                .onEnded { _ in cancel() }
        )
    }

    private func begin() {
        guard !holding, !done else { return }
        holding = true
        Haptics.impact(.light)
        withAnimation(.linear(duration: duration)) { progress = 1 }
        let work = DispatchWorkItem {
            done = true
            Haptics.impact(.heavy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDone() }
        }
        commit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func cancel() {
        guard holding, !done else { return }
        holding = false
        commit?.cancel(); commit = nil
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }
}
