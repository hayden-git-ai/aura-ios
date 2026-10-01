//
//  OfflineShareSheet.swift
//  Aura iOS
//

import SwiftUI

/// A card to post when you're stepping away, so the people who'd otherwise
/// wonder where you went know.
///
/// The point is social cover. Leaving your phone for half an hour is easy; the
/// unanswered messages waiting afterwards are what makes people not bother. A
/// card that says "back soon" removes the reason, and it happens to be the best
/// advertisement the app has.
///
/// ONE card, not a carousel of backdrops. The carousel came from the reference
/// and every version of it generated mismatches: no scene is right for making a
/// bed, and scoping the list per method only narrowed which wrong answers were
/// on offer. The card names the habit and wears the method's colour, which is
/// true of every habit in the app without a choice being made.
struct OfflineShareSheet: View {
    let title: String
    let subtitle: String
    /// The card reads the same for every method.
    ///
    /// Focus, quick, reps and Lock In each had their own wording, which meant
    /// four sets of grammar to keep in agreement and — as soon as the art is
    /// real — four illustrations to draw. One card says the only thing all four
    /// have in common, which is the thing worth saying: the phone is down.
    static let hero = "Touching grass"
    static let detail = "No phone, be back soon 👀"
    /// The message that travels with it. Ends in the link, so the card is the
    /// message and the link is a footnote in it.
    static var shareText: String {
        """
        Hey, consider this your "stop doomscrolling" invite.
        Join me on Aura and replace doomscrolling with healthy habits.
        \(downloadURL.absoluteString)
        """
    }
    static let previewTitle = "Going offline 👀"
    /// The line that travels WITH the image. Not a title — this is what
    /// somebody actually reads in their messages next to the card.
    let sticker: String
    let accent: Color
    let accentShade: Color

    @State private var showShare = false

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                LightSheetTitle(title: title, subtitle: subtitle)

                // A spacer either side, so the card centres in the room between
                // the subtitle and the button rather than hanging off the
                // header with all the slack below it.
                Spacer(minLength: Theme.Spacing.xl)

                card
                    .frame(height: 400)
                    // A deliberate 24pt bias, and it has to be this large.
                    //
                    // The card and the Share button are the SAME BLUE, so the
                    // eye groups them and reads the white between them as a
                    // seam rather than a gap. Above the card that same white
                    // sits between blue and grey type and reads fully open.
                    // Measured equal, it looks top-heavy; measured 50/55 it
                    // still looked top-heavy. Grouping beats arithmetic, so the
                    // numbers have to be wrong for the picture to be right.
                    .padding(.bottom, Theme.Spacing.xl)

                Spacer(minLength: Theme.Spacing.xl)

                Button { showShare = true } label: {
                    Text("Share")
                        .font(SheetType.ctaFont)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(accent, in: Capsule())
                        .background(alignment: .bottom) {
                            Capsule().fill(accentShade).frame(height: 56).offset(y: 5)
                        }
                }
                .buttonStyle(PressBounceStyle())
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .sheet(isPresented: $showShare) {
            // Image, sentence, link. All three, or the card is an advert with
            // no address on it.
            ShareSheet(image: renderedUIImage,
                       text: Self.shareText,
                       previewTitle: Self.previewTitle)
        }
        #if DEBUG
        // `-dumpcard` writes the exact PNG a recipient receives into the app
        // container, where `simctl get_app_container` can fetch it. The
        // Simulator can't send a message, so this is the only way to judge the
        // artefact at full size without a device.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-dumpcard") else { return }
            guard let data = renderedUIImage.pngData() else { return }
            let url = URL.documentsDirectory.appendingPathComponent("aura-share-card.png")
            try? data.write(to: url)
        }
        #endif
    }

    /// TODO: swap for the App Store listing once there is one.
    static let downloadURL = URL(string: "https://www.downloadaura.app")!

    private var card: some View {
        OfflineCard(sticker: sticker, ground: accent)
    }

    /// The card as a flat image, which is the only thing worth handing to
    /// another app — a SwiftUI view can't leave the process.
    @MainActor
    private var renderedUIImage: UIImage {
        let renderer = ImageRenderer(content: card.frame(width: 354, height: 400))
        // Sharing at 1x produces a card that looks soft the moment anyone opens
        // it full screen in Messages.
        renderer.scale = 3
        return renderer.uiImage ?? UIImage()
    }
}

/// The shareable card itself. Its own view because it has to render twice: on
/// screen, and again through `ImageRenderer` for the share.
struct OfflineCard: View {
    let sticker: String
    let ground: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(OfflineShareSheet.hero)
                .auraFont(.display, SheetType.hero, .heavy)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.xl)

            Text(OfflineShareSheet.detail)
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.xs)

            Spacer(minLength: Theme.Spacing.m)

            HStack(spacing: Theme.Spacing.s) {
                Image("AuraAppIcon")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .appIconChrome(side: 22, border: 0)
                Text("Join me on Aura")
                    .auraFont(.body, SheetType.cardTitle, .bold)
                    .foregroundStyle(.white)
            }
            .padding(.bottom, Theme.Spacing.l)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            // The whole card is one illustrated scene now, not a flat colour.
            Image("AuraOfflineCard")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                // A soft dark scrim over the top so the white headline reads
                // against the bright sky. Fades to clear before the midline so
                // the scene below is untouched.
                .overlay {
                    LinearGradient(
                        stops: [.init(color: .black.opacity(0.42), location: 0),
                                .init(color: .clear, location: 0.42)],
                        startPoint: .top, endPoint: .bottom)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
    }
}
