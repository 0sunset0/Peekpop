import XCTest
@testable import Peekpop

final class SubjectSegmenterTests: XCTestCase {
    private func loadFixture(_ name: String) -> CGImage {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: name, withExtension: "png")!
        let data = try! Data(contentsOf: url)
        return UIImage(data: data)!.cgImage!
    }

    private func innerPhotoCrop(of image: CGImage, x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat) -> CGImage {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let rect = CGRect(x: x0 * w, y: y0 * h, width: (x1 - x0) * w, height: (y1 - y0) * h)
        return image.cropping(to: rect)!
    }

    // MARK: - 실사진 축: TestFixtures 4장 전부 plausible(true)로 판정돼야 함
    // (docs/ade.md 스파이크에서 검증된 크롭 좌표 그대로 사용)
    //
    // NOTE: VNGenerateForegroundInstanceMaskRequest는 Neural Engine 추론이 필요해서
    // iOS 시뮬레이터에서 "Could not create inference context"(Vision 에러코드 9)로
    // 항상 실패한다 (코드 버그 아님 — 동일 크롭을 macOS 호스트에서 직접 돌리면 정상
    // 동작 확인됨, docs/ade.md 참고). 시뮬레이터에서는 스킵하고, 실기기 검증은
    // phase 11 실기기 QA에서 수행한다.

    private func skipIfSimulator() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("VNGenerateForegroundInstanceMaskRequest requires a real device (Neural Engine) — see docs/ade.md")
        #endif
    }

    func test_frontFacing_producesPlausibleCutout() async throws {
        try skipIfSimulator()
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-front-facing")
        let cropped = innerPhotoCrop(of: full, x0: 0.262, y0: 0.200, x1: 0.760, y1: 0.688)
        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        XCTAssertTrue(mask.map(segmenter.isPlausible) ?? false)
    }

    func test_tiltedLandscape_producesPlausibleCutout() async throws {
        try skipIfSimulator()
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-tilted-landscape")
        let cropped = innerPhotoCrop(of: full, x0: 0.340, y0: 0.245, x1: 0.775, y1: 0.660)
        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        XCTAssertTrue(mask.map(segmenter.isPlausible) ?? false)
    }

    func test_recording_producesPlausibleCutout() async throws {
        try skipIfSimulator()
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-recording")
        let cropped = innerPhotoCrop(of: full, x0: 0.262, y0: 0.205, x1: 0.760, y1: 0.735)
        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        XCTAssertTrue(mask.map(segmenter.isPlausible) ?? false)
    }

    func test_inFlight_producesPlausibleCutout() async throws {
        try skipIfSimulator()
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-in-flight")
        let cropped = innerPhotoCrop(of: full, x0: 0.304, y0: 0.290, x1: 0.746, y1: 0.701)
        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        XCTAssertTrue(mask.map(segmenter.isPlausible) ?? false)
    }

    // MARK: - 경계값 축: 커버리지 임계값 로직 자체를 합성 이미지로 검증
    // (실제로 degenerate가 나오는 실사진 샘플을 스파이크에서 못 구했음 — docs/testing.md 참고)

    func test_isPlausible_falseForEmptyMask() {
        let segmenter = SubjectSegmenter()
        let empty = Self.solidAlphaImage(width: 100, height: 100, coverage: 0.0)
        XCTAssertFalse(segmenter.isPlausible(empty))
    }

    func test_isPlausible_falseForFullMask() {
        let segmenter = SubjectSegmenter()
        let full = Self.solidAlphaImage(width: 100, height: 100, coverage: 1.0)
        XCTAssertFalse(segmenter.isPlausible(full))
    }

    func test_isPlausible_trueForHalfMask() {
        let segmenter = SubjectSegmenter()
        let half = Self.solidAlphaImage(width: 100, height: 100, coverage: 0.5)
        XCTAssertTrue(segmenter.isPlausible(half))
    }

    /// `coverage`만큼의 세로 폭(왼쪽부터)을 불투명하게 채운 이미지를 만든다.
    private static func solidAlphaImage(width: Int, height: Int, coverage: CGFloat) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let opaqueWidth = Int(CGFloat(width) * coverage)
        if opaqueWidth > 0 {
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: opaqueWidth, height: height))
        }
        return ctx.makeImage()!
    }
}
