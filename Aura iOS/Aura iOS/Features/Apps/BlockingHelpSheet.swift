//
//  BlockingHelpSheet.swift
//  Aura iOS
//

import SwiftUI

/// "How Blocking Works", built from the same `LaneCard` the board uses — so it
/// teaches the three lanes with the real cards (fox, burst, the actual app-state
/// row) rather than a flat copy. No generic mascot; the explanation rides as each
/// card's subtitle, with a note that time running out re-freezes everything.
/// Reload lives at the bottom, as it did on the old sheet.
struct BlockingHelpSheet: View {
    /// The Reload Aura action — returns whether the reload succeeded.
    var onReload: (() async -> Bool)?

    @Environment(\.dismiss) private var dismiss
    @Environment(HabitStore.self) private var store
    @State private var actionPhase: ReloadPhase = .idle

    /// One height for all three cards — they must always match, whatever the
    /// copy length. Sized to hold the longest explanation (3 lines) plus the fox.
    private static let cardHeight: CGFloat = 144

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                Text("How Blocking Works")
                    .auraFont(.display, SheetType.title, .bold)
                    .foregroundStyle(SheetType.titleColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.l + Theme.Spacing.m)
                    .padding(.horizontal, Theme.Spacing.xl)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.m) {
                        LaneCard(rule: .blocked,
                                 selection: store.blockConfig[.blocked],
                                 subtitle: "Gone for good. Nothing opens these, and only you can see this list.",
                                 showApps: false, fixedHeight: Self.cardHeight)
                        LaneCard(rule: .distracting,
                                 selection: store.blockConfig[.distracting],
                                 subtitle: "Frozen until you buy screen time with the coins you earn from quests.",
                                 showApps: false, fixedHeight: Self.cardHeight)
                        LaneCard(rule: .allowed,
                                 selection: store.blockConfig[.allowed],
                                 subtitle: "Aura keeps these open, and never freezes them.",
                                 showApps: false, fixedHeight: Self.cardHeight)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.l)
                }

                LightPrimaryButton(title: "Got it", face: LightSheet.blue,
                                   shade: LightSheet.blue.darkened(by: 0.12)) { dismiss() }
                    .padding(.horizontal, Theme.Spacing.xl)

                if let onReload {
                    Button { ReloadPhase.run($actionPhase, work: onReload) } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            ReloadGlyph(phase: actionPhase)
                            Text(reloadLabel)
                                .auraFont(.body, SheetType.subtitle, .semibold)
                                .contentTransition(.opacity)
                        }
                        .foregroundStyle(actionPhase == .failed ? LightSheet.danger : LightSheet.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: CircleIconButton.minimumTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(actionPhase != .idle)
                    .padding(.horizontal, Theme.Spacing.xl)
                }
            }
            .padding(.bottom, Theme.Spacing.l)
        }
        .presentationDetents([.height(688)])
        .presentationDragIndicator(.hidden)
    }

    private var reloadLabel: String {
        switch actionPhase {
        case .idle:    "Apps not freezing properly? Reload Aura."
        case .running: "Reloading"
        case .done:    "Done!"
        case .failed:  "Couldn't reload"
        }
    }
}
