//
//  ScreentimeStoreView.swift
//  Aura iOS
//

import SwiftUI

/// The Scroll Bank — where earned Aura coins are spent for screen time
/// (1 coin = 1 minute). Opened from the Home "Scroll" card.
struct ScreentimeStoreView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// Opens on the cheapest option — the store shouldn't preselect a bigger
    /// spend than the user asked for.
    @State private var selectedMinutes = 5
    @State private var receipt: ScrollReceipt?
    @State private var checkingOut = false
    @State private var showAmountSheet = false
    /// Set once the paper and button have left. Everything stops drawing, so
    /// the cover slides away over an empty field instead of revealing the
    /// checkout that was sitting behind the receipt.
    @State private var blankOut = false
    /// A past purchase re-opened from the list. Separate from `receipt`, which
    /// is the one that prints at the end of a checkout.
    @State private var pastReceipt: ScrollReceipt?

    // MARK: Checkout
    //
    // Checkout happens in place rather than in another sheet: the store's own
    // chrome slides away, the reader drops in from above, and the card stays put
    // and simply moves. A sheet would cross-fade the card into a copy of itself.
    private enum Phase { case waiting, authorizing, done }
    @State private var phase: Phase = .waiting
    @State private var drag: CGFloat = 0
    @State private var spin: Double = 0
    /// Set the moment the checkmark lands, which fires the burst.
    @State private var passedThreshold = false
    @State private var dots = 0
    @State private var dotTimer: Timer?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How far up the card has to travel before it counts as tapped.
    private let reachDistance: CGFloat = 150
    /// Disc and resting-card frames, measured in the checkout coordinate space.
    /// The landing offset is derived from these rather than guessed: an offset
    /// doesn't affect layout, so any hardcoded number drifts the moment the
    /// spacing above the card changes.
    @State private var discFrame: CGRect = .zero
    @State private var cardFrame: CGRect = .zero
    /// The card's centre with no drag and no scale on it, captured once the
    /// checkout layout has settled.
    @State private var restingCardMidY: CGFloat = 0

    /// The offset that puts the card's center on the disc's.
    ///
    /// Measured from the card at rest *in the checkout layout*. Mid-drag the
    /// card is also being scaled by `proximity`, and the reported frame carries
    /// that transform, so back-computing a resting position from it lands
    /// 14pt differently depending on how far you swiped. The disc's own midY
    /// is rock steady at 185 either way.
    private var landedOffset: CGFloat {
        guard discFrame != .zero, restingCardMidY != 0 else { return 0 }
        // Divided by the scale because the offset is applied inside it: at
        // landing the card is at 0.92, so an offset of X only travels X * 0.92
        // on screen. Measured — 185 - 584.32 = -399.32 of travel needs -434 of
        // offset, which is exactly the one swipe that used to land right.
        return (discFrame.midY - restingCardMidY) / landingScale + landingTrim
    }

    /// The card's scale at the moment it lands: `proximity` is 1 by then.
    private var landingScale: CGFloat { 1 - 0.08 }

    /// Residual trim, in points. Negative sits the card higher on the disc.
    private let landingTrim: CGFloat = 0
    private let discSize: CGFloat = 176

    private func closePastReceipt() {
        Haptics.impact(.light)
        withAnimation(.easeInOut(duration: 0.32)) { pastReceipt = nil }
    }

    /// 0…1 as the card closes on the disc, so the reader reacts to the card
    /// approaching instead of waiting for contact.
    private var proximity: CGFloat { min(1, max(0, -drag / reachDistance)) }

    // The Blocks-screen surface. White cards need a tinted ground to sit on,
    // or their drop edges read as a stray smudge.
    // The page is the button's blue, so everything that used to be dark on
    // light inverts: white chrome, white reader, blue glyph inside it.
    private let sheetColor = LightSheet.blue

    var body: some View {
        VStack(spacing: 0) {

            if !checkingOut && !blankOut {
                header
                    .padding(.top, Theme.Spacing.l)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if checkingOut && receipt == nil && !blankOut {
                VStack(spacing: 0) {
                    reader
                    amount
                        .padding(.top, Theme.Spacing.xl)
                        // Holds through authorizing — the cost is still the
                        // relevant number until the payment actually lands —
                        // then goes on the same curve as the caption below it.
                        .opacity(phase == .done ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: phase)
                    caption
                        .padding(.top, Theme.Spacing.s)
                }
                .padding(.top, Theme.Spacing.xxl + Theme.Spacing.xxxl)
                .transition(.opacity)

                Spacer(minLength: Theme.Spacing.xxxl + Theme.Spacing.xl)
            }

            // Never conditional: the card is the one thing both layouts share,
            // so it moves between positions instead of being torn down and
            // rebuilt somewhere else.
            card
                .opacity(receipt == nil && !blankOut ? 1 : 0)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, checkingOut ? 0 : Theme.Spacing.xxl)
                .offset(y: drag)
                .scaleEffect(1 - proximity * 0.08)
                .opacity(phase == .done ? 0 : 1)
                .gesture(cardSwipe)

            if !checkingOut && !blankOut {
                transactionsPanel
                    .padding(.top, Theme.Spacing.xxl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if checkingOut && receipt == nil && !blankOut {
                nevermindButton
                    .padding(.top, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xxl)
                    .opacity(phase == .waiting ? 1 : 0)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "checkout")
        .onPreferenceChange(DiscFrameKey.self) { discFrame = $0 }
        .onPreferenceChange(AuraCardFrameKey.self) { frame in
            cardFrame = frame
            // Only in checkout, and only while it's home: before checkout the
            // card sits somewhere else entirely, and mid-drag it's scaled.
            if checkingOut, drag == 0 { restingCardMidY = frame.midY }
        }
        .background(sheetColor.ignoresSafeArea())
        .sheet(isPresented: $showAmountSheet) {
            BuyScreentimeSheet { minutes in
                selectedMinutes = minutes
                // Same frame the sheet starts dropping on, so the card is
                // already sliding into its swipe-up position behind it.
                withAnimation(.snappy(duration: 0.45)) { checkingOut = true }
            }
        }
        .overlay {
            if pastReceipt != nil {
                // Dims the store behind a re-opened receipt. The fresh one
                // doesn't need this — it prints over its own checkout, which
                // is already the whole screen.
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { closePastReceipt() }
                    .zIndex(1)
            }

            if let pastReceipt {
                ReceiptPreviewView(receipt: pastReceipt) { closePastReceipt() }
                    // Leaves the way it came in.
                    .transition(.move(edge: .top))
                    .zIndex(2)
            }
        }
        // An overlay rather than a cover: a cover always slides up from the
        // bottom, and the receipt should print downward from the top.
        .overlay {
            if let receipt {
                ScrollReceiptView(receipt: receipt) {
                    Haptics.impact(.medium)
                    // The clock starts here, not at payment — nobody's minutes
                    // should be draining while they read the receipt.
                    store.startPurchasedScreenTime(minutes: selectedMinutes)
                    // Pull the paper out of the hierarchy before dismissing. It
                    // has already slid off screen, so removing it is invisible
                    // — and leaving it mounted lets it come back as a fresh
                    // instance mid-dismissal and replay its entrance.
                    var instant = Transaction()
                    instant.disablesAnimations = true
                    withTransaction(instant) {
                        blankOut = true
                        self.receipt = nil
                    }
                    dismiss()
                }
                .transition(.move(edge: .top))
            }
        }
    }

    // MARK: - Checkout

    private var reader: some View {
        ZStack {
            // Two pings on the same 2.4s cycle, the second half a cycle late so
            // a new ring leaves as the last one fades.
            //
            // Driven off the timeline rather than `repeatForever`: a repeating
            // animation started in `onAppear` gets cancelled by any other
            // transaction touching this view — the drag, the phase change, the
            // dots timer — and never restarts. Derived from elapsed time it
            // can't be interrupted.
            if !reduceMotion, phase == .waiting {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        sonarRing(progress: ringProgress(t, offset: 0))
                        sonarRing(progress: ringProgress(t, offset: 0.5))
                    }
                }
            }

            // The resting halo the pings leave behind. Widens as the card
            // closes in, then holds while authorizing.
            //
            // This is the frame the card lands on: it's the outer edge you can
            // actually see, so centring on it is centring on what's on screen.
            // Measured before the scale so the target doesn't move as the card
            // approaches and grows it.
            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: discSize + 34, height: discSize + 34)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: DiscFrameKey.self,
                            value: proxy.frame(in: .named("checkout"))
                        )
                    }
                )
                .scaleEffect(1 + proximity * 0.10)

            Circle()
                .fill(.white)
                .frame(width: discSize, height: discSize)
                .shadow(color: .black.opacity(0.18), radius: 22, y: 10)

            switch phase {
            case .waiting:
                // Template + tint: the artwork is a flat silhouette, so the
                // colour belongs in code rather than in a second export.
                Image("AuraTapToPay")
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(LightSheet.blue)
                    .frame(width: discSize * 0.52)

            case .authorizing:
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(LightSheet.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: discSize * 0.42, height: discSize * 0.42)
                    .rotationEffect(.degrees(spin))
                    .onAppear {
                        withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
                            spin = 360
                        }
                    }

            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: 62, weight: .bold))
                    .foregroundStyle(LightSheet.blue)
            }
        }
        .animation(.snappy(duration: 0.25), value: phase)
    }

    /// 0…1 through one 2.4s ping, `offset` staggering the second ring.
    private func ringProgress(_ time: TimeInterval, offset: Double) -> Double {
        let cycle = 2.4
        return ((time / cycle) + offset).truncatingRemainder(dividingBy: 1)
    }

    private func sonarRing(progress: Double) -> some View {
        // Eased out so it leaves quickly and drifts to a stop, and faded to
        // nothing at the peak so the loop point is invisible.
        let eased = 1 - pow(1 - progress, 3)
        return Circle()
            .fill(.white.opacity(0.22))
            .frame(width: discSize + 34, height: discSize + 34)
            .scaleEffect(1 + 0.55 * eased)
            .opacity(0.4 * (1 - eased))
    }

    private var caption: some View {
        HStack(spacing: 0) {
            Text(captionText)
            if phase == .authorizing {
                // All three dots hold their space, so the line doesn't shuffle
                // sideways as they light up one at a time.
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { i in
                        Text(".").opacity(dots > i ? 1 : 0)
                    }
                }
                .animation(.easeInOut(duration: 0.15), value: dots)
            }
        }
        .auraFont(.body, SheetType.cardTitle, .semibold)
        .foregroundStyle(.white)
        .opacity(phase == .done ? 0 : 1)
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    private var captionText: String {
        switch phase {
        case .waiting:     return "Swipe your card up to pay"
        case .authorizing: return "Authorizing payment"
        // Kept, not blanked: the line fades out on `.done`, and emptying the
        // string would clear it before the fade could run.
        case .done:        return "Authorizing payment"
        }
    }

    /// What it costs, between the reader and the instruction. No "Total" label
    /// — the coin says what the number is.
    private var amount: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image("AuraCoinIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 36, height: 36)
            Text("\(selectedMinutes)")
                .auraFont(.display, 38, .bold)
                .foregroundStyle(.white)
        }
    }

    private var nevermindButton: some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.snappy(duration: 0.45)) {
                checkingOut = false
                drag = 0
            }
        } label: {
            Text("Nevermind")
                .auraFont(.body, 15, .bold)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, Theme.Spacing.s)
                .padding(.horizontal, Theme.Spacing.l)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var cardSwipe: some Gesture {
        DragGesture()
            .onChanged { value in
                guard checkingOut, phase == .waiting else { return }
                if drag == 0 { Haptics.impact(.light, intensity: 0.7) }
                // Upward only — dragging back down just returns to rest.
                drag = min(0, value.translation.height)

                // A detent at the threshold, so releasing-will-work is
                // something the hand knows rather than something to guess.
                let past = -drag >= reachDistance
                if past != passedThreshold {
                    passedThreshold = past
                    if past { Haptics.impact(.rigid, intensity: 0.8) }
                }
            }
            .onEnded { _ in
                guard checkingOut, phase == .waiting else { return }
                passedThreshold = false
                if -drag >= reachDistance {
                    tap()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { drag = 0 }
                }
            }
    }

    /// Card lands on the reader, authorizes, then prints the receipt. The swipe
    /// is the commit — backing out of checkout costs nothing.
    private func tap() {
        // Up onto the disc, held there while it authorizes, then back down to
        // where it started.
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { drag = landedOffset }
        withAnimation(.snappy(duration: 0.25).delay(0.3)) { phase = .authorizing }

        // Contact lands with the card, not with the finger lifting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            Haptics.transient(intensity: 0.9, sharpness: 0.7)
            // The hum under the spinner — the one thing UIKit's generators
            // can't do, and the reason the pause doesn't feel like a stall.
            Haptics.startRumble(intensity: 0.22, sharpness: 0.1, duration: 1.8)
        }

        dots = 0
        dotTimer?.invalidate()
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
            dots = (dots + 1) % 4
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { drag = 0 }

            guard store.chargeForScreenTime(minutes: selectedMinutes) else {
                Haptics.stopRumble()
                Haptics.notify(.error)
                withAnimation(.snappy(duration: 0.3)) {
                    checkingOut = false
                    drag = 0
                    phase = .waiting
                }
                return
            }
            dotTimer?.invalidate()
            dotTimer = nil
            Haptics.stopRumble()
            // Checkmark once the card is clear of the disc.
            withAnimation(.snappy(duration: 0.25).delay(0.3)) { phase = .done }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Haptics.notify(.success) }

            // A beat on the checkmark so the payment reads as settled before
            // the paper starts printing over it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Slow enough to watch the paper travel — a quick slide reads
                // as a screen swap rather than something printing.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    Haptics.impact(.soft)
                }
                withAnimation(.spring(response: 0.85, dampingFraction: 0.88)) {
                    receipt = ScrollReceipt(
                        name: store.displayName,
                        minutes: selectedMinutes,
                        coins: selectedMinutes,
                        date: .now
                    )
                }
                // Checkout stays up behind the paper. Resetting here would
                // rebuild the store's picker and button underneath it, which
                // shows through as the receipt slides down.
            }
        }
    }

    // MARK: - Header

    /// The balance IS the header.
    ///
    /// It was a row of its own under a "Screentime Store" title, which put four
    /// things — title, X, `?`, balance — in the top third before the card. The
    /// title was the one confirming something you already knew: you opened this
    /// from the Scroll card. Dropping it gives the balance the empty middle of a
    /// row that already existed.
    private var header: some View {
        ZStack {
            balanceLine

            // X left, `?` right — the pairing every quest screen uses, so help
            // is in the same corner wherever you are.
            HStack {
                closeButton
                Spacer()
                ExplainerButton(explainer: QuestExplainer.coins, onBlue: true)
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
    }

    private var closeButton: some View {
        CircleIconButton(symbol: "xmark", fill: LightSheet.chromeOnBlue,
                         glyphColor: .white, bounces: false) { dismiss() }
    }

    // MARK: - Card

    private var card: some View {
        AuraBankCard(cardholder: "Hayden Berio", measureIn: "checkout")
    }

    /// The balance, on the field rather than in a card.
    ///
    /// It had its own white card directly under the payment card — two
    /// card-shaped objects stacked, and the plain one was competing with the
    /// thing the screen is actually about. As a line on the blue it costs no
    /// shape at all, and the card gets to be the only card here.
    private var balanceLine: some View {
        HStack(spacing: Theme.Spacing.s) {
            Image("AuraCoinIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: Self.balanceCoin, height: Self.balanceCoin)
            Text("\(store.coinBalance)")
                .auraFont(.display, Self.balanceFigure, .bold)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
        }
    }

    /// The balance is context above the card, not the headline of the screen —
    /// it took Stats' 34pt figure and read as the loudest thing here. The coin
    /// is derived from the numeral so the two can't drift.
    private static let balanceFigure = SheetType.title
    private static let balanceCoin = balanceFigure * 1.2

    // MARK: - Recent transactions

    /// Fills the bottom of the screen: rows scroll inside it, the CTA sits at
    /// its foot. Today only — this is a running tally of what you've spent
    /// since midnight, not an archive.
    private var transactionsPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Recent Transactions")
                .auraFont(.display, 17, .bold)
                .foregroundStyle(SheetType.titleColor)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.xl)

            // The empty state skips the scroll view entirely. A `ScrollView`
            // sizes itself to its content, so anything inside it can't centre in
            // the panel — it can only sit at the top of a box its own height.
            if todaysPurchases.isEmpty {
                transactions
                    .padding(.horizontal, Theme.Spacing.xl)
            } else {
                ScrollView(showsIndicators: false) {
                    transactions
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.bottom, Theme.Spacing.l)
                }
            }

            buyButton
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: Theme.Radius.sheet, topTrailingRadius: Theme.Radius.sheet, style: .continuous)
                .fill(Color.white)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    /// Purchases made today, newest first.
    private var todaysPurchases: [HabitStore.Purchase] {
        store.purchases.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var transactions: some View {
        VStack(spacing: Theme.Spacing.s) {
            if todaysPurchases.isEmpty {
                // Same shape as the habit list's empty state: art at 86, a bold
                // line, a quiet one under it.
                VStack(spacing: Theme.Spacing.m) {
                    Image("ScreentimeStoreEmptyState")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(height: 132)
                        .shadow(color: .black.opacity(0.16), radius: 12, y: 5)

                    VStack(spacing: Theme.Spacing.xs) {
                        Text("No purchases today")
                            .auraFont(.display, SheetType.sectionHeader, .bold)
                            .foregroundStyle(SheetType.titleColor)
                        Text("Screentime you buy shows up here.")
                            .auraFont(.body, SheetType.subtitle, .regular)
                            .foregroundStyle(SheetType.subtitleColor)
                    }
                    .multilineTextAlignment(.center)
                }
                // Centred in what's left under the heading rather than sitting
                // just below it — an empty state pinned to the top of a tall
                // panel reads as content that failed to load.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(todaysPurchases) { purchase in
                    transactionRow(purchase)
                }
            }
        }
    }

    private func transactionRow(_ purchase: HabitStore.Purchase) -> some View {
        Button {
            Haptics.impact(.light)
            pastReceipt = ScrollReceipt(
                name: store.displayName,
                minutes: purchase.minutes,
                coins: purchase.minutes,
                date: purchase.date
            )
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                receiptThumb

                VStack(alignment: .leading, spacing: RowType.labelGap) {
                    Text(FocusDuration.label(purchase.minutes))
                        .auraFont(.body, RowType.label, .semibold)
                        .foregroundStyle(RowType.labelColor)
                    Text(Self.stamp.string(from: purchase.date))
                        .auraFont(.body, RowType.subLabel, .medium)
                        .foregroundStyle(LightSheet.subtitle)
                }

                Spacer(minLength: Theme.Spacing.s)

                // Signed, because this is the one list in the app where the
                // number goes down.
                HStack(spacing: 4) {
                    Image("AuraCoinIcon")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                    // Keeps the red — it's the one list where the number goes
                    // down — but drops to the row scale's weight and size.
                    Text("-\(purchase.minutes)")
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(LightSheet.danger)
                }
            }
            .padding(Theme.Spacing.m)
            .contentShape(Rectangle())
            // A plain white card, like every other row in the app. The store's
            // page is blue, so it takes the on-colour drop edge the habit rows
            // use rather than the translucent one meant for a white ground.
            .bottomDropCard(radius: Theme.Radius.card, shade: LightSheet.whiteShadeOnColour)
        }
        .buttonStyle(PressBounceStyle())
    }

    /// The receipt itself, shrunk to a marker: the same torn shape as the real
    /// one with a few ruled lines. Says what tapping the row will give you.
    private var receiptThumb: some View {
        Image("ScreentimeStoreReceipt")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            // Contour + shadow are baked into the sticker now.
            .frame(height: 40)
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    private var buyButton: some View {
        Button {
            Haptics.impact(.medium)
            showAmountSheet = true
        } label: {
            Text("Buy Screentime")
                .font(SheetType.ctaFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .blueDropCapsule()
        }
        .buttonStyle(.plain)
    }
}

/// Both keys ignore empty values when reducing. Every sibling that doesn't set
/// the key still contributes `defaultValue`, so a plain `value = nextValue()`
/// lets the last sibling wipe out the one measurement that mattered.
private struct DiscFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
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
