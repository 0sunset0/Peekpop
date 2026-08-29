# Peekpop Testing Strategy

## 원칙

- **순수 로직에 집중**: mock으로 접착제 코드를 테스트하지 않는다. 구현을 두 번 쓰는 것이지 동작을 검증하는 게 아니다.
- **커버리지 숫자 목표 없음**: 숫자를 채우기 위한 mock 테스트 양산은 시간 낭비. 깨지면 치명적인 로직만 커버.
- **구현과 테스트를 함께 작성**: 모듈 구현 직후 해당 테스트를 작성한다. 일괄 작성 금지.

중요: 테스트는 해당 모듈 구현 직후 바로 작성한다. `docs/superpowers/plans/`의 구현 계획에 테스트 작성 시점이 명시된다.

---

## XCTest 타겟

`PeekpopTests` 타겟. `docs/code-architecture.md`에서 이미 정한 대로 **핵심 로직 서비스만** 테스트하고, SwiftUI 뷰/화면 흐름은 UI 테스트를 만들지 않는다 (실기기 수동 QA로 대체).

- **범위**: Vision/Core Graphics 래퍼(`PhoneFrameDetector`, `SubjectSegmenter`, `PopOutCompositor`)와 상태 전이 로직(`CreationFlowViewModel`), 순수 데이터 타입(`ScreenQuad`). SwiftUI 뷰, `PhotoPicker`/`CameraPicker` 같은 `UIViewControllerRepresentable` 래퍼는 테스트 대상 아님 — UIKit 화면 흐름을 mock하는 건 구현을 다시 쓰는 것과 같다.
- **현재 대상** (v0 스코프, `docs/prd.md`의 "v0 스코프 결정" 참고):
  - `ScreenQuad` — `defaultRect`가 세로로 긴 형태로 중앙에 오는지, 2케이스
  - `PhoneFrameDetector` — 실제 검증된 `TestFixtures/` 사진으로 (a) 정확 검출 시 그럴싸한 종횡비 반환, (b) 오탐/미검출 사진에서 nil 반환, 2케이스
  - `SubjectSegmenter` — degenerate 판정이 정상/비정상을 실제로 구분하는지가 v0에서 유일하게 남은 실질적 불확실성이라 두 축으로 검증한다:
    - 실사진 축: `TestFixtures/`의 4개 샘플(phone-front-facing, phone-tilted-landscape, phone-recording, phone-in-flight) 전부를 검증된 크롭 좌표로 잘라 마스크를 생성하고, 전부 `isPlausible == true`(정상)로 판정되는지 확인 — 4케이스. (4개 다 정상 판정되는 샘플만 있고 실제로 degenerate가 나오는 샘플은 스파이크에서 못 구했음 — ade.md 참고)
    - 경계값 축: 합성 이미지(완전 투명 → 커버리지 0%, 완전 불투명 → 커버리지 100%, 절반만 칠함 → 커버리지 ~50%)로 `isPlausible`의 임계값 로직 자체를 검증 — 0%/100%는 degenerate(false), 50%는 plausible(true), 3케이스.
  - `PopOutCompositor` — 합성 결과가 base 이미지와 동일한 크기로 나오는지 스모크 테스트, 1케이스 (픽셀 단위 정확도는 자동화하지 않음 — `docs/ade.md`에서 이미 "여러 샘플로 미세 조정 필요"로 명시된 영역)
  - `CreationFlowViewModel` — 화면 전이 로직: 메인에서 사진 선택 트리거, 사진 선택 후 화면경계확인 전이, 선택된 사진 없이 확정 시 에러 전이, **degenerate 마스크 시 에러 전이(브러시 화면 없음, v0)**, 에러/다시 만들기 시 피커 자동 표시, 5케이스
- **파일 위치**: `PeekpopTests/<TypeName>Tests.swift` — 1파일 1타입. `@testable import Peekpop`으로 internal 심볼에 접근한다.
- **CI 실행**: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop test -destination "platform=iOS Simulator,name=<iPhone ...>"`. destination은 `xcrun simctl list devices available` 결과에서 동적으로 고르거나, 없으면 `iPhone 17`로 폴백.
- **외부 의존 금지**: Quick/Nimble 등 테스트 보조 라이브러리를 도입하지 않는다. XCTest 내장만 사용한다 (`docs/ade.md`의 "간결하고 빠르게" 원칙과 일치).
- **확장 정책**: 새 서비스/로직 모듈을 추가할 때는 그 모듈을 구현하는 같은 태스크 안에서 테스트도 함께 추가한다. 이 타겟을 "전체 모듈 커버리지"로 부풀리지 않는다 — Vision/SwiftUI 화면 코드에 대한 mock 테스트는 추가하지 않는다.
