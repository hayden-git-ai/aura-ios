//
//  LightSheet.swift
//  Aura iOS
//

import SwiftUI

/// Shared palette + chrome for the light earn-flow sheets (Screentime Store,
/// Blocks, Photo/Exercise Rewards, Apple Health…), so they all read as one
/// design system. Mirrors the values first established on the Store/Blocks
/// sheets.
enum LightSheet {
    /// The app-screen ground (Blocks, Stats, Profile) — a hair off white so the
    /// white cards on it read as raised.
    static let ground = Color(hex: "FAFAFA")
    /// Sheet/screen surface. The same off-white as `ground`: sheets and method
    /// screens sit on the app's ground colour, not pure white, so the white
    /// cards on them keep popping and nothing reads as a whiter third surface.
    static let bg = ground
    /// Every recessed light surface: text fields, the app strip inside a card,
    /// app tiles, icon trays. Was four tokens spanning F4F4F5–EFEFF2 — five
    /// points end to end, which nothing could tell apart.
    static let field = Color(hex: "F4F4F5")
    static let fieldStroke = Color(hex: "E6E6E9")
    /// The drop edge under a `field`-faced control.
    static let fieldShade = Color(hex: "DCDCE1")
    static let title = Color(hex: "1C1C1E")
    static let subtitle = Color(hex: "9B9BA3")
    /// The darker secondary gray established on the Deep Focus sheets — used for
    /// card labels + subtitles in the "Focus" sheet layout.
    static let subtitleDark = Color(hex: "3A3A3D")
    /// Idle text on segmented/pill controls — a few shades darker than
    /// `subtitle`, but lighter than the card labels.
    ///
    /// #767676 exactly, not a rounder number: it's the darkest neutral grey
    /// that still clears WCAG AA on white (4.54:1). #78787F, two points
    /// lighter and faintly blue, came to 4.38 and failed. `RowType` uses this
    /// for every sub-label, so the whole rung passes on this one value.
    static let controlIdle = Color(hex: "767676")
    /// iOS's icon corner as a fraction of the icon's width. Every app icon in
    /// the app derives its clip from this — hard-coded radii drifted the moment
    /// the icon sizes changed, and 9pt on a 24pt icon reads as a blob.
    static let iconCornerRatio: CGFloat = 0.2237

    // MARK: - The sticker treatment, as ratios
    //
    // The baked stickers carry a white contour and a soft shadow sized as a
    // fraction of the drawing, so the edge reads the same whether the thing is
    // 15pt or 180pt. App icons used a FIXED 10% keyline and a hard drop, which
    // made them the heaviest border on the screen while being the smallest
    // object on it — in the blocked pill a 15pt app icon carried 2pt of white
    // against the 23pt lock sticker's 0.8pt beside it.
    //
    // These are the sticker pipeline's numbers, expressed against the drawn
    // size: contour 18/512, shadow 8/512 down and 26/512 of blur at 30%.

    /// White keyline, as a fraction of the icon's drawn size.
    static let stickerContour: CGFloat = 18.0 / 512
    /// …but never thinner than this.
    ///
    /// A proportional border does not stay equally visible as the thing shrinks.
    /// At 18pt the ratio gives 0.63pt, which is under two device pixels — the
    /// point where a hairline stops reading as a line and starts reading as a
    /// slightly soft edge. It also has the most work to do at that size: a
    /// sticker can afford a thin contour because its artwork carries its own
    /// dark edges, where an app icon is a dense photograph with a hard
    /// rectangular boundary and nothing between it and whatever is behind.
    ///
    /// A floor rather than a per-call-site override on purpose. Every app icon
    /// in the app used to carry its own hand-picked border and no two agreed;
    /// this is a rule that holds everywhere and that the next small icon
    /// inherits for free. Above about 29pt it changes nothing.
    static let stickerContourFloor: CGFloat = 1
    static let stickerShadowDrop: CGFloat = 8.0 / 512
    static let stickerShadowBlur: CGFloat = 26.0 / 512
    static let stickerShadowAlpha: CGFloat = 0.30

