//
//  AuraLink.swift
//  Aura iOS
//

import Foundation

/// Every outbound link the app opens, in one place.
enum AuraLink {
    static let site = URL(string: "https://www.downloadaura.app")!
    static let help = URL(string: "https://www.downloadaura.app/help")!
    static let requestFeature = URL(string: "https://downloadaura.featurebase.app/dashboard/posts?b=69f2830050101ae6f637615a")!
    // Report a bug and Contact us now open the in-app founders chat
    // (SupportChatView), not a web form, so their URLs are gone.
    static let privacy = URL(string: "https://www.downloadaura.app/privacy")!
    static let terms = URL(string: "https://www.downloadaura.app/terms")!
    static let manageSubscription = URL(string: "https://www.downloadaura.app/manage-subscription")!
    static let instagram = URL(string: "https://www.instagram.com/downloadaura")!
    static let tiktok = URL(string: "https://www.tiktok.com/@downloadaura.app")!
}
