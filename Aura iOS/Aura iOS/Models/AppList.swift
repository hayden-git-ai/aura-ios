//
//  AppList.swift
//  Aura iOS
//

import Foundation

/// A named, reusable set of apps ("Brainrot Apps", "Off Limits", …) that block
/// rules point at. Managed on the Blocks screen's App Lists section.
struct AppList: Identifiable, Hashable {
    let id: UUID
    var name: String
    var appIconNames: [String]

    init(id: UUID = UUID(), name: String, appIconNames: [String] = []) {
        self.id = id
        self.name = name
        self.appIconNames = appIconNames
    }
}

/// The set of apps a user can add to a list — stand-ins until the real
/// FamilyActivityPicker is wired once Screen Time entitlements exist.
enum AppCatalog {
    struct Entry: Identifiable, Hashable {
        var iconName: String
        var displayName: String
        var id: String { iconName }
    }

    static let all: [Entry] = [
        .init(iconName: "AppIconInstagram", displayName: "Instagram"),
        .init(iconName: "AppIconTikTok", displayName: "TikTok"),
        .init(iconName: "AppIconYouTube", displayName: "YouTube"),
        .init(iconName: "AppIconSnapchat", displayName: "Snapchat"),
        .init(iconName: "AppIconX", displayName: "X"),
        .init(iconName: "AppIconReddit", displayName: "Reddit"),
        .init(iconName: "AppIconThreads", displayName: "Threads"),
        .init(iconName: "AppIconFacebook", displayName: "Facebook"),
        .init(iconName: "AppIconChatGPT", displayName: "ChatGPT"),
        .init(iconName: "MessagesIcon", displayName: "Messages"),
        .init(iconName: "MusicIcon", displayName: "Music"),
        .init(iconName: "BooksIcon", displayName: "Books"),
    ]

    static func displayName(for icon: String) -> String {
        all.first(where: { $0.iconName == icon })?.displayName ?? icon
    }
}
