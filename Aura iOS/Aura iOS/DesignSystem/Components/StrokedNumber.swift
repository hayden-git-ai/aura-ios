//
//  StrokedNumber.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// The outline weight every stroked numeral in the app derives from.
///
/// Set by the Home countdown: 34pt of glyph carrying a 3pt outline, or 8.8%.
/// The streak badge beside it was on 2.2/14 — 15.7% — so at 18pt it wore nearly
/// twice the outline relative to its own size and read as visibly the heavier
/// of the two, sitting inches apart on the same screen.
enum StrokedNumeral {
    static let outlineRatio: CGFloat = 3.0 / 34
}

/// A single-line numeral with a clean outer outline: the dark outline is
/// stroked first, then the fill is drawn on top so it covers the inner half of
/// the stroke (no dark bleeding into the glyph). SwiftUI's `Text` can't do this,
/// so it drops to a custom `UILabel`.
struct StrokedNumber: UIViewRepresentable {
    let text: String
    let font: UIFont
    let fill: UIColor
    let stroke: UIColor
    /// Visible outer outline thickness, in points.
    let outlineWidth: CGFloat
    /// Extra space between glyphs. Defaults to the font's own spacing.
    var tracking: CGFloat = 0

    func makeUIView(context: Context) -> OutlinedLabel {
        let label = OutlinedLabel()
        label.textAlignment = .center
        label.clipsToBounds = false
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        // Configure the label before SwiftUI can place its first frame. Leaving
        // UIKit's default black text in the newly-created view caused timers to
        // flash solid black until the first update pass supplied their colors.
        configure(label)
        return label
    }

    func updateUIView(_ label: OutlinedLabel, context: Context) {
        configure(label)
    }

    private func configure(_ label: OutlinedLabel) {
        label.font = font
        label.fillColor = fill
        // UILabel can be composited before its first drawText pass. Keep its
        // native foreground in the final fill color too, so that first frame
        // can never expose UIKit's default black text.
        label.textColor = fill
        label.outlineColor = stroke
        label.outlineWidth = outlineWidth
        if tracking == 0 {
            label.attributedText = nil
            label.text = text
        } else {
            // Kern on the last glyph would pad the trailing edge and push the
            // whole label off-center, so it stops one short.
            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [.font: font, .kern: tracking]
            )
            if !text.isEmpty {
                attributed.removeAttribute(.kern, range: NSRange(location: text.count - 1, length: 1))
            }
            label.attributedText = attributed
        }
        label.invalidateIntrinsicContentSize()
        label.setNeedsDisplay()
    }
}

/// UILabel that strokes an outline then fills on top — an outer-only outline.
final class OutlinedLabel: UILabel {
    var fillColor: UIColor = .white
    var outlineColor: UIColor = .black
    var outlineWidth: CGFloat = 0

    // Reserve room so the outline isn't clipped by the layout box.
    //
    // Width rounded up to an EVEN whole number. A fractional or odd intrinsic
    // width leaves the label's centre on a half-pixel when its parent centres
    // it, which rounds one pixel to the left — visible on the Home streak
    // numeral sitting under the flame.
    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        func evenUp(_ v: CGFloat) -> CGFloat { let n = ceil(v); return n.truncatingRemainder(dividingBy: 2) == 0 ? n : n + 1 }
        return CGSize(width: evenUp(base.width + outlineWidth * 2),
                      height: ceil(base.height + outlineWidth * 2))
    }

    override func drawText(in rect: CGRect) {
        guard outlineWidth > 0, let ctx = UIGraphicsGetCurrentContext() else {
            textColor = fillColor
            super.drawText(in: rect)
            return
        }
        // Stroke pass: half of this width sits outside the glyph edge, which is
        // the part that stays visible after the fill covers the inner half.
        ctx.setLineWidth(outlineWidth * 2)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.setTextDrawingMode(.stroke)
        textColor = outlineColor
        super.drawText(in: rect)
        // Fill pass on top.
        ctx.setTextDrawingMode(.fill)
        textColor = fillColor
        super.drawText(in: rect)
    }
}