    /// The single soft ground shadow every raw fox illustration shares — sheets,
    /// empty states, the how-it-works heroes, the stats foxes. One knob for all
    /// of them, applied via `.foxShadow()`. These illustrations are raw art (no
    /// baked shadow), so this is the only shadow they carry.
    static let foxShadowAlpha: CGFloat = 0.12
    static let blue = Color(hex: "2586FF")
    /// The darker shade drawn under primary buttons for the chunky "drop
    /// outline" 3D edge.
    static let blueShade = Color(hex: "1C69D6")
    static let green = Theme.Color.signalGood
    /// The darker shade drawn under green buttons for the drop edge.
    static let greenShade = Color(hex: "25A160")
    /// The edge under any white face — cards, capsules, app icons alike.
    ///
    /// Translucent rather than the old solid #CFCFD8, which assumed the card
    /// sat on white and carried a blue cast that the icons' edge didn't. This
    /// picks up whatever is behind it, which matters now that cards sit on
    /// white, lavender and blue in different places.
    static let whiteShade = Color.black.opacity(0.14)
    /// The app's orange, everywhere it appears: Extreme Focus's "on" fill, the
    /// Blocks screen's Add Block CTA, the streak screen's ground and freeze
    /// pill, and Camera Reps' card, field and habit headers.
    ///
    /// There were three — FF8A1F here, F2790C on Camera Reps, FF6B03 on the
    /// streak — close enough that no one could name the difference in isolation
    /// and impossible to miss side by side.
    static let orange = Color(hex: "FF6B03")
    /// The drop edge under it — the same 82% step Camera Reps' shade takes.
    static let orangeShade = Color(hex: "D15702")
    /// The edge under a white card that sits on COLOUR. `whiteShade` is
    /// translucent so it adapts across the light surfaces — over blue or orange
    /// that means it tints, which reads as muddy. Same grey as `fieldDeep`,
    /// stated opaquely.
    static let whiteShadeOnColour = fieldDeep

    /// The one recessed grey that has to read as darker: count badges and
    /// settings discs, where `field` disappears into a white card.
    static let fieldDeep = Color(hex: "E1E1E8")
    /// Control tracks and chrome discs — segmented tracks, progress tracks,
    /// close buttons. Absorbed `dragGray`, which was two points away.
    static let track = Color(hex: "ECECEE")
    /// The sheet grabber. Translucent, not a fixed grey: #CFCFD6 was tuned on
    /// a white sheet (1.55:1) and faded to 1.38:1 on the lavender surface the
    /// settings sheets use. This holds on both.
    ///
    /// Deliberately under WCAG's 3:1 for non-text — that would need ~#949494,
    /// heavier than iOS's own. It hints at swipe-to-dismiss rather than
    /// conveying state, and the gesture works without it.
    static let grabber = Color.black.opacity(0.2)
    static let danger = Color(hex: "F0453E")
    /// The app's strong red — destructive tints (Delete Account, delete photo),
    /// the "Tempting" lane, blocked-app buttons, the proof-failure ground.
    /// Promoted from a hex that was repeated across seven feature files.
    static let rippleRed = Color(hex: "FF3B30")
    /// The deeper "drained / without-Aura" red — the two-paths brainrot ground
    /// and its time-loss rates.
    static let drainRed = Color(hex: "E0413B")
    /// The notification-badge red — the unread-count pill on the profile chat FAB,
    /// adapted from the Instagram kit's "Messages" component. Brighter than
    /// `rippleRed`; reserved for count badges, not destructive actions.
    static let notification = Color(hex: "FF0034")
    /// The founders / feedback card violet. Its own accent, kept off the
    /// deep-focus purple world so the two never read as the same surface.
    static let feedbackViolet = Color(hex: "6D5CE0")
    /// The review-star gold.
    static let starGold = Color(hex: "FFC53D")
    /// A light-grey card fill that still reads as a distinct card on a white
    /// ground (the review-wall cards). Darker than `field` on purpose.
    static let cardGrey = Color(hex: "E5E7EC")

