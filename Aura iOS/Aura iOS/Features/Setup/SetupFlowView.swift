//
//  SetupFlowView.swift
//  Aura iOS
//
//  Container for the setup handoff. Every step is a full-size view stacked at the
//  same origin and offset horizontally to its distance from the current step, so
//  the row slides as one piece. Nothing is ever added or removed, so the viewport
//  stays fully covered by a screen's ray background — no white gap between steps.
//

import SwiftUI

struct SetupFlowView: View {
    @Environment(SetupFlow.self) private var flow

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let current = flow.step.rawValue
            ZStack {
                ForEach(SetupFlow.Step.allCases, id: \.self) { step in
                    // Each screen is its own full-size view (so its buttons hit-test
                    // normally), offset by its signed distance from the current step.
                    // The current screen sits at offset 0; neighbours wait just off
                    // either edge. Changing the step animates the offsets together.
                    screen(for: step)
                        .frame(width: w, height: geo.size.height)
                        .offset(x: CGFloat(step.rawValue - current) * w)
                        // Only the current screen takes touches — the others are
                        // parked off-screen but still stacked here, and would
                        // otherwise swallow taps meant for the visible screen.
                        .allowsHitTesting(step.rawValue == current)
                }
            }
            .frame(width: w, height: geo.size.height)
            .environment(\.setupContentHeight, geo.size.height)
        }
    }

    @ViewBuilder
    private func screen(for step: SetupFlow.Step) -> some View {
        switch step {
        case .welcome:       SetupWelcomeView()
        case .signIn:        SetupSignInView()
        case .notifications: SetupNotificationsView()
        case .screenTime:    SetupScreenTimeView()
        case .appPicker:     SetupAppPickerView()
        case .allSet:        SetupAllSetView()
        }
    }
}
