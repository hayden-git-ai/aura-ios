//
//  EmergencyUnlockView.swift
//  Aura iOS
//

import SwiftUI

/// The Emergency Pass — a full screen (not a sheet) that hands the user a
/// printed "pass" they hold to redeem, unlocking Distracting apps for an hour,
/// once a week. Redeeming slams a red REDEEMED stamp onto the pass; the stamped
/// pass then IS the used state, so reopening later in the week shows the same
/// pass with its reset countdown rather than a separate screen.
///
/// Light ground, receipt-paper pass (the store receipt's mono type and barcode),
/// a live self-mirror in the FaceTime-style window the interventions use, and
/// the Aura icon as the issuing seal.
struct EmergencyUnlockView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Redeemed: the stamp is on and the footer shows the reset countdown.
    @State private var used = false
    @State private var sway = false
    @State private var stampScale: CGFloat = 1.6
    @State private var stampOpacity: Double = 0
    @State private var jolt: CGFloat = 0

    var body: some View {
        ZStack {
            // The day/night pass backdrop, filling the screen.
            Image(HomeDaylight.isDay() ? "EmergencyPassDay" : "EmergencyPassNight")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer(minLength: 0)

                EmergencyPassCard(stampScale: stampScale, stampOpacity: stampOpacity)
                    .rotationEffect(.degrees((sway ? 2 : -2) + jolt))

                Spacer(minLength: 0)

                TimelineView(.periodic(from: .now, by: 60)) { timeline in
                    footer(at: timeline.date)
                        .onChange(of: timeline.date) { _, date in
                            guard !store.emergencyUnlockIsUsed(at: date) else { return }
                            used = false
                            stampOpacity = 0
                            stampScale = 1.6
                        }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .onAppear {
            if store.emergencyUnlockIsUsed(at: .now) {
                used = true
                stampScale = 1
                stampOpacity = 1
            }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
                sway = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Image("AuraLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: 64)

            HStack {
                Spacer()
                CircleIconButton(symbol: "xmark", fill: LightSheet.chromeOnBlue,
                                 glyphColor: .white, bounces: false) { dismiss() }
            }
        }
        .frame(height: 64)
    }

    // MARK: - Footer

    @ViewBuilder
    private func footer(at date: Date) -> some View {
        if used && store.emergencyUnlockIsUsed(at: date) {
            VStack(spacing: Theme.Spacing.s) {
                Text("Pass redeemed")
                    .auraFont(.display, SheetType.title, .bold)
                    .foregroundStyle(.white)

                Text("Resets in \(countdown(to: store.emergencyUnlockResetAt ?? date, from: date))")
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.top, Theme.Spacing.l)
        } else {
            VStack(spacing: Theme.Spacing.m) {
                HoldToConfirmButton(
                    tint: LightSheet.danger,
                    idleCaption: "Hold to Redeem",
                    holdingCaption: "Keep Holding…",
                    doneCaption: "Apps Unlocked",
                    idleCaptionColor: .white,
                    captionWeight: .bold,
                    captionShadow: true,
                    trackColor: .white.opacity(0.35),
                    duration: 2
                ) { redeem() }

                Text("Unlock your Distracting apps for one hour. Once a week.")
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
            }
        }
    }

    // MARK: - Redeem

    private func redeem() {
        guard store.useEmergencyUnlock() else { return }
        Haptics.impact(.medium)

        if reduceMotion {
            stampScale = 1
            stampOpacity = 1
        } else {
            // The stamp slams down: big and clear, settling with a bounce.
            withAnimation(.spring(response: 0.28, dampingFraction: 0.5)) {
                stampScale = 1
                stampOpacity = 1
            }
            // A quick jolt on the pass, as if the stamp landed on it.
            withAnimation(.spring(response: 0.16, dampingFraction: 0.4)) { jolt = 2 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { jolt = 0 }
            }
        }

        // A beat on the button's own "Apps Unlocked" state before the footer
        // swaps to the reset countdown.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 0.3)) { used = true }
        }
    }

    // MARK: - Reset date

    private func countdown(to resetDate: Date, from now: Date) -> String {
        let remaining = max(0, resetDate.timeIntervalSince(now))
        let days = Int(remaining) / 86400
        let hours = (Int(remaining) % 86400) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}

// MARK: - The pass

private struct EmergencyPassCard: View {
    var stampScale: CGFloat
    var stampOpacity: Double

    /// Height of the tear-off stub below the perforation — where the notches sit.
    private let stubHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {
            // The main pass.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EMERGENCY\nPASS")
                            .font(PassInk.mono(22, .heavy))
                            .foregroundStyle(PassInk.dark)
                            .fixedSize()

                        HStack(spacing: 5) {
                            seal
                            Text("ISSUED BY AURA")
                                .font(PassInk.mono(9))
                                .foregroundStyle(PassInk.faded)
                        }
                    }

                    Spacer(minLength: 0)

                    mirror
                }
                .padding(.bottom, Theme.Spacing.l)

                PassRule(dashed: true)

                fieldRow("GOOD FOR", "ONE HOUR")
                fieldRow("UNLOCKS", "DISTRACTING APPS")
                fieldRow("RESETS", "ONCE A WEEK")

                PassRule(dashed: true)
                    .padding(.top, Theme.Spacing.xs)

                Text("No judgment. Use it when you need it.")
                    .font(PassInk.mono(9))
                    .foregroundStyle(PassInk.faded)
                    .frame(maxWidth: .infinity)
                    .padding(.top, Theme.Spacing.m)
            }
            .padding(Theme.Spacing.l)

            // The tear-off stub, below the perforation and the side notches.
            VStack(spacing: 0) {
                PassRule(dashed: true)
                    .padding(.horizontal, Theme.Spacing.l)
                PassBarcode(seed: 20260820)
                    .frame(height: 34)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.m)
            }
            .frame(height: stubHeight, alignment: .top)
        }
        .background(
            TicketShape(stubHeight: stubHeight)
                .fill(LinearGradient(colors: [.white, PassInk.paperEdge],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(
                    TicketShape(stubHeight: stubHeight)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.14), radius: 4, y: 2)
                .shadow(color: .black.opacity(0.12), radius: 22, y: 12)
        )
        // Over the main pass, not the stub.
        .overlay { stamp.offset(y: -stubHeight / 2) }
        .padding(.horizontal, Theme.Spacing.s)
    }

    /// The actual Aura app icon as the issuing seal, lifted off the paper with a
    /// soft shadow.
    private var seal: some View {
        Image("AuraAppIcon")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 20, height: 20)
            .clipShape(RoundedRectangle(cornerRadius: 20 * LightSheet.iconCornerRatio,
                                        style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 3, y: 1.5)
    }

    /// The live self-mirror, in the interventions' FaceTime PiP shape.
    private var mirror: some View {
        SelfMirrorCameraView()
            .frame(width: 60, height: 60 * 4 / 3)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(PassInk.dark.opacity(0.25), lineWidth: 1.5)
            )
    }

    private func fieldRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(PassInk.mono(10))
                .foregroundStyle(PassInk.faded)
            Spacer(minLength: Theme.Spacing.m)
            Text(value)
                .font(PassInk.mono(11, .bold))
                .foregroundStyle(PassInk.dark)
        }
        .padding(.vertical, 5)
    }

    private var stamp: some View {
        Text("REDEEMED")
            .auraFont(.display, 30, .heavy)
            .foregroundStyle(LightSheet.danger)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LightSheet.danger, lineWidth: 3)
            )
            .rotationEffect(.degrees(-15))
            .scaleEffect(stampScale)
            .opacity(stampOpacity)
    }
}

