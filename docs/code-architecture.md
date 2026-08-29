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

`CreationFlowViewModel`이 들고, 루트 뷰가 switch로 화면을 바꾼다. `NavigationStack` 미사용 — "홈으로"/"다시 시도"처럼 스택을 여러 단계 건너뛰는 이동이 있어, push/pop보다 단일 상태값 전환이 더 간결하다.

## 동시성

Vision 호출(`VNImageRequestHandler.perform`, 동기 API)은 `Task { }` 안에서 `async`/`await`로 감싸고, 완료 후 메인 액터에서 ViewModel 상태를 갱신한다.

## PopOutCompositor 배치 로직

1. `SubjectSegmenter`는 `croppedToInstancesExtent: false`로 마스크를 만든다 — 크롭 영역과 같은 크기, 피사체는 원래 있던 자리 그대로, 나머지는 투명. 위치 정보를 지키기 위함(스파이크와 동일 설정, docs/ade.md).
2. `PopOutCompositor.boundingRect(for:imageWidth:imageHeight:)`로 원본 사진 속 크롭 영역(=quad를 감싸는 축 정렬 사각형)을 계산한다 — `CreationFlowViewModel`이 크롭할 때도 같은 함수를 재사용해 둘이 어긋나지 않게 한다.
3. 그 크롭 영역의 **중심**을 기준으로 컷아웃을 확대한다 — 피사체가 크롭 안 어디에 있었든 원래 자리를 덮으며 사방으로 커진다("항상 아래쪽에만 나온다"던 이전 설계의 버그를 고침).
4. 사용자가 지정한 4점에서 계산한 사각형 회전각만큼 그 중심을 기준으로 회전시켜 기울어진 사진에서도 자연스럽게 만든다.
5. 그림자를 적용한다.

`PopOutCompositor.compose(baseImage:quad:cutout:extraScale:extraOffset:extraRotation:)`의 `extraScale`/`extraOffset`/`extraRotation`은 결과 화면에서 사용자가 드래그·핀치·두 손가락 회전으로 조정한 값이다(기본 1.0/.zero/0 = 조정 없음) — Vision을 다시 부르지 않고 같은 마스크로 즉시 재합성한다. `CreationFlowViewModel.adjustmentChanged(scale:offset:rotation:)`가 이 재합성을 트리거한다. `ResultView`는 `DragGesture`+`MagnificationGesture`+`RotationGesture`를 `SimultaneousGesture`로 중첩해서 셋을 동시에 받는다.

정확한 기본 확대 배율(`enlargeScale`)은 스파이크·실기기 QA로 튜닝한 값이라, 다양한 사진으로 추가 검증 여지가 있다 — 다만 이제 사용자가 결과 화면에서 직접 보정할 수 있어 완벽한 자동값이 아니어도 된다.

## 에러 처리

두 경우 모두 `CreationFlowViewModel`이 `Screen.error(message)`로 전환하고, 같은 에러 화면("다시 시도" 버튼 하나로 사진 선택 화면 복귀)을 재사용한다.

`retryFromError()`(에러→피커 자동 표시), `startOver()`(경계확인 뒤로가기 `<`→피커 자동 표시)와 `goHome()`(결과 화면 "홈으로"→메인에 머무름, 피커 자동 표시 안 함)은 서로 다른 함수다 — 이름이 비슷해 보이지만 뒤로가기·재시도는 "바로 사진 선택으로", 홈으로는 "메인 화면에서 잠깐 멈춤"으로 의도적으로 다르게 동작한다(디자인 리뷰 반영).

1. Vision 단계에서 실제 예외(인식 실패가 아닌 진짜 오류)가 발생했을 때.
2. `SubjectSegmenter`가 마스크는 만들었지만 결과가 degenerate(커버리지가 `plausibleCoverageRange` 밖 — 거의 비어있거나 거의 전체를 덮음)할 때. v0엔 브러시로 고쳐 쓰는 UI가 없으므로, 애매한 경우도 전부 재시도로 보낸다(다음 버전의 브러시 보정 화면이 이 경로를 대체할 예정).

## 테스트 범위

- 유닛 테스트: `PhoneFrameDetector`, `SubjectSegmenter`, `PopOutCompositor` — 번들 포함 샘플 이미지 몇 장으로 회귀 테스트만.
- SwiftUI 뷰/화면 흐름 UI 테스트는 만들지 않는다 — 실기기 수동 QA로 대체.
