import CoreGraphics
import XCTest
@testable import Aura_iOS

final class PoseCoordinateTransformTests: XCTestCase {
    func testPortraitAspectFillMirrorsOnceAndCropsHorizontally() {
        // 3:4 camera on a 1:2 viewport: 600x800 scales to 600x800,
        // clipping 100 points on each side of a 400x800 preview.
        let point = PoseCoordinateTransform.previewPoint(
            fromVisionPoint: CGPoint(x: 0.25, y: 0.75),
            bufferSize: CGSize(width: 600, height: 800),
            previewSize: CGSize(width: 400, height: 800), mirrored: true)
        XCTAssertEqual(point.x, 350, accuracy: 0.001)
        XCTAssertEqual(point.y, 200, accuracy: 0.001)
    }

    func testWidePreviewCropsVerticallyAndKeepsCenterFixed() {
        let size = CGSize(width: 400, height: 400)
        let center = PoseCoordinateTransform.previewPoint(
            fromVisionPoint: CGPoint(x: 0.5, y: 0.5),
            bufferSize: CGSize(width: 600, height: 800), previewSize: size, mirrored: true)
        XCTAssertEqual(center.x, 200, accuracy: 0.001)
        XCTAssertEqual(center.y, 200, accuracy: 0.001)
        let top = PoseCoordinateTransform.previewPoint(
            fromVisionPoint: CGPoint(x: 0, y: 1),
            bufferSize: CGSize(width: 600, height: 800), previewSize: size, mirrored: false)
        XCTAssertEqual(top.x, 0, accuracy: 0.001)
        XCTAssertEqual(top.y, -66.6667, accuracy: 0.001)
    }
}
