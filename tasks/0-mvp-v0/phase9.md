# Phase 9: ProcessingView, ErrorView, RootView 배선

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/flow.md` — "4. 처리 (로딩)"과 "환경/예외" 섹션: Vision 실제 오류와 degenerate 마스크 둘 다 같은 에러 화면("다시 시도" 단일 버튼)으로 라우팅. 다크 테마 고정, 세로 화면 고정. 카메라/사진 저장 권한 거부 시 설정 이동 안내.
- `docs/code-architecture.md` — `Screen` enum 5케이스와 `NavigationStack` 미사용 원칙(enum switch로 화면 전환).
- `docs/data-schema.md` — `hasSeenOnboarding`은 v0에서 온보딩 화면이 없으므로 실질적으로 쓰이지 않는다(향후 버전 대비 필드만 유지, 이 phase에서 읽거나 쓰지 않는다).

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Flow/CreationFlowViewModel.swift` — `@Published var screen: Screen`
- `Peekpop/Shared/Screen.swift` — `enum Screen { case main, boundaryConfirm, processing, result, error(String) }`
- `Peekpop/Views/MainView.swift` — `PrimaryButtonStyle`, `MainView`
- `Peekpop/Views/BoundaryConfirmView.swift` — `BoundaryConfirmView`

`Peekpop/PeekpopApp.swift`는 Xcode 프로젝트 생성 시(Phase 1) 기본 템플릿으로 이미 존재한다 — 이 phase에서 덮어쓴다.

## 작업 내용

`Peekpop/Views/ProcessingView.swift`를 작성하라:

```swift
import SwiftUI

struct ProcessingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                Text("만드는 중...")
                    .foregroundStyle(.white)
            }
        }
    }
}
```

`Peekpop/Views/ErrorView.swift`를 작성하라:

```swift
import SwiftUI

struct ErrorView: View {
    let message: String
    @ObservedObject var viewModel: CreationFlowViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(message)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if message.contains("설정") {
                    Button("설정으로 이동") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("다시 시도") {
                    viewModel.retryFromError()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 32)
        }
    }
}
```

`Peekpop/Views/RootView.swift`를 작성하라. `Screen.result`는 Phase 10에서 `ResultView`로 채워질 때까지 `ProcessingView`로 임시 대체한다:

```swift
import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = CreationFlowViewModel()

    var body: some View {
        Group {
            switch viewModel.screen {
            case .main:
                MainView(viewModel: viewModel)
            case .boundaryConfirm:
                BoundaryConfirmView(viewModel: viewModel)
            case .processing:
                ProcessingView()
            case .result:
                ProcessingView() // Phase 10에서 ResultView로 교체
            case .error(let message):
                ErrorView(message: message, viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
    }
}
```

`Peekpop/PeekpopApp.swift`를 아래로 교체하라:

```swift
import SwiftUI

@main
struct PeekpopApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

## Acceptance Criteria

```bash
xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## AC 검증 방법

빌드가 성공하면 `tasks/0-mvp-v0/index.json`의 phase 9 status를 `"completed"`로 변경하라. 이 시점부터 앱이 처음으로 실행 가능해진다 — 가능하면 시뮬레이터에서 한 번 띄워서 메인 화면(예시 사진+버튼)이 보이는지 육안으로 확인하라(자동화된 AC는 아니고, 통과 여부에 영향 없음). 3회 이상 빌드 실패하면 status를 `"error"`로.

## 주의사항

- `Screen.result` 케이스에 `ProcessingView()`를 임시로 넣은 걸 다른 걸로 바꾸지 마라 — Phase 10이 `ResultView`로 교체하는 게 정해진 순서다.
- `NavigationStack`을 쓰지 마라 — `docs/code-architecture.md`에 이미 결정된 사항이다(enum switch가 "다시 만들기" 같은 비-순차 전환에 더 간결).
