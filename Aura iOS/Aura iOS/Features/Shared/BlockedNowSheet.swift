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

    // 3 columns, matching the Forbidden / Tempting / Allowed sheets.
    private let grid = [
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top),
        GridItem(.flexible(), alignment: .top),
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

                        LazyVGrid(columns: grid, alignment: .leading, spacing: Theme.Spacing.m) {
                            ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in
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
        .presentationDetents([.height(500)])
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

    /// The frozen ice block over the app's name, in a soft gray card — sized to
    /// match the Forbidden / Tempting / Allowed tiles. No minus badge: this list
    /// is read-only.
    private func tile(_ icon: AppIconSource) -> some View {
        VStack(spacing: Theme.Spacing.s) {
            FrozenAppTile(icon: icon, side: 56)
            appName(icon)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .auraFont(.body, 13, .semibold)
                .foregroundStyle(SheetType.titleColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.s)
        .background(Color.black.opacity(0.05),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    /// The app's name — the display name for a stand-in, the system title for a
    /// real token.
    @ViewBuilder private func appName(_ icon: AppIconSource) -> some View {
        switch icon {
        case .asset(let name): Text(AppCatalog.displayName(for: name))
        case .token(let token): Label(token).labelStyle(.titleOnly)
        }
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        BlockedNowSheet(icons: [.asset("MessagesIcon"), .asset("MusicIcon"), .asset("BooksIcon")])
    }
}
