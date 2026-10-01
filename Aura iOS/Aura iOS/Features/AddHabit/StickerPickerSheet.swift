//
//  StickerPickerSheet.swift
//  Aura iOS
//

import SwiftUI

/// Exactly the 22 approved Healthy Habits stickers. No generic, method,
/// Settings, or Apple Health artwork belongs in this picker.
enum StickerCatalog {
    static let all: [String] = [
        "FoxHabitBrushTeeth",
        "FoxHabitCleanRoom",
        "FoxHabitDeepWork",
        "FoxHabitGardening",
        "FoxHabitGym",
        "FoxHabitHealthyMeal",
        "FoxHabitHydrate",
        "FoxHabitJournal",
        "FoxHabitMakeBed",
        "FoxHabitMeditate",
        "FoxHabitPracticeInstrument",
        "FoxHabitRead",
        "FoxHabitRun",
        "FoxHabitSkincare",
        "FoxHabitSmile",
        "FoxHabitSocialize",
        "FoxHabitStudy",
        "FoxHabitTakeVitamins",
        "FoxHabitTouchGrass",
        "FoxHabitWalk",
        "FoxHabitWorkOnBusiness",
        "FoxHabitYoga",
    ]

    // Alpha bounds measured at import time. No image decoding/scanning on scroll.
    static func geometry(for name: String) -> (width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) {
        switch name {
        case "FoxHabitBrushTeeth": return (65.574, 65.574, 0.000, 0.940)
        case "FoxHabitCleanRoom": return (65.574, 65.574, 0.000, 0.940)
        case "FoxHabitDeepWork": return (59.159, 59.159, 0.000, 0.848)
        case "FoxHabitGardening": return (65.312, 65.312, 0.000, 2.288)
        case "FoxHabitGym": return (64.621, 64.621, 0.000, 0.442)
        case "FoxHabitHealthyMeal": return (65.576, 65.576, 0.000, 0.640)
        case "FoxHabitHydrate": return (65.312, 65.312, 0.000, 2.080)
        case "FoxHabitJournal": return (65.312, 65.312, 0.000, -0.624)
        case "FoxHabitMakeBed": return (58.734, 58.734, 0.000, 1.777)
        case "FoxHabitMeditate": return (54.557, 54.557, 0.000, 1.012)
        case "FoxHabitPracticeInstrument": return (64.794, 64.794, 0.000, 1.857)
        case "FoxHabitRead": return (65.415, 65.415, 0.000, -1.725)
        case "FoxHabitRun": return (64.794, 64.794, 0.000, -1.651)
        case "FoxHabitSkincare": return (65.312, 65.312, 0.000, 1.872)
        case "FoxHabitSmile": return (65.312, 65.312, 0.000, 1.040)
        case "FoxHabitSocialize": return (65.576, 65.576, -0.064, 0.512)
        case "FoxHabitStudy": return (54.427, 54.427, 0.000, 1.647)
        case "FoxHabitTakeVitamins": return (65.312, 65.312, 0.104, 1.456)
        case "FoxHabitTouchGrass": return (55.537, 55.537, 0.000, -0.973)
        case "FoxHabitWalk": return (56.647, 56.647, 0.000, 1.660)
        case "FoxHabitWorkOnBusiness": return (65.574, 65.574, 0.000, 0.940)
        case "FoxHabitYoga": return (65.496, 65.496, 0.000, 0.416)
        default: return (40, 40, 0, 0)
        }
    }

    enum Category: String, CaseIterable {
        case all = "All", focus = "Focus", exercise = "Exercise", wellness = "Wellness"
        case social = "Social", creative = "Creative", home = "Home"
    }

    static func category(for name: String) -> Category {
        switch name {
        case "FoxHabitDeepWork", "FoxHabitRead", "FoxHabitStudy", "FoxHabitWorkOnBusiness": return .focus
        case "FoxHabitGym", "FoxHabitRun", "FoxHabitWalk": return .exercise
        case "FoxHabitBrushTeeth", "FoxHabitHealthyMeal", "FoxHabitHydrate", "FoxHabitMeditate", "FoxHabitSkincare", "FoxHabitTakeVitamins", "FoxHabitTouchGrass", "FoxHabitYoga": return .wellness
        case "FoxHabitSmile", "FoxHabitSocialize": return .social
        case "FoxHabitJournal", "FoxHabitPracticeInstrument": return .creative
        case "FoxHabitCleanRoom", "FoxHabitGardening", "FoxHabitMakeBed": return .home
        default: return .all
        }
    }
}
/// A grid sticker picker — same sheet chrome/size as the Target Time and App
/// Lists sheets (drag capsule + centered title + X, `.height(420)` detent). The
/// current selection carries the method's accent border + wash.
struct StickerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selected: String?
    let accent: Color
    var onSelect: (String?) -> Void

    /// Local mirror so tapping a sticker highlights it without dismissing — the
    /// user closes the sheet manually.
    @State private var localSelected: String?
    @State private var category: StickerCatalog.Category = .all

    init(selected: String?, accent: Color = LightSheet.blue,
         onSelect: @escaping (String?) -> Void) {
        self.selected = selected
        self.accent = accent
        self.onSelect = onSelect
        _localSelected = State(initialValue: selected)
    }


    private let columns = Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.m), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(StickerCatalog.Category.allCases, id: \.self) { item in
                        Button {
                            Haptics.selection()
                            category = item
                        } label: {
                            Text(item.rawValue)
                                .auraFont(.body, RowType.label, .semibold)
                                .foregroundStyle(category == item ? .white : LightSheet.title)
                                .padding(.horizontal, Theme.Spacing.m)
                                .frame(height: 44)
                                .background(category == item ? accent : LightSheet.field, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
            }

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: Theme.Spacing.m) {
                    ForEach(StickerCatalog.all.filter { category == .all || StickerCatalog.category(for: $0) == category }, id: \.self) { name in
                        cell(name)
                    }
                }
                .padding(.horizontal, Theme.Spacing.xl)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .background(LightSheet.bg.ignoresSafeArea())
        .preferredColorScheme(.light)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var header: some View {
        VStack(spacing: 0) {
            LightDragCapsule()

            Text("Choose a Sticker")
                .auraFont(.display, 22, .bold)
                .foregroundStyle(LightSheet.title)
                .frame(maxWidth: .infinity)
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.l)
            .padding(.bottom, Theme.Spacing.l)
        }
    }

    private func cell(_ name: String) -> some View {
        let isSelected = localSelected == name
        let geometry = StickerCatalog.geometry(for: name)
        return Button {
            Haptics.selection()
            localSelected = name
            onSelect(name)
        } label: {
            Image(name)
                .resizable()
                .interpolation(.high)
                .frame(width: geometry.width, height: geometry.height)
                .offset(x: geometry.x, y: geometry.y)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(isSelected ? accent.opacity(0.16) : LightSheet.field,
                           in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                        .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(PressBounceStyle())
    }
}

#Preview {
    Color.gray.sheet(isPresented: .constant(true)) {
        StickerPickerSheet(selected: "FoxDeepFocus") { _ in }
    }
}
