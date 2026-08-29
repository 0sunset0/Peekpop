# Phase 5: PopOutCompositor

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/code-architecture.md` — "PopOutCompositor 배치 로직" 섹션: 회전각 계산 → 컷아웃 회전+확대 배치 → 그림자.
- `docs/ade.md` — "합성 배치: 사각형 기울기 반영 필수" 섹션. 고정 비율 배치는 폰이 기울어진 사진에서 어색했고, 사용자가 지정한 4점의 기울기를 반영해야 한다.
- `docs/testing.md` — PopOutCompositor 테스트 3케이스(스모크 1 + 회전각 2). 시각적 배치 품질은 주관적이라 자동화하지 않고 phase 11 실기기 QA로 검증한다.
- `tasks/0-mvp-v0/docs-diff.md`

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Shared/ScreenQuad.swift`

## 작업 내용

`Peekpop/Services/PopOutCompositor.swift`를 작성하라. 회전각 계산은 순수 함수로 분리해서(테스트 가능하게) 만든다:

```swift
import CoreGraphics

/// 오려낸 피사체를 화면 경계 밖으로 확대·재배치하고 그림자를 넣어 "튀어나온" 합성 이미지를
/// 만든다. 배치는 사용자가 지정한 사각형의 기울기를 반영한다 — 고정 비율 배치는 폰이
/// 기울어진 사진에서 부자연스러웠다 (docs/ade.md).
struct PopOutCompositor {
    private let popOutScale: CGFloat = 1.3
    private let insideFraction: CGFloat = 0.42

    /// 사각형 아래쪽 변(bottomLeft→bottomRight)의 기울기를 라디안으로 반환한다.
    /// 순수 함수 — 이미지 좌표계(원점 좌상단, y 아래로 증가)를 그대로 쓴다.
    static func rotationAngle(bottomLeft: CGPoint, bottomRight: CGPoint) -> CGFloat {
        atan2(bottomRight.y - bottomLeft.y, bottomRight.x - bottomLeft.x)
    }

    func compose(baseImage: CGImage, quad: ScreenQuad, cutout: CGImage) -> CGImage? {
        let outW = baseImage.width, outH = baseImage.height
        guard let ctx = CGContext(
            data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(baseImage, in: topDownRectToContext(CGRect(x: 0, y: 0, width: outW, height: outH), canvasH: outH))

        let bottomLeftPx = CGPoint(x: quad.bottomLeft.x * CGFloat(outW), y: quad.bottomLeft.y * CGFloat(outH))
        let bottomRightPx = CGPoint(x: quad.bottomRight.x * CGFloat(outW), y: quad.bottomRight.y * CGFloat(outH))
        let angle = Self.rotationAngle(bottomLeft: bottomLeftPx, bottomRight: bottomRightPx)
        let bottomMid = CGPoint(x: (bottomLeftPx.x + bottomRightPx.x) / 2, y: (bottomLeftPx.y + bottomRightPx.y) / 2)

        let cutoutW = CGFloat(cutout.width) * popOutScale
        let cutoutH = CGFloat(cutout.height) * popOutScale

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
        ctx.translateBy(x: bottomMid.x, y: CGFloat(outH) - bottomMid.y)
        ctx.rotate(by: -angle)
        let drawRect = CGRect(x: -cutoutW / 2, y: -(cutoutH * insideFraction), width: cutoutW, height: cutoutH)
        ctx.draw(cutout, in: drawRect)
        ctx.restoreGState()

        return ctx.makeImage()
    }

    private func topDownRectToContext(_ rect: CGRect, canvasH: Int) -> CGRect {
        CGRect(x: rect.origin.x, y: CGFloat(canvasH) - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }
}
```

`PeekpopTests/PopOutCompositorTests.swift`를 작성하라:

```swift
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
```

## Acceptance Criteria

```bash
xcodegen generate
xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/PopOutCompositorTests
```

## AC 검증 방법

3개 테스트 전부 통과하면 `tasks/0-mvp-v0/index.json`의 phase 5 status를 `"completed"`로 변경하라. 3회 이상 실패하면 status를 `"error"`로.

## 주의사항

- `popOutScale`(1.3)과 `insideFraction`(0.42)은 스파이크에서 대략 검증한 값이다 — 정확한 시각적 품질은 phase 11에서 사람이 눈으로 확인하고, 필요하면 그때 조정한다. 지금 단계에서 "더 예뻐 보이게" 임의로 바꾸지 마라.
- `compose`가 반환하는 이미지의 시각적 정확도(배치가 자연스러운가)는 이 phase의 AC 대상이 아니다 — 크기만 맞으면 통과다.
