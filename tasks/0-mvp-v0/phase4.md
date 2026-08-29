# Phase 4: SubjectSegmenter

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/ade.md` — "인물 추출: 크롭 후 범용 전경 인식 채택", "크롭 대상: 폰 UI 제외, 사진 부분만" 두 섹션. 핵심: `VNGeneratePersonSegmentationRequest` 등 사람 특정 인식기는 가장 깔끔한 샘플에서도 0% 인식됐고, `VNGenerateForegroundInstanceMaskRequest`를 **카메라 UI를 제외하고 크롭한 이미지**에만 실행해야 25~56% 커버리지로 안정적으로 작동한다.
- `docs/testing.md` — SubjectSegmenter 테스트 7케이스(실사진 4 + 경계값 3)의 정확한 근거.
- `tasks/0-mvp-v0/docs-diff.md`

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Shared/ScreenQuad.swift`

## 작업 내용

`Peekpop/Services/SubjectSegmenter.swift`를 작성하라:

```swift
import Vision
import CoreImage

/// 이미 크롭된 "사진 영역" 이미지에서 전경 피사체를 오려낸다. 반드시 카메라 UI가 제외된
/// 크롭 이미지로 호출해야 한다 — 그렇지 않으면 인물이 아니라 "UI 대비 밝은 사각형 영역
/// 전체"를 하나의 덩어리로 오려낸다 (docs/ade.md). "사람" 카테고리로 특정하는 인식기는
/// 쓰지 않는다 — 화면에 "찍힌 사진 속 인물"이라 실물 사람과 다르게 인식돼 신뢰도가 낮았다.
struct SubjectSegmenter {
    /// 이 범위 밖이면 degenerate(비정상)로 판정한다. docs/ade.md 스파이크의 실측값
    /// (25~56% 커버리지)을 감싸는 초기값 — 실사용 데이터로 추후 튜닝 필요.
    static let plausibleCoverageRange: ClosedRange<CGFloat> = 0.15...0.85

    private let ciContext = CIContext()

    func generateMask(croppedImage: CGImage) async -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: croppedImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let topInstance = observation.allInstances.sorted().first else {
            return nil
        }
        guard let pixelBuffer = try? observation.generateMaskedImage(
            ofInstances: [topInstance], from: handler, croppedToInstancesExtent: true
        ) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    /// `cutout`의 불투명 픽셀 비율이 plausibleCoverageRange 안에 있는지. 4픽셀 간격으로
    /// 샘플링한다(속도).
    func isPlausible(_ cutout: CGImage) -> Bool {
        Self.plausibleCoverageRange.contains(alphaCoverage(of: cutout))
    }

    private func alphaCoverage(of image: CGImage) -> CGFloat {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return 0 }
        var data = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var opaqueCount = 0
        var sampledCount = 0
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                sampledCount += 1
                if data[y * width + x] > 40 { opaqueCount += 1 }
            }
        }
        guard sampledCount > 0 else { return 0 }
        return CGFloat(opaqueCount) / CGFloat(sampledCount)
    }
}
```

`PeekpopTests/SubjectSegmenterTests.swift`를 작성하라. 실사진 축(4케이스) + 경계값 축(3케이스), 총 7케이스:

```swift
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

    func test_frontFacing_producesPlausibleCutout() async {
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-front-facing")
        let cropped = innerPhotoCrop(of: full, x0: 0.238, y0: 0.25, x1: 0.696, y1: 0.65)
        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        XCTAssertTrue(mask.map(segmenter.isPlausible) ?? false)
    }

    func test_tiltedLandscape_producesPlausibleCutout() async {
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-tilted-landscape")
        let cropped = innerPhotoCrop(of: full, x0: 0.291, y0: 0.395, x1: 0.692, y1: 0.86)
        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        XCTAssertTrue(mask.map(segmenter.isPlausible) ?? false)
    }

    func test_recording_producesPlausibleCutout() async {
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-recording")
        let cropped = innerPhotoCrop(of: full, x0: 0.05, y0: 0.02, x1: 0.95, y1: 0.75)
        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        XCTAssertTrue(mask.map(segmenter.isPlausible) ?? false)
    }

    func test_inFlight_producesPlausibleCutout() async {
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-in-flight")
        let cropped = innerPhotoCrop(of: full, x0: 0.05, y0: 0.05, x1: 0.95, y1: 0.75)
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
```

## Acceptance Criteria

```bash
xcodegen generate
xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/SubjectSegmenterTests
```

## AC 검증 방법

7개 테스트 전부 통과해야 한다. 통과하면 `tasks/0-mvp-v0/index.json`의 phase 4 status를 `"completed"`로. 실사진 4케이스 중 하나라도 계속 실패하면 크롭 좌표를 의심하기 전에 `TestFixtures/`의 실제 이미지 크기·내용이 원본 스파이크 샘플과 같은지 먼저 확인하라(리사이즈되지 않았는지). 3회 이상 실패하면 status를 `"error"`로 바꾸고 어느 케이스가 왜 실패했는지 기록하라.

## 주의사항

- `plausibleCoverageRange`(0.15~0.85) 값을 실사진 테스트를 통과시키려고 임의로 넓히지 마라 — 넓히면 degenerate 판정이 무의미해진다. 실사진 4개는 이미 이 범위 안에 들어오는 것으로 스파이크에서 확인됐다(docs/ade.md).
- 크롭 좌표(x0/y0/x1/y1)를 바꾸지 마라 — 스파이크에서 실측 검증된 값이다. 바꾸면 "카메라 UI 포함 크롭" 문제가 재발한다.
