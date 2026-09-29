//
//  HabitRoutineSheet.swift
//  Aura iOS
//

import SwiftUI
import UIKit
import UserNotifications

/// A standing reminder for one habit: pick a time, pick the days.
///
/// The one screen in the app that asks for something rather than giving it, so
/// it stays short: a time, seven circles, one button. Everything else about the
/// habit is set on the screen behind this one.
struct HabitRoutineSheet: View {
    let habitName: String
    let accent: Color
    let accentShade: Color

    @Environment(\.dismiss) private var dismiss
    @Environment(HabitStore.self) private var store
    @State private var hour = 8
    @State private var minute = 0
    @State private var isPM = false
    @State private var weekdays: Set<Int> = []
    @State private var saving = false
    /// Whether one already existed when this opened, which is what turns the
    /// sheet from a create form into an edit form.
    @State private var hadRoutine = false
    @State private var confirmingDelete = false
    @State private var notificationsDenied = false

    /// Sunday first, matching iOS's own weekday numbering so the set can be
    /// handed straight to `DateComponents`.
    private let days: [(label: String, weekday: Int)] = [
        ("SU", 1), ("MO", 2), ("TU", 3), ("WE", 4), ("TH", 5), ("FR", 6), ("SA", 7),
    ]

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                LightDragCapsule()

                // One sticker for every create-a-routine sheet, whichever
                // method opened it. Setting a reminder is the same act on all
                // four, so it gets its own art rather than borrowing the
                // habit's icon.
                // Equal air above and below: `xl` over the icon, and the title
                // pulled up so the same gap sits under it. `LightSheetTitle`
                // carries a 28pt inset built for a title directly under the
                // drag capsule; -xs leaves ~24 to match the top.
                Image("CreateRoutineReminder")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: 96)
                    .foxShadow()
                    .padding(.top, Theme.Spacing.xl)

                LightSheetTitle(
                    title: "Create a routine",
                    subtitle: "Set it once and forget it. I'll remind you."
                )
                .padding(.top, -Theme.Spacing.xs)

                timeWheel
                    .padding(.top, Theme.Spacing.xxl)
                    .padding(.horizontal, Theme.Spacing.xl)

                Text("Choose the days you want reminding")
                    .auraFont(.body, SheetType.subtitle, .regular)
                    .foregroundStyle(SheetType.subtitleColor)
                    .padding(.top, Theme.Spacing.xxl)

                dayRow
                    .padding(.top, Theme.Spacing.l)

                Spacer(minLength: Theme.Spacing.xl)

                LightPrimaryButton(title: hadRoutine ? "Save routine" : "Create routine",
                                   face: accent,
                                   shade: accentShade,
                                   enabled: !weekdays.isEmpty && !saving) {
                    save()
                }

                // Only once there is something to delete. Red and text-only:
                // destructive, and never the thing your thumb lands on.
                if hadRoutine {
                    Button { confirmingDelete = true } label: {
                        Text("Delete routine")
                            .auraFont(.body, SheetType.cardTitle, .semibold)
                            .foregroundStyle(LightSheet.danger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Theme.Spacing.xs)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.l)
        }
        .onAppear(perform: load)
        .alert("Delete this routine?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't get any more reminders for \(habitName) unless you set a new one.")
        }
        // A denial used to be silent: the routine saved, the row showed it as
        // set, and nothing was ever delivered. Somebody would have a reminder
        // that looked active and never fired.
        .alert("Notifications are off", isPresented: $notificationsDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Not now", role: .cancel) { dismiss() }
        } message: {
            Text("Your routine is saved, but Aura can't remind you until notifications are turned on.")
        }
    }

    /// One pill, three columns.
    private var timeWheel: some View {
        ZStack {
            AuraWheel.pill

            HStack(spacing: 0) {
                // Hours and minutes come round; AM/PM is two values and has
                // nowhere to come round from.
                AuraWheelColumn(values: Array(1...12), selection: $hour, wraps: true) { "\($0)" }
                AuraWheelColumn(values: Array(0...59), selection: $minute, wraps: true) {
                    String(format: "%02d", $0)
                }
                AuraWheelColumn(values: [false, true], selection: $isPM) { $0 ? "PM" : "AM" }
            }
        }
        .frame(height: AuraWheel.height)
    }

    private var dayRow: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.weekday) { day in
                let on = weekdays.contains(day.weekday)
                Button {
                    Haptics.impact(.light)
                    withAnimation(.snappy(duration: 0.18)) {
                        if on { weekdays.remove(day.weekday) } else { weekdays.insert(day.weekday) }
                    }
                } label: {
                    Text(day.label)
                        .auraFont(.body, RowType.subLabel, .bold)
                        .foregroundStyle(on ? .white : LightSheet.controlIdle)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(on ? accent : LightSheet.field))
                }
                .buttonStyle(PressBounceStyle(hapticsEnabled: false))
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// Reopening shows what's already set rather than a blank form, so this
    /// doubles as the edit screen without being a second one.
    private func load() {
        guard let existing = RoutineStore.routine(for: habitName) else { return }
        hadRoutine = true
        weekdays = existing.weekdays
        let h = existing.hour
        isPM = h >= 12
        hour = h % 12 == 0 ? 12 : h % 12
        minute = existing.minute
    }

    private func delete() {
        Task {
            await RoutineStore.remove(habitName: habitName)
            store.libraryChangedLocally()
            Haptics.notify(.success)
            dismiss()
        }
    }

    private func save() {
        saving = true
        var h24 = hour % 12
        if isPM { h24 += 12 }
        let routine = HabitRoutine(habitName: habitName,
                                   minuteOfDay: h24 * 60 + minute,
                                   weekdays: weekdays)
        Task {
            // Asked for here rather than up front. Somebody who never sets a
            // routine should never see the permission prompt, and somebody who
            // just picked a time and three days has told us exactly what the
            // prompt is for.
            let centre = UNUserNotificationCenter.current()
            if await centre.notificationSettings().authorizationStatus == .notDetermined {
                _ = try? await centre.requestAuthorization(options: [.alert, .sound, .badge])
            }
            await RoutineStore.save(routine)
            store.libraryChangedLocally()
            Haptics.notify(.success)

            // Saved either way. A denial doesn't throw the routine away —
            // turning notifications on later reschedules it — but it does have
            // to be said out loud.
            if await centre.notificationSettings().authorizationStatus != .authorized {
                saving = false
                notificationsDenied = true
                return
            }
            dismiss()
        }
    }
}
