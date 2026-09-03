import XCTest
@testable import Peekpop

final class UIImageOrientedTests: XCTestCase {
    private func makeCGImage(width: Int, height: Int) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    func test_upOrientation_leavesBufferUnchanged() {
        let raw = makeCGImage(width: 50, height: 80)
        let uiImage = UIImage(cgImage: raw, scale: 1, orientation: .up)

        let oriented = uiImage.orientedCGImage

        XCTAssertEqual(oriented?.width, 50)
        XCTAssertEqual(oriented?.height, 80)
    }

    func test_rightOrientation_normalizesToUprightDimensions() {
        // Portrait photo: sensor buffer is stored landscape (100x200) and tagged
        // `.right` so viewers rotate it 90° — this is exactly the shape that made
        // portrait photos come out sideways when the raw `.cgImage` was used directly.
        let raw = makeCGImage(width: 100, height: 200)
        let uiImage = UIImage(cgImage: raw, scale: 1, orientation: .right)

        XCTAssertEqual(uiImage.size, CGSize(width: 200, height: 100))

        let oriented = uiImage.orientedCGImage

        XCTAssertEqual(oriented?.width, 200)
        XCTAssertEqual(oriented?.height, 100)
    }
}
