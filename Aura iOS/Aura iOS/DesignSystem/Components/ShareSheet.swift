//
//  ShareSheet.swift
//  Aura iOS
//

import LinkPresentation
import SwiftUI
import UIKit

/// The system share sheet, carrying the card and a line of text together.
///
/// `ShareLink` takes a single `Transferable`, which is why the card first went
/// out as an image and nothing else — no text, no link. `UIActivityViewController`
/// takes an array, so both travel in one message.
///
/// Two things it costs, and both are fixed below.
///
/// **The link goes IN the text, not beside it.** Passed as its own `URL` item,
/// several targets decide the whole share is a link and treat the image as an
/// attachment to it, which is backwards: the card is the message and the link
/// is a footnote in it.
///
/// **The preview header is ours.** Given raw items, the sheet builds its own
/// header out of whatever it can infer — a thumbnail of the image and some
/// derived text. `UIActivityItemSource` lets us hand it real metadata instead,
/// so it shows Aura's mark and Aura's title the way `SharePreview` used to.
struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage
    /// Already contains the link. One blob, so it lands as one message.
    let text: String
    let previewTitle: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [CardSource(image: image, title: previewTitle), text],
            applicationActivities: nil
        )
        // Nothing here belongs in a print queue or a contact photo, and leaving
        // them in makes the sheet longer than the useful options.
        controller.excludedActivityTypes = [.assignToContact, .print, .addToReadingList]
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Supplies the image AND the header the share sheet shows above it.
private final class CardSource: NSObject, UIActivityItemSource {
    private let image: UIImage
    private let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    /// A placeholder of the right TYPE, which is all this is asked for. It is
    /// called before the sheet appears, so handing back the real image here
    /// renders it twice.
    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        UIImage()
    }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType type: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewController(_ controller: UIActivityViewController,
                                subjectForActivityType type: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        // Aura's mark rather than a shrunk copy of the card, which is
        // unreadable at the size this thumbnail renders.
        if let icon = UIImage(named: "AuraAppIcon") {
            metadata.iconProvider = NSItemProvider(object: icon)
        }
        return metadata
    }
}
