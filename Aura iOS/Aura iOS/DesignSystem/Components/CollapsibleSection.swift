//
//  CollapsibleSection.swift
//  Aura iOS
//

import SwiftUI

/// Shared header + body used by every section on the Apps screen (Blocked
/// Apps, Rules, Apps) — always expanded, no collapse/chevron. An optional
/// trailing accessory (e.g. Rules' "+ New") sits at the header's far right
/// in place of a chevron.
struct CollapsibleSection<Content: View, Accessory: View>: View {
    var title: String
    var count: Int? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, Theme.Spacing.m)

            content()
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.s) {
            Text(title)
                .auraFont(.display, 19, .bold)
                .foregroundStyle(Theme.Color.textPrimary)

            if let count {
                Text("\(count)")
                    .auraFont(.body, 13, .bold)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(minWidth: 26, minHeight: 26)
                    .padding(.horizontal, Theme.Spacing.s)
                    // Deliberately unobtrusive — recessed rather than a
                    // raised surface, so it doesn't draw the eye.
                    .background(Theme.Color.surfaceRecessed, in: Capsule())
            }

            Spacer(minLength: Theme.Spacing.s)

            accessory()
        }
    }
}

extension CollapsibleSection where Accessory == EmptyView {
    init(title: String, count: Int? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.count = count
        self.content = content
        self.accessory = { EmptyView() }
    }
}

#Preview {
    ZStack {
        Theme.Color.background.ignoresSafeArea()
        VStack {
            CollapsibleSection(title: "Rules") {
                Text("Body content").foregroundStyle(.white)
            } accessory: {
                Text("+ New").foregroundStyle(.white)
            }
            CollapsibleSection(title: "Blocked Apps", count: 5) {
                Text("Body content").foregroundStyle(.white)
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
