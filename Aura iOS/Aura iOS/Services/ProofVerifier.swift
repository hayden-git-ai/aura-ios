//
//  ProofVerifier.swift
//  Aura iOS
//

import UIKit

/// What the verifier decided about a photo.
struct ProofVerdict {
    let passed: Bool
    /// What the verifier saw in this photo, in one line. On a pass it's the
    /// line under the celebration; on a fail it's the diagnosis.
    let reason: String?
    /// What to point the camera at next time. Fails only.
    ///
    /// Separate from `reason` because the failure screen shows them as two
    /// lines and the fix goes first: being told how to get it right is more use
    /// than being told what went wrong. Rolled into one sentence the
    /// instruction gets buried behind the diagnosis.
    let fix: String?
    /// True when nothing actually judged the photo: the network was down, the
    /// endpoint failed, the call timed out. The verdict still says pass or
    /// fail, because the user is standing there having done the thing and
    /// needs an answer either way — this is how a caller can tell the
    /// difference between a judgement and a shrug.
    let isFallback: Bool
    /// True when the model's own safety filters refused the photo.
    ///
    /// A fail, but not the same kind of fail, and the screen has to know the
    /// difference. Everything else on the failure screen is the fox being
    /// friendly about a bad angle. This one gets neutral copy, no joke, no
    /// description of what was seen, and no accusation: the filters catch
    /// kitchen knives, boxing gloves and skin as readily as anything genuinely
    /// out of order, and being warned by an app over a photo of your dinner is
    /// how you lose somebody who did nothing wrong.
    let isBlocked: Bool

    init(passed: Bool, reason: String? = nil, fix: String? = nil,
         isFallback: Bool = false, isBlocked: Bool = false) {
        self.passed = passed
        self.reason = reason
        self.fix = fix
        self.isFallback = isFallback
        self.isBlocked = isBlocked
    }
}

/// Judges a photo against what the habit asked for.
///
/// A seam, like `ScreenTimeService`, and for the same reason: the thing behind
/// it is a paid API on somebody else's servers, it can't run in the Simulator
/// without a key, and which vendor it is should be one line rather than a
/// question every screen has an opinion about.
///
/// Deliberately cannot fail. There's no `throws` and no optional return: the
/// user has already done the habit and is holding their phone up waiting, and
/// "an error occurred" is not an outcome the flow has anywhere to put. A live
/// implementation catches its own failures and answers with a fallback verdict.
protocol ProofVerifier: AnyObject {
    func verify(image: UIImage, habit: Habit) async -> ProofVerdict
}

/// Always passes, after a beat.
///
/// The beat is the point. Verification is the one moment in the app where the
/// user waits on something, and a version that answers instantly would let the
/// whole flow be designed around a timing that won't exist in production.
final class MockProofVerifier: ProofVerifier {
    /// DEV: arms the fail path so the retry screen can be exercised. Set from
    /// the camera screen's dev toggle.
    static var forceFail = false

    func verify(image: UIImage, habit: Habit) async -> ProofVerdict {
        try? await Task.sleep(for: .milliseconds(1400))

        if Self.forceFail {
            return ProofVerdict(passed: false,
                                reason: "i genuinely can't tell what that is.",
                                fix: "point it at your \(habit.name.lowercased()) and fill the frame, then try again.")
        }
        return ProofVerdict(passed: true, reason: "looks like \(habit.name.lowercased()) to me.")
    }
}

/// Getting a photo down to something worth sending.
///
/// Separate from any one vendor because it isn't a vendor question. A 12MP
/// capture is thousands of times the data needed to answer "is there a book in
/// this", and every byte of it costs money and seconds on a phone that may be
/// on a gym's wifi. 768px is far more than enough for the judgements these
/// hints ask for.
enum ProofImage {
    static func encoded(_ image: UIImage,
                        maxEdge: CGFloat = 768,
                        quality: CGFloat = 0.7) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }

        let scale = min(1, maxEdge / longest)
        guard scale < 1 else { return image.jpegData(compressionQuality: quality) }

        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1   // points are pixels here; the source is already at device scale
        return UIGraphicsImageRenderer(size: target, format: format)
            .image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
            .jpegData(compressionQuality: quality)
    }
}
