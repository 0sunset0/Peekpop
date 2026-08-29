# Phase 7: MainView + 사진 선택(카메라/앨범) 연동

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/flow.md` — "1. 메인" 화면: 온보딩 캐러셀이 없으므로 이 화면이 예시 사진 1장 + 안내 문구로 촬영법을 겸해 안내한다. "2. 사진 선택"은 iOS 표준 시트, 앨범 선택은 권한 불필요.
- `docs/ade.md` — Info.plist 권한 문구(Phase 1에서 이미 추가됨), 카메라 권한은 촬영 선택 시에만 트리거됨.

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Flow/CreationFlowViewModel.swift` — `mainButtonTapped()`, `photoSelected(_ image: CGImage)`, `@Published var isPickerPresented: Bool`

## 작업 내용

`Peekpop/Assets.xcassets`에 Image Set `phone-front-facing`을 추가하고, 레포 루트의 `TestFixtures/phone-front-facing.png`를 넣어라(1x 슬롯이면 충분) — 메인 화면의 예시 사진으로 재사용한다.

`Peekpop/Views/PhotoPicker.swift`를 작성하라:

```swift
import SwiftUI
import PhotosUI

/// PHPickerViewController 래핑. 이 방식은 권한 프롬프트가 없다(docs/ade.md).
struct PhotoPicker: UIViewControllerRepresentable {
    var onImagePicked: (CGImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (CGImage) -> Void
        init(onImagePicked: @escaping (CGImage) -> Void) { self.onImagePicked = onImagePicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [onImagePicked] object, _ in
                guard let uiImage = object as? UIImage, let cgImage = uiImage.cgImage else { return }
                DispatchQueue.main.async { onImagePicked(cgImage) }
            }
        }
    }
}
```

`Peekpop/Views/CameraPicker.swift`를 작성하라:

```swift
import SwiftUI

/// UIImagePickerController(카메라 모드) 래핑. 처음 표시될 때 NSCameraUsageDescription
/// 프롬프트를 띄운다.
struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (CGImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (CGImage) -> Void
        init(onImagePicked: @escaping (CGImage) -> Void) { self.onImagePicked = onImagePicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let uiImage = info[.originalImage] as? UIImage, let cgImage = uiImage.cgImage else { return }
            onImagePicked(cgImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
```

`Peekpop/Views/MainView.swift`를 작성하라 (예시 사진+안내 문구가 온보딩을 대신한다):

```swift
import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct MainView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var presentCamera = false
    @State private var presentLibrary = false

    var body: some View {
        VStack(spacing: 24) {
            Image("phone-front-facing")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("폰 카메라 앱을 켜고,\n화면에 인물이 보이게 찍어주세요")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
            Button("사진 선택하기") {
                viewModel.mainButtonTapped()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 48)
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .confirmationDialog("사진 선택", isPresented: $viewModel.isPickerPresented, titleVisibility: .hidden) {
            Button("카메라로 촬영") { presentCamera = true }
            Button("앨범에서 선택") { presentLibrary = true }
            Button("취소", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $presentCamera) {
            CameraPicker { image in
                presentCamera = false
                viewModel.photoSelected(image)
            }
        }
        .sheet(isPresented: $presentLibrary) {
            PhotoPicker { image in
                presentLibrary = false
                viewModel.photoSelected(image)
            }
        }
    }
}
```

## Acceptance Criteria

```bash
xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## AC 검증 방법

빌드가 `** BUILD SUCCEEDED **`로 성공하면 `tasks/0-mvp-v0/index.json`의 phase 7 status를 `"completed"`로 변경하라. 이 phase 시점엔 아직 `RootView`가 없어서 앱을 직접 실행해 확인할 수는 없다(Phase 9에서 배선됨) — 빌드 성공만으로 충분하다. 3회 이상 빌드 실패하면 status를 `"error"`로.

## 주의사항

- `PrimaryButtonStyle`을 다른 파일에서 또 정의하지 마라 — 이후 phase(8, 9, 10)의 뷰들이 이 파일에 정의된 걸 그대로 재사용한다(같은 타겟이라 import 없이 접근 가능).
- 온보딩 캐러셀이나 페이지 인디케이터를 만들지 마라 — v0는 이 한 화면으로 안내를 끝낸다.
