//
//  CustomPhotoLibraryPicker.swift
//  Aura iOS
//

import Photos
import SwiftUI
import UIKit

/// Aura's own photo picker, in the Instagram shape: a circular crop preview up
/// top (pan + pinch to position), a confirm check, then the recents grid below.
/// Tapping a grid photo loads it into the crop; the check renders exactly what's
/// framed and hands it back.
struct CustomPhotoLibraryPicker: View {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var status: PHAuthorizationStatus = .notDetermined
    @State private var selectedID: String?
    @State private var selectedImage: UIImage?

    // Crop transform for the preview.
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// The crop preview is a full-width square (edge to edge, like Instagram), so
    /// its side equals the screen width. Measured from the layout rather than
    /// hard-coded; the fallback covers the first frame before measurement.
    @State private var cropSide: CGFloat = 320

    // One-off picker sizes (DESIGN.md §2: named constants, never bare literals).
    /// The hairline gap between photo tiles (an Instagram-style grid, deliberately
    /// tighter than the 4pt scale so photos read as one contact sheet).
    private static let gridGap: CGFloat = 2
    /// The crop ring's inset and the selection ring's stroke.
    private static let cropRingInset: CGFloat = 6
    private static let selectionStroke: CGFloat = 3
    private let columns = Array(repeating: GridItem(.flexible(), spacing: gridGap), count: 3)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LightSheet.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if status == .denied || status == .restricted {
                        deniedState
                    } else {
                        cropArea
                        recentsHeader
                        grid
                    }
                }
            }
            // The crop is a full-width square; pin its side to the real container
            // width so it never shrinks to fit leftover vertical space.
            .onAppear { cropSide = geo.size.width }
            .onChange(of: geo.size.width) { _, w in cropSide = w }
        }
        .onAppear(perform: load)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Library")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(SheetType.titleColor)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SheetType.titleColor)
                        .frame(width: 40, height: 40)
                        .background(LightSheet.chromeOnLight, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(PressBounceStyle())

                Spacer()

                Button { confirm() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(LightSheet.blue, in: Circle())
                        // 40pt disc inside a 44pt hit area (DESIGN.md §8).
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(PressBounceStyle())
                .disabled(selectedImage == nil)
                .opacity(selectedImage == nil ? 0.4 : 1)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.s)
    }

    // MARK: - Crop preview

    private var cropArea: some View {
        // A full-width square (edge to edge). `cropSide` is the real container
        // width, so the saved render (see `confirm`) matches what's framed here.
        cropContent
            .overlay {
                // Dim outside the circle + a hairline ring, so it reads as a
                // circular crop the way the avatar will.
                Rectangle()
                    .fill(LightSheet.bg.opacity(0.55))
                    .reverseMask { Circle().padding(Self.cropRingInset) }
                    .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2).padding(Self.cropRingInset) }
                    .allowsHitTesting(false)
            }
            .frame(width: cropSide, height: cropSide)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { g in
                        offset = CGSize(width: lastOffset.width + g.translation.width,
                                        height: lastOffset.height + g.translation.height)
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in scale = max(1, lastScale * value) }
                    .onEnded { _ in lastScale = scale }
            )
            .padding(.bottom, Theme.Spacing.m)
    }

    /// Exactly what gets rendered on confirm — the transformed image in a square,
    /// clipped. No overlays, so the saved photo is just the framed picture.
    private var cropContent: some View {
        ZStack {
            Color.black
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(offset)
            }
        }
        .frame(width: cropSide, height: cropSide)
        .clipped()
    }

    // MARK: - Grid

    private var recentsHeader: some View {
        Text("Recents")
            .auraFont(.body, SheetType.cardTitle, .bold)
            .foregroundStyle(SheetType.titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.s)
    }

    private var grid: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: Self.gridGap) {
                ForEach(assets, id: \.localIdentifier) { asset in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { PhotoThumbnail(asset: asset) }
                        .overlay {
                            if asset.localIdentifier == selectedID {
                                Rectangle().strokeBorder(LightSheet.blue, lineWidth: Self.selectionStroke)
                            }
                        }
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            Haptics.impact(.light)
                            select(asset)
                        }
                }
            }
            .padding(.horizontal, Self.gridGap)
        }
    }

    private var deniedState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 40))
                .foregroundStyle(LightSheet.subtitle)
            Text("Photo access is off")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(SheetType.titleColor)
            Text("Turn on Photos access for Aura in Settings to pick a picture.")
                .auraFont(.body, SheetType.subtitle, .regular)
                .foregroundStyle(LightSheet.subtitle)
                .multilineTextAlignment(.center)

            // A real recovery path (DESIGN.md §8 native feel, error-recovery).
            LightPrimaryButton(title: "Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .padding(.top, Theme.Spacing.s)
            .padding(.horizontal, Theme.Spacing.xl)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Library

    private func load() {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                DispatchQueue.main.async {
                    status = newStatus
                    if newStatus == .authorized || newStatus == .limited { fetch() }
                }
            }
        } else {
            status = current
            if current == .authorized || current == .limited { fetch() }
        }
    }

    private func fetch() {
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        opts.fetchLimit = 300
        let result = PHAsset.fetchAssets(with: opts)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in list.append(asset) }
        assets = list
        if let first = list.first { select(first) }   // land on the newest, framed
    }

    private func select(_ asset: PHAsset) {
        selectedID = asset.localIdentifier
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero

        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.resizeMode = .exact
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1400, height: 1400),
            contentMode: .aspectFit,
            options: opts
        ) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            if let image, !degraded { selectedImage = image }
        }
    }

    @MainActor private func confirm() {
        let renderer = ImageRenderer(content: cropContent)
        renderer.scale = 3
        if let image = renderer.uiImage {
            Haptics.impact(.medium)
            onImage(image)
            dismiss()
        }
    }
}

/// One square grid cell that loads its own thumbnail from the asset.
private struct PhotoThumbnail: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(LightSheet.track)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .onAppear { loadThumb(pointSize: geo.size) }
        }
    }

    private func loadThumb(pointSize: CGSize) {
        let scale: CGFloat = 2
        let target = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.resizeMode = .fast
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(for: asset, targetSize: target,
                                              contentMode: .aspectFill, options: opts) { img, _ in
            if let img { image = img }
        }
    }
}
