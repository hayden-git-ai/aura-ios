//
//  AppIconView.swift
//  Aura iOS
//

import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

/// System artwork is rendered on its native canvas, then scaled to Aura's tile.
/// Token identity also owns the remote view, preventing stale artwork on reuse.
struct AppIconView: View {
    let source: AppIconSource
    let side: CGFloat

    var body: some View {
        switch source {
        case .asset(let name):
            Image(name)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)

        case .token(let token, _, _):
            if let bundleIdentifier = source.bundleIdentifier {
                AppStoreArtworkView(bundleIdentifier: bundleIdentifier, side: side) {
                    FittedSystemIcon(side: side) { Label(token).labelStyle(.iconOnly).id(source.stableID) }
                }
            } else {
                FittedSystemIcon(side: side) { Label(token).labelStyle(.iconOnly).id(source.stableID) }
            }
        case .category(let token, _):
            FittedSystemIcon(side: side) { Label(token).labelStyle(.iconOnly).id(source.stableID) }
        case .webDomain(let token, _):
            FittedSystemIcon(side: side) { Label(token).labelStyle(.iconOnly).id(source.stableID) }
        }
    }
}

/// Apple's token view only supplies a 20pt raster. When Family Controls gives
/// Aura a bundle identifier, use Apple's public catalog artwork at the same
/// approved layout size and keep the token view as the offline/missing fallback.
struct AppStoreArtworkView<Fallback: View>: View {
    let bundleIdentifier: String
    let side: CGFloat
    @ViewBuilder let fallback: () -> Fallback

    @State private var artworkURL: URL?

    var body: some View {
        Group {
            if let artworkURL {
                AsyncImage(url: artworkURL, transaction: Transaction(animation: nil)) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    } else {
                        fallback()
                    }
                }
            } else {
                fallback()
            }
        }
        .frame(width: side, height: side)
        .task(id: bundleIdentifier) {
            artworkURL = await AppStoreArtworkResolver.shared.artworkURL(for: bundleIdentifier)
        }
    }
}

private actor AppStoreArtworkResolver {
    static let shared = AppStoreArtworkResolver()

    private var cache: [String: URL?] = [:]

    func artworkURL(for bundleIdentifier: String) async -> URL? {
        if let cached = cache[bundleIdentifier] { return cached }

        var components = URLComponents(string: "https://itunes.apple.com/lookup")
        components?.queryItems = [
            URLQueryItem(name: "bundleId", value: bundleIdentifier),
            URLQueryItem(name: "country", value: Locale.current.region?.identifier ?? "US"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components?.url else {
            cache[bundleIdentifier] = nil
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                cache[bundleIdentifier] = nil
                return nil
            }
            let result = try JSONDecoder().decode(AppStoreLookupResponse.self, from: data)
            let artworkURL = result.results.first?.artworkURL
            cache[bundleIdentifier] = artworkURL
            return artworkURL
        } catch {
            cache[bundleIdentifier] = nil
            return nil
        }
    }
}

private struct AppStoreLookupResponse: Decodable {
    struct Result: Decodable {
        let artworkUrl512: URL?
        let artworkUrl100: URL?

        var artworkURL: URL? {
            artworkUrl512 ?? artworkUrl100.flatMap { url in
                URL(string: url.absoluteString.replacingOccurrences(of: "100x100", with: "512x512"))
            }
        }
    }

    let results: [Result]
}

/// Give the remote system icon a fixed rendering canvas before scaling it.
/// Its reported ideal layout size includes space outside the artwork, so
/// measuring that size and scaling against it leaves the actual icon tiny.
private struct FittedSystemIcon<Icon: View>: View {
    let side: CGFloat
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        icon()
            .frame(width: 20, height: 20)
            .scaleEffect(side / 20)
            .frame(width: side, height: side)
            .clipped()
    }
}

/// A title needs a real proposed width. FamilyActivityTitleView's ideal size
/// is not its eventual text width; fixedSize can collapse it to one character.
struct AppNameLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            configuration.title
                .frame(width: geometry.size.width, height: geometry.size.height)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(Color.black)
                .environment(\.colorScheme, .light)
        }
        .frame(height: 40)
    }
}

struct AppNameView: View {
    let source: AppIconSource

