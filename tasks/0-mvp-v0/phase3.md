# Phase 3: PhoneFrameDetector

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/ade.md` — "화면 경계 인식: 자동 결과를 신뢰하지 않고 프리필+사용자 확인으로" 섹션. 실제 스파이크 수치: `VNDetectRectanglesRequest`를 4장에 테스트해서 정확 검출 25%, 신뢰도 1.00 오탐 50%, 미검출 25%. 종횡비 0.4~0.6 필터로 오탐을 걸러냈다.
- `docs/testing.md` — PhoneFrameDetector 테스트 2케이스.
- `tasks/0-mvp-v0/docs-diff.md`

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Shared/ScreenQuad.swift` — `ScreenQuad` 구조체(원점 좌상단, y 아래로 증가)
- `PeekpopTests/` 안의 `TestFixtures/` 참조 방식(타겟 멤버십으로 추가돼 있음)

## 작업 내용

`Peekpop/Services/PhoneFrameDetector.swift`를 작성하라:

```swift
import Vision
import CoreGraphics

/// 사진 속 "사진이 표시되는 영역"을 자동으로 추정한다. 이 결과는 절대 그대로 신뢰하지
/// 않는다 — 사용자가 항상 확인/조정하는 초안(프리필) 용도다 (docs/ade.md: 신뢰도 1.0으로
/// 확신에 찬 오탐이 나온 사례 있음).
struct PhoneFrameDetector {
    private static let plausibleAspectRange: ClosedRange<CGFloat> = 0.4...0.6

    func detectQuad(in image: CGImage) async -> ScreenQuad? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumConfidence = 0.5
        request.maximumObservations = 5

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results else { return nil }

        for observation in results {
            let width = hypot(
                observation.topRight.x - observation.topLeft.x,
                observation.topRight.y - observation.topLeft.y
            )
            let height = hypot(
                observation.topLeft.x - observation.bottomLeft.x,
                observation.topLeft.y - observation.bottomLeft.y
            )
            guard height > 0 else { continue }
            let aspect = width / height
            guard Self.plausibleAspectRange.contains(aspect) else { continue }

            // Vision 좌표는 원점 좌하단, y 위로 증가 — ScreenQuad 규약(원점 좌상단, y 아래로
            // 증가)에 맞게 y를 뒤집는다.
            return ScreenQuad(
                topLeft: CGPoint(x: observation.topLeft.x, y: 1 - observation.topLeft.y),
                topRight: CGPoint(x: observation.topRight.x, y: 1 - observation.topRight.y),
                bottomRight: CGPoint(x: observation.bottomRight.x, y: 1 - observation.bottomRight.y),
                bottomLeft: CGPoint(x: observation.bottomLeft.x, y: 1 - observation.bottomLeft.y)
            )
        }
        return nil
    }
}
```

`PeekpopTests/PhoneFrameDetectorTests.swift`를 작성하라:

```swift
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
        XCTAssertTrue((0.35...0.65).contains(aspect), "detected aspect \(aspect) should look like a phone screen")
    }

    func test_detectQuad_returnsNil_whenNoPlausibleRectangle() async {
        let detector = PhoneFrameDetector()
        let image = loadFixture("phone-in-flight")
        let quad = await detector.detectQuad(in: image)
        XCTAssertNil(quad, "no confident, plausible-aspect rectangle should be found in this photo")
    }
}
```

## Acceptance Criteria

```bash
xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/PhoneFrameDetectorTests
```

## AC 검증 방법

위 커맨드로 두 테스트가 다 통과하면 `tasks/0-mvp-v0/index.json`의 phase 3 status를 `"completed"`로 변경하라. `phone-in-flight` 샘플이 실제로는 아주 낮은 확률로 다른 이유의 사각형을 찾아 테스트가 흔들릴 수 있는데, 그런 경우 `plausibleAspectRange`를 건드리지 말고(스파이크로 검증된 값) 왜 실패했는지 로그를 남기고 재시도하라. 3회 이상 실패하면 status를 `"error"`로 바꿔라.

## 주의사항

- `plausibleAspectRange`(0.4~0.6)나 `minimumAspectRatio`/`maximumAspectRatio`(0.3~1.0) 값을 임의로 바꾸지 마라 — `docs/ade.md`에 실측으로 근거가 남아있다.
- 이 서비스가 nil을 반환하는 건 정상 동작이다(실패 케이스가 아니라 "확신 없음"을 뜻함) — nil을 다른 값으로 fallback하지 마라. fallback은 Phase 6의 `CreationFlowViewModel`이 `ScreenQuad.defaultRect`로 처리한다.
