//
//  StickerPickerSheet.swift
//  Aura iOS
//

import SwiftUI

/// Curated active sticker assets, deduplicated by decoded pixels. Coins are excluded.
enum StickerCatalog {
    static let all: [String] = [
        "EarnCardIcon",
        "ScrollCardIcon",
        "StreakFireIcon",
        "FoxPhotoProof",
        "FoxCameraReps",
        "FoxDeepFocus",
        "FoxAppleHealth",
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
        "FoxCaloriesBurned",
        "FoxCreateRoutine",
        "FoxExerciseMinutes",
        "FoxMindfulMinutes",
        "FoxRunWalk",
        "FoxSettingsBugReport",
        "FoxSettingsContact",
        "FoxSettingsHelp",
        "FoxSteps",
    ]

    // Alpha bounds measured at import time. No image decoding/scanning on scroll.
    static func geometry(for name: String) -> (width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) {
        switch name {
        case "EarnCardIcon": return (50.056, 50.056, 0.000, 1.229)
        case "ScrollCardIcon": return (50.056, 50.056, 0.000, 1.676)
        case "StreakFireIcon": return (50.000, 50.000, 0.000, 1.875)
        case "FoxPhotoProof": return (64.606, 64.606, 0.000, 0.315)
        case "FoxCameraReps": return (55.956, 55.956, 0.000, 0.984)
        case "FoxDeepFocus": return (52.245, 52.245, 0.000, 1.327)
        case "FoxAppleHealth": return (65.641, 65.641, -0.064, 0.000)
        case "FoxHabitBrushTeeth": return (52.245, 52.245, 0.000, 1.020)
        case "FoxHabitCleanRoom": return (52.245, 52.245, 0.000, 0.918)
        case "FoxHabitDeepWork": return (52.379, 52.379, 0.051, 0.870)
        case "FoxHabitGardening": return (52.245, 52.245, 0.000, 2.041)
        case "FoxHabitGym": return (52.112, 52.112, 0.000, 0.458)
        case "FoxHabitHealthyMeal": return (52.112, 52.112, 0.000, 0.662)
        case "FoxHabitHydrate": return (52.112, 52.112, 0.000, 1.781)
        case "FoxHabitJournal": return (52.112, 52.112, 0.000, -0.356)
        case "FoxHabitMakeBed": return (52.112, 52.112, 0.000, 1.781)
        case "FoxHabitMeditate": return (57.853, 57.853, 0.000, 1.356)
        case "FoxHabitPracticeInstrument": return (52.245, 52.245, 0.051, 1.735)
        case "FoxHabitRead": return (52.112, 52.112, 0.000, -1.272)
        case "FoxHabitRun": return (52.112, 52.112, 0.000, -1.170)
        case "FoxHabitSkincare": return (52.112, 52.112, 0.000, 1.679)
        case "FoxHabitSmile": return (52.245, 52.245, 0.000, 1.020)
        case "FoxHabitSocialize": return (52.245, 52.245, 0.051, 0.612)
        case "FoxHabitStudy": return (55.054, 55.054, 0.000, 1.828)
        case "FoxHabitTakeVitamins": return (52.112, 52.112, 0.051, 1.374)
        case "FoxHabitTouchGrass": return (52.112, 52.112, 0.000, -0.763)
        case "FoxHabitWalk": return (52.112, 52.112, 0.000, 1.679)
        case "FoxHabitWorkOnBusiness": return (52.245, 52.245, 0.000, 0.816)
        case "FoxHabitYoga": return (52.245, 52.245, 0.000, 0.510)
        case "FoxCaloriesBurned": return (51.980, 51.980, 0.000, 0.914)
        case "FoxCreateRoutine": return (52.112, 52.112, 0.000, 3.715)
        case "FoxExerciseMinutes": return (52.245, 52.245, 0.000, 0.612)
        case "FoxMindfulMinutes": return (51.980, 51.980, 0.000, 0.508)
        case "FoxRunWalk": return (51.980, 51.980, 0.000, 1.117)
        case "FoxSettingsBugReport": return (54.924, 54.924, 0.051, 0.355)
        case "FoxSettingsContact": return (54.555, 54.555, 0.000, 0.254)
        case "FoxSettingsHelp": return (52.112, 52.112, 0.000, 0.865)
        case "FoxSteps": return (52.245, 52.245, 0.000, 0.204)
        default: return (40, 40, 0, 0)
        }
    }

    enum Category: String, CaseIterable {
        case all = "All", focus = "Focus", exercise = "Exercise", wellness = "Wellness"
        case social = "Social", creative = "Creative", home = "Home", more = "More"
    }

    static func category(for name: String) -> Category {
        switch name {
        case "FoxDeepFocus", "FoxHabitDeepWork", "FoxHabitRead", "FoxHabitStudy", "FoxHabitWorkOnBusiness", "FoxLockInRoutine": return .focus
        case "FoxCameraReps", "FoxHabitGym", "FoxHabitRun", "FoxHabitWalk", "FoxRunWalk", "FoxSteps", "FoxExerciseMinutes", "FoxCaloriesBurned": return .exercise
        case "FoxAppleHealth", "FoxHabitBrushTeeth", "FoxHabitHealthyMeal", "FoxHabitHydrate", "FoxHabitMeditate", "FoxHabitSkincare", "FoxHabitTakeVitamins", "FoxHabitTouchGrass", "FoxHabitYoga", "FoxMindfulMinutes": return .wellness
        case "FoxHabitSmile", "FoxHabitSocialize", "FoxSettingsContact": return .social
        case "FoxHabitJournal", "FoxHabitPracticeInstrument": return .creative
        case "FoxHabitCleanRoom", "FoxHabitGardening", "FoxHabitMakeBed", "FoxCreateRoutine": return .home
        default: return .more
        }
    }
}

/// A grid sticker picker — same sheet chrome/size as the Target Time and App
/// Lists sheets (drag capsule + centered title + X, `.height(420)` detent). The
/// current selection carries a blue border + a faint blue wash.
struct StickerPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let selected: String?
    var onSelect: (String?) -> Void

    /// Local mirror so tapping a sticker highlights it without dismissing — the
    /// user closes the sheet manually.
    @State private var localSelected: String?
    @State private var category: StickerCatalog.Category = .all

    init(selected: String?, onSelect: @escaping (String?) -> Void) {
        self.selected = selected
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
                                .background(category == item ? LightSheet.blue : LightSheet.field, in: Capsule())
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
        .presentationDetents([.height(420)])
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
                .frame(height: 72)
                .background(isSelected ? LightSheet.blueWash : LightSheet.field,
                           in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                        .strokeBorder(isSelected ? LightSheet.blue : Color.clear, lineWidth: 2)
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