    // Promoted from the per-file palettes that used to shadow this one. `bg` is
    // a sheet's white; `surface` is the light lavender the full screens sit on.
    static let surface = Color(hex: "EEEDF0")
    static let divider = Color(hex: "EDEDF1")
    static let badge = Color(hex: "B8B8BE")
    /// The soft blue disc an avatar or a chosen sticker sits on.
    /// Deliberately stronger than `blueWash`: an avatar or a chosen sticker
    /// needs its disc to read as a disc.
    static let avatarBlue = Color(hex: "CDEBFF")
    static let selectedTint = Color(hex: "9BD8FF")
    /// The middle step of the screen-time split — between `blue` and the grey
    /// of "Other", so three segments read as one ramp.
    static let blueLight = Color(hex: "8FC2FF")
    /// The disc behind an icon button. Three values, by what's behind it — see
    /// `CircleIconButton`.
    static let chromeOnLight = Color.black.opacity(0.08)
    /// The nav bar's selected-tab disc. Not chrome: it marks state.
    static let tabSelection = Color.white.opacity(0.16)
    /// Over a photo or a bright flat ground we own — the streak screen's
    /// orange. Fine under a white glyph, which holds at 3.4:1 even on the
    /// palest part of that ground.
    static let chromeOnPhoto = Color.black.opacity(0.4)
    /// Over the flat blue field — the store's header, the Stats toggle row.
    ///
    /// `chromeOnPhoto` was doing this job and it's the wrong tool: 40% black on
    /// #2586FF resolves to #165099, a navy hole punched in the blue. A known
    /// flat ground needs nothing like that much. At 25% the disc still reads as
    /// its own object and a white glyph sits on it at 5.8:1.
    ///
    /// Also the streak screen's orange, by choice rather than by measurement:
    /// a white glyph there is 2.25:1 on the palest part of that ground, under
    /// the 3:1 an icon control wants. Taken deliberately so every screen's
    /// chrome is one object — don't "fix" it.
    static let chromeOnBlue = Color.black.opacity(0.25)
    /// Translucent white over a live viewfinder — the habit pill, the flip
    /// button, a disabled capsule. The two cameras had drifted to 0.12 and
    /// 0.14 for the same element.
    static let chromeOnCamera = Color.white.opacity(0.14)
    /// Any translucent surface sitting ON a coloured field that carries WHITE
    /// text: the segmented pill's track, the trend chip, the summary panel.
    ///
    /// A surface tints in whichever direction helps its own text. These carry
    /// white, so they tint DOWN — every one of them used to tint up, which put
    /// the seat lighter than the ground and capped the label it was seating.
    /// The Blocks preset card's mini pill carries dark text and correctly does
    /// the opposite.
    ///
    /// One value so the three read as one system. They were 0.22, 0.14 and
    /// 0.12 white, close enough to look like a mistake and far enough apart to
    /// show a seam where two of them met.
    static let surfaceOnColour = Color.black.opacity(0.14)
    /// A full card's worth of the same idea: Stats' summary panel on the blue,
    /// the streak screen's challenge card on the orange. Two points deeper than
    /// `surfaceOnColour` because a card carries more than a chip does.
    static let panelOnColour = Color.black.opacity(0.16)
    /// Secondary text on a coloured or dark surface — a subtitle under a white
    /// title, a value beside a white label. Was 0.8, 0.85, 0.9 and 0.92 across
    /// fifteen sites for the same job.
    static let onColour = Color.white.opacity(0.85)

    /// Apple Health's own pink-to-red — its heart, and the metric glyphs that
    /// stand in for it. Theirs, not ours, which is why it sits outside the
    /// blue/orange/green set.
    static let healthPink = Color(hex: "FF61AD")
    static let healthRed = Color(hex: "FF2719")
    /// The brand blue at wash strength: tip panels, the store's receipt row,
    /// a method's soft accent, a selected tile. Four pale blues did this —
    /// #DCEBFF, #E4EDFF, #EAF3FF and a hand-written #DBE7FB — spanning 14
    /// points, which is nothing on a fill that size.
    static let blueWash = Color(hex: "DCEBFF")
    /// Its drop edge.
    static let blueWashShade = Color(hex: "BDD2F2")

    // A blocker's state, text over fill.
    static let activeText = Color(hex: "2CA26A")
    static let activeBg = Color(hex: "DCF3E7")
    static let schedText = Color(hex: "6E6E77")
    static let schedBg = Color(hex: "E7E7EA")
    static let breakText = Color(hex: "B0791A")
    static let breakBg = Color(hex: "FBEED3")
}

