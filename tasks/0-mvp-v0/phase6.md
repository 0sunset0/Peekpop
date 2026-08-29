# Phase 6: CreationFlowViewModel

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/code-architecture.md` 전체 — 특히 "화면 상태"(Screen 5케이스), "동시성"(async/await), "에러 처리"(Vision 예외와 degenerate 마스크 둘 다 같은 에러 화면으로) 섹션.
- `docs/flow.md` — v0 5화면 흐름과 "다시 만들기"가 메인이 아니라 사진 선택으로 바로 가는 이유.
- `docs/testing.md` — CreationFlowViewModel 테스트 5케이스.
- `tasks/0-mvp-v0/docs-diff.md`

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Shared/ScreenQuad.swift` — `ScreenQuad`, `static let defaultRect`
- `Peekpop/Shared/Screen.swift` — `enum Screen { case main, boundaryConfirm, processing, result, error(String) }`
- `Peekpop/Services/PhoneFrameDetector.swift` — `func detectQuad(in image: CGImage) async -> ScreenQuad?`
- `Peekpop/Services/SubjectSegmenter.swift` — `func generateMask(croppedImage: CGImage) async -> CGImage?`, `func isPlausible(_ cutout: CGImage) -> Bool`
- `Peekpop/Services/PopOutCompositor.swift` — `func compose(baseImage: CGImage, quad: ScreenQuad, cutout: CGImage) -> CGImage?`

## 작업 내용

`Peekpop/Flow/CreationFlowViewModel.swift`를 작성하라. v0는 온보딩·브러시 보정이 없으므로 관련 상태/메서드를 만들지 않는다. `SubjectSegmenter.isPlausible`이 false면 브러시 화면 대신 곧장 에러로 라우팅한다:

```swift
import CoreGraphics
import Foundation

/// 흐름 전체의 단일 상태 소스. 화면별로 쪼개지 않는다(docs/code-architecture.md).
@MainActor
final class CreationFlowViewModel: ObservableObject {
    @Published var screen: Screen = .main
    @Published var isPickerPresented: Bool = false
    @Published var selectedImage: CGImage?
    @Published var quad: ScreenQuad = .defaultRect
    @Published var resultImage: CGImage?

    private let frameDetector: PhoneFrameDetector
    private let segmenter: SubjectSegmenter
    private let compositor: PopOutCompositor

    init(
        frameDetector: PhoneFrameDetector = PhoneFrameDetector(),
        segmenter: SubjectSegmenter = SubjectSegmenter(),
        compositor: PopOutCompositor = PopOutCompositor()
    ) {
        self.frameDetector = frameDetector
        self.segmenter = segmenter
        self.compositor = compositor
    }

    func mainButtonTapped() {
        isPickerPresented = true
    }

    func photoSelected(_ image: CGImage) {
        selectedImage = image
        quad = .defaultRect
        screen = .boundaryConfirm
        Task { await detectInitialQuad() }
    }

    private func detectInitialQuad() async {
        guard let image = selectedImage else { return }
        if let detected = await frameDetector.detectQuad(in: image) {
            quad = detected
        }
    }

    func confirmBoundary(_ confirmedQuad: ScreenQuad) async {
        quad = confirmedQuad
        screen = .processing
        guard let image = selectedImage, let cropped = croppedImage(from: image, quad: confirmedQuad) else {
            screen = .error("사진을 처리하지 못했어요.")
            return
        }
        guard let mask = await segmenter.generateMask(croppedImage: cropped), segmenter.isPlausible(mask) else {
            screen = .error("튀어나올 부분을 찾지 못했어요. 다른 사진으로 다시 시도해주세요.")
            return
        }
        guard let composed = compositor.compose(baseImage: image, quad: confirmedQuad, cutout: mask) else {
            screen = .error("이미지를 합성하지 못했어요.")
            return
        }
        resultImage = composed
        screen = .result
    }

    func retryFromError() {
        selectedImage = nil
        resultImage = nil
        screen = .main
        isPickerPresented = true
    }

    func startOver() {
        selectedImage = nil
        resultImage = nil
        screen = .main
        isPickerPresented = true
    }

    private func croppedImage(from image: CGImage, quad: ScreenQuad) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let minX = min(quad.topLeft.x, quad.bottomLeft.x) * w
        let maxX = max(quad.topRight.x, quad.bottomRight.x) * w
        let minY = min(quad.topLeft.y, quad.topRight.y) * h
        let maxY = max(quad.bottomLeft.y, quad.bottomRight.y) * h
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return image.cropping(to: rect)
    }
}
```

