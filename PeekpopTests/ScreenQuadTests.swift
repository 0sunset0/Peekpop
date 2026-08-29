import XCTest
@testable import Peekpop

final class ScreenQuadTests: XCTestCase {
    func test_defaultRect_isCenteredAndPortrait() {
        let quad = ScreenQuad.defaultRect
        let width = quad.topRight.x - quad.topLeft.x
        let height = quad.bottomLeft.y - quad.topLeft.y
        XCTAssertGreaterThan(height, width, "default rect should be taller than wide")
        XCTAssertEqual(quad.topLeft.x, 1 - quad.topRight.x, accuracy: 0.001, "should be horizontally centered")
        XCTAssertEqual(quad.topLeft.y, 1 - quad.bottomLeft.y, accuracy: 0.001, "should be vertically centered")
    }
}