/// The type scale for a light sheet or settings screen, above the row level.
///
/// Every rung existed at two or more sizes before this: titles at 21, 22, 24
/// and 26; subtitles at 13 and 14 inside the same file; section headers at 15
/// and 17; and a field label set at 15 bold — the same grade as a section
/// header set in the body face rather than the display one, which is what made
/// "Your Name" read as shouting.
enum SheetType {
    /// A full screen's one statement: the verdict screens' headline, and any
    /// celebration that owns the whole page.
    ///
    /// A rung above `title`, because it heads a screen with nothing else on it
    /// rather than a sheet with a stack of controls underneath. It arrived as a
    /// private `32` declared separately inside two files that sit next to each
    /// other in the flow, which is exactly how the old four-titles-at-four-sizes
    /// problem started.
    static let hero: CGFloat = 34
    /// A full-screen statement whose line is too long to fit at `hero` — the
    /// onboarding promise headline. One real rung under `hero` (Apple's Title 1
    /// sits here at 28); reach for `hero` when the line fits, this when it wraps.
    static let heroCompact: CGFloat = 28
    /// The sheet's own title.
    static let title: CGFloat = 22
    /// A full-width sentence sitting on the field rather than in a card — the
    /// two Stats banners and the loading block.
    ///
    /// A real rung, not a bend: this role was running at 19, 20 and 21 in three
    /// places, and the nearest existing tokens are a sheet title (22) and a
    /// section header (15), neither of which is a sentence. The emphasised span
    /// inside a banner is this size too — it separates by weight and colour, not
    /// by growing.
    static let banner: CGFloat = 20
    /// The line under it.
    static let subtitle: CGFloat = 13
    /// Anything sitting outside a card, heading what's below it — a group of
    /// cards, a field, a grid. One rung, not two: a field label and a section
    /// header do the same job at the same level, and it's the same thing Stats
    /// uses for "Peak hours" and "Your past 90 days".
    ///
    /// Set in `display`, not `body`. The old field labels were `body` bold at
    /// this size, which is what read as heavy — the weight was right, the
    /// typeface wasn't.
    static let sectionHeader: CGFloat = 15
    /// Heads a card that holds MORE than one line — a toggle plus a blurb.
    /// A single-line row is a row, however it's boxed: it takes `RowType.label`,
    /// like Settings' nav rows. Getting that backwards is what made "Your plan"
    /// and "Cancel subscription" read heavy.
    static let cardTitle: CGFloat = 15
    /// The explanatory line inside such a card.
    static let cardBlurb: CGFloat = 13
    /// A primary button's label: `body` **bold**, via `ctaFont` so a call site
    /// can't set the size and forget the weight. Bold rather than semibold
    /// because at a 56pt button semibold reads underweight — Lock In was
    /// already bold, and the standard moved to meet it.
    static let cta: CGFloat = 18
    static let ctaFont = Typography.body(size: cta, weight: .bold)
    /// A text field's input text. 16 is deliberately off the display scale: it is
    /// the iOS-standard input size, comfortable to read and above the point where
    /// a field triggers auto-zoom. Every text field uses this so none carries a
    /// bare 16.
    static let input: CGFloat = 16

    static let titleColor = LightSheet.title
    static let subtitleColor = LightSheet.subtitleDark
}

/// The list-row type scale: a name, a line under it, and an optional trailing
/// value.
///
/// One definition for every icon-name-value row in the app — Stats' three
/// lists, the Blocks cards, the store's receipts, the Apple Health metrics.
/// They were five near-misses across three different name treatments (14
/// semibold, 13 semibold, 13 medium) because nothing named the shape.
///
/// The colours travel with the sizes: a row that picked up one without the
/// other is how they drifted in the first place.
enum RowType {
    static let label: CGFloat = 13
    /// 12, not 11. At 11 this was both the smallest size in the app and, in
    /// `subtitle`, the lightest colour — about 2.6:1 on white, where small text
    /// wants 4.5. 11 is also Apple's Caption 2, the floor of their scale, which
    /// is a photo-caption size rather than the second line of every row.
    static let subLabel: CGFloat = 12
    static let value: CGFloat = 12
    /// Between the name and the line under it.
    static let labelGap: CGFloat = 4

    static let labelColor = LightSheet.title
    /// `controlIdle`, not `subtitle`: the size bump alone left it failing on
    /// contrast. ~3.9:1 — still shy of AA, but no longer the weakest thing on
    /// the screen, and still clearly a caption.
    static let subLabelColor = LightSheet.controlIdle
    static let valueColor = LightSheet.subtitleDark
}

/// The light segmented pill (blue selection on a gray track), matching the
/// Create Blocker sheet's All Day / Schedule control. Any number of options.
struct LightSegmentedPill: View {
    let titles: [String]
    @Binding var selection: Int
    /// Defaults match the sheets this was built for; Stats runs it smaller.
    var height: CGFloat = 40
    var fontSize: CGFloat = 14
    /// Inverted for the method screens: the blue selection would disappear into
    /// the blue field, so the pill goes white and the track translucent.
    var onBlue: Bool = false
    /// The field's colour, used for the selected pill's label when `onBlue`.
    var onColor: Color = LightSheet.blue

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                let selected = selection == index
                Text(title)
                    .auraFont(.body, fontSize, .bold)
                    // Solid white when idle, not `onColour`'s 85%. Same finding
                    // as the summary card: on a mid-tone field, white text
                    // tops out just above 4.5:1, so shaving 15% off it drops
                    // the whole label under. Selection is carried by the white
                    // pill, which is unmissable without help from the label.
                    .foregroundStyle(onBlue
                        ? (selected ? onColor : .white)
                        : (selected ? .white : LightSheet.controlIdle))
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background { if selected { Capsule().fill(onBlue ? .white : LightSheet.blue) } }
                    .contentShape(Capsule())
                    .onTapGesture { withAnimation(.snappy(duration: 0.2)) { selection = index } }
            }
        }
        .padding(4)
        // Tinted down rather than up on blue, matching the trend chip and the
        // summary panel below it: three translucent surfaces on the same field,
        // so they have to recede the same way. Lightening one of the three read
        // as a seam between them.
        .background(onBlue ? LightSheet.surfaceOnColour : LightSheet.track, in: Capsule())
    }
}