`PeekpopTests/CreationFlowViewModelTests.swift`를 작성하라:

```swift
import XCTest
@testable import Peekpop

@MainActor
final class CreationFlowViewModelTests: XCTestCase {
    func test_mainButtonTapped_presentsPicker() {
        let vm = CreationFlowViewModel()
        vm.mainButtonTapped()
        XCTAssertTrue(vm.isPickerPresented)
    }

    func test_photoSelected_goesToBoundaryConfirm() {
        let vm = CreationFlowViewModel()
        let image = Self.solidImage(width: 10, height: 10)
        vm.photoSelected(image)
        XCTAssertEqual(vm.screen, .boundaryConfirm)
        XCTAssertNotNil(vm.selectedImage)
    }

    func test_confirmBoundary_withNoSelectedImage_goesToError() async {
        let vm = CreationFlowViewModel()
        await vm.confirmBoundary(.defaultRect)
        if case .error = vm.screen {} else {
            XCTFail("expected .error, got \(vm.screen)")
        }
    }

    func test_confirmBoundary_withDegenerateMask_goesToErrorNotBrush() async {
        // SubjectSegmenter의 실제 Vision 호출 결과는 크롭 대상에 따라 달라지므로, 여기서는
        // "선택된 이미지가 있고 크롭도 유효한데 세그멘테이션이 아무 인스턴스도 못 찾는" 경우를
        // 아주 작은 단색 이미지(피사체가 없어 인스턴스가 안 잡힘)로 재현한다.
        let vm = CreationFlowViewModel()
        let blank = Self.solidImage(width: 50, height: 50)
        vm.photoSelected(blank)
        await vm.confirmBoundary(.defaultRect)
        if case .error = vm.screen {} else {
            XCTFail("degenerate/empty segmentation should route to .error, not a brush screen (v0 has none), got \(vm.screen)")
        }
    }

    func test_retryFromError_returnsToMainAndPresentsPicker() {
        let vm = CreationFlowViewModel()
        vm.screen = .error("test")
        vm.retryFromError()
        XCTAssertEqual(vm.screen, .main)
        XCTAssertTrue(vm.isPickerPresented)
    }

    private static func solidImage(width: Int, height: Int) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}
```

## Acceptance Criteria

```bash
xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/CreationFlowViewModelTests
```

## AC 검증 방법

5개 테스트 전부 통과하면 `tasks/0-mvp-v0/index.json`의 phase 6 status를 `"completed"`로. `test_confirmBoundary_withDegenerateMask_goesToErrorNotBrush`가 흔들리면(단색 이미지에서도 어쩌다 인스턴스가 잡히는 경우) 이미지를 더 단순하게(완전 흰색 1x1을 리사이즈 없이 그대로 등) 바꿔서 재시도하라. 3회 이상 실패하면 status를 `"error"`로.

## 주의사항

- `Screen` enum에 없는 케이스(onboarding, brushRefine 등)를 참조하는 코드를 쓰지 마라 — 컴파일 에러가 난다.
- `confirmBoundary`에서 `isPlausible`이 false일 때 절대 `compose`를 호출하지 마라 — degenerate 마스크를 그대로 합성하면 이상한 결과가 조용히 나가는 걸 막는다는 v0의 핵심 성공 기준(docs/prd.md)을 어기는 것이다.
