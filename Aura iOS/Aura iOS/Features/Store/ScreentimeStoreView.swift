//
//  ScreentimeStoreView.swift
//  Aura iOS
//

import SwiftUI

/// Spend earned Aura coins on screen time, then hand off its count-up to Home.
struct ScreentimeStoreView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpending = false
    @State private var showPurchaseError = false
    @State private var spendProgress: CGFloat = 0
    @State private var balanceBeforeSpend = 0
    /// Zero leaves all durations unselected until the user chooses one.
    @State private var selectedMinutes = 0
    @State private var hasSelection = false

    // Illustration palette: deliberately darker blue under the top-down light.
    private enum StoreArt {
        static let blue = Color(red: 0.025, green: 0.31, blue: 0.72)
        static let lowerBlue = Color(red: 0.015, green: 0.23, blue: 0.58)
        static let cyanLight = Color(red: 0.37, green: 0.82, blue: 1)
        static let banner = Color(red: 0.035, green: 0.15, blue: 0.37)
        static let foxOpacity = 0.11
        static let patternPeriod: Double = 40
        static let bannerHeight: CGFloat = 38
    }

    var body: some View {
        storeFront
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(!isSpending)
        .alert("Couldn't save your purchase", isPresented: $showPurchaseError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your coins haven't been spent. Try again.")
        }
        .onAppear {
            if store.pendingScreenTimePurchase != nil {
                balanceBeforeSpend = store.coinBalance
                isSpending = true
            }
        }
        .task(id: "\(isSpending)-\(scenePhase == .active)") {
            guard isSpending, scenePhase == .active else { return }
            await finishSpendAnimation()
        }
        .background(LightSheet.blue.ignoresSafeArea())
    }

    private var storeFront: some View {
        GeometryReader { proxy in
            let heroHeight = min(220, max(170, proxy.size.height * 0.25))
            let artHeight = min(112, max(94, (proxy.size.width - 48) / 3 * 0.90))
            ZStack {
                storeBackground
                foxPattern
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        storeHeader
                            .padding(.top, Theme.Spacing.l)
                            .zIndex(1)

                        ZStack {
                            chestGlow(heroHeight: heroHeight)
                            floatingChest(heroHeight: heroHeight)
                        }
                        .frame(height: heroHeight)
                        .padding(.top, Theme.Spacing.s)

                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            SpendBalanceReel(
                                from: isSpending ? balanceBeforeSpend : store.coinBalance,
                                to: store.coinBalance,
                                progress: isSpending ? spendProgress : 0)
                            StrokedNumber(
                                text: "coins",
                                font: Typography.displayUIFont(size: 30, weight: .black),
                                fill: .black, stroke: .white, outlineWidth: 2)
                        }
                        .padding(.top, Theme.Spacing.xl)

                        durationGrid(artHeight: artHeight)
                            .padding(.top, Theme.Spacing.xxl)
                            .padding(.horizontal, Theme.Spacing.l)
                            .padding(.bottom, Theme.Spacing.l)
                    }
                    .frame(maxWidth: .infinity)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    LightPrimaryButton(
                        title: "Buy Screentime",
                        coins: hasSelection ? selectedMinutes : nil,
                        face: .white,
                        textColor: .black,
                        shade: LightSheet.whiteShadeOnColour,
                        enabled: hasSelection && selectedMinutes <= store.coinBalance,
                        depth: 6,
                        action: buySelectedTime)
                    .padding(.horizontal, Theme.Spacing.l)
                    .padding(.top, Theme.Spacing.m)
                    .padding(.bottom, Theme.Spacing.l)
                }
            }
        }
    }

    private var storeBackground: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LinearGradient(colors: [StoreArt.blue, StoreArt.lowerBlue],
                               startPoint: .top, endPoint: .bottom)
                Ellipse()
                    .fill(RadialGradient(
                        colors: [StoreArt.cyanLight.opacity(0.65), StoreArt.cyanLight.opacity(0.23), .clear],
                        center: .top, startRadius: 0, endRadius: proxy.size.height * 0.72))
                    .frame(width: proxy.size.width * 1.55, height: proxy.size.height * 1.25)
                    .position(x: proxy.size.width * 0.5, y: proxy.size.height * 0.25)
            }
            // Keep oversized illumination inside the moving cover during its
            // presentation and dismissal; it must never paint over Home.
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var storeHeader: some View {
        HStack {
            closeButton
            Spacer()
            ExplainerButton(explainer: QuestExplainer.coins, onBlue: true)
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private func chestGlow(heroHeight: CGFloat) -> some View {
        // Match the approved 1040×1400 preview: its chest occupies a 732pt
        // frame centered at y826, and the lowered ring is centered at y1160.
        let lightingHeight = heroHeight * 1400 / 732 * 1.15
        let lightingWidth = heroHeight * 1040 / 732 * 1.30
        let ringCenter = heroHeight * (1160 - 826) / 732
        let verticalOffset = ringCenter - lightingHeight * (1160.0 / 1400 - 0.5)
        return TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let brightness = reduceMotion ? 1 : 0.96 + sin(time * 1.2) * 0.04
            Image("AuraStoreChestLightingB")
                .resizable()
                .interpolation(.high)
                .frame(width: lightingWidth, height: lightingHeight)
                .mask {
                    // A broad eased feather avoids a visible straight boundary
                    // where the bright PNG meets the blue screen.
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.02), location: 0.04),
                        .init(color: .white.opacity(0.10), location: 0.08),
                        .init(color: .white.opacity(0.26), location: 0.12),
                        .init(color: .white.opacity(0.50), location: 0.18),
                        .init(color: .white.opacity(0.76), location: 0.24),
                        .init(color: .white.opacity(0.94), location: 0.30),
                        .init(color: .white, location: 0.36),
                        .init(color: .white, location: 0.64),
                        .init(color: .white.opacity(0.94), location: 0.70),
                        .init(color: .white.opacity(0.76), location: 0.76),
                        .init(color: .white.opacity(0.50), location: 0.82),
                        .init(color: .white.opacity(0.26), location: 0.88),
                        .init(color: .white.opacity(0.10), location: 0.92),
                        .init(color: .white.opacity(0.02), location: 0.96),
                        .init(color: .clear, location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                }
                .mask {
                    // Preserve the ring, then ease the remaining bloom to
                    // transparent before the bitmap's lower boundary.
                    LinearGradient(stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.88),
                        .init(color: .white.opacity(0.85), location: 0.91),
                        .init(color: .white.opacity(0.50), location: 0.94),
                        .init(color: .white.opacity(0.15), location: 0.97),
                        .init(color: .clear, location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
                .opacity(brightness)
                .offset(y: verticalOffset)
        }
        .frame(width: lightingWidth, height: heroHeight)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func floatingChest(heroHeight: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate * .pi / 2
            let bob = reduceMotion ? 0 : sin(phase) * 3
            ZStack {
                Image("AuraStoreOpenChest")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: heroHeight)
                heroStars(heroHeight: heroHeight)
            }
            .offset(y: Theme.Spacing.xs + bob)
        }
    }

    private func heroStars(heroHeight: CGFloat) -> some View {
        let placements: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (-0.64, -0.32, 24, 0.0), (-0.39, -0.49, 20, 0.7),
            (0.40, -0.49, 18, 1.4), (0.64, -0.18, 22, 2.1),
            (-0.64, 0.22, 20, 2.8), (0.64, 0.38, 24, 3.5)
        ]
        return ZStack {
            ForEach(0..<placements.count, id: \.self) { index in
                let item = placements[index]
                IceSparkle(size: item.2, delay: item.3)
                    .colorMultiply(LightSheet.starGold)
                    .offset(x: item.0 * heroHeight, y: item.1 * heroHeight)
            }
        }
        .allowsHitTesting(false)
    }

    private var foxPattern: some View {
        GeometryReader { proxy in
            let pitch = proxy.size.width / 6
            let rowPitch = pitch * 1.32
            let rows = Int(ceil(proxy.size.height / rowPitch)) + 4
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                // A two-row translation returns the staggered lattice to itself.
                let progress = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: StoreArt.patternPeriod) / StoreArt.patternPeriod
                ZStack {
                    ForEach(-2..<rows, id: \.self) { row in
                        ForEach(-2..<9, id: \.self) { column in
                            Image("NavHomeSticker")
                                .renderingMode(.original)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .saturation(0)
                                .frame(width: pitch * 0.56, height: pitch * 0.56)
                                .rotationEffect(.degrees(15))
                                .position(
                                    x: (CGFloat(column) + (row.isMultiple(of: 2) ? 0.25 : 0.75)) * pitch - progress * pitch,
                                    y: CGFloat(row) * rowPitch + progress * rowPitch * 2)
                        }
                    }
                }
                .opacity(StoreArt.foxOpacity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func durationGrid(artHeight: CGFloat) -> some View {
        let options = [5, 10, 15, 30, 45, 60]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 3), spacing: Theme.Spacing.s) {
            ForEach(options, id: \.self) { minutes in
                let selected = hasSelection && selectedMinutes == minutes
                Button {
                    guard minutes <= store.coinBalance else { return }
                    Haptics.impact(.light)
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.55)) {
                        selectedMinutes = minutes
                        hasSelection = true
                    }
                } label: {
                    VStack(spacing: 0) {
                        durationArt(for: minutes)
                        .frame(maxWidth: .infinity)
                        .frame(height: artHeight)

                        ZStack {
                            Rectangle()
                                .fill(selected ? LightSheet.starGold : StoreArt.banner)
                            Text("\(minutes) min")
                                .auraFont(.body, SheetType.cardTitle, .bold)
                                .foregroundStyle(selected ? Theme.Color.background : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: StoreArt.bannerHeight)
                    }
                    // Keep the art field saturated so the hard cyan burst reads behind each pile.
                    .background(StoreArt.blue, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .strokeBorder(selected ? LightSheet.starGold : .white.opacity(0.45), lineWidth: selected ? 2 : 1)
                    }
                }
                .buttonStyle(PressBounceStyle())
                .disabled(minutes > store.coinBalance)
                .accessibilityLabel("\(minutes) minutes")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func durationArt(for minutes: Int) -> some View {
        GeometryReader { proxy in
            Image("AuraStoreCardRays")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .overlay {
                    Image("AuraStoreChoice\(minutes)")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: minutes == 45 ? proxy.size.width * 0.80 : proxy.size.width * coinPileScale(for: minutes) * 1.20,
                               height: minutes == 45 ? proxy.size.height - Theme.Spacing.m : (proxy.size.height - Theme.Spacing.s) * 1.20)
                }
                .overlay {
                    ZStack {
                        IceSparkle(size: 10, delay: 0.2)
                            .position(x: proxy.size.width * 0.15, y: proxy.size.height * 0.25)
                        IceSparkle(size: 8, delay: 0.6)
                            .position(x: proxy.size.width * 0.84, y: proxy.size.height * 0.20)
                        IceSparkle(size: 7, delay: 1.0)
                            .position(x: proxy.size.width * 0.87, y: proxy.size.height * 0.72)
                    }
                }
                .clipped()
        }
    }

    private func coinPileScale(for minutes: Int) -> CGFloat {
        switch minutes {
        case 5: return 0.78
        case 10: return 0.83
        case 15: return 0.87
        case 30: return 0.92
        case 45: return 0.97
        default: return 1
        }
    }

    private func buySelectedTime() {
        guard !isSpending, hasSelection, selectedMinutes > 0,
              selectedMinutes <= store.coinBalance else { return }
        balanceBeforeSpend = store.coinBalance
        guard store.beginPendingScreenTimePurchase(minutes: selectedMinutes) else {
            showPurchaseError = true
            Haptics.notify(.error)
            return
        }
        Haptics.impact(.medium)
        isSpending = true
    }

    @MainActor
    private func finishSpendAnimation() async {
        guard store.pendingScreenTimePurchase != nil else { return }
        spendProgress = 0
        do {
            try await Task.sleep(for: .milliseconds(20))
            try Task.checkCancellation()
        } catch { return }
        withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.70)) {
            spendProgress = 1
        }
        do {
            try await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 700))
            try Task.checkCancellation()
            guard scenePhase == .active else { return }
            NotificationCenter.default.post(name: .auraPurchasedTimeReady, object: nil)
            dismiss()
        } catch {
            // Payment stays durable. Resume the handoff when the scene returns.
        }
    }

    private var closeButton: some View {
        CircleIconButton(symbol: "xmark", fill: LightSheet.chromeOnBlue,
                         glyphColor: .white, bounces: false) { dismiss() }
    }

}

