//
//  WallOfWins.swift
//  Aura iOS
//

import SwiftUI

/// One captured proof photo.
///
/// `asset` is a placeholder: real wins are photographs, which have to be written
/// to disk and referenced by filename — this app has no persistence yet, so the

/// Every win, three across. Tapping one opens it; the trash empties the wall.
struct WallOfWinsSheet: View {
    @Environment(HabitStore.self) private var store
    @State private var selected: Win?
    @State private var confirmingWipe = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 3)

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                ZStack {
                    LightSheetTitle(
                        title: "Wall of wins",
                        subtitle: store.wins.isEmpty
                            ? "Every habit you prove shows up here."
                            : "\(store.wins.count) win\(store.wins.count == 1 ? "" : "s") captured."
                    )

                    if !store.wins.isEmpty {
                        HStack {
                            Spacer()
                            CircleIconButton(symbol: "trash.fill",
                                             glyphColor: LightSheet.danger) {
                                confirmingWipe = true
                            }
                            .padding(.trailing, Theme.Spacing.xl)
                        }
                    }
                }

                if store.wins.isEmpty {
                    WinsEmptyState()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: Theme.Spacing.s) {
                        ForEach(store.wins) { win in
                            Button {
                                Haptics.impact(.light)
                                selected = win
                            } label: {
                                WinTile(win: win)
                            }
                            .buttonStyle(PressBounceStyle(hapticsEnabled: false))
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.xxl)
                }
                }
            }
        }
        .presentationDragIndicator(.hidden)
        // A cover, not a sheet: the photo is edge-to-edge, and a sheet's inset
        // card would clip it at the corners.
        .fullScreenCover(item: $selected) { win in
            WinDetailView(win: win) { store.deleteWin(win) }
                .preferredColorScheme(.dark)
        }
        .alert("Delete all wins?", isPresented: $confirmingWipe) {
            Button("Delete All", role: .destructive) { store.deleteAllWins() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All \(store.wins.count) photos will be deleted for good. This can't be undone.")
        }
    }

}

/// What the wall says before there is one — used both on the full sheet and
/// inline under the Wall of Wins strip on the main screen, so an empty wall
/// reads the same in both places rather than one showing art and the other
/// a blank gap. Callers add their own vertical framing: the sheet centres it in
/// the whole body, the strip gives it a little breathing room.
struct WinsEmptyState: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Text("No wins yet")
                .auraFont(.display, SheetType.cardTitle, .bold)
                .foregroundStyle(SheetType.titleColor)

            Text("Complete a healthy habit with photo-verification and you'll see it here.")
                .auraFont(.body, SheetType.cardBlurb, .regular)
                .foregroundStyle(SheetType.subtitleColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.xl)
    }
}

/// A single win. 3:4 because that's what the camera produces — the capture
/// runs at `.photo`, which is the sensor's 4:3, so a portrait shot fits with no
/// crop. The caption rides on the photo rather than under it, so a row of them
/// stays a wall of pictures.
struct WinTile: View {
    let win: Win

    var body: some View {
        ZStack(alignment: .bottom) {
            WinPhotoView(photo: win.photo)

            VStack(alignment: .leading, spacing: RowType.labelGap) {
                Text(win.habit)
                    .auraFont(.body, RowType.subLabel, .semibold)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(Self.dayLabel(win.date))
                    .auraFont(.body, 11, .medium)
                    .foregroundStyle(LightSheet.onColour)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.s)
            .background(.black.opacity(0.55))
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
        // The Apps lane-card depth; the wall strip pads its scroll vertically so
        // this isn't sliced off at the tile edges (see the wallOfWins section).
        .shadow(color: .black.opacity(0.16), radius: 20, y: 11)
        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
    }

    /// The two days you'd recognise get their names; everything older gets a
    /// date. "Aug 7" doesn't tell you it was yesterday.
    static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return stamp.string(from: date)
    }

    static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

/// One win, full size. The photo is the view; the label and the trash float on
/// it under a scrim, so nothing has to be redesigned when real photographs
/// replace the placeholders.
struct WinDetailView: View {
    let win: Win
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            GeometryReader { proxy in
                WinPhotoView(photo: win.photo, bundledPadding: Theme.Spacing.xxxl)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            // Darkens the foot of the photo so the label reads on it whatever
            // the picture happens to be. A gradient rather than a bar: the
            // caption sits *in* the photo instead of under it.
            LinearGradient(
                colors: [.clear, .black.opacity(0.65)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 260)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)

            // Sticker on top and much larger, so the block reads object →
            // habit → date instead of two same-weight things side by side.
            VStack(spacing: Theme.Spacing.m) {
                Image(win.icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(-10))

                VStack(spacing: RowType.labelGap) {
                    Text(win.habit)
                        .auraFont(.display, 28, .bold)
                        .foregroundStyle(.white)
                    Text(Self.dayLabel(win.date))
                        .auraFont(.body, SheetType.cardTitle, .medium)
                        .foregroundStyle(LightSheet.onColour)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, Theme.Spacing.xxl)
            .overlay(alignment: .topLeading) {
                CircleIconButton(symbol: "xmark",
                                 fill: LightSheet.chromeOnPhoto, glyphColor: .white) {
                    dismiss()
                }
                .padding(.leading, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.s)
            }
            .overlay(alignment: .topTrailing) {
                CircleIconButton(symbol: "trash.fill",
                                 fill: .white.opacity(0.88), glyphColor: LightSheet.danger) {
                    confirming = true
                }
                .padding(.trailing, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.s)
            }
        }
        .presentationDragIndicator(.hidden)
        .alert("Delete this win?", isPresented: $confirming) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The photo will be deleted for good. This can't be undone.")
        }
    }

    /// Matches the tiles on the relative days, but keeps the long form for
    /// anything older — there's room for it here.
    static func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return full.string(from: date)
    }

    private static let full: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
}
