import XCTest
@testable import Peekpop

final class ImageLayoutTests: XCTestCase {
    func test_matchingAspect_fillsContainerExactly() {
        let rect = ImageLayout.displayedRect(
            containerSize: CGSize(width: 200, height: 400),
            imageSize: CGSize(width: 100, height: 200)
        )
        XCTAssertEqual(rect, CGRect(x: 0, y: 0, width: 200, height: 400))
    }

    func test_widerImage_letterboxesTopAndBottom() {
        let rect = ImageLayout.displayedRect(
            containerSize: CGSize(width: 200, height: 400),
            imageSize: CGSize(width: 400, height: 100)
        )
        XCTAssertEqual(rect.width, 200, accuracy: 0.001)
        XCTAssertEqual(rect.height, 50, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 175, accuracy: 0.001)
    }

    func test_narrowerImage_letterboxesLeftAndRight() {
        let rect = ImageLayout.displayedRect(
            containerSize: CGSize(width: 400, height: 200),
            imageSize: CGSize(width: 100, height: 400)
        )
        XCTAssertEqual(rect.height, 200, accuracy: 0.001)
        XCTAssertEqual(rect.width, 50, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 175, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 0, accuracy: 0.001)
    }
}
