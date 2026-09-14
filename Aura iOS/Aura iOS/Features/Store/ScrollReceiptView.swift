//
//  ScrollReceiptView.swift
//  Aura iOS
//

import SwiftUI

/// What a screen-time purchase produces: a paper record of what was bought and
/// what it cost. Identifiable so the store can present it with `.sheet(item:)`.
struct ScrollReceipt: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let minutes: Int
    let coins: Int
    let date: Date

    /// Seeded from the purchase itself, not from `id`. A UUID's hash changes
    /// whenever the struct is rebuilt, which redrew the bars on any re-render.
    /// This way a given purchase always prints the same barcode.
    var barcodeSeed: Int {
        Int(date.timeIntervalSince1970) &* 31 &+ minutes
    }
}

/// The receipt that prints after buying screen time. Monospace, dashed rules,
/// and a barcode, so it reads as a till slip rather than another app card.
///
/// Draws no background — it's meant to slide over the checkout surface it was
/// bought on, not replace it.
/// Rounded at the top, torn along the bottom. The tear is what makes it read
/// as something that came off a roll rather than a white card.
struct ReceiptPaper: Shape {
    /// How deep the zigzag cuts.
    var tear: CGFloat
    /// Nominal tooth width. The real one divides the paper evenly, so both
    /// corners land on a full tooth instead of a runt.
    var tooth: CGFloat = 14
    var corner: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let base = rect.maxY - tear

        p.move(to: CGPoint(x: rect.minX, y: base))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: base))

        // An even number of half-teeth across the width, so the tear starts and
        // ends at the base on both sides and every tooth is identical.
        let steps = max(2, (rect.width / tooth).rounded() * 2)
        let step = rect.width / steps
        for i in stride(from: steps - 1, through: 0, by: -1) {
            let x = rect.minX + step * i
            // Odd indices dip to the point, even ones return to the base.
            p.addLine(to: CGPoint(x: x, y: i.truncatingRemainder(dividingBy: 2) == 1 ? rect.maxY : base))
        }
        p.closeSubpath()
        return p
    }
}

/// A receipt you tapped to look at, rather than one that just printed. No
/// button — the dim behind it says it's a temporary layer, and tapping puts it
/// down. Shares the paper with `ScrollReceiptView` and nothing else: the two
/// have different entrances, different exits, and only one of them starts a
/// clock, so sharing the choreography is what caused them to drift.
struct ReceiptPreviewView: View {
    let receipt: ScrollReceipt
    var onDismiss: () -> Void

    @State private var settled = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ReceiptPaperView(receipt: receipt)
                .scaleEffect(settled ? 1 : 0.55)
                .opacity(settled ? 1 : 0)
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Spacing.xxl)
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear {
            // No print to wait for, so no delay — it's already on screen by the
            // time you've registered the tap.
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { settled = true }
        }
    }
}

struct ScrollReceiptView: View {
    let receipt: ScrollReceipt
    var onDone: () -> Void

    /// Flips once the paper has finished dropping in. Drives the settle: the
    /// receipt rides down small and pops to full size on arrival, and the
    /// button rises from below rather than dropping in with the paper.
    @State private var settled = false
    /// Set on Start Scrolling. The paper and the button clear the screen before
    /// the cover closes — dismissing under them is what looked janky.
    @State private var leaving = false

    var body: some View {
        // No background of its own: the paper prints onto whatever surface it
        // slides over, so checkout stays one continuous screen instead of
        // cutting to a white one.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            ReceiptPaperView(receipt: receipt)
                .scaleEffect(settled ? 1 : 0.6)
                .offset(y: leaving ? -900 : 0)
            Spacer(minLength: 0)

            // `whiteShadeOnColour`, not `whiteShade` — the latter is translucent
            // black, so on the blue checkout it tints instead of shading and the
            // edge reads muddy blue-grey rather than as a shadow.
            LightPrimaryButton(title: "Start Scrolling", face: .white,
                               textColor: LightSheet.blue,
                               shade: LightSheet.whiteShadeOnColour) {
                // Paper up, button down, then the cover closes behind them.
                withAnimation(.easeIn(duration: 0.28)) { leaving = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { onDone() }
            }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
                .offset(y: (settled && !leaving) ? 0 : 220)
                .opacity(settled ? 1 : 0)
        }
        .padding(.top, Theme.Spacing.xxl)
        .onAppear {
            // Waits out the slide, then settles — a spring so the paper lands
            // with a little weight instead of easing flat.
            withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.6)) {
                settled = true
            }
        }
    }

}

/// The slip itself: monospace, dashed rules, a barcode, and a torn foot. Shared
/// by the purchase finale and the preview — the paper is the only thing those
/// two have in common.
struct ReceiptPaperView: View {
    let receipt: ScrollReceipt
    /// Depth of the torn edge along the foot of the paper.
    private let tearDepth: CGFloat = 9

    var body: some View { paper }

    // MARK: - Paper

    private var paper: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SCROLL RECEIPT")
                .font(Self.mono(13, .bold))
                .foregroundStyle(Ink.dark)
            Text(Self.dateLine(receipt.date))
                .font(Self.mono(10))
                .foregroundStyle(Ink.faded)
                .padding(.top, RowType.labelGap)