    var body: some View {
        Group {
            if let displayName = source.displayName {
                Text(displayName)
                    .frame(maxWidth: .infinity, minHeight: 40)
            } else {
                GeometryReader { geometry in
                    CenteredSystemTitle(source: source, width: geometry.size.width)
                        .frame(width: geometry.size.width, height: 40)
                }
                .frame(height: 40)
            }
        }
        .id(source.stableID)
        .auraFont(.body, 13, .semibold)
        .foregroundStyle(Color.black)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .environment(\.colorScheme, .light)
    }
}

/// FamilyActivityTitleView paints at the leading edge of every proposed width,
/// and asking it for an ideal width can collapse the remote view to one letter.
/// Render once at the real two-line width, crop only transparent margins, then
/// display that complete title centered. This uses public rendering APIs and
/// never inspects the framework's private view hierarchy.
private struct CenteredSystemTitle: UIViewRepresentable {
    let source: AppIconSource
    let width: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let width = max(1, width)
        let identity = source.stableID
        guard width > 1,
              context.coordinator.identity != identity || context.coordinator.width != width else {
            return
        }

        context.coordinator.identity = identity
        context.coordinator.width = width
        view.subviews.forEach { $0.removeFromSuperview() }

        let title = nativeTitle(width: width)
        let host = UIHostingController(rootView: title)
        host.view.backgroundColor = .clear
        // UIViewRepresentable has no intrinsic content size, so SwiftUI places
        // its UIKit origin at the centre of the reserved frame. Centre the
        // hosted title canvas around that origin instead of starting there.
        let titleFrame = CGRect(x: -width / 2, y: -20, width: width, height: 40)
        host.view.frame = titleFrame
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        context.coordinator.host = host

        let imageView = UIImageView(frame: titleFrame)
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .center
        imageView.backgroundColor = .clear
        view.addSubview(imageView)

        let generation = context.coordinator.nextGeneration()
        Task { @MainActor in
            for delay in [80, 250, 600] {
                try? await Task.sleep(for: .milliseconds(delay))
                guard context.coordinator.generation == generation,
                      context.coordinator.identity == identity else { return }
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                if let image = Self.croppedSnapshot(of: host.view), image.size.width > 4 {
                    imageView.image = image
                    host.view.isHidden = true
                }
            }
        }
    }

    private func nativeTitle(width: CGFloat) -> AnyView {
        let body: AnyView
        switch source {
        case .asset:
            body = AnyView(EmptyView())
        case .token(let token, _, _):
            body = AnyView(Label(token).labelStyle(.titleOnly).id(source.stableID))
        case .category(let token, _):
            body = AnyView(Label(token).labelStyle(.titleOnly).id(source.stableID))
        case .webDomain(let token, _):
            body = AnyView(Label(token).labelStyle(.titleOnly).id(source.stableID))
        }
        return AnyView(
            body
                .auraFont(.body, 13, .semibold)
                .foregroundStyle(Color.black)
                .lineLimit(2)
                .frame(width: width, height: 40, alignment: .leading)
                .environment(\.colorScheme, .light)
        )
    }

    private static func croppedSnapshot(of view: UIView) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = view.window?.screen.scale ?? UIScreen.main.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: format)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        guard let cgImage = image.cgImage,
              let crop = paintedBounds(in: cgImage),
              let cropped = cgImage.cropping(to: crop) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private static func paintedBounds(in image: CGImage) -> CGRect? {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                if pixels[offset + 3] > 24 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let padding = 2
        let x = max(0, minX - padding)
        let y = max(0, minY - padding)
        let right = min(width, maxX + padding + 1)
        let bottom = min(height, maxY + padding + 1)
        return CGRect(x: x, y: y, width: right - x, height: bottom - y)
    }

    final class Coordinator {
        var identity = ""
        var width: CGFloat = 0
        var generation = 0
        var host: UIHostingController<AnyView>?

        func nextGeneration() -> Int {
            generation += 1
            return generation
        }
    }
}

struct AppRowLabel: View {
    let source: AppIconSource
    let side: CGFloat

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            AppIconView(source: source, side: side).appIconChrome(side: side)
            AppNameView(source: source)
        }
    }
}

/// Independent icon/title labels prevent the icon's 20pt rendering proposal
/// from constraining the system title to the same tiny width.
struct AppTileLabel: View {
    let source: AppIconSource
    let side: CGFloat

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            AppIconView(source: source, side: side).appIconChrome(side: side)
            AppNameView(source: source)
        }
        .frame(maxWidth: .infinity)
    }
}
