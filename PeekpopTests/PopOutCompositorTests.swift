import XCTest
@testable import Peekpop

final class PopOutCompositorTests: XCTestCase {
    func test_compose_producesImageMatchingBaseDimensions() {
        let compositor = PopOutCompositor()
        let base = Self.solidImage(width: 200, height: 300, gray: 0.8)
        let cutout = Self.solidImage(width: 80, height: 160, gray: 0.2)
        let quad = ScreenQuad(
            topLeft: CGPoint(x: 0.25, y: 0.1), topRight: CGPoint(x: 0.75, y: 0.1),
            bottomRight: CGPoint(x: 0.75, y: 0.6), bottomLeft: CGPoint(x: 0.25, y: 0.6)
        )
        let result = compositor.compose(baseImage: base, quad: quad, cutout: cutout)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, base.width)
        XCTAssertEqual(result?.height, base.height)
    }

    func test_rotationAngle_isZero_forHorizontalBottomEdge() {
        let angle = PopOutCompositor.rotationAngle(
            bottomLeft: CGPoint(x: 100, y: 500), bottomRight: CGPoint(x: 300, y: 500)
        )
        XCTAssertEqual(angle, 0, accuracy: 0.0001)
    }

    func test_rotationAngle_matchesExpectedTilt() {
        let bl = CGPoint(x: 100, y: 400)
        let br = CGPoint(x: 400, y: 460)
        let angle = PopOutCompositor.rotationAngle(bottomLeft: bl, bottomRight: br)
        let expected = atan2(br.y - bl.y, br.x - bl.x)
        XCTAssertEqual(angle, expected, accuracy: 0.0001)
        XCTAssertGreaterThan(angle, 0, "bottom-right lower than bottom-left should give a positive angle in y-down space")
    }

    private static func solidImage(width: Int, height: Int, gray: CGFloat) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}
