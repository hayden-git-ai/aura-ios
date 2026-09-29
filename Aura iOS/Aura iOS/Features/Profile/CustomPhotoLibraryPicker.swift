//
//  CustomPhotoLibraryPicker.swift
//  Aura iOS
//

import Photos
import PhotosUI
import SwiftUI
import UIKit

/// Aura's own photo picker, in the Instagram shape: a circular crop preview up
/// top (pan + pinch to position), a confirm check, then the recents grid below.
/// Tapping a grid photo loads it into the crop; the check renders exactly what's
/// framed and hands it back.
struct CustomPhotoLibraryPicker: View {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var assets: [PHAsset] = []
    @State private var status: PHAuthorizationStatus = .notDetermined
    @State private var selectedID: String?
    @State private var selectedImage: UIImage?
    @State private var selectionRevision = 0

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
    private let columns = Array(repeating: GridItem(.flexible(), spacing: gridGap), count: 4)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LightSheet.bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    if status == .denied || status == .restricted {
                        deniedState
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                cropArea.id("crop")
                                recentsHeader
                                grid
                            }
                            .onChange(of: selectionRevision) { _, _ in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo("crop", anchor: .top)
                                }
                            }
                        }
                    }
                }
            }
            // The crop is a full-width square; pin its side to the real container
            // width so it never shrinks to fit leftover vertical space.
            .onAppear { cropSide = geo.size.width }
            .onChange(of: geo.size.width) { _, w in cropSide = w }
        }
        .onAppear(perform: load)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text("Library")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(SheetType.titleColor)

            HStack {
                Button { Haptics.impact(.light); dismiss() } label: {
                    WoodButtonArtwork(role: .close)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(PressBounceStyle(hapticsEnabled: false))

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
                    .fill(Color.black.opacity(0.62))
                    .reverseMask { Circle().padding(Self.cropRingInset) }
                    .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2).padding(Self.cropRingInset) }
                    .allowsHitTesting(false)
            }
            .frame(width: cropSide, height: cropSide)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { g in
                        offset = boundedOffset(CGSize(width: lastOffset.width + g.translation.width,
                                                      height: lastOffset.height + g.translation.height))
                    }
                    .onEnded { _ in lastOffset = boundedOffset(offset) }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(4, max(1, lastScale * value))
                        offset = boundedOffset(offset)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        lastOffset = boundedOffset(offset)
                        offset = lastOffset
                    }
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
                    .frame(width: fittedImageSize.width, height: fittedImageSize.height)
                    .scaleEffect(scale)
                    .offset(offset)
            }
        }
        .frame(width: cropSide, height: cropSide)
        .clipped()
    }

    private func boundedOffset(_ proposed: CGSize) -> CGSize {
        let horizontal = max(0, (fittedImageSize.width * scale - cropSide) / 2)
        let vertical = max(0, (fittedImageSize.height * scale - cropSide) / 2)
        return CGSize(width: min(horizontal, max(-horizontal, proposed.width)),
                      height: min(vertical, max(-vertical, proposed.height)))
    }

    private var fittedImageSize: CGSize {
        guard let image = selectedImage, image.size.width > 0, image.size.height > 0 else {
            return CGSize(width: cropSide, height: cropSide)
        }
        let fit = max(cropSide / image.size.width, cropSide / image.size.height)
        return CGSize(width: image.size.width * fit, height: image.size.height * fit)
    }

    // MARK: - Grid

    private var recentsHeader: some View {
        HStack {
            Text("Recents")
                .auraFont(.body, SheetType.cardTitle, .bold)
                .foregroundStyle(SheetType.titleColor)
            Spacer()
            if status == .limited {
                Button("Choose more") { Haptics.impact(.light); presentLimitedPicker() }
                    .auraFont(.body, 14, .semibold)
                    .foregroundStyle(LightSheet.blue)
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.vertical, Theme.Spacing.s)
    }

    private var grid: some View {
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
        // Fetch metadata for the entire authorized library; the lazy grid loads
        // thumbnails only as cells become visible.
        let result = PHAsset.fetchAssets(with: opts)
        var list: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in list.append(asset) }
        assets = list
        if !list.contains(where: { $0.localIdentifier == selectedID }) {
            selectedID = nil
            selectedImage = nil
            if let first = list.first { select(first) }
        }
    }

    private func presentLimitedPicker() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let controller = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var presenter = controller
        while let presented = presenter.presentedViewController { presenter = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter) { _ in
            DispatchQueue.main.async { load() }
        }
    }

    private func select(_ asset: PHAsset) {
        selectedID = asset.localIdentifier
        selectedImage = nil
        selectionRevision += 1
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero

        let opts = PHImageRequestOptions()
        opts.deliveryMode = .highQualityFormat
        opts.isNetworkAccessAllowed = true
        opts.resizeMode = .exact
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: max(900, cropSide * 3), height: max(900, cropSide * 3)),
            contentMode: .aspectFit,
            options: opts
        ) { image, info in
            let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            guard selectedID == asset.localIdentifier else { return }
            if let image, !degraded { selectedImage = image }
        }
    }

    @MainActor private func confirm() {
        let diameter = cropSide - Self.cropRingInset * 2
        let renderer = ImageRenderer(content: cropContent.frame(width: diameter, height: diameter).clipped())
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