// MARK: - Deep Focus sheet kit
//
// Shared chrome for the "Focus" sheet layout (mascot hero → recessed cards →
// blue capsule button), first designed on the Deep Focus sheets and reused
// across the earn-flow sheets so they read as one family.

/// The gray drag capsule pinned at the top of a light sheet.
struct LightDragCapsule: View {
    var body: some View {
        Capsule()
            .fill(LightSheet.grabber)
            .frame(width: 40, height: RowType.labelGap)
            .padding(.top, Theme.Spacing.m)
    }
}

/// The 36pt gray circular close (X) button — corner chrome for light sheets.
struct LightCloseButton: View {
    var action: () -> Void
    var body: some View {
        CircleIconButton(symbol: "xmark", glyphColor: LightSheet.subtitleDark, bounces: false, action: action)
    }
}

/// Centered mascot sticker + heavy title + thin dark-gray subtitle — the hero
/// block at the top of a Focus-style sheet.
struct FocusHero: View {
    var sticker: String
    var title: String
    var subtitle: String
    var stickerHeight: CGFloat = FocusHero.defaultStickerHeight

    /// Named so a caller that needs to override it for one screen can still
    /// state "the same as everywhere else" for the rest.
    static let defaultStickerHeight: CGFloat = 134
    /// Overridable for the method screens, where the text sits on blue.
    var titleColor: Color = LightSheet.title
    var subtitleColor: Color = LightSheet.subtitleDark
    /// Extra room between the mascot and the title.
    ///
    /// The quest screens used to set this to 10 so the colour break could pass
    /// through the gap without cutting either. The break sits on the mascot
    /// now, so the gap has nothing to clear and the 10 was only pushing the
    /// title away from the art it belongs to.
    var titleGap: CGFloat = 0

    /// How far the block sits below the top of its scroll view, clearing the
    /// corner chrome (the X and the `?`) so the mascot never overlaps them.
    ///
    /// Public because `MethodScreenBackground` has to know where the mascot
    /// lands to put its arc through the middle of it.
    static let chromeClearance: CGFloat = Theme.Spacing.xxxl

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: stickerHeight)
                .foxShadow()
            Text(title)
                .auraFont(.display, 22, .bold)
                .foregroundStyle(titleColor)
                .padding(.top, titleGap)
            Text(subtitle)
                .auraFont(.body, SheetType.subtitle, .regular)
                .foregroundStyle(subtitleColor)
                .multilineTextAlignment(.center)
        }
        .padding(.top, FocusHero.chromeClearance)
    }
}

/// Sub-sheet header (Target Time / Apps to Block style): drag capsule, a
/// centered 24pt title with an optional centered subtitle, and an optional
/// corner X. No mascot — the lighter-weight counterpart to `FocusHero`.
struct LightSubSheetHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            Text(title)
                .auraFont(.display, 22, .bold)
                .foregroundStyle(LightSheet.title)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)

            if let subtitle {
                Text(subtitle)
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.xxl)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }
}

/// The blue 50pt capsule primary button used at the bottom of the Focus sheets.
struct LightPrimaryButton: View {
    var title: String
    /// Optional sticker shown BEFORE the title — e.g. the chest on a success
    /// screen's Claim Reward button.
    var leadingIcon: String? = nil
    /// Optional payout shown after the title as a coin and a number, for CTAs
    /// that start something with a known reward.
    var coins: Int? = nil
    /// Overridable so a screen's CTA can carry its method's colour.
    var face: Color = LightSheet.blue
    /// Label colour — flips to the face's own hue for the white variant.
    var textColor: Color = .white
    var shade: Color = LightSheet.blueShade
    var enabled: Bool = true
    /// How far the darker "drop outline" edge peeks below the button face.
    var depth: CGFloat = 5
    /// Overridable so a screen can dial the label back without forking the
    /// button (Help uses a lighter, smaller label).
    var titleFont: Font = SheetType.ctaFont
    /// Last so trailing-closure call sites keep working.
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let leadingIcon {
                    Image(leadingIcon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: SheetType.cta * 1.55, height: SheetType.cta * 1.55)
                }

                Text(title)
                    .font(titleFont)
                    .foregroundStyle(textColor)

