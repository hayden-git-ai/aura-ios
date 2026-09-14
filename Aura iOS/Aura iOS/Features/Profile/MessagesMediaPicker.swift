//
//  MessagesMediaPicker.swift
//  Aura iOS
//
//  The Apple Messages style media attachment for the support composer: an inline,
//  horizontally-scrolling grid of recent photos and videos shown BELOW the input
//  row, and a strip of the picked thumbnails shown ABOVE it. No modal photo sheet.
//
//  `RecentMediaStore` owns Photos access, the recent-asset fetch, and thumbnail /
//  export helpers. `InlineMediaGrid` is the picker grid; `SelectedMediaStrip` is
//  the row of chosen items. Selection is an ordered `[PHAsset]` the composer owns.
//

import Photos
import SwiftUI
import UIKit

// MARK: - Store

/// A photo album / collection surfaced in the picker's Collections tab.
struct MediaCollection: Identifiable {
    let id: String
    let title: String
    let count: Int
    let cover: PHAsset?
    let collection: PHAssetCollection
}

@MainActor
@Observable
final class RecentMediaStore {
    private(set) var assets: [PHAsset] = []
    private(set) var collections: [MediaCollection] = []
    private(set) var status: PHAuthorizationStatus = .notDetermined
    private let imageManager = PHCachingImageManager()
    private let allowsVideos: Bool

    init(allowsVideos: Bool = true) {
        self.allowsVideos = allowsVideos
    }

    var authorized: Bool { status == .authorized || status == .limited }

    /// Requests access (once) and loads the most recent photos + videos.
    func load() async {
        if status == .notDetermined {
            status = await withCheckedContinuation { cont in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { cont.resume(returning: $0) }
            }
        } else {
            status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        }
        guard authorized else { return }
        loadAssets(in: nil)
    }

    /// Loads the grid from a specific album, or the whole library (recents) when
    /// `collection` is nil.
    func loadAssets(in collection: PHAssetCollection?) {
        guard authorized else { return }
        let opts = PHFetchOptions()
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 300
        opts.predicate = mediaPredicate
        let result = collection.map { PHAsset.fetchAssets(in: $0, options: opts) }
            ?? PHAsset.fetchAssets(with: opts)
        var out: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in out.append(asset) }
        assets = out
    }

    /// Fetches the user's albums (smart albums + user albums), each with a cover and
    /// a count, skipping empties. Populates `collections`.
    func loadCollections() {
        guard authorized else { return }
        var out: [MediaCollection] = []
        let media = PHFetchOptions()
        media.predicate = mediaPredicate
        media.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        func collect(_ fetch: PHFetchResult<PHAssetCollection>) {
            fetch.enumerateObjects { coll, _, _ in
                let assets = PHAsset.fetchAssets(in: coll, options: media)
                guard assets.count > 0 else { return }
                out.append(MediaCollection(
                    id: coll.localIdentifier,
                    title: coll.localizedTitle ?? "Album",
                    count: assets.count,
                    cover: assets.firstObject,
                    collection: coll))
            }
        }

        // Favourites + a few useful smart albums first, then the user's own albums.
        let smartTypes: [PHAssetCollectionSubtype] = [
            .smartAlbumFavorites, .smartAlbumRecentlyAdded, .smartAlbumSelfPortraits,
            .smartAlbumScreenshots, .smartAlbumVideos, .smartAlbumBursts,
            .smartAlbumPanoramas, .smartAlbumLivePhotos,
        ]
        for t in smartTypes {
            collect(PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: t, options: nil))
        }
        collect(PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil))
        collections = out
    }

    private var mediaPredicate: NSPredicate {
        if allowsVideos {
            return NSPredicate(
                format: "mediaType == %d OR mediaType == %d",
                PHAssetMediaType.image.rawValue, PHAssetMediaType.video.rawValue)
        }
        return NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
    }

    /// A thumbnail for a grid/strip cell. `highQualityFormat` fires the handler
    /// exactly once, so the continuation is safe.
    func thumbnail(for asset: PHAsset, size: CGSize) async -> UIImage? {
        await withCheckedContinuation { cont in
            var resumed = false
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            opts.resizeMode = .fast
            imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: opts) { image, _ in
                if !resumed { resumed = true; cont.resume(returning: image) }
            }
        }
    }

    /// Full-resolution image bytes, normalised to JPEG for upload.
    func exportImageJPEG(_ asset: PHAsset) async -> Data? {
        await withCheckedContinuation { cont in
            var resumed = false
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isNetworkAccessAllowed = true
            opts.version = .current
            imageManager.requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                if resumed { return }
                resumed = true
                if let data, let img = UIImage(data: data) {
                    cont.resume(returning: img.jpegData(compressionQuality: 0.8))
                } else {
                    cont.resume(returning: data)
                }
            }
        }
    }

    /// Writes the original video file to a temp URL and returns its bytes. Videos
    /// can be large; a size guard lives at the call site.
    func exportVideoData(_ asset: PHAsset) async -> Data? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .video || $0.type == .fullSizeVideo }) else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        let opts = PHAssetResourceRequestOptions()
        opts.isNetworkAccessAllowed = true
        let ok: Bool = await withCheckedContinuation { cont in
            PHAssetResourceManager.default().writeData(for: resource, toFile: tmp, options: opts) { error in
                cont.resume(returning: error == nil)
            }
        }
        guard ok else { return nil }
        defer { try? FileManager.default.removeItem(at: tmp) }
        return try? Data(contentsOf: tmp)
    }
}

