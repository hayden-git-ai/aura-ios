//
//  RepCounter.swift
//  Aura iOS
//

import Foundation
import Vision
import CoreGraphics

/// A single detected body pose — Vision joints in normalized image space
/// (origin bottom-left), already confidence-filtered by the controller.
struct BodyPose {
    var points: [VNHumanBodyPoseObservation.JointName: CGPoint]

    func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        points[joint]
    }
}

enum PoseMath {
    /// Interior angle at vertex `b` of the triangle a-b-c, in degrees.
    static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        let v1 = CGVector(dx: a.x - b.x, dy: a.y - b.y)
        let v2 = CGVector(dx: c.x - b.x, dy: c.y - b.y)
        let m1 = hypot(v1.dx, v1.dy)
        let m2 = hypot(v2.dx, v2.dy)
        guard m1 > 0, m2 > 0 else { return 180 }
        let cosv = max(-1, min(1, (v1.dx * v2.dx + v1.dy * v2.dy) / (m1 * m2)))
        return acos(cosv) * 180 / .pi
    }
}

/// Counts reps (or accumulates held seconds) for one exercise from a stream of
/// poses. Rep counting uses a two-threshold hysteresis on a joint angle so a
/// rep only fires on a full flex→extend cycle, not on jitter.
///
/// NOTE: thresholds (and the Vision image orientation in the controller) are
/// sensible defaults but WILL need tuning on a physical device — the simulator
/// has no camera to calibrate against.
final class RepEngine {
    let exercise: Exercise

    private(set) var reps = 0
    /// Whether the last pose carried the joints this exercise needs.
    ///
    /// Deliberately the same test the counter uses rather than a second guess
    /// at it: `flexionMetric` returning nil IS "cannot count this pose", so the
    /// framing hint and the rep counter can never disagree about whether
    /// somebody is usable in frame.
    private(set) var canRead = false

    private var isFlexed = false

    init(exercise: Exercise) {
        self.exercise = exercise
    }

    func consume(_ pose: BodyPose, at time: Date) {
        updateReps(pose)
    }

    // MARK: - Reps

    private func updateReps(_ pose: BodyPose) {
        guard let flexion = flexionMetric(pose) else {
            canRead = false
            return
        }
        canRead = true
        // `flexion` is 0 (fully extended) … 1 (fully flexed). Enter the flexed
        // phase past 0.65, leave it (and score) once back under 0.35.
        if !isFlexed, flexion > 0.65 {
            isFlexed = true
        } else if isFlexed, flexion < 0.35 {
            isFlexed = false
            reps += 1
        }
    }

    /// A normalized 0…1 "how flexed is the tracked joint" scalar per exercise.
    private func flexionMetric(_ pose: BodyPose) -> CGFloat? {
        switch exercise.id {
        case "pushups":
            return angleFlexion(avgElbowAngle(pose), extended: 160, flexed: 90)
        case "squats", "lunges":
            return angleFlexion(avgKneeAngle(pose), extended: 165, flexed: 100)
        case "situps":
            return angleFlexion(hipAngle(pose), extended: 150, flexed: 90)
        case "jumpingjacks":
            return jumpingJackFlexion(pose)
        default:
            return nil
        }
    }

    /// Maps a joint angle to 0 (at/above `extended`) … 1 (at/below `flexed`).
    private func angleFlexion(_ angle: CGFloat?, extended: CGFloat, flexed: CGFloat) -> CGFloat? {
        guard let angle else { return nil }
        return max(0, min(1, (extended - angle) / (extended - flexed)))
    }

    /// Arms overhead → flexed. Uses wrist height relative to the shoulder-nose
    /// span so it's scale-independent.
    private func jumpingJackFlexion(_ pose: BodyPose) -> CGFloat? {
        guard
            let nose = pose.point(.nose),
            let ls = pose.point(.leftShoulder),
            let rs = pose.point(.rightShoulder)
        else { return nil }
        let shoulderY = (ls.y + rs.y) / 2
        let span = max(0.05, nose.y - shoulderY)   // Vision y increases upward
        var samples: [CGFloat] = []
        if let lw = pose.point(.leftWrist) { samples.append((lw.y - shoulderY) / span) }
        if let rw = pose.point(.rightWrist) { samples.append((rw.y - shoulderY) / span) }
        guard !samples.isEmpty else { return nil }
        let raised = samples.reduce(0, +) / CGFloat(samples.count)   // ~1 at head height, >1 overhead
        return max(0, min(1, raised))
    }

    // MARK: - Joint angles (averaged across whichever side is visible)

    private func avgElbowAngle(_ pose: BodyPose) -> CGFloat? {
        averaged([
            triAngle(pose, .leftShoulder, .leftElbow, .leftWrist),
            triAngle(pose, .rightShoulder, .rightElbow, .rightWrist),
        ])
    }

    private func avgKneeAngle(_ pose: BodyPose) -> CGFloat? {
        averaged([
            triAngle(pose, .leftHip, .leftKnee, .leftAnkle),
            triAngle(pose, .rightHip, .rightKnee, .rightAnkle),
        ])
    }

    private func hipAngle(_ pose: BodyPose) -> CGFloat? {
        averaged([
            triAngle(pose, .leftShoulder, .leftHip, .leftKnee),
            triAngle(pose, .rightShoulder, .rightHip, .rightKnee),
        ])
    }

    private func triAngle(
        _ pose: BodyPose,
        _ a: VNHumanBodyPoseObservation.JointName,
        _ b: VNHumanBodyPoseObservation.JointName,
        _ c: VNHumanBodyPoseObservation.JointName
    ) -> CGFloat? {
        guard let pa = pose.point(a), let pb = pose.point(b), let pc = pose.point(c) else { return nil }
        return PoseMath.angle(pa, pb, pc)
    }

    private func averaged(_ values: [CGFloat?]) -> CGFloat? {
        let present = values.compactMap { $0 }
        guard !present.isEmpty else { return nil }
        return present.reduce(0, +) / CGFloat(present.count)
    }
}
