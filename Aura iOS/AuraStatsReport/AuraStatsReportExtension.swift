//
//  AuraStatsReportExtension.swift
//  AuraStatsReport
//
//  The report extension. Apple hands Screen Time figures to this process and
//  nowhere else — the app can host the view it renders, but can never read the
//  numbers behind it. That constraint is the reason this target exists.
//

import DeviceActivity
import SwiftUI

@main
struct AuraStatsReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        ScreenTimeWeekScene()
    }
}

// The context is declared in `ScreenTimeStats.swift`, which both targets share,
// so the name the app asks for and the name this answers to are one symbol
// rather than two strings that have to be kept identical by hand.
