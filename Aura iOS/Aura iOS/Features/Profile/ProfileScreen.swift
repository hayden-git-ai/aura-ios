//
//  ProfileScreen.swift
//  Aura iOS
//

import SwiftUI

/// The Profile tab: an X-style header — a cover banner, a settable avatar that
/// straddles the seam with the stats beside it, then the name + join year on the
/// ground below. The settings gear in the banner opens `SettingsScreen`, which
/// holds everything else. The outbound links it uses live in `AuraLink.swift`.
struct ProfileScreen: View {
    @Environment(HabitStore.self) private var store
    @Environment(NavChrome.self) private var navChrome

    @State private var showEditProfile = false
    @State private var showSettings = false
    /// Tapping the avatar opens Aura's own library picker straight away (no
    /// intermediate source sheet). Removing a photo lives in Edit profile.
    @State private var showLibraryPicker = false
    @State private var showSupportChat = false
    /// The founders booking opens in an in-app browser rather than leaving the app.
    @State private var browserLink: BrowserLink?
    /// Shared support thread — drives the unread badge on the chat FAB.
    @State private var chat = SupportChatStore.shared

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.ground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // The cover image, then the identity + stats straddling the
                    // seam, then the feedback card on the light ground.
                    // Gear rides ON the cover; the avatar and stats hang over the
                    // seam (inside the scroll, so they scroll away with the header
                    // rather than pinning).
                    coverBanner
                        // Soften the seam where the cover meets the ground: a wash
                        // that fades from clear up top into the background colour.
                        .overlay(alignment: .bottom) { coverSeamFade }
                        .overlay(alignment: .topTrailing) {
                            gearButton
                                .padding(.top, TabTopCardMetrics.topInset)
                                .padding(.trailing, Theme.Spacing.xl)
                        }
                        // Avatar straddles the seam (half cover, half ground),
                        // pinned to the leading edge, X-style.
                        .overlay(alignment: .bottomLeading) {
                            avatarButton
                                .padding(.leading, Theme.Spacing.xl)
                                .offset(y: Self.avatarSize / 2)
                        }
                        // Stats sit to the right of the avatar, their baseline on
                        // the avatar's bottom edge. In THIS layer (above the info)
                        // so their taller icons aren't clipped by the cover seam.
                        .overlay(alignment: .bottomLeading) {
                            statsStrip
                                .padding(.leading, Self.avatarSize + Theme.Spacing.xl + Theme.Spacing.m)
                                .padding(.trailing, Theme.Spacing.xl)
                                .offset(y: Self.avatarSize / 2)
                        }
                        // Draw the cover and its overhanging avatar above the info.
                        .zIndex(1)
                    profileInfo

                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        foundersHeader
                        feedbackCard
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                navChrome.track(y)
            }
            // Bounce even when the (short) content fits, so the stretchy header
            // can be pulled down.
            .scrollBounceBehavior(.always)
            .ignoresSafeArea(edges: .top)

            // A floating chat FAB, pinned bottom-right above the nav bar.
            chatFAB
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, Theme.Spacing.xl)
                // Sits just above the nav bar — one spacing step inside the
                // clearance so it tucks closer to it.
                .padding(.bottom, Theme.Layout.navBarClearance - Theme.Spacing.xl)
        }
        .fullScreenCover(isPresented: $showEditProfile) { ProfileEditScreen() }
        .fullScreenCover(isPresented: $showSettings) { SettingsScreen() }
        .fullScreenCover(isPresented: $showSupportChat) { SupportChatView() }
        .inAppBrowser($browserLink)
        // Tapping the avatar opens Aura's own picker directly.
        .fullScreenCover(isPresented: $showLibraryPicker) {
            CustomPhotoLibraryPicker { saveProfileImage($0) }
        }
        // Pull the thread so the FAB badge reflects any founder replies since last open.
        .task { await chat.refresh() }
    }

    // MARK: - Cover + gear

    private static let bannerHeight: CGFloat = 180
    /// Avatar diameter. Half of it hangs below the cover seam, so the info block
    /// below reserves `avatarSize / 2` of top room for the overhang.
    private static let avatarSize: CGFloat = 92

    // One-off art sizes (DESIGN.md §2: named constants, never bare literals).
    /// How far the cover-to-ground wash reaches up from the seam.
    private static let seamFadeHeight: CGFloat = 96
    /// The stat sticker's drawn height and the stroked numeral riding over it.
    private static let statIconHeight: CGFloat = 44
    private static let statNumberSize: CGFloat = 22
    private static let statNumberDrop: CGFloat = 6
    /// The feedback card: its height, the leading gutter that clears the corner
    /// fox, the fox art height, and the fox's nudge out of the bottom-left corner.
    private static let feedbackCardHeight: CGFloat = 130
    private static let feedbackCopyLeading: CGFloat = 148
    private static let feedbackFoxHeight: CGFloat = 138
    private static let feedbackFoxOffset = CGSize(width: -14, height: 22)
    private static let arrowChipSize: CGFloat = 34
    /// The chat-bubble sticker, and the unread badge's nudge onto its top-right.
    private static let chatBubbleSize: CGFloat = 64
    private static let badgeCornerOffset = CGSize(width: -6, height: 5)

    /// The cover image behind the avatar — a snowy-mountain scene, full-bleed and
    /// running up under the status bar. Stretchy like X: on pull-down it scales
    /// UNIFORMLY (both width and height) from the bottom, so the image zooms and
    /// the sides crop off-screen rather than leaving white space above.
    private var coverBanner: some View {
        GeometryReader { proxy in
            let minY = proxy.frame(in: .global).minY
            let stretch = max(0, minY)
            let scale = (Self.bannerHeight + stretch) / Self.bannerHeight
            Image("Profile_Header")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: proxy.size.width, height: Self.bannerHeight)
                .clipped()
                .scaleEffect(scale, anchor: .bottom)
        }
        .frame(height: Self.bannerHeight)
    }

    /// A soft wash over the cover's bottom edge — transparent up top fading into
    /// the background colour, so the image dissolves into the ground instead of
    /// meeting it on a hard line.
    private var coverSeamFade: some View {
        // Ramps to fully opaque ground before the very bottom, so the last stretch
        // is solid background and the hard image edge is gone, not just softened.
        LinearGradient(stops: [
            .init(color: LightSheet.ground.opacity(0), location: 0.0),
            .init(color: LightSheet.ground, location: 0.78),
            .init(color: LightSheet.ground, location: 1.0),
        ], startPoint: .top, endPoint: .bottom)
            .frame(height: 96)
            .allowsHitTesting(false)
    }

    /// Opens the settings screen. A translucent dark disc on the banner, like
    /// the reference's cover buttons.
    private var gearButton: some View {
        Button {
            Haptics.impact(.light)
            showSettings = true
        } label: {
            WoodButtonArtwork(role: .settings, diameter: 40)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(PressBounceStyle(hapticsEnabled: false))
    }

    // MARK: - Profile info

    /// The identity block on the ground: the name + join year left-aligned under
    /// the avatar, then the two pills. Stats ride up beside the avatar (see body).
    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: RowType.labelGap) {
                // The name is text, so it stays in Rubik (DESIGN.md §1 reserves the
                // stroked sticker-numeral for hero NUMBERS, not names).
                Text(store.displayName)
                    .auraFont(.display, SheetType.title, .bold)
                    .foregroundStyle(SheetType.titleColor)
                    .maskedInReplays()
                Text(joinedLabel)
                    .auraFont(.body, SheetType.subtitle, .medium)
                    .foregroundStyle(LightSheet.controlIdle)
            }

            profileButtons
                .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.xl)
        // Clear the half-avatar (and the stats) hanging down over the seam, plus a
        // little breathing room above the name.
        .padding(.top, Self.avatarSize / 2 + Theme.Spacing.l)
        .padding(.bottom, Theme.Spacing.l)
        .background(LightSheet.ground)
    }

    /// The circular avatar. Tapping it opens Aura's own library picker directly;
    /// the Edit profile screen is reached from the button below.
    private var avatarButton: some View {
        Button {
            Haptics.impact(.light)
            showLibraryPicker = true
        } label: {
            ProfileAvatarCircle(size: Self.avatarSize)
        }
        .buttonStyle(PressBounceStyle(hapticsEnabled: false))
    }

    /// Downscales an image to an avatar-sized JPEG and stores it locally.
    private func saveProfileImage(_ image: UIImage) {
        let maxDim: CGFloat = 512
        let scale = min(1, maxDim / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        store.profileImageData = resized.jpegData(compressionQuality: 0.85)
    }

    /// The two pill actions under the name — `chromeOnLight` capsules on the ground.
    private var profileButtons: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button {
                Haptics.impact(.light)
                showEditProfile = true
            } label: { pillLabel("Edit profile") }
                .buttonStyle(PressBounceStyle(hapticsEnabled: false))

            ShareLink(item: AuraLink.site) { pillLabel("Share Aura") }
                .buttonStyle(PressBounceStyle())
        }
    }

    private func pillLabel(_ title: String) -> some View {
        Text(title)
            .auraFont(.body, RowType.label, .bold)
            .foregroundStyle(LightSheet.subtitleDark)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(LightSheet.chromeOnLight, in: Capsule())
    }

    /// The section label above the feedback card.
    private var foundersHeader: some View {
        Text("Talk to the founders")
            .auraFont(.display, SheetType.banner, .bold)
            .foregroundStyle(SheetType.titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The feedback card — the fox bleeds out the bottom-left over its sunburst,
    /// copy on the right, arrow chip in the top-right corner. Opens the board.
    private var feedbackCard: some View {
        let colour = LightSheet.feedbackViolet
        return Button { browserLink = BrowserLink(url: SupportChatView.foundersBookingURL) } label: {
            // Copy on the right, clear of the corner fox.
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Got feedback?")
                    .auraFont(.display, SheetType.banner, .bold)
                    .foregroundStyle(.white)
                Text("Book a quick video call with us.")
                    .auraFont(.body, SheetType.cardBlurb, .medium)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Reserve the left corner for the fox, with extra leading so the copy
            // sits clear of it.
            .padding(.leading, Self.feedbackCopyLeading)
            .padding(.trailing, Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.feedbackCardHeight)   // matches the Blocks lane cards
            .background(
                LinearGradient(colors: [colour.lightened(by: 0.12), colour],
                               startPoint: .top, endPoint: .bottom)
            )
            // Sunbeams out of the bottom-left corner, then the fox over them.
            .overlay { feedbackSunburst }
            .overlay(alignment: .bottomLeading) {
                Image("Profile_Feedback Illustration")
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(height: Self.feedbackFoxHeight)
                    .offset(x: Self.feedbackFoxOffset.width, y: Self.feedbackFoxOffset.height)
                    .allowsHitTesting(false)
            }
            // Arrow chip pinned to the top-right corner.
            .overlay(alignment: .topTrailing) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: Self.arrowChipSize, height: Self.arrowChipSize)
                    .background(Circle().fill(LightSheet.panelOnColour))
                    .padding(.top, Theme.Spacing.m)
                    .padding(.trailing, Theme.Spacing.m)
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.hero, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(PressBounceStyle())
    }

    /// A floating chat FAB — the chat-bubble sticker on a flat `chromeOnLight` disc,
    /// bottom-right above the nav bar. Opens the support chat.
    private var chatFAB: some View {
        Button { showSupportChat = true } label: {
            Image("Profile_Chat Bubble")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: Self.chatBubbleSize, height: Self.chatBubbleSize)
                // Badge centre straddles the bubble's true top-right corner. That
                // corner (the 45° extreme of the rounded body) measures to (48, 12)
                // in this 64pt frame; anchored top-trailing the badge centres near
                // (54, 8), so it is nudged in and down onto the corner.
                .overlay(alignment: .topTrailing) {
                    unreadBadge.offset(x: Self.badgeCornerOffset.width, y: Self.badgeCornerOffset.height)
                }
                .padding(Theme.Spacing.s)
                // Same disc as the "?" explainer chip on the quest screens:
                // `chromeOnLight`, flat, no shadow.
                .background(Circle().fill(LightSheet.chromeOnLight))
                .contentShape(Circle())
        }
        .buttonStyle(PressBounceStyle())
    }

    /// The Instagram kit's "Messages" notification pill (node 1:6798), rebuilt to
    /// spec: a #ff0034 capsule, 16 tall / 19 min-wide, 6pt side padding, with a white
    /// semibold number. Present only when a founder reply is unread.
    @ViewBuilder
    private var unreadBadge: some View {
        if chat.unreadCount > 0 {
            Text(chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)")
                .auraFont(.body, RowType.subLabel, .semibold)
                .kerning(0.4)
                .foregroundStyle(.white)
                .monospacedDigit()
                .padding(.horizontal, Theme.Spacing.xs)
                .frame(minWidth: 20, minHeight: 18)
                .background(Capsule().fill(LightSheet.notification))
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.32, dampingFraction: 0.7), value: chat.unreadCount)
        }
    }

    /// Angular rays fanning up from the bottom-left corner, radial-masked into it
    /// — the streak/lane-card sunburst language, behind the feedback fox.
    private var feedbackSunburst: some View {
        let rays = 40
        var stops: [Gradient.Stop] = []
        for i in 0..<rays {
            let c: Color = i % 2 == 0 ? Color.white.opacity(0.16) : .clear
            stops.append(.init(color: c, location: Double(i) / Double(rays)))
            stops.append(.init(color: c, location: Double(i + 1) / Double(rays)))
        }
        return Rectangle()
            .fill(AngularGradient(gradient: Gradient(stops: stops), center: .bottomLeading))
            .mask(
                RadialGradient(gradient: Gradient(colors: [.white, .white, .clear]),
                               center: .bottomLeading, startRadius: 0, endRadius: 200)
            )
            .allowsHitTesting(false)
    }

    /// The three headline stats, sitting beside the avatar: an icon with its
    /// stroked number over its lower portion, and a label beneath.
    private var statsStrip: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            // Per-sticker scale normalises their visible content height (the PNGs
            // fill their canvases by different amounts).
            profileStatColumn(sticker: "ProfileStatStreak", iconScale: 0.99,
                              value: "\(store.streak.longestStreak)", label: "Best streak")
            profileStatColumn(sticker: "ProfileStatHabits", iconScale: 1.02,
                              value: "\(store.lifetimeHealthyHabits)", label: "Habits done")
            profileStatColumn(sticker: "ProfileStatTimeSaved", iconScale: 1.07,
                              value: "\(store.lifetimeFocusHours)",
                              label: "Focus hours")
        }
    }

    private func profileStatColumn(sticker: String, iconScale: CGFloat,
                                   value: String, label: String) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Image(sticker)
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(height: Self.statIconHeight)
                    .scaleEffect(iconScale)

                StrokedNumber(text: value,
                              font: Typography.displayUIFont(size: Self.statNumberSize, weight: .black, tabular: true),
                              fill: .black, stroke: .white, outlineWidth: 2.2)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(y: Self.statNumberDrop)

            }
            .padding(.bottom, Theme.Spacing.xs)

            Text(label)
                .auraFont(.body, RowType.subLabel, .semibold)
                .foregroundStyle(LightSheet.controlIdle)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity)
    }

    private var joinedLabel: String {
        let joinDate = Calendar.current.date(byAdding: .day, value: -store.daysSinceInstall, to: .now) ?? .now
        return "Joined \(Calendar.current.component(.year, from: joinDate))"
    }


}

#Preview {
    ProfileScreen()
        .environment(HabitStore())
}
