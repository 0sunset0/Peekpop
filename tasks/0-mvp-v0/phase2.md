# Phase 2: 공용 타입 — ScreenQuad, Screen

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/code-architecture.md` — "화면 상태" 섹션의 `Screen` enum 정의(5케이스: main, boundaryConfirm, processing, result, error).
- `docs/ade.md` — 좌표계 관련: 화면 경계 사각형은 정규화(0...1) 좌표, 원점 좌상단, y 아래로 증가(일반 이미지 좌표계와 동일). Vision의 결과는 원점 좌하단이라 변환이 필요하다는 점.
- `docs/testing.md` — ScreenQuad 테스트 2케이스.
- `tasks/0-mvp-v0/docs-diff.md`

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop.xcodeproj`, `Peekpop/` 디렉토리 구조 (Phase 1에서 생성됨)

## 작업 내용

`Peekpop/Shared/ScreenQuad.swift`를 작성하라:

```swift
import CoreGraphics

/// 사용자가 화면에서 지정하는 "사진이 보이는 영역". 정규화(0...1), 원점 좌상단, y 아래로 증가.
struct ScreenQuad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// 자동 검출이 실패했을 때 쓰는 기본값: 화면 중앙의 세로로 긴(~1:1.6) 사각형.
    static let defaultRect: ScreenQuad = {
        let halfW: CGFloat = 0.25
        let halfH: CGFloat = 0.4
        let midX: CGFloat = 0.5
        let midY: CGFloat = 0.5
        return ScreenQuad(
            topLeft: CGPoint(x: midX - halfW, y: midY - halfH),
            topRight: CGPoint(x: midX + halfW, y: midY - halfH),
            bottomRight: CGPoint(x: midX + halfW, y: midY + halfH),
            bottomLeft: CGPoint(x: midX - halfW, y: midY + halfH)
        )
    }()
}
```

`Peekpop/Shared/Screen.swift`를 작성하라:

```swift
/// v0 화면 상태. 온보딩·브러시 보정 화면은 없다 (tech-critic-lead 게이트, docs/prd.md 참고).
enum Screen: Equatable {
    case main
    case boundaryConfirm
    case processing
    case result
    case error(String)
}
```

`PeekpopTests/ScreenQuadTests.swift`를 작성하라:

```swift
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
```

## Acceptance Criteria

```bash
xcodegen generate
xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/ScreenQuadTests
```

## AC 검증 방법

위 커맨드를 실행해 `** TEST SUCCEEDED **`가 나오면 통과다. `tasks/0-mvp-v0/index.json`의 phase 2 status를 `"completed"`로 변경하라. 실패 시 코드를 고치고 재실행하되, 3회 이상 실패하면 status를 `"error"`로 바꾸고 에러 내용을 기록하라.

## 주의사항

- `Screen` enum에 `onboarding`이나 `brushRefine` 케이스를 넣지 마라 — v0엔 없다.
- `ScreenQuad`의 좌표계(원점 좌상단, y 아래로 증가)를 다른 방향으로 바꾸지 마라. 이후 모든 phase(특히 PhoneFrameDetector의 Vision 좌표 변환, PopOutCompositor의 배치 계산)가 이 규약을 전제로 한다.
