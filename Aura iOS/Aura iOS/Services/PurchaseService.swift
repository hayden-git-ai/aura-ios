//
//  PurchaseService.swift
//  Aura iOS
//
//  StoreKit seam. The Live impl (StoreKit 2 Product/Transaction/AppStore) lands in
//  Phase E with App Store Connect products. The Mock drives the paywall,
//  purchase, restore, pending, and failure paths deterministically. Views never
//  call StoreKit directly. No release path hardcodes a successful entitlement.
//

import Foundation

/// Which offer a purchase targets.
enum PurchaseablePlan: Equatable {
    case annual
    case weekly
    case exitOffer

    var selectedPlan: SelectedPlan {
        switch self {
        case .annual, .exitOffer: return .annual
        case .weekly:             return .weekly
        }
    }
}
