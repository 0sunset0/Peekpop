# Code Architecture — Peekpop

단일 Xcode 프로젝트/타겟. SPM 모듈 분리 없음 (규모 대비 과한 추상화, "간결하고 빠르게" 원칙).

## 레이어

```
Views/     화면당 SwiftUI View 1개 (flow.md v0의 5개 화면). CreationFlowViewModel을 관찰만 함.
Flow/      CreationFlowViewModel — 단일 ObservableObject. 흐름 전체 상태(선택 사진, 확정
           사각형 4점, AI 마스크, 합성 결과, 현재 화면, 에러)를 전부 보유.
           화면별로 쪼개지 않는다 — 흐름이 선형이라 하나로 충분, 쪼개면 동기화 비용만 늚.
Services/  PhoneFrameDetector, SubjectSegmenter, PopOutCompositor — Vision/CoreGraphics
           래퍼. 프로토콜 추상화·DI 없이 concrete 타입 (테스트도 실제 이미지로 돌리므로
           Vision을 mock할 이유가 없음).
```

## 화면 상태

```swift
enum Screen {
  case main, boundaryConfirm, processing, result, error(String)
}
```

v0는 온보딩 캐러셀과 브러시 보정 화면이 없다(tech-critic-lead 게이트, `docs/prd.md` 참고). `generating`/`compositing` 두 로딩 상태도 `processing` 하나로 합친다 — 사용자에게는 어차피 같은 스피너로 보이고, 중간에 melt-in할 별도 화면이 없다.

`CreationFlowViewModel`이 들고, 루트 뷰가 switch로 화면을 바꾼다. `NavigationStack` 미사용 — "다시 만들기"처럼 스택을 여러 단계 건너뛰는 이동이 있어, push/pop보다 단일 상태값 전환이 더 간결하다.

## 동시성

Vision 호출(`VNImageRequestHandler.perform`, 동기 API)은 `Task { }` 안에서 `async`/`await`로 감싸고, 완료 후 메인 액터에서 ViewModel 상태를 갱신한다.

## PopOutCompositor 배치 로직

1. 사용자가 지정한 4점에서 사각형 회전각을 계산한다 (예: 아래쪽 두 점을 잇는 선의 기울기).
2. 컷아웃을 그 각도로 회전시킨 뒤, 사각형 아래쪽 변 밖으로 확대·오프셋 배치한다.
3. 그림자는 배치 방향에 맞춰 오프셋을 준다.

정확한 확대 배율·오프셋 비율은 스파이크에서 고정값으로 대략 검증한 수준이라, 구현 중 여러 샘플로 미세 조정이 필요하다.

## 에러 처리

두 경우 모두 `CreationFlowViewModel`이 `Screen.error(message)`로 전환하고, 같은 에러 화면("다시 시도" 버튼 하나로 사진 선택 화면 복귀)을 재사용한다 — 결과 화면의 "다시 만들기"와 동일 패턴.

1. Vision 단계에서 실제 예외(인식 실패가 아닌 진짜 오류)가 발생했을 때.
2. `SubjectSegmenter`가 마스크는 만들었지만 결과가 degenerate(커버리지가 `plausibleCoverageRange` 밖 — 거의 비어있거나 거의 전체를 덮음)할 때. v0엔 브러시로 고쳐 쓰는 UI가 없으므로, 애매한 경우도 전부 재시도로 보낸다(다음 버전의 브러시 보정 화면이 이 경로를 대체할 예정).

## 테스트 범위

- 유닛 테스트: `PhoneFrameDetector`, `SubjectSegmenter`, `PopOutCompositor` — 번들 포함 샘플 이미지 몇 장으로 회귀 테스트만.
- SwiftUI 뷰/화면 흐름 UI 테스트는 만들지 않는다 — 실기기 수동 QA로 대체.
