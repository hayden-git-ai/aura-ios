//
//  PoseSkeletonOverlay.swift
//  Aura iOS
//

import SwiftUI
import Vision

/// Draws the detected body-pose skeleton (bones + joints) over the camera feed
/// in the app's cyan. Points are converted from Vision space to view space by
/// the controller so they line up with the mirrored aspect-fill preview.
struct PoseSkeletonOverlay: View {
    @ObservedObject var poseLayer: PoseLayer
    let convert: (CGPoint) -> CGPoint

    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        // No neck-to-nose. Vision gives no skull, so it drew as a bare line
        // running off the shoulders to a floating dot rather than as a head.
    ]

    /// Every joint that is an end of a bone. Derived from `bones` rather than
    /// listed again, so removing a line removes its orphan dots with it.
    private static let jointsInUse: Set<VNHumanBodyPoseObservation.JointName> =
        Set(bones.flatMap { [$0.0, $0.1] })

    /// The app's blue, not the cyan every pose-tracking app defaults to.
    private let boneColor = LightSheet.blue

    var body: some View {
        Canvas { context, _ in
            guard let pose = poseLayer.pose else { return }

            for (a, b) in Self.bones {
                guard let pa = pose.point(a), let pb = pose.point(b) else { continue }
                var path = Path()
                path.move(to: convert(pa))
                path.addLine(to: convert(pb))
                context.stroke(path, with: .color(boneColor.opacity(0.9)), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            }

            // Only joints a line actually lands on. Vision tracks the nose and
            // the neck whether or not anything is drawn between them, so with
            // the neck line gone they were still painting two dots floating
            // above the shoulders with nothing to belong to.
            for (joint, point) in pose.points where Self.jointsInUse.contains(joint) {
                _ = joint
                let p = convert(point)
                let r: CGFloat = 5
                context.fill(
                    Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                    // Under full white: the joints are punctuation on the
                    // lines, and at full strength they read as the brighter
                    // element and break the limbs into segments.
                    with: .color(.white.opacity(0.7))
                )
            }
        }
        .allowsHitTesting(false)
    }
}
