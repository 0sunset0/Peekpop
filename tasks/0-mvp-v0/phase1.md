# Phase 1: Xcode 프로젝트 스캐폴딩 (xcodegen, CLI 전용)

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/code-architecture.md` — 레이어 구성(Views/Flow/Services), 최소 iOS 17.
- `docs/ade.md`의 "Info.plist / Privacy Manifest" 섹션 — 정확한 권한 문구.
- `tasks/0-mvp-v0/docs-diff.md` (이번 task의 문서 변경 기록 — phase 0에서 자동 생성됨)

이전 phase 산출물은 없다(코드 관련 첫 phase). `TestFixtures/`(레포 루트, `phone-front-facing.png`/`phone-tilted-landscape.png`/`phone-recording.png`/`phone-in-flight.png` 4장)는 이미 존재하는 실제 검증용 샘플 사진이니 그대로 사용하라.

**GUI로 Xcode를 열어 "File → New → Project"를 하지 마라.** 이 phase는 CLI 전용으로 진행한다 — `xcodegen`(이미 `/opt/homebrew/bin/xcodegen`에 설치돼 있고 버전 2.45.4로 동작 확인됨)으로 `project.yml`에서 `.xcodeproj`를 생성한다.

## 작업 내용

레포 루트에 아래 파일들을 만들어라.

`project.yml`:

```yaml
name: Peekpop
options:
  bundleIdPrefix: com.peekpop
  deploymentTarget:
    iOS: "17.0"
targets:
  Peekpop:
    type: application
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: Peekpop
    info:
      path: Peekpop/Info.plist
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.peekpop.Peekpop
        TARGETED_DEVICE_FAMILY: "1"
        GENERATE_INFOPLIST_FILE: NO
  PeekpopTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - path: PeekpopTests
      - path: TestFixtures
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.peekpop.PeekpopTests
        GENERATE_INFOPLIST_FILE: YES
    dependencies:
      - target: Peekpop
schemes:
  Peekpop:
    build:
      targets:
        Peekpop: all
        PeekpopTests: [test]
    test:
      targets:
        - PeekpopTests
```

`TestFixtures`를 `sources`에 `path: TestFixtures`로만(폴더 참조 타입 지정 없이) 넣어야 한다 — 이렇게 하면 리소스가 번들 최상위에 평평하게 복사돼서, 테스트 코드의 `Bundle(for:).url(forResource:withExtension:)` 호출(서브디렉토리 인자 없음)이 그대로 찾을 수 있다. `type: folder`를 쓰면 `TestFixtures/` 하위 경로로 중첩 복사돼서 못 찾는다(실제로 검증됨).

`Peekpop/PeekpopApp.swift` (나중 phase에서 교체될 임시 진입점 — 지금은 컴파일만 되면 된다):

```swift
import SwiftUI

@main
struct PeekpopApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Peekpop")
        }
    }
}
```

`Peekpop/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ko</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>폰 화면에 보이는 사진을 촬영하기 위해 카메라 접근이 필요해요</string>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>완성된 사진을 앨범에 저장하기 위해 접근이 필요해요</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiresFullScreen</key>
    <true/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>
</dict>
</plist>
```

`Peekpop/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

`Peekpop/Assets.xcassets/Contents.json` (빈 에셋 카탈로그 — Phase 7에서 이미지가 추가됨):

```json
{
  "info": {
    "author": "xcode",
    "version": 1
  }
}
```

프로젝트를 생성하고 빌드하라:

```bash
xcodegen generate
```

## Acceptance Criteria

```bash
xcodegen generate
xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## AC 검증 방법

두 커맨드를 순서대로 실행하라. `xcodebuild`가 `** BUILD SUCCEEDED **`를 출력하면 통과다. `tasks/0-mvp-v0/index.json`의 phase 1 status를 `"completed"`로 변경하라. iPhone 17 시뮬레이터가 없으면 `xcrun simctl list devices available`로 사용 가능한 iPhone 시뮬레이터 이름을 확인해 destination을 그걸로 바꿔라(이후 모든 phase의 AC 커맨드도 동일하게 바꿔야 한다). 수정 3회 이상 시도해도 빌드가 안 되면 status를 `"error"`로 바꾸고 에러 내용을 기록하라.

## 주의사항

- Xcode GUI로 프로젝트를 만들지 마라 — `xcodegen generate`만 쓴다. GUI로 만들면 이후 phase들이 프로젝트 구조를 재현성 있게 다시 만들 수 없다.
- `Peekpop.xcodeproj`는 `xcodegen generate`가 `project.yml`로부터 매번 재생성하는 산출물이다 — 그래도 git에는 커밋한다(다른 개발자가 xcodegen 없이도 바로 열 수 있게). `project.yml`을 고쳤으면 커밋 전에 반드시 `xcodegen generate`를 다시 실행해 `.xcodeproj`를 최신 상태로 맞춰라.
- `TestFixtures`의 `sources` 항목에 `type: folder`를 쓰지 마라 — 리소스가 서브디렉토리로 중첩돼서 이후 phase(3, 4)의 테스트가 `Bundle.url(forResource:withExtension:)`로 파일을 못 찾게 된다(직접 검증됨).
- Info.plist의 두 권한 문구를 다른 문구로 바꾸지 마라 — `docs/ade.md`에서 이미 확정된 문구다.