// MARK: - Duration formatting

private func durationLabel(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    return String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - Grid

/// The vertically-scrolling grid of recent media. It simply FILLS whatever frame it
/// is given — the enclosing black sheet owns the size and rounded corners. Photos
/// run edge-to-edge (3 columns, hairline gaps), Apple-Messages style. Tapping a cell
/// toggles it in `selection`.
struct InlineMediaGrid: View {
    let store: RecentMediaStore
    @Binding var selection: [PHAsset]

    let cols = 3
    private let gap: CGFloat = 2

    /// The square cell edge for a full-bleed 3-up grid, so callers can size the
    /// sheet to a whole number of rows.
    static func cellSide(width: CGFloat, cols: Int = 3, gap: CGFloat = 2) -> CGFloat {
        (width - gap * CGFloat(cols - 1)) / CGFloat(cols)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: gap), count: cols)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: gap) {
                ForEach(store.assets, id: \.localIdentifier) { asset in
                    MediaCell(
                        store: store,
                        asset: asset,
                        selectionIndex: selection.firstIndex(where: { $0.localIdentifier == asset.localIdentifier })
                    )
                    .onTapGesture { toggle(asset) }
                }
            }
        }
        // The photos fill the sheet to the very top — no inherited safe-area inset
        // leaving a black strip above the first row.
        .contentMargins(.vertical, 0, for: .scrollContent)
        .scrollClipDisabled(false)
    }

    private func toggle(_ asset: PHAsset) {
        if let i = selection.firstIndex(where: { $0.localIdentifier == asset.localIdentifier }) {
            selection.remove(at: i)
        } else {
            selection.append(asset)
        }
    }
}

private struct MediaCell: View {
    let store: RecentMediaStore
    let asset: PHAsset
    let selectionIndex: Int?

    @State private var thumb: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let thumb {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.white.opacity(0.06))
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if asset.mediaType == .video {
                    Text(durationLabel(asset.duration))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(5)
                }
            }
            .overlay {
                if selectionIndex != nil { Color.black.opacity(0.22) }
            }
            .overlay(alignment: .bottomTrailing) {
                if let index = selectionIndex {
                    ZStack {
                        Circle().fill(LightSheet.blue)
                        Circle().strokeBorder(.white, lineWidth: 1.5)
                        Text("\(index + 1)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    }
                    .frame(width: 22, height: 22)
                    .padding(6)
                }
            }
            .task(id: asset.localIdentifier) {
                thumb = await store.thumbnail(for: asset, size: CGSize(width: 260, height: 260))
            }
    }
}

// MARK: - Selected strip

/// The row of chosen thumbnails shown ABOVE the input, each removable, scrolling
/// horizontally when there are more than fit.
struct SelectedMediaStrip: View {
    let store: RecentMediaStore
    @Binding var selection: [PHAsset]

    private let side: CGFloat = 64

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selection, id: \.localIdentifier) { asset in
                    SelectedThumb(store: store, asset: asset, side: side) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selection.removeAll { $0.localIdentifier == asset.localIdentifier }
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
    }
}

private struct SelectedThumb: View {
    let store: RecentMediaStore
    let asset: PHAsset
    let side: CGFloat
    let onRemove: () -> Void

    @State private var thumb: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                if let thumb {
                    Image(uiImage: thumb).resizable().scaledToFill()
                } else {
                    Rectangle().fill(Color.white.opacity(0.08))
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(alignment: .bottomTrailing) {
                if asset.mediaType == .video {
                    Image(systemName: "video.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white).shadow(radius: 2).padding(4)
                }
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .padding(2)
        }
        .task(id: asset.localIdentifier) {
            thumb = await store.thumbnail(for: asset, size: CGSize(width: side * 2, height: side * 2))
        }
    }
}
