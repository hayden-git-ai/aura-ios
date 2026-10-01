//
//  BlockedNowSheet.swift
//  Aura iOS
//

import FamilyControls
import SwiftUI

/// Read-only list of everything blocked right now, opened from the pill. The
/// Apps tab owns editing; this is just the answer to "what's locked?".
struct BlockedNowSheet: View {
    let icons: [AppIconSource]

    @Environment(HabitStore.self) private var store
    @State private var showEmergency = false

    // Outer artwork edges align with the section text edges. Rows use the
    // design system's largest spacing step for an airy, regular grid.
    private let grid = [
        GridItem(.flexible(), spacing: 0, alignment: .topLeading),
        GridItem(.flexible(), spacing: 0, alignment: .top),
        GridItem(.flexible(), spacing: 0, alignment: .topTrailing),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightSubSheetHeader(
                    title: "Frozen Apps",
                    subtitle: icons.count == 1 ? "1 app is frozen right now."
                                               : "\(icons.count) apps are frozen right now."
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        // The same "Apps (n)" header the rule sheets carry — but
                        // no Clear All, since this list is read-only.
                        Text("Apps (\(icons.count))")
                            .auraFont(.display, 17, .bold)
                            .foregroundStyle(SheetType.titleColor)

                        LazyVGrid(columns: grid, alignment: .center, spacing: Theme.Spacing.xxxl) {
                            ForEach(icons, id: \.stableID) { icon in
                                tile(icon)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.l)
                    .padding(.bottom, Theme.Spacing.l)
                }

                // The escape hatch lives here now — off the main Apps screen so
                // the lane cards read clean, and one level deeper so it isn't the
                // loudest thing inviting you to cave.
                emergencyButton
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.s)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
        .preferredColorScheme(.light)
        .presentationDetents([.height(icons.count > 3 ? 620 : 500), .large])
        .presentationDragIndicator(.hidden)
        .fullScreenCover(isPresented: $showEmergency) {
            EmergencyUnlockView()
        }
    }

    private var emergencyButton: some View {
        let used = store.emergencyUnlockUsed
        return Button {
            Haptics.impact(.light)
            showEmergency = true
        } label: {
            Text(used ? "Emergency Unfreeze Used" : "Emergency Unfreeze")
                .font(SheetType.ctaFont)
                .foregroundStyle(.white)
        }
        .buttonStyle(PillPressButtonStyle(face: LightSheet.rippleRed,
                                          shade: Color(hex: "CC2F26"),
                                          enabled: !used))
        .disabled(used)
    }

    /// Compact frozen artwork only. This list is read-only.
    private static let frozenIconSide: CGFloat = 54

    private func tile(_ icon: AppIconSource) -> some View {
        FrozenAppTile(icon: icon, side: Self.frozenIconSide)
            .frame(width: 79)
    }


}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        BlockedNowSheet(icons: [.asset("MessagesIcon"), .asset("MusicIcon"), .asset("BooksIcon")])
    }
}
