//
//  AuraWheel.swift
//  Aura iOS
//

import SwiftUI
import AudioToolbox

/// Aura's wheel picker: one highlight pill, the app's own type, and rows that
/// fade toward the ends.
///
/// Not SwiftUI's wheel `Picker`. That one draws a selection indicator of its
/// own that cannot be turned off, so every sheet that wanted the app's
/// highlight ended up with two — Aura's pill and the system's on top of it. It
/// also paints its labels from the system appearance, which is how a white
/// sheet presented from a `.dark` screen produced white text on white.
///
/// Plain scroll views with `.viewAligned` snapping give all of it back: one
/// pill, drawn once behind however many columns there are, and rows we colour
/// ourselves.
enum AuraWheel {
    static let rowHeight: CGFloat = 40
    /// Five rows: the selection, two above, two below. Fewer reads as a
    /// stepper; more turns a sheet into a slot machine.
    static let height: CGFloat = rowHeight * 5

    /// The pill, behind whatever columns sit on it. `fill` overrides the default
    /// track for surfaces that aren't a light sheet (e.g. onboarding's dark
    /// scene, where the pill matches the input-field material instead).
    static func pill(fill: Color = LightSheet.track) -> some View {
        Capsule()
            .fill(fill)
            .frame(height: rowHeight)
    }

    /// Convenience for the common light-sheet pill.
    static var pill: some View { pill() }
}

struct AuraWheelColumn<Value: Hashable>: View {
    let values: [Value]
    @Binding var selection: Value
    /// Runs off the end and comes back round, the way a clock's minutes do.
    /// Without it a time wheel opens on 00 with nothing above it, and getting to
    /// 59 means dragging the whole hour backwards.
    var wraps: Bool = false
    /// Row type size. Defaults to the light-sheet 20; larger on standalone
    /// number pickers (age) where the value carries the screen.
    var fontSize: CGFloat = 20
    /// The centred (selected) row's colour.
    var selectedColor: Color = LightSheet.title
    /// The off-centre rows' colour.
    var idleColor: Color = LightSheet.controlIdle
    let label: (Value) -> String

    /// How many times the values repeat when wrapping. Odd, so there is a true
    /// middle to start in, and large enough that nobody flicks to either end —
    /// 60 minutes across 101 copies is a wheel six thousand rows long.
    private static var copies: Int { 101 }

    @State private var position: Int?

    private var rowCount: Int { wraps ? values.count * Self.copies : values.count }
    private func value(at index: Int) -> Value { values[index % values.count] }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<rowCount, id: \.self) { index in
                    Text(label(value(at: index)))
                        .auraFont(.display, fontSize, .bold)
                        // Explicit on both sides: a row that inherits its colour
                        // follows the system appearance.
                        .foregroundStyle(index == position ? selectedColor : idleColor)
                        .frame(height: AuraWheel.rowHeight)
                        .frame(maxWidth: .infinity)
                }
            }
            .scrollTargetLayout()
        }
        // Half a wheel of margin at each end, so the first and last values can
        // reach the centre pill like every other one.
        .contentMargins(.vertical, (AuraWheel.height - AuraWheel.rowHeight) / 2, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position)
        // Rows thin out toward the ends, the way a real wheel falls away. A
        // hard cut at the edge reads as a list in a window; this reads as a
        // surface curving out of view.
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.35), location: 0.16),
                    .init(color: .black, location: 0.42),
                    .init(color: .black, location: 0.58),
                    .init(color: .black.opacity(0.35), location: 0.84),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
        // The click. A system wheel's tick is haptic, not audio — this is the
        // same generator it uses.
        .sensoryFeedback(.selection, trigger: selection)
        .onAppear { position = startIndex }
        .onChange(of: position) { _, new in
            guard let new else { return }
            let picked = value(at: new)
            if picked != selection {
                selection = picked
                AudioServicesPlaySystemSound(1104)   // soft keyboard "tock" click on each tick
            }
        }
    }

    /// Opens on the current value, in the middle copy when wrapping so there is
    /// as much wheel above as below.
    private var startIndex: Int {
        let offset = values.firstIndex(of: selection) ?? 0
        guard wraps else { return offset }
        return values.count * (Self.copies / 2) + offset
    }
}
