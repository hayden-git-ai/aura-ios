//
//  AppSlider.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// A slider with an explicitly colored track on both sides — SwiftUI's `Slider`
/// leaves the unfilled (max) track a near-white system gray, which vanishes on
/// a light card. This exposes both the filled (`fill`) and unfilled (`track`)
/// colors so the full-length track always reads.
struct AppSlider: UIViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double = 0
    var fill: Color
    var track: Color = Color(hex: "E6E6E9")

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.isContinuous = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        slider.minimumTrackTintColor = UIColor(fill)
        slider.maximumTrackTintColor = UIColor(track)
        if abs(Double(slider.value) - value) > 0.0001 {
            slider.setValue(Float(value), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        var parent: AppSlider
        init(_ parent: AppSlider) { self.parent = parent }

        @objc func changed(_ slider: UISlider) {
            var v = Double(slider.value)
            if parent.step > 0 {
                v = (v / parent.step).rounded() * parent.step
            }
            parent.value = min(parent.range.upperBound, max(parent.range.lowerBound, v))
        }
    }
}