                if let coins {
                    // Sized off the label, not picked. A 22pt coin beside 18pt
                    // type stood taller than the letters, because a capital
                    // reaches about 72% of its point size while a coin fills its
                    // whole frame. Matching the cap height exactly then read as
                    // undersized — an icon beside text wants to sit between the
                    // cap and the ascender, not level with the caps.
                    Image("AuraCoinIcon")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: SheetType.cta * 1.05, height: SheetType.cta * 1.05)
                    Text("\(coins)")
                        .font(titleFont)
                        .foregroundStyle(textColor)
                        .contentTransition(.numericText())
                }
            }
        }
        .buttonStyle(PillPressButtonStyle(face: face, shade: shade, lip: depth, enabled: enabled))
        .disabled(!enabled)
    }
}

/// The app's pill button (a capsule — matching the FAB and nav) with Duolingo's
/// satisfying press: a flat face over a darker bottom lip that the face drops
/// onto when tapped. The lip lives INSIDE the 56pt button, so it's no taller than
/// the original pill — just a flat face and a clean bottom edge that presses down.
struct PillPressButtonStyle: ButtonStyle {
    var face: Color
    var shade: Color
    var lip: CGFloat = 5
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        // `configuration.isPressed` read directly, exactly like `PressBounceStyle`
        // — the proven pattern in this app.
        ZStack(alignment: .top) {
            // The darker lip fills the full height; the face sits `lip` short of
            // the bottom, so the lip shows as a clean bottom edge.
            Capsule().fill(shade)
            configuration.label
                .frame(maxWidth: .infinity)
                .frame(height: 56 - lip)
                .background(Capsule().fill(face))
                .offset(y: configuration.isPressed && enabled ? lip : 0)
        }
        .frame(height: 56)
        // A quick scale-pop as well as the sink, so there's clear feedback even
        // on a fast tap that dismisses before the sink is noticed.
        .scaleEffect(configuration.isPressed && enabled ? 0.96 : 1)
        .opacity(enabled ? 1 : 0.45)
        .animation(.spring(response: 0.24, dampingFraction: 0.55), value: configuration.isPressed)
        // A light tap when the press lands, so the app's primary action feels
        // alive. App-wide: every primary pill button gets this.
        .onChange(of: configuration.isPressed) { _, pressed in
            if pressed && enabled { Haptics.impact(.light) }
        }
    }
}

extension View {
    /// Fills a CTA with a colored face over a darker capsule, so the button
    /// reads as a chunky pressable block with a "drop outline" edge.
    func dropCapsule(face: Color, shade: Color, depth: CGFloat = 4) -> some View {
        self
            .background(
                ZStack {
                    // The darker capsule fills the button's own bounds — nothing
                    // is drawn outside the frame, so the pill never gets clipped
                    // and no extra margin is introduced.
                    Capsule()
                        .fill(shade)

                    // The face, pulled in from the trailing/bottom edges so the
                    // darker layer shows as a rim up the right side (tapering
                    // toward the top-right via the pill's curve) and along the
                    // bottom.
                    Capsule()
                        .fill(face)
                        .padding(.trailing, depth)
                        .padding(.bottom, depth)
                }
            )
    }

    /// The blue primary CTA treatment.
    func blueDropCapsule(depth: CGFloat = 4) -> some View {
        dropCapsule(face: LightSheet.blue, shade: LightSheet.blueShade, depth: depth)
    }




    /// The one soft ground shadow every fox illustration shares. Driving it off
    /// `LightSheet.foxShadowAlpha` means the strength is a single knob for the
    /// whole app instead of a number copied into a dozen call sites.
    func foxShadow() -> some View {
        shadow(color: .black.opacity(LightSheet.foxShadowAlpha), radius: 10, y: 5)
    }

    /// The one content-card elevation — every white / surface card reads at the
    /// same height. This is for UI cards only; illustration depth is `foxShadow`
    /// / the sticker-shadow tokens, and text-on-photo legibility and
    /// sticker-outline depth are their own (heavier, purpose-specific) shadows.
    func cardShadow() -> some View {
        shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }

    /// The one modal / sheet elevation — a step heavier than a card.
    func modalShadow() -> some View {
        shadow(color: .black.opacity(0.16), radius: 24, y: 10)
    }


    /// The white treatment — a white face over a soft gray edge, for compact
    /// buttons that sit on artwork (the Blocks header's Add Block pill).
    func whiteDropCapsule(depth: CGFloat = 3, shade: Color = LightSheet.whiteShade) -> some View {
        dropCapsule(face: .white, shade: shade, depth: depth)
    }

    /// A bottom-only drop edge: the shade sits under the face along the bottom
    /// only, with the sides flush. Used by the Blocks screen's white cards and
    /// its gray "add" buttons, where a full wrap-around rim would be too loud.
    func bottomDrop<S: InsettableShape>(_ shape: S, face: Color, shade: Color, depth: CGFloat = 4) -> some View {
        self
            // Reserve the edge's room below the content first, so the face ends
            // up wrapping the content symmetrically — without this the face is
            // `depth` shorter at the bottom while the content stays centred in
            // the full frame, which reads as extra padding at the top.
            .padding(.bottom, depth)
            .background(
                ZStack {
                    shape.fill(shade)
                    shape.fill(face).padding(.bottom, depth)
                }
            )
    }

