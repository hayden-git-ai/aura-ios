//
//  StepsExplainerSheet.swift
//  Aura iOS
//

import SwiftUI

/// "How this works", as numbered steps.
///
/// One sheet for the coins explainer and all four quests. The words and accent
/// change per method, while the steps share one layout.
struct StepsExplainerSheet: View {
    struct Step {
        let title: String
        let copy: String
    }

    let title: String
    let subtitle: String
    /// Blocking retains its established explainer art; Earn and camera sheets
    /// intentionally leave this nil.
    var hero: String? = nil
    let steps: [Step]
    /// The numerals' colour. Each quest brings its own so the sheet reads as
    /// part of the screen it opened from.
    var accent: Color = LightSheet.blue
    /// An optional line under the steps — troubleshooting, caveats, anything
    /// that isn't a step. Quieter than the steps so it doesn't read as a fifth.
    var footnote: String?
    /// An optional action under the primary button — something the sheet lets
    /// you *do* as well as read. Plain text, so it can't be mistaken for the
    /// button above it.
    ///
    /// The work returns whether it succeeded and the sheet owns the feedback:
    /// callers shouldn't each invent their own spinner and confirmation.
    var secondaryTitle: String?
    var secondaryAction: (() async -> Bool)?

    @State private var actionPhase: ReloadPhase = .idle

    @Environment(\.dismiss) private var dismiss

    /// A step is a block, not a line: a title plus two lines of copy runs about
    /// 58pt tall. At `xl` the gap between blocks was the same one the app uses
    /// between single-line rows, which is only ~40% of a block's own height and
    /// reads as cramped.
    private static let betweenSteps = Theme.Spacing.xxl
    private static let heroHeight: CGFloat = 140
    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                if let hero {
                    Image(hero)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: Self.heroHeight)
                        .foxShadow()
                        .padding(.top, Theme.Spacing.l)
                }

                Text(title)
                    .auraFont(.display, SheetType.title, .bold)
                    .foregroundStyle(SheetType.titleColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, hero == nil ? Theme.Spacing.l : Theme.Spacing.l + Theme.Spacing.m)
                    .padding(.horizontal, Theme.Spacing.xl)

                Text(subtitle)
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, Theme.Spacing.xs)

                // Steps and footnote scroll; the capsule and header art above
                // and the buttons below do not.
                //
                // This used to be one VStack inside a fixed 730pt sheet, which
                // meant the tallest explainer overflowed and SwiftUI pushed the
                // top of the content off the sheet — taking the drag capsule
                // with it. "How Blocking Works" is the only one with four steps,
                // a footnote AND a secondary button, so it was the only one that
                // lost its capsule. A scroll view makes the length irrelevant.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: Self.betweenSteps) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            row(number: index + 1, step: step)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xxl)

                    if let footnote {
                        // Glyph and sizes lifted from the same note on the Passive
                        // Income screen, so the two read as one message in two
                        // places rather than two different asides.
                        HStack(alignment: .top, spacing: Theme.Spacing.s) {
                            Image(systemName: "info.circle")
                                .font(.system(size: RowType.label))
                            Text(footnote)
                                .auraFont(.body, RowType.subLabel, .regular)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(LightSheet.subtitle)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.xl)
                    }

                    }
                }

                LightPrimaryButton(title: "Got it", face: accent,
                                   shade: accent.darkened(by: 0.12)) { dismiss() }
                    .padding(.horizontal, Theme.Spacing.xl)

                if let secondaryTitle, let secondaryAction {
                    Button { ReloadPhase.run($actionPhase, work: secondaryAction) } label: {
                        HStack(spacing: Theme.Spacing.s) {
                            ReloadGlyph(phase: actionPhase)
                            Text(label(for: secondaryTitle))
                                .auraFont(.body, SheetType.subtitle, .semibold)
                                .contentTransition(.opacity)
                        }
                        // On the whole row, not just the label: the glyph had no
                        // colour of its own and inherited the app's forced dark
                        // scheme — white on a white sheet.
                        .foregroundStyle(actionPhase == .failed ? LightSheet.danger : accent)
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
        .presentationDetents([.height(800)])
        .presentationDragIndicator(.hidden)
    }

    /// Numeral, then the pair. No card behind it — the rows are already a list,
    /// and boxing each one turns the sheet into a stack of shapes.
    private func row(number: Int, step: Step) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            // The method's colour, filled, with a white numeral. This was an
            // accent numeral on a pale grey disc, which measured 2.96:1 and was
            // excused as decorative. Inverting it makes the contrast a
            // non-question and ties each sheet to the method it describes.
            Text("\(number)")
                .auraFont(.display, SheetType.cardTitle, .bold)
                .foregroundStyle(.white)
                .frame(width: Self.discSide, height: Self.discSide)
                .background(Circle().fill(accent))

            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(step.title)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(SheetType.titleColor)
                Text(step.copy)
                    .auraFont(.body, SheetType.cardBlurb, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }

    private func label(for title: String) -> String {
        switch actionPhase {
        case .idle:    title
        case .running: "Reloading"
        case .done:    "Done!"
        case .failed:  "Couldn't reload"
        }
    }

    /// The numeral's disc, on the same grade as the app's other small circles.
    private static let discSide = CircleIconButton.Grade.chrome.diameter
}
