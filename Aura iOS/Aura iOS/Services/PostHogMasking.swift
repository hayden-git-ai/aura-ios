//
//  PostHogMasking.swift
//  Aura iOS
//
//  `.maskedInReplays()` hides a view from PostHog session recordings so personal
//  content (support messages, name, email) never appears in a replay. PostHog's
//  built-in `maskAllTextInputs` / `maskAllImages` cover text FIELDS and images, but
//  not static displayed `Text` — this is how we mask those specific surfaces.
//
//  No-op until the PostHog package is added (same `#if canImport` pattern as the
//  bootstrap), so it's safe to sprinkle on views regardless.
//

import SwiftUI

extension View {
    @ViewBuilder
    func maskedInReplays() -> some View {
        #if canImport(PostHog)
        self.postHogMask()
        #else
        self
        #endif
    }
}

#if canImport(PostHog)
import PostHog
#endif
