# Phase 1: Xcode 프로젝트 스캐폴딩

## 사전 준비

먼저 아래 문서들을 반드시 읽고 프로젝트의 전체 아키텍처와 설계 의도를 완전히 이해하라:

- `docs/code-architecture.md` — 레이어 구성(Views/Flow/Services), 최소 iOS 17.
- `docs/ade.md`의 "Info.plist / Privacy Manifest" 섹션 — 정확한 권한 문구.
- `tasks/0-mvp-v0/docs-diff.md` (이번 task의 문서 변경 기록 — phase 0에서 자동 생성됨)

이전 phase 산출물은 없다(코드 관련 첫 phase). `TestFixtures/`(레포 루트, `phone-front-facing.png`/`phone-tilted-landscape.png`/`phone-recording.png`/`phone-in-flight.png` 4장)는 이미 존재하는 실제 검증용 샘플 사진이니 그대로 사용하라.

## 작업 내용

Xcode에서 새 iOS App 프로젝트를 만들어라:
- Product Name: `Peekpop`
- Organization Identifier: `com.peekpop`
- Interface: SwiftUI, Language: Swift, Storage: None
- Include Tests: 체크 (→ `PeekpopTests` 타겟 자동 생성)
- 저장 위치: 레포 루트 (`Peekpop.xcodeproj`가 레포 루트에 생기도록 — 새 git repo를 만들지 마라, 이미 있는 repo를 그대로 쓴다)
- 두 타겟(`Peekpop`, `PeekpopTests`) 모두 Minimum Deployments를 iOS 17.0으로 설정

`Peekpop/Info.plist`에 아래를 추가하라:

```xml
<key>NSCameraUsageDescription</key>
<string>폰 화면에 보이는 사진을 촬영하기 위해 카메라 접근이 필요해요</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>완성된 사진을 앨범에 저장하기 위해 접근이 필요해요</string>
<key>UIRequiresFullScreen</key>
<true/>
<key>UISupportedInterfaceOrientations</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
</array>
```

File → New → File → Resource → App Privacy File로 `Peekpop/PrivacyInfo.xcprivacy`를 만들고, `NSPrivacyAccessedAPITypes`에 `NSPrivacyAccessedAPICategoryUserDefaults` 항목을 추가하고 reason code `CA92.1`(기기 내 앱 자체 데이터 저장 목적)을 선택하라. `NSPrivacyCollectedDataTypes`는 비워둔다.

레포 루트의 `TestFixtures/` 폴더를 Xcode에서 `PeekpopTests` 타겟으로 드래그해 추가하라 ("Create folder references" 선택, `PeekpopTests` 타겟 멤버십만 체크).

## Acceptance Criteria

```bash
xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## AC 검증 방법

위 커맨드를 실행하라. `** BUILD SUCCEEDED **`가 출력되면 통과다. `tasks/0-mvp-v0/index.json`의 phase 1 status를 `"completed"`로 변경하라. iPhone 17 시뮬레이터가 없으면 `xcrun simctl list devices available`로 사용 가능한 iPhone 시뮬레이터 이름을 확인해 destination을 그걸로 바꿔라. 수정 3회 이상 시도해도 빌드가 안 되면 status를 `"error"`로 바꾸고 에러 내용을 기록하라.

## 주의사항

- Xcode가 git 저장소를 새로 만들자고 제안하면 거부하라 — 이미 `/Users/sunset/Desktop/노을/프로젝트/Peekpop`에 git repo가 있다.
- `Assets.xcassets`에 온보딩용 이미지를 지금 추가하지 마라 — 그건 Phase 7에서 한다(v0는 온보딩 캐러셀이 없고, 메인 화면에 예시 사진 1장만 필요하다).