            Rule(dashed: true).padding(.vertical, Theme.Spacing.l)

            // Line items, each closed by its own rule. The solid one under
            // DURATION is the till convention for "everything above is what
            // you bought; what follows is what it cost".
            row("NAME", receipt.name.uppercased())
            Rule(dashed: true).padding(.vertical, Theme.Spacing.m)

            row("ACTIVITY", "GUILT-FREE SCROLLING", bold: true)
            Rule(dashed: true).padding(.vertical, Theme.Spacing.m)

            row("DURATION", "\(receipt.minutes) min")
            Rule(dashed: false).padding(.vertical, Theme.Spacing.m)

            costRow

            Rule(dashed: true).padding(.top, Theme.Spacing.l)

            Barcode(seed: receipt.barcodeSeed)
                .frame(height: 54)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.xl)

            HStack(spacing: Theme.Spacing.s) {
                // Aura's own, now that it exists — the line says AURA APP, and
                // it was standing in with the Messages icon.
                Image("AuraAppIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    // A black keyline, since the Aura icon is white — a white
                    // outline would vanish into it.
                    .appIconChrome(side: 20, border: 0)
                Text("AURA APP")
                    .font(Self.mono(10, .bold))
                    .foregroundStyle(Ink.dark)
            }
            .frame(maxWidth: .infinity)

            Text("You earned this one. Enjoy it.")
                .font(Self.mono(9))
                .foregroundStyle(Ink.faded)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .padding(Theme.Spacing.l)
        // Extra room at the foot so the tear has something to bite into
        // without clipping the last line.
        .padding(.bottom, tearDepth)
        .background(
            ReceiptPaper(tear: tearDepth)
                .fill(
                    // Barely there, but it's the difference between paper and
                    // a white rectangle: light at the top, faintly grey by the
                    // time it reaches the tear.
                    LinearGradient(
                        colors: [.white, Ink.paperEdge],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .overlay(
            ReceiptPaper(tear: tearDepth)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        // Contact plus ambient, so it sits on the surface and has height.
        .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
        .shadow(color: .black.opacity(0.14), radius: 24, y: 14)
        .padding(.horizontal, Theme.Spacing.xxl)
    }

    /// Label left, value right — the layout every till slip uses.
    private func row(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(Self.mono(10))
                .foregroundStyle(Ink.faded)
            Spacer(minLength: Theme.Spacing.m)
            Text(value)
                .font(Self.mono(11, bold ? .bold : .regular))
                .foregroundStyle(Ink.dark)
                .multilineTextAlignment(.trailing)
        }
    }

    /// The total. Centered rather than baseline-aligned so the coin and the
    /// amount share a centerline instead of the glyph hanging off the text's
    /// baseline.
    private var costRow: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("COST")
                // Matches the ACTIVITY value rather than the labels above it,
                // so the total reads as the line that matters.
                .font(Self.mono(11, .bold))
                .foregroundStyle(Ink.dark)
            Spacer(minLength: Theme.Spacing.m)
            Image("AuraCoinIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 18, height: 18)
            Text("-\(receipt.coins)")
                .font(Self.mono(14, .bold))
                .foregroundStyle(LightSheet.danger)
                .padding(.leading, Theme.Spacing.s)
        }
    }

    // MARK: - Type + color

    private enum Ink {
        static let dark = LightSheet.title
        static let faded = Color(hex: "8A8A92")
        /// The paper's shaded edge — part of the facsimile, like the mono type.
        static let paperEdge = Color(hex: "F4F4F2")
    }

    /// SF Mono. Aura's own faces are Montserrat and Rubik, neither monospaced,
    /// and the fixed pitch is most of what makes this read as a receipt.
    private static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    private static func dateLine(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M/d/yyyy"
        let stamp = f.string(from: date)
        return Calendar.current.isDateInToday(date) ? "Today, \(stamp)" : stamp
    }
}

/// A hairline across the full width, dashed for line items and solid for the
/// break above the total.
private struct Rule: View {
    var dashed: Bool

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)
            .overlay(
                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: 10_000, y: 0))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 3] : []))
                .foregroundStyle(Color.black.opacity(0.22))
            )
            .clipped()
    }
}

/// Decorative barcode. Bar widths come from a seeded generator rather than
/// `random()`, so a given receipt draws the same bars every time it's laid out.
private struct Barcode: View {
    let seed: Int

    var body: some View {
        Canvas { context, size in
            var value = UInt64(bitPattern: Int64(seed)) | 1
            var x: CGFloat = 0

            while x < size.width {
                // xorshift — cheap, deterministic, no Foundation RNG state.
                value ^= value << 13
                value ^= value >> 7
                value ^= value << 17

                let barWidth = CGFloat(value % 3 + 1)
                let gap = CGFloat((value >> 8) % 3 + 1)
                guard x + barWidth <= size.width else { break }

                context.fill(
                    Path(CGRect(x: x, y: 0, width: barWidth, height: size.height)),
                    with: .color(.black)
                )
                x += barWidth + gap
            }
        }
    }
}

#Preview {
    ScrollReceiptView(
        receipt: ScrollReceipt(name: "Hayden", minutes: 10, coins: 10, date: .now)
    ) {}
}
