//
//  MockAppPicker.swift
//  Aura iOS
//
//  Stand-in for `FamilyActivityPicker`, which only exists on a real device.
//

import SwiftUI
import UIKit

/// The Simulator's app picker.
///
/// It exists so the flow is the same in both places. `MockScreenTimeService`
/// used to silently add one catalogue app per tap and return, which meant
/// "+ Add app or website" appeared to do nothing while quietly changing the
/// list — a flow nobody could test and everybody misread as broken.
///
/// Deliberately the same shape as the real one's wrapper: title, list, count,
/// Save, Cancel. Only the list differs, because only the list can.
struct MockAppPickerSheet: View {
    let alreadyPicked: [String]
    var onDone: ([String]) -> Void
    var onCancel: () -> Void

    @State private var chosen: Set<String>

    init(alreadyPicked: [String],
         onDone: @escaping ([String]) -> Void,
         onCancel: @escaping () -> Void) {
        self.alreadyPicked = alreadyPicked
        self.onDone = onDone
        self.onCancel = onCancel
        _chosen = State(initialValue: Set(alreadyPicked))
    }

    private var entries: [AppCatalog.Entry] { AppCatalog.all }

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightSubSheetHeader(title: "Choose apps",
                                    subtitle: "Simulator stand-in. On a device this is Apple's picker.")

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(entries.indices, id: \.self) { index in
                            row(entries[index])
                            if index < entries.count - 1 {
                                Rectangle()
                                    .fill(LightSheet.divider)
                                    .frame(height: 1)
                                    .padding(.leading, 34 + Theme.Spacing.m)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                }

                VStack(spacing: Theme.Spacing.m) {
                    Text(chosen.count == 1 ? "1 item selected" : "\(chosen.count) items selected")
                        .auraFont(.body, RowType.value, .medium)
                        .foregroundStyle(LightSheet.subtitle)

                    LightPrimaryButton(title: "Save", enabled: !chosen.isEmpty) {
                        onDone(AppCatalog.all.map(\.iconName).filter { chosen.contains($0) })
                    }

                    Button("Cancel", action: onCancel)
                        .auraFont(.body, RowType.label, .semibold)
                        .foregroundStyle(LightSheet.subtitle)
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.xl)
            }
        }
    }

    private func row(_ entry: AppCatalog.Entry) -> some View {
        Button {
            Haptics.impact(.light)
            if chosen.contains(entry.iconName) {
                chosen.remove(entry.iconName)
            } else {
                chosen.insert(entry.iconName)
            }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                AppIconView(source: .asset(entry.iconName), side: 34)
                    .appIconChrome(side: 34)

                Text(entry.displayName)
                    .auraFont(.body, SheetType.cardTitle, .semibold)
                    .foregroundStyle(SheetType.titleColor)

                Spacer(minLength: Theme.Spacing.s)

                Image(systemName: chosen.contains(entry.iconName)
                      ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(chosen.contains(entry.iconName)
                                     ? LightSheet.blue : LightSheet.controlIdle)
            }
            .padding(.vertical, Theme.Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum MockAppPickerPresenter {
    @MainActor
    static func top() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
