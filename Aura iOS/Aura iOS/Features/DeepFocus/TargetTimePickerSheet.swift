//
//  TargetTimePickerSheet.swift
//  Aura iOS
//

import SwiftUI

/// The Target Time wheel picker — hours + minutes (5-minute steps) over a light
/// sheet, committing back to the Focus Mode sheet's length. Matches the light
/// design system (centered title, subtitle, blue Done button).
struct TargetTimePickerSheet: View {
    @Binding var totalMinutes: Int
    @Environment(\.dismiss) private var dismiss

    @State private var hours: Int
    @State private var minutes: Int

    private static let minuteStep = 5
    private static let minuteOptions = Array(stride(from: 0, through: 55, by: minuteStep))
    private static let hourOptions = Array(0...8)


    init(totalMinutes: Binding<Int>) {
        _totalMinutes = totalMinutes
        let clamped = max(0, totalMinutes.wrappedValue)
        _hours = State(initialValue: clamped / 60)
        _minutes = State(initialValue: (clamped % 60 / Self.minuteStep) * Self.minuteStep)
    }

    var body: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            VStack(spacing: Theme.Spacing.xs) {
                Text("Focus Length")
                    .auraFont(.display, 22, .bold)
                    .foregroundStyle(LightSheet.title)
                Text("Set how long your focus session will last")
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(LightSheet.subtitleDark)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Theme.Spacing.xl)
            .padding(.horizontal, Theme.Spacing.xl)

            wheels
                .frame(maxHeight: .infinity)

            doneButton
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.bottom, Theme.Spacing.l)
        }
        .background(LightSheet.bg.ignoresSafeArea())
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.hidden)
    }

    private var wheels: some View {
        HStack(spacing: 0) {
            Picker("", selection: $hours) {
                ForEach(Self.hourOptions, id: \.self) { h in
                    Text("\(h)").auraFont(.display, 20, .bold).foregroundStyle(LightSheet.title).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)

            Text("hours")
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(LightSheet.title)
                .frame(width: 70, alignment: .leading)

            Picker("", selection: $minutes) {
                ForEach(Self.minuteOptions, id: \.self) { m in
                    Text("\(m)").auraFont(.display, 20, .bold).foregroundStyle(LightSheet.title).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)

            Text("min")
                .auraFont(.body, SheetType.cardTitle, .semibold)
                .foregroundStyle(LightSheet.title)
                .frame(width: 70, alignment: .leading)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        // The app forces dark mode at the root; force this picker to light so
        // the wheel numerals render dark on the white sheet instead of white.
        .environment(\.colorScheme, .light)
    }

    private var doneButton: some View {
        Button {
            // Never commit a zero-length target — floor at one 5-minute step.
            totalMinutes = max(Self.minuteStep, hours * 60 + minutes)
            dismiss()
        } label: {
            Text("Done")
                .font(SheetType.ctaFont)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .blueDropCapsule()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        TargetTimePickerSheet(totalMinutes: .constant(30))
    }
}