    /// Bottom-only edge on a rounded-rect card.
    /// The card's soft shadow comes with it. Nineteen of the twenty-two call
    /// sites wrote the identical `.shadow(...)` on the next line; pass
    /// `shadow: false` for the handful that sit inside another card.
    func bottomDropCard(radius: CGFloat, face: Color = .white, shade: Color = LightSheet.whiteShade,
                        depth: CGFloat = 4, shadow: Bool = true) -> some View {
        bottomDrop(RoundedRectangle(cornerRadius: radius, style: .continuous), face: face, shade: shade, depth: depth)
            .shadow(color: shadow ? .black.opacity(0.06) : .clear, radius: 12, y: 6)
    }

    /// A card sitting inside another card: lighter and tighter than the
    /// standard one `bottomDropCard` carries, so the two don't stack into a
    /// smudge. Pair with `shadow: false`.
    func innerCardShadow() -> some View {
        shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    /// The lift under the FAB menu's rows — heavier than `chromeShadow`, since
    /// these float over the dimmed Home screen rather than a light surface.
    func fabShadow() -> some View {
        shadow(color: .black.opacity(0.25), radius: 8, y: 3)
    }

    /// The lift under a small floating circle — a back button, a gear.
    func chromeShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }


    /// The shared app-icon treatment: rounded clip, a white keyline, and a
    /// bottom-only drop edge. The bottom padding reserves the edge's room so
    /// nothing draws outside the icon's frame.
    /// Chrome derived from the icon's own width, which is the only way the
    /// corners stay right when the size changes.
    ///
    /// `side` is the ARTWORK's width, not the finished footprint — the keyline
    /// grows outward from it. Pass `border`/`depth` only where they were tuned
    /// by hand; otherwise they scale too.
    func appIconChrome(side: CGFloat, border: CGFloat? = nil, depth: CGFloat? = nil,
                       shade: Color = LightSheet.whiteShade) -> some View {
        // Sticker treatment: round the artwork, wrap it in a white keyline, and
        // ground it with a soft drop shadow. `side` is the artwork's width; the
        // keyline grows outward from it and the corners stay concentric. Pass
        // `border: 0` for a white app icon — no visible keyline, shadow only.
        let radius = side * LightSheet.iconCornerRatio
        let keyline = border ?? max(1.5, side * 0.075)
        return self
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .padding(keyline)
            // The shadow is cast by the opaque keyline itself. The offset stays
            // smaller than the blur, so the shadow hugs the icon instead of
            // detaching into a hard line beneath it, while sitting low enough not
            // to gray the outline. The white is painted on top of its own shadow.
            .background {
                RoundedRectangle(cornerRadius: radius + keyline, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.13), radius: side * 0.15, y: side * 0.06)
            }
    }

    // Rounded corners only. Kept for the radius-based call sites that opted out
    // of the keyline/shadow; `border`/`depth`/`shade` stay in the signature so
    // those sites still compile.
    func appIconChrome(radius: CGFloat, border: CGFloat = 3, depth: CGFloat = 3,
                       shade: Color = LightSheet.whiteShade) -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// The green coin badge shared across the earn views — a coin + value in a soft
/// green pill (e.g. 🪙 30, 🪙 1 / rep, 🪙 26).
struct CoinBadge: View {
    var text: String

