//
//  OnbLaunchCommit.swift
//  Aura iOS
//
//  Launch-flow copy of OnbCommitView (screen 12: hold-to-commit ritual). Carries
//  its own copy of the hold control so it is fully independent of the v2 original.
//  Progress off the active sequence (flow.progress).
//

import SwiftUI

struct OnbLaunchCommit: View {
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        ZStack {
            LightSheet.blue.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: false, progress: flow.progress, onSky: true)

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

                ZStack {
                    // Concentric ripple rings dropped down to the fox's feet, so it
                    // stands inside them rather than above them.
                    ZStack {
                        ForEach(0..<3, id: \.self) { i in
                            Ellipse()
                                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                                .frame(width: 180 + CGFloat(i) * 70, height: 60 + CGFloat(i) * 24)
                        }
                    }
                    .offset(y: 72)

                    // Keep the commitment moment calm and deterministic in the
                    // launch flow. The full flow may use motion, but launch uses
                    // the approved static Aura sticker so this screen never
                    // starts an animated media loop.
                    Image("FoxLockInHero")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: 200)
                        // The same soft contact shadow the other onboarding foxes carry.
                        .background(alignment: .bottom) {
                            Ellipse().fill(Color.black.opacity(0.13))
                                .frame(width: 200 * 0.51, height: 200 * 0.136)
                                .offset(y: -14)
                        }
                }

                Spacer()

                OnbLaunchHoldCommit { flow.advance() }
                    .padding(.bottom, Theme.Spacing.xxl)
            }
        }
    }
}

/// White disc with the Aura coin, ringed by a track that fills as the finger stays
/// down. Launch-flow copy of OnbHoldCommit.
private struct OnbLaunchHoldCommit: View {
    var duration: Double = 2.5
    var onDone: () -> Void

    @State private var progress: CGFloat = 0
    @State private var holding = false
    @State private var done = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var commit: DispatchWorkItem?
    @State private var completion: DispatchWorkItem?

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hold to commit")
        .accessibilityHint("Press and hold for \(duration.formatted()) seconds")
        .accessibilityAddTraits(.isButton)
        .onDisappear { stopInteraction() }
        .onChange(of: scenePhase) { _, value in
            if value != .active { stopInteraction() }
        }
    }

    private func begin() {
        guard !holding, !done else { return }
        holding = true
        Haptics.impact(.light)
        Haptics.startRumble(intensity: 0.35, sharpness: 0.25, duration: duration)
        withAnimation(.linear(duration: duration)) { progress = 1 }

        // Use the same deterministic timer-backed gesture as the proven shared
        // hold control. SwiftUI's native long-press recognizer can cancel when
        // the finger moves slightly during the hold, leaving this final screen
        // with no way forward on a physical device.
        let work = DispatchWorkItem { complete() }
        commit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func complete() {
        guard holding, !done else { return }
        done = true
        Haptics.stopRumble()
        Haptics.impact(.heavy)
        let finish = DispatchWorkItem { onDone() }
        completion = finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: finish)
    }

    private func stopInteraction() {
        cancel()
        commit?.cancel()
        completion?.cancel()
        commit = nil
        completion = nil
        Haptics.stopRumble()
        holding = false
        done = false
        progress = 0
    }

    private func cancel() {
        guard holding, !done else { return }
        commit?.cancel()
        commit = nil
        holding = false
        Haptics.stopRumble()
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }
}
