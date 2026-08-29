# Phase 11: 실기기 QA

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/testing.md` — SwiftUI 뷰/화면 흐름은 자동 UI 테스트를 만들지 않고 실기기 수동 QA로 대체한다는 원칙.
- `docs/flow.md` — v0 전체 흐름(메인→사진선택→화면경계확인→처리→결과, 에러 화면 포함)과 각 화면의 정확한 동작.
- `docs/ade.md` — PopOutCompositor의 배율(1.3)·오프셋 비율(0.42)은 스파이크에서 대략 검증한 값이라 실기기에서 미세 조정이 필요할 수 있다는 점.

그리고 이전 phase의 작업물을 전부 확인하라 — Phase 1~10에서 만든 `Peekpop/` 전체 코드와 `PeekpopTests/` 전체 테스트.

## 작업 내용

### 1. 전체 유닛 테스트 실행

```bash
xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17'
```

모든 테스트(`ScreenQuadTests` 2, `PhoneFrameDetectorTests` 2, `SubjectSegmenterTests` 7, `PopOutCompositorTests` 3, `CreationFlowViewModelTests` 5 — 합계 19케이스)가 통과해야 한다.

### 2. 실기기 설치 및 수동 QA 체크리스트

물리 iPhone을 연결해 Xcode에서 실행하라(시뮬레이터는 카메라가 없고 Vision 전경 인식 정확도도 실기기와 다를 수 있다). `TestFixtures/`의 4장을 AirDrop이나 케이블로 기기 사진 앱에 미리 넣어두고, 아래 항목을 하나씩 실행하며 pass/fail을 기록하라:

- [ ] 앱 최초 실행 시 메인 화면에 예시 사진(`phone-front-facing`)과 안내 문구, "사진 선택하기" 버튼이 보인다.
- [ ] "사진 선택하기" 탭 → "카메라로 촬영"/"앨범에서 선택" 선택지가 뜬다.
- [ ] "카메라로 촬영" 선택 시(최초 1회) `NSCameraUsageDescription`에 설정한 문구("폰 화면에 보이는 사진을 촬영하기 위해...")로 권한 프롬프트가 뜬다.
- [ ] "앨범에서 선택" → `TestFixtures/phone-front-facing` 선택 → 확인 없이 곧장 화면 경계 확인 화면으로 넘어간다.
- [ ] 화면 경계 확인 화면에서 노란 사각형이 사진 위에 뜨고, 네 꼭짓점을 각각 드래그해서 위치를 바꿀 수 있다.
- [ ] "뒤로" 탭 → 사진 선택 시트가 다시 뜬다(메인 화면 버튼을 또 누를 필요 없이).
- [ ] `phone-front-facing`으로 "확인" 탭 → 로딩 화면("만드는 중...") → 결과 화면까지 브러시 보정 화면 없이 한 번에 도달한다(그럴싸함 게이트 통과 경로).
- [ ] 결과 화면에서 합성된 이미지가 보이고, 인물이 화면 경계 밖으로 튀어나온 것처럼 보인다(완벽하지 않아도 됨 — `docs/ade.md`에 이미 배치 비율은 튜닝 필요 항목으로 명시됨).
- [ ] "저장" 탭 → 버튼이 잠깐 체크마크로 바뀐다. 최초 1회는 `NSPhotoLibraryAddUsageDescription` 문구로 권한 프롬프트가 뜬다. 카메라롤(사진 앱)에 결과 이미지가 실제로 추가됐는지 확인한다.
- [ ] "공유하기" 탭 → iOS 공유 시트가 뜨고 이미지가 첨부돼 있다.
- [ ] "다시 만들기" 탭 → 메인 화면을 거치지 않고 곧장 사진 선택 시트가 뜬다.
- [ ] `TestFixtures/phone-in-flight`(스파이크에서 화면 경계 자동 검출이 실패했던 샘플)로 다시 시도 — 화면 경계 확인 화면에서 자동 프리필 없이 기본 사각형(세로로 긴 형태, 사진 중앙)이 뜨는지 확인한다.
- [ ] 사진 저장 권한을 설정 앱에서 껐다가 "저장"을 다시 탭 → 에러 화면(설정 이동 안내 문구 + "설정으로 이동" 버튼)이 뜨고, 버튼을 누르면 실제로 설정 앱으로 이동한다.
- [ ] 세로 모드에서 가로로 기기를 돌려도 화면이 회전하지 않는다(세로 고정).
- [ ] 시스템 설정이 라이트 모드여도 앱은 항상 다크 테마로 보인다.

## Acceptance Criteria

```bash
xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17'
# 전체 19개 유닛 테스트 케이스 PASS
```

위 "실기기 설치 및 수동 QA 체크리스트"의 14개 항목이 전부 pass여야 한다(자동 실행 커맨드는 없음 — 각 항목을 직접 수행하고 pass/fail로 판정).

## AC 검증 방법

유닛 테스트 커맨드를 실행해 전부 통과하는지 먼저 확인하라. 그다음 체크리스트 14개 항목을 순서대로 실기기에서 실행하고, 각 항목의 pass/fail을 `tasks/0-mvp-v0/index.json`의 phase 11 항목에 `qa_checklist`라는 배열 필드로 기록하라(각 원소: `{"item": "...", "result": "pass"|"fail"}`). 전부 pass면 status를 `"completed"`로 바꿔라. fail인 항목이 있으면, 그 항목이 가리키는 phase(예: 저장 관련이면 Phase 10, 배치 관련이면 Phase 5)의 코드를 직접 고치고 다시 체크리스트를 처음부터 수행하라. 수정 3회 이상 시도해도 어떤 항목이 계속 fail하면 status를 `"error"`로 바꾸고 어느 항목이 왜 실패하는지 `error_message`에 기록하라.

## 주의사항

- 체크리스트 항목을 "대충 봤을 때 괜찮아 보임" 수준으로 pass 처리하지 마라 — 특히 권한 프롬프트 문구, 카메라롤 실제 저장 여부, "다시 만들기"가 메인이 아니라 사진 선택으로 바로 가는지는 눈으로 직접 확인해야 한다.
- 배치 비율(`popOutScale`, `insideFraction`)을 조정하고 싶으면 `Peekpop/Services/PopOutCompositor.swift`를 고치고 Phase 5의 유닛 테스트(`PopOutCompositorTests`)가 여전히 통과하는지 재확인하라 — 값이 바뀌어도 그 테스트들은 각도/크기 로직만 검증하므로 깨지지 않아야 정상이다.
