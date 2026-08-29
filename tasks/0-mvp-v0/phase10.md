# Phase 10: ResultView

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/flow.md` — "5. 결과": 저장/공유하기/다시 만들기, 수정 버튼 없음, 저장 탭 시 체크마크 피드백, "다시 만들기"는 메인이 아니라 사진 선택으로 바로 감.
- `docs/ade.md` — `NSPhotoLibraryAddUsageDescription`(add-only 권한, 전체 라이브러리 접근 아님) 사용 이유.

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Flow/CreationFlowViewModel.swift` — `@Published var resultImage: CGImage?`, `func startOver()`, `var screen: Screen`(에러로 전환 가능)
- `Peekpop/Views/MainView.swift` — `PrimaryButtonStyle`
- `Peekpop/Views/RootView.swift` — `.result` 케이스가 지금 `ProcessingView()`로 임시 처리돼 있음, 이걸 `ResultView`로 교체한다

## 작업 내용

`Peekpop/Views/ResultView.swift`를 작성하라:

```swift
import SwiftUI
import Photos

struct ResultView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var justSaved = false
    @State private var shareURL: URL?

    var body: some View {
        VStack(spacing: 24) {
            if let result = viewModel.resultImage {
                Image(decorative: result, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }

            HStack(spacing: 16) {
                Button {
                    Task { await save() }
                } label: {
                    Image(systemName: justSaved ? "checkmark" : "square.and.arrow.down")
                }
                .buttonStyle(PrimaryButtonStyle())

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("다시 만들기") {
                    viewModel.startOver()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .task { prepareShareURL() }
    }

    private func prepareShareURL() {
        guard let result = viewModel.resultImage else { return }
        let uiImage = UIImage(cgImage: result)
        guard let data = uiImage.pngData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        try? data.write(to: url)
        shareURL = url
    }

    private func save() async {
        guard let result = viewModel.resultImage else { return }
        let uiImage = UIImage(cgImage: result)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            viewModel.screen = .error("설정에서 사진 저장 권한을 허용해주세요")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }
            justSaved = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            justSaved = false
        } catch {
            viewModel.screen = .error("저장하지 못했어요. 다시 시도해주세요.")
        }
    }
}
```

`Peekpop/Views/RootView.swift`의 `.result` 케이스를 교체하라:

```swift
case .result:
    ResultView(viewModel: viewModel)
```

## Acceptance Criteria

```bash
xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## AC 검증 방법

빌드가 성공하면 `tasks/0-mvp-v0/index.json`의 phase 10 status를 `"completed"`로 변경하라. 이 시점에 v0의 모든 화면 코드가 갖춰진다(메인→화면경계확인→처리→결과/에러) — 앱을 시뮬레이터에서 실행해 첫 화면이 뜨는지 확인해도 좋다. 3회 이상 빌드 실패하면 status를 `"error"`로.

## 주의사항

- `PHPhotoLibrary.requestAuthorization(for: .addOnly)`를 `for: .readWrite`로 바꾸지 마라 — add-only가 `NSPhotoLibraryAddUsageDescription`(Phase 1에서 설정한 권한)에 대응하는 최소 권한이다. `.readWrite`로 바꾸면 다른 Info.plist 키(`NSPhotoLibraryUsageDescription`)가 필요해지고 더 넓은 권한을 요구하게 된다.
- 저장 버튼이 체크마크로 바뀌는 애니메이션에 별도 라이브러리를 쓰지 마라 — `justSaved` 상태값 토글로 충분하다.
