import XCTest
@testable import Peekpop

final class PhoneFrameDetectorTests: XCTestCase {
    private func loadFixture(_ name: String) -> CGImage {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: name, withExtension: "png")!
        let data = try! Data(contentsOf: url)
        return UIImage(data: data)!.cgImage!
    }

    func test_detectQuad_findsPlausibleRectangle_onFrontFacingPhoto() async {
        let detector = PhoneFrameDetector()
        let image = loadFixture("phone-front-facing")
        let quad = await detector.detectQuad(in: image)
        XCTAssertNotNil(quad, "should detect the screen on a straight-on phone photo")
        guard let quad else { return }
        let width = quad.topRight.x - quad.topLeft.x
        let height = quad.bottomLeft.y - quad.topLeft.y
        let aspect = width / height
        XCTAssertTrue((0.35...0.7).contains(aspect), "detected aspect \(aspect) should look like a phone screen")
    }

    func test_detectQuad_returnsNil_whenNoPlausibleRectangle() async {
        let detector = PhoneFrameDetector()
        let image = loadFixture("phone-in-flight")
        let quad = await detector.detectQuad(in: image)
        XCTAssertNil(quad, "no confident, plausible-aspect rectangle should be found in this photo")
    }
}
