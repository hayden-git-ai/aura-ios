//
//  InterventionStyleSheet.swift
//  Aura iOS
//

import SwiftUI

/// Which interventions can come up when a blocked app is opened.
///
/// More than one can be on. Aura picks between them at random per run, which is
/// the whole reason to have several: the same conversation every time becomes a
/// button you learn to tap through without reading.
struct InterventionStyleSheet: View {
    @Environment(HabitStore.self) private var store

    var body: some View {
        SettingsSheetScaffold(
            title: "Intervention style",
            subtitle: "What happens when you open a blocked app.",
            detent: .fraction(0.88)
        ) {
            ForEach(InterventionStyle.allCases) { style in
                SettingToggleCard(
                    sticker: style.sticker,
                    title: style.title,
                    blurb: style.blurb,
                    isOn: binding(style)
                )
            }
        }
    }

    /// Turning the last one off puts it straight back on. There's no "no
    /// intervention" state: the shield sends you here, so something has to
    /// happen when you arrive.
    private func binding(_ style: InterventionStyle) -> Binding<Bool> {
        Binding(
            get: { store.interventionStyles.contains(style) },
            set: { isOn in
                var styles = store.interventionStyles
                if isOn {
                    styles.insert(style)
                } else {
                    styles.remove(style)
                    if styles.isEmpty { styles.insert(style) }
                }
                store.interventionStyles = styles
            }
        )
    }
}

#Preview {
    LightSheet.bg.sheet(isPresented: .constant(true)) {
        InterventionStyleSheet()
            .environment(HabitStore())
    }
}