/// Local, outlined decimal reels. Payment is durable before this presentation;
/// only the displayed balance waits for its digits to settle.
private struct SpendBalanceReel: View {
    let from: Int
    let to: Int
    var progress: CGFloat

    private var font: UIFont { Typography.displayUIFont(size: 56, weight: .black, tabular: true) }
    private var glyphWidth: CGFloat { ("0" as NSString).size(withAttributes: [.font: font]).width + 6 }
    private var glyphHeight: CGFloat { font.lineHeight + 6 }

    var body: some View {
        let old = Array(String(from))
        let target = Array(String(repeating: " ", count: max(0, old.count - String(to).count)) + String(to))
        HStack(spacing: -6) {
            ForEach(old.indices, id: \.self) { index in
                let values = reel(from: old[index], to: target[index])
                VStack(spacing: 0) {
                    ForEach(values.indices, id: \.self) { row in
                        StrokedNumber(text: String(values[row]), font: font,
                                      fill: .black, stroke: .white, outlineWidth: 3)
                            .frame(width: glyphWidth, height: glyphHeight)
                    }
                }
                .offset(y: -progress * CGFloat(values.count - 1) * glyphHeight)
                .frame(width: glyphWidth, height: glyphHeight, alignment: .top)
                .clipped()
            }
        }
        .padding(.horizontal, 3)
        .accessibilityLabel("\(to)")
    }

    private func reel(from: Character, to: Character) -> [Character] {
        guard from != to else { return [from] }
        guard let start = from.wholeNumberValue, let end = to.wholeNumberValue else { return [from, to] }
        let steps = (start - end + 10) % 10
        return (0...steps).map { Character(String((start - $0 + 10) % 10)) }
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            ScreentimeStoreView()
                .environment(HabitStore())
        }
        .preferredColorScheme(.dark)
}
