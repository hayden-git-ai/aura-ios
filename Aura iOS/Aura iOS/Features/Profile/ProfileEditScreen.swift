//
//  ProfileEditScreen.swift
//  Aura iOS
//

import SwiftUI
import UIKit

/// The account editor, opened from the Profile "Edit profile" button and the
/// Settings "Profile" row. First name, last name, the account email shown
/// read-only, and the avatar picker, on the app's light surface.
/// Fields use the app's standard stroked field (Add Habit / Add Block); the
/// avatar carries the same pencil badge as the sticker picker. The display name
/// is the editable identity field wired through to the store today.
struct ProfileEditScreen: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    /// Tapping the avatar opens Aura's own library picker.
    @State private var showLibraryPicker = false

    private enum Field { case first, last }
    @FocusState private var focused: Field?

    private static let avatarSize: CGFloat = 104

    var body: some View {
        ZStack(alignment: .top) {
            LightSheet.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Theme.Spacing.xl) {
                        avatarSection

                        fieldBlock("First name", $firstName, placeholder: "Your first name", field: .first)
                        fieldBlock("Last name", $lastName, placeholder: "Your last name", field: .last)
                        readOnlyField("Email", value: store.email)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Layout.scrollBottomClearance)
                }
            }
        }
        .fullScreenCover(isPresented: $showLibraryPicker) {
            CustomPhotoLibraryPicker { saveProfileImage($0) }
        }
        .onAppear(perform: prefill)
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Profile")
                .auraFont(.display, SheetType.title, .bold)
                .foregroundStyle(SheetType.titleColor)

            HStack {
                // The shared corner control: a chevron on the app's circular chrome
                // disc, same as every other back/close button.
                CircleIconButton(symbol: "chevron.left") {
                    Haptics.impact(.light)
                    save()
                    dismiss()
                }
                Spacer()
            }
        }
        .padding(.horizontal, Theme.Spacing.l)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.m)
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: Theme.Spacing.m) {
            // The avatar itself is the change control: a dim over the picture with
            // a white plus. Tapping it opens Aura's library picker. Removal is the
            // only text link, and only when a photo exists.
            Button {
                Haptics.impact(.light)
                showLibraryPicker = true
            } label: {
                ProfileAvatarCircle(size: Self.avatarSize)
                    .overlay {
                        Circle()
                            .fill(LightSheet.chromeOnPhoto)
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            // Sit inside the avatar's white ring, not over it.
                            .padding(3)
                    }
            }
            .buttonStyle(PressBounceStyle())

            if store.profileImageData != nil {
                Button {
                    Haptics.impact(.medium)
                    store.profileImageData = nil
                } label: {
                    Text("Remove photo")
                        .auraFont(.body, RowType.label, .bold)
                        .foregroundStyle(LightSheet.rippleRed)
                        // Keep the tap target at least 44pt tall (the text is ~20).
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressBounceStyle())
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Downscales the picked photo to an avatar-sized JPEG and stores it locally.
    /// The picker already hands back a square, cropped image.
    private func saveProfileImage(_ image: UIImage) {
        let maxDim: CGFloat = 512
        let scale = min(1, maxDim / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        store.profileImageData = resized.jpegData(compressionQuality: 0.85)
    }

    // MARK: - Fields

    /// The app's standard field: a label over a recessed, stroked grey field
    /// (matches Add Habit / Add Block). A prompt fills the empty state.
    private func fieldBlock(_ label: String, _ text: Binding<String>,
                            placeholder: String,
                            autocap: TextInputAutocapitalization = .words,
                            field: Field) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(label)
                .auraFont(.display, SheetType.sectionHeader, .bold)
                .foregroundStyle(SheetType.titleColor)

            TextField("", text: text,
                      prompt: Text(placeholder).foregroundStyle(LightSheet.subtitle))
                .auraFont(.body, SheetType.input, .medium)
                .foregroundStyle(LightSheet.title)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
                .focused($focused, equals: field)
                // Return advances through the fields, then closes the keyboard on the last.
                .submitLabel(field == .last ? .done : .next)
                .onSubmit {
                    switch field {
                    case .first: focused = .last
                    case .last: focused = nil
                    }
                }
                .fieldChrome()
        }
    }

    /// Authentication email is account-owned. Until a verified provider-aware
    /// update flow exists, display it honestly instead of accepting edits that
    /// would be discarded.
    private func readOnlyField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(label)
                .auraFont(.display, SheetType.sectionHeader, .bold)
                .foregroundStyle(SheetType.titleColor)

            Text(value.isEmpty ? "Not available" : value)
                .auraFont(.body, SheetType.input, .medium)
                .foregroundStyle(LightSheet.subtitle)
                .lineLimit(1)
                .truncationMode(.middle)
                .fieldChrome()
                .accessibilityLabel("\(label): \(value.isEmpty ? "Not available" : value)")
        }
    }

    // MARK: - Data

    private func prefill() {
        let parts = store.displayName.split(separator: " ", maxSplits: 1).map(String.init)
        firstName = parts.first ?? store.displayName
        lastName = parts.count > 1 ? parts[1] : ""
    }

    private func save() {
        let name = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if !name.isEmpty { store.displayName = name }
    }
}

private extension View {
    /// The app's recessed stroked field container (Add Habit / Add Block): the
    /// light field fill, a hairline stroke, and the standard 56pt control height.
    func fieldChrome() -> some View {
        self
            .padding(.horizontal, Theme.Spacing.l)
            .frame(height: Theme.Layout.fieldHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LightSheet.field, in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous)
                .strokeBorder(LightSheet.fieldStroke, lineWidth: 1))
    }
}

#Preview {
    ProfileEditScreen()
        .environment(HabitStore())
}
