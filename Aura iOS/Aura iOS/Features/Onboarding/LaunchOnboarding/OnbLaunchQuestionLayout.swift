//
//  OnbLaunchQuestionLayout.swift
//  Aura iOS
//
//  Shared light Aura shell for every launch question screen.
//

import SwiftUI

struct OnbLaunchQuestionLayout<Content: View, Bottom: View>: View {
    var showBack: Bool = true
    var progress: Double? = nil
    var contentTopSpacing: CGFloat = Theme.Spacing.xxl
    let question: String
    @ViewBuilder var content: () -> Content
    @ViewBuilder var bottom: () -> Bottom

    var body: some View {
        ZStack {
            LightSheet.ground.ignoresSafeArea()

            VStack(spacing: 0) {
                OnbTopBar(showBack: showBack, progress: progress, onSky: false)
                    .padding(.bottom, Theme.Spacing.m)

                AuraQuestionHeader(text: question)
                    .padding(.horizontal, Theme.Spacing.xl)

                content()
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, contentTopSpacing)

                Spacer(minLength: Theme.Spacing.l)

                bottom()
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
    }
}

/// One static Aura mark and one centered question. No card, video, or typing.
private struct AuraQuestionHeader: View {
    let text: String
    private let iconSize: CGFloat = 64

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Image("AuraAppIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: iconSize, height: iconSize)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(LightSheet.blue, lineWidth: 3)
                }
                .chromeShadow()
                .accessibilityHidden(true)

            Text(text)
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(LightSheet.title)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
        }
    }
}

/// Aura answer card shared by single and multi-select launch questions.
struct OnbLaunchAnswerCard: View {
    let label: String
    let emoji: String
    var selected: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.m) {
                Text(emoji)
                    .font(.system(size: 32))
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)

                Text(label)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(selected ? Color.white : LightSheet.title)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 64)
            .bottomDropCard(
                radius: Theme.Radius.card,
                face: selected ? LightSheet.blue : Color.white,
                shade: selected ? LightSheet.blueShade : LightSheet.whiteShade
            )
        }
        .buttonStyle(PressBounceStyle())
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

func onbLaunchContinue(enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
    LightPrimaryButton(title: "Continue", face: LightSheet.blue, textColor: Color.white,
                       shade: LightSheet.blueShade, enabled: enabled, action: action)
}