// MARK: - Receipt-paper helpers (the store receipt's own type + barcode)

private enum PassInk {
    static let dark = LightSheet.title
    static let faded = Color(hex: "8A8A92")
    static let paperEdge = Color(hex: "F4F4F2")

    /// SF Mono — the same fixed pitch the Screentime Store receipt uses, which is
    /// most of what reads as "printed".
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// A boarding-pass outline: a rounded rectangle with a semicircular notch cut
/// into the left and right edges at the perforation line, `stubHeight` up from
/// the bottom. Both fill and stroke follow it, so the paper and its hairline
/// share the notched edge.
private struct TicketShape: Shape {
    var corner: CGFloat = 22
    var notchRadius: CGFloat = 13
    /// Distance from the bottom edge to the notch centre.
    var stubHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let notchY = rect.maxY - stubHeight
        var p = Path()

        // Top edge, left to right.
        p.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)

        // Right edge down to the notch, cut inward, then on to the corner.
        p.addLine(to: CGPoint(x: rect.maxX, y: notchY - notchRadius))
        p.addArc(center: CGPoint(x: rect.maxX, y: notchY),
                 radius: notchRadius, startAngle: .degrees(270), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner),
                 radius: corner, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)

        // Bottom edge, right to left.
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner),
                 radius: corner, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)

        // Left edge up to the notch, cut inward, then on to the corner.
        p.addLine(to: CGPoint(x: rect.minX, y: notchY + notchRadius))
        p.addArc(center: CGPoint(x: rect.minX, y: notchY),
                 radius: notchRadius, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)

        p.closeSubpath()
        return p
    }
}

/// A hairline across the full width, dashed for line items.
private struct PassRule: View {
    var dashed: Bool
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 1)
            .overlay(
                Path { p in
                    p.move(to: .zero)
                    p.addLine(to: CGPoint(x: 10_000, y: 0))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 3] : []))
                .foregroundStyle(Color.black.opacity(0.22))
            )
            .clipped()
    }
}

/// Decorative barcode, seeded so it draws the same bars every layout.
private struct PassBarcode: View {
    let seed: Int
    var body: some View {
        Canvas { context, size in
            var value = UInt64(bitPattern: Int64(seed)) | 1
            var x: CGFloat = 0
            while x < size.width {
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
    EmergencyUnlockView()
        .environment(HabitStore())
}
