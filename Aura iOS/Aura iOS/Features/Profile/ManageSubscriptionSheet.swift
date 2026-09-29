//
//  ManageSubscriptionSheet.swift
//  Aura iOS
//

import SwiftUI

/// Subscription management plus the cancel-feedback flow, opened from Settings.
/// Four steps in one sheet: the plan overview, why you're canceling, free text,
/// then a thank-you that hands off to the App Store's subscription page.
/// Nothing here cancels the subscription. Apple owns that screen; we only collect
/// the reason on the way out.
struct ManageSubscriptionSheet: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    enum Step { case overview, reason, details, thanks }

    @State private var step: Step = .overview
    @State private var reason: CancelReason?
    @State private var notes = ""
    @FocusState private var noteFocused: Bool

    private let noteLimit = 1000

    /// The identity this subscription is tied to: the account email, falling back
    /// to the display name, empty when neither is known (signed out).
    private var accountLabel: String {
        if !store.email.isEmpty { return store.email }
        return store.displayName
    }


    var body: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            switch step {
            case .overview: overview
            case .reason:   reasonStep
            case .details:  detailsStep
            case .thanks:   thanksStep
            }
        }
        .background(LightSheet.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .animation(.snappy(duration: 0.22), value: step)
        .onChange(of: step) { _, _ in
            // Clearing @FocusState alone doesn't resign the responder when the
            // field is torn down by the step switch, so the keyboard would
            // linger on the next step. Resign it directly.
            noteFocused = false
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
            )
        }
    }

    // MARK: - Chrome

    private func backButton(_ action: @escaping () -> Void) -> some View {
        HStack {
            CircleIconButton(symbol: "chevron.left", action: action)
            Spacer()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .auraFont(.display, SheetType.sectionHeader, .bold)
            .foregroundStyle(SheetType.titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, Theme.Spacing.l)
            .frame(maxWidth: .infinity)
            .bottomDropCard(radius: Theme.Radius.card)
    }

    /// The 34pt sticker that leads a row, matching Settings' nav rows.
    private func rowIcon(_ name: String) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 38, height: 38)
    }

    // MARK: - 1. Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            Text("Subscription")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(SheetType.titleColor)
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.l)

            // Label sits tight to its own card; the xl spacing above separates
            // the two groups.
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                sectionHeader("Plan")
                card {
                    VStack(spacing: 0) {
                        HStack(spacing: Theme.Spacing.m) {
                            rowIcon("SubscriptionPlan")
                            Text("Your plan")
                                .auraFont(.body, RowType.label, .semibold)
                                .foregroundStyle(RowType.labelColor)
                            Spacer(minLength: Theme.Spacing.s)
                            Text(store.isSubscribed ? "Aura Pro" : "Free")
                                .auraFont(.body, RowType.value, .medium)
                                .foregroundStyle(RowType.valueColor)
                        }
                        .padding(.vertical, Theme.Spacing.l)

                    }
                }
                if !accountLabel.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        sectionHeader("Account")
                        card {
                            HStack(spacing: Theme.Spacing.m) {
                                rowIcon("SettingsName")
                                Text("Account")
                                    .auraFont(.body, RowType.label, .semibold)
                                    .foregroundStyle(RowType.labelColor)
                                Spacer(minLength: Theme.Spacing.s)
                                Text(accountLabel)
                                    .auraFont(.body, RowType.value, .medium)
                                    .foregroundStyle(RowType.valueColor)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            .padding(.vertical, Theme.Spacing.l)
                            .maskedInReplays()
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                sectionHeader("Manage")
                card {
                    Button { step = .reason } label: {
                        HStack(spacing: Theme.Spacing.m) {
                            rowIcon("SubscriptionManage")
                            Text("Cancel subscription")
                                .auraFont(.body, RowType.label, .semibold)
                                .foregroundStyle(RowType.labelColor)
                            Spacer(minLength: Theme.Spacing.s)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(LightSheet.subtitle)
                        }
                        .padding(.vertical, Theme.Spacing.l)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressBounceStyle())
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: - 2. Reason

    private var reasonStep: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Theme.Spacing.xl) {
                    Text("What's the biggest reason you're canceling?")
                        .auraFont(.display, SheetType.title, .bold)
                        .foregroundStyle(SheetType.titleColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.top, Theme.Spacing.xxxl)

                    VStack(spacing: Theme.Spacing.m) {
                        ForEach(CancelReason.allCases) { option in
                            reasonCard(option)
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
            }

            LightPrimaryButton(title: "Continue", enabled: reason != nil) {
                step = .details
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    private func reasonCard(_ option: CancelReason) -> some View {
        let picked = reason == option
        return Button {
            Haptics.impact(.light)
            withAnimation(.snappy(duration: 0.15)) { reason = option }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                // Stickers stay full color; the chosen one cocks 15° as the
                // selection tell.
                Image(option.sticker)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .rotationEffect(.degrees(picked ? -15 : 0))
                Text(option.label)
                    .auraFont(.body, RowType.label, .medium)
                    .foregroundStyle(RowType.labelColor)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .bottomDropCard(radius: Theme.Radius.card, face: picked ? LightSheet.selectedTint : .white, shadow: false)
            .innerCardShadow()
        }
        .buttonStyle(PressBounceStyle())
    }

    // MARK: - 3. Free text

    private var detailsStep: some View {
        // The copy + input ignore the keyboard so they never move; the button
        // sits in its own bottom-aligned layer that does NOT ignore it, so
        // SwiftUI's built-in avoidance lifts just that one element.
        ZStack(alignment: .bottom) {
            detailsContent
                .ignoresSafeArea(.keyboard, edges: .bottom)

            LightPrimaryButton(title: "Continue") { step = .thanks }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
    }

    private var detailsContent: some View {
        VStack(spacing: 0) {
            backButton { step = .reason }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)

            // Same rhythm as the reason step: centered title block, then an xl
            // gap before the input.
            VStack(spacing: Theme.Spacing.xl) {
                VStack(spacing: Theme.Spacing.s) {
                    Text("Anything else we should know?")
                        .auraFont(.display, SheetType.title, .bold)
                        .foregroundStyle(SheetType.titleColor)
                        .multilineTextAlignment(.center)

                    Text("Specific feedback helps us figure out what to fix.")
                        .auraFont(.body, SheetType.subtitle, .regular)
                        .foregroundStyle(SheetType.subtitleColor)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Theme.Spacing.m)

                VStack(spacing: Theme.Spacing.xs) {
                    TextEditor(text: $notes)
                        .focused($noteFocused)
                        .auraFont(.body, SheetType.input, .medium)
                        .foregroundStyle(LightSheet.title)
                        .scrollContentBackground(.hidden)
                        // Return inserts a newline here, so give it an explicit close.
                        .keyboardDoneToolbar()
                        .padding(Theme.Spacing.s)
                        .frame(height: 180)
                        .bottomDropCard(radius: Theme.Radius.card, shadow: false)
                        .innerCardShadow()
                        // Tapping the card's padding (not just the glyph area)
                        // still puts the caret in the field.
                        .contentShape(Rectangle())
                        .onTapGesture { noteFocused = true }
                        .onChange(of: notes) { _, new in
                            if new.count > noteLimit { notes = String(new.prefix(noteLimit)) }
                        }

                    Text("\(notes.count)/\(noteLimit.formatted())")
                        .auraFont(.body, RowType.value, .medium)
                        .monospacedDigit()
                        .foregroundStyle(LightSheet.subtitle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer(minLength: 0)
        }
    }

    // MARK: - 4. Thanks

    private var thanksStep: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: 0)

            Image("FoxHabitJournal")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: 152)
                .foxShadow()

            Text("Thanks for your feedback!")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(SheetType.titleColor)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            Text("We'll take you to our cancellation page with instructions for both App Store and web subscriptions.")
                .auraFont(.body, SheetType.subtitle, .regular)
                .foregroundStyle(SheetType.subtitleColor)
                .multilineTextAlignment(.center)

            LightPrimaryButton(title: "Manage subscription") {
                // Record the cancel reason + notes (best-effort, fire-and-forget so
                // it never blocks the hand-off to Apple's page).
                if let reason {
                    Task {
                        await SupabaseManager.shared.sendCancelFeedback(reason: reason.rawValue, notes: notes)
                    }
                }
                openURL(AuraLink.manageSubscription)
                dismiss()
            }
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.l)
    }
}

/// The cancel-survey options, in the order they're shown.
enum CancelReason: String, CaseIterable, Identifiable {
    case builtHabit, noImprovement, bugs, price, tooHard, notExpected, otherApp

    var id: String { rawValue }

    var label: String {
        switch self {
        case .builtHabit:    return "I've built the habit I wanted"
        case .noImprovement: return "My screen time hasn't improved"
        case .bugs:          return "I ran into bugs or glitches"
        case .price:         return "It's too expensive"
        case .tooHard:       return "It's too hard to set up or use"
        case .notExpected:   return "It's not what I was expecting"
        case .otherApp:      return "I'm trying a different app"
        }
    }

    var sticker: String {
        switch self {
        case .builtHabit:    return "CancelReason1"
        case .noImprovement: return "CancelReason2"
        case .bugs:          return "CancelReason3"
        case .price:         return "CancelReason4"
        case .tooHard:       return "CancelReason5"
        case .notExpected:   return "CancelReason6"
        case .otherApp:      return "CancelReason7"
        }
    }
}

#Preview {
    LightSheet.bg.sheet(isPresented: .constant(true)) {
        ManageSubscriptionSheet()
    }
}