    var body: some View {
        // No pill, no green: it was the one trailing value in the app inside a
        // container and in its own colour. Reads as every other row's value now.
        HStack(spacing: 4) {
            Image("AuraCoinIcon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 14, height: 14)
            Text(text)
                .auraFont(.body, RowType.value, .medium)
                .foregroundStyle(RowType.valueColor)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Settings sheet kit
//
// The Difficulty / Reminders / Screen Time sheets are the same shape: a
// centred title with a subtitle, then one or more toggle cards. These two
// pieces keep them identical instead of three near-copies.

/// Centred sheet title + subtitle, positioned to match the Help sheet's hero.
struct LightSheetTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Text(title)
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(SheetType.titleColor)
            Text(subtitle)
                .auraFont(.body, SheetType.subtitle, .regular)
                .foregroundStyle(SheetType.subtitleColor)
                .multilineTextAlignment(.center)
                // Keeps its full height on a fixed-height sheet. Without this
                // SwiftUI squeezes it to one line and truncates when the sheet
                // runs short.
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        // Help's scroll inset (l) plus its hero inset (m), so every sheet's
        // title lands at the same height.
        .padding(.top, Theme.Spacing.l + Theme.Spacing.m)
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

/// A white card holding a sticker, a title, a toggle, and a line of
/// explanation — the Difficulty sheet's card.
struct SettingToggleCard: View {
    let sticker: String
    let title: String
    let blurb: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(sticker)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 38, height: 38)

            // Title over blurb, stacked to the right of the icon rather than
            // the blurb running full-width under it.
            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(title)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(SheetType.titleColor)
                Text(blurb)
                    .auraFont(.body, SheetType.cardBlurb, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    // One line, one size across every card. Subtitles are
                    // written short enough to fit, so nothing shrinks or wraps.
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Spacing.s)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(Theme.Color.signalGood)
                // A settings toggle is a meaningful action (DESIGN.md §7): confirm
                // it with a light haptic. Every SettingToggleCard gets this.
                .onChange(of: isOn) { _, _ in Haptics.impact(.light) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.l)
        .bottomDropCard(radius: Theme.Radius.card)
    }
}

/// The shell every settings sheet shares: white surface, drag capsule, title
/// block, then a scrolling stack of cards.
struct SettingsSheetScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    /// The family's short detent. A sheet with more than a couple of cards
    /// passes its own rather than scrolling inside a 420pt window.
    var detent: PresentationDetent = .height(420)
    @ViewBuilder var content: Content

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()
                LightSheetTitle(title: title, subtitle: subtitle)

                ScrollView(showsIndicators: false) {
                    // Tighter between cards than between the subtitle and the
                    // first one, so a group reads as a set.
                    VStack(spacing: Theme.Spacing.m) { content }
                        .padding(.horizontal, Theme.Spacing.xl)
                        .padding(.top, Theme.Spacing.xxl)
                        .padding(.bottom, Theme.Spacing.xxl)
                }
            }
        }
        // The short detent the rest of the sheet family uses (Target Time, App
        // Lists, the break sheets). These hold a couple of cards at most, so a
        // full-height sheet would be mostly empty; the ScrollView covers the
        // case where a settings sheet grows past it.
        .presentationDetents([detent])
        .presentationDragIndicator(.hidden)
    }
}


extension View {
    /// The soft ground under a control floating on a camera feed or a photo.
    ///
    /// Lifted from `CreateHabitButton`'s FAB, where a disc sits on a shallow
    /// ellipse of translucent black. Over a live feed the discs need it more
    /// than they do on a flat field: without it a dark frame swallows them
    /// completely.
    ///
    /// Shared by both cameras. It started life private to Photo Proof, which is
    /// how Camera Reps ended up with bare buttons on a different token.
    /// Padded as a FRACTION of the control's diameter, not by fixed spacing.
    ///
    /// The FAB's halo is 16 and 8 around a 62pt disc, which is where this came
    /// from. Copying those numbers onto a 36pt button gave a 1.36:1 ellipse
    /// against the FAB's 1.20:1, and copying them onto the 72pt shutter gave a
    /// circle. Same object, three shapes. Scaling the padding keeps the shape
    /// and lets the size follow whatever it is wrapped around.
    ///
    /// Off the 4-grid on purpose: these are derived from another component's
    /// proportion rather than chosen, and rounding them to the grid is what
    /// broke the shape in the first place.
    func photoHalo(diameter: CGFloat = CircleIconButton.Grade.chrome.diameter) -> some View {
        padding(.horizontal, diameter * 0.258)
            .padding(.vertical, diameter * 0.129)
            .background(Ellipse().fill(.black.opacity(0.12)))
    }
}


extension View {
    /// Every Aura sheet's presentation, in one place.
    ///
    /// `.preferredColorScheme(.light)` is the part that matters and the part
    /// nobody remembers. Aura's sheets are white, but several are presented
    /// FROM screens that force `.dark` so a coloured header gets white
    /// status-bar glyphs — and a sheet inherits its presenter's scheme. Any
    /// control that colours itself from the system appearance then renders
    /// white on white: the routine sheet's time wheel was invisible, and
    /// `WheelPickerSheet` carries a comment about hitting the same thing and
    /// working around it row by row.
    ///
    /// Forgetting this is invisible in a Preview and invisible on any screen
    /// that doesn't set `.dark`, so it only shows up on the one path somebody
    /// happens to walk. Bundling it with the detent means a sheet cannot be
    /// presented without it.
    func auraSheet(_ detents: Set<PresentationDetent>) -> some View {
        presentationDetents(detents)
            // Aura draws its own drag capsule in the header; the system was
            // adding a second one above it.
            .presentationDragIndicator(.hidden)
            .preferredColorScheme(.light)
    }
}
