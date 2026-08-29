import XCTest
@testable import Peekpop

final class ScreenQuadTests: XCTestCase {
    func test_defaultRect_isCenteredAndPortrait() {
        let quad = ScreenQuad.defaultRect
        let widthFraction = quad.topRight.x - quad.topLeft.x
        let heightFraction = quad.bottomLeft.y - quad.topLeft.y
        // widthFraction은 컨테이너 "가로" 기준, heightFraction은 "세로" 기준이라 서로 다른
        // 축이다 — 컨테이너가 정사각형이 아니므로(세로로 긴 폰 화면) 프랙션을 그대로
        // 비교하면 안 되고, 대표 컨테이너 크기(iPhone 기준)에 대입해 실제 화면비로 비교한다.
        let referenceContainer = CGSize(width: 393, height: 852)
        let widthPoints = widthFraction * referenceContainer.width
        let heightPoints = heightFraction * referenceContainer.height
        XCTAssertGreaterThan(heightPoints, widthPoints, "default rect should render taller than wide on a real portrait screen")
        XCTAssertEqual(quad.topLeft.x, 1 - quad.topRight.x, accuracy: 0.001, "should be horizontally centered")
        XCTAssertEqual(quad.topLeft.y, 1 - quad.bottomLeft.y, accuracy: 0.001, "should be vertically centered")
    }
}
