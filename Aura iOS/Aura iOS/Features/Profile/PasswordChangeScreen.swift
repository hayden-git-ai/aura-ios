//
//  PasswordChangeScreen.swift
//  Aura iOS
//

import SwiftUI

/// Change-password flow, opened from the Profile editor's Password row: old, new,
/// and confirm, each with a show/hide toggle. On the app's light surface. Stubbed
/// until an account backend exists.
struct PasswordChangeScreen: View {
    @Environment(\.dismiss) private var dismiss

    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showOld = false
    @State private var showNew = false
    @State private var showConfirm = false

    private enum Field { case old, new, confirm }
    @FocusState private var focused: Field?

    private var canSave: Bool {
        !oldPassword.isEmpty && !newPassword.isEmpty && newPassword == confirmPassword
    }

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.xl) {
                        secureField("Old password", $oldPassword, reveal: $showOld, field: .old)
                        secureField("New password", $newPassword, reveal: $showNew, field: .new)
                        secureField("Confirm password", $confirmPassword, reveal: $showConfirm, field: .confirm, error: confirmError)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                }

                LightPrimaryButton(title: "Save", enabled: canSave) { save() }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
    }

    private var topBar: some View {
        ZStack {
            Text("Password")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(LightSheet.title)

            HStack {
                // Same corner control as the rest of the app: a chevron on the
                // circular chrome disc.
                CircleIconButton(symbol: "chevron.left") { dismiss() }
                Spacer()
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.m)
    }

    private func secureField(_ label: String, _ text: Binding<String>, reveal: Binding<Bool>,
                             field: Field, error: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(label)
                .auraFont(.display, SheetType.sectionHeader, .bold)
                .foregroundStyle(SheetType.titleColor)

            HStack(spacing: Theme.Spacing.s) {
                Group {
                    if reveal.wrappedValue {
                        TextField("", text: text)
                    } else {
                        SecureField("", text: text)
                    }
                }
                .auraFont(.body, SheetType.input, .medium)
                .foregroundStyle(LightSheet.title)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
                // Return advances old to new to confirm, then saves (or just closes
                // the keyboard), so the keyboard is never stuck without a Done key.
                .submitLabel(field == .confirm ? .done : .next)
                .onSubmit {
                    switch field {
                    case .old: focused = .new
                    case .new: focused = .confirm
                    case .confirm:
                        focused = nil
                        if canSave { Haptics.impact(.light); save() }
                    }
                }

                Button { reveal.wrappedValue.toggle() } label: {
                    Image(systemName: reveal.wrappedValue ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 17, weight: .semibold))
                        // A quiet icon-control neutral, not the loud blue accent.
                        .foregroundStyle(LightSheet.controlIdle)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressBounceStyle())
            }
            .padding(.leading, Theme.Spacing.l)
            // The eye button carries its own 44pt hit area, so no trailing text pad.
            .frame(height: Theme.Layout.fieldHeight)
            .background(LightSheet.field, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                .strokeBorder(LightSheet.fieldStroke, lineWidth: 1))

            if let error {
                Text(error)
                    .auraFont(.body, SheetType.cardBlurb, .medium)
                    .foregroundStyle(LightSheet.danger)
            }
        }
    }

    /// Shown under the confirm field once a mismatching confirmation is typed, so
    /// the disabled Save button is never a silent dead end.
    private var confirmError: String? {
        guard !confirmPassword.isEmpty, confirmPassword != newPassword else { return nil }
        return "New passwords must match."
    }

    private func save() {
        // TODO: wire the password change once an account backend exists.
        dismiss()
    }
}

#Preview {
    PasswordChangeScreen()
}
