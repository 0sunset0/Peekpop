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
    /// 자동 배치 후 결과 화면에서 사용자가 손가락으로 조정한 값 — PopOutCompositor에
    /// 그대로 전달돼 재합성에 쓰인다. 1.0/.zero면 자동 배치 그대로.
    @Published var adjustScale: CGFloat = 1.0
    @Published var adjustOffset: CGPoint = .zero
    @Published var adjustRotation: CGFloat = 0

    private var maskedCutout: CGImage?

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
        maskedCutout = mask
        adjustScale = 1.0
        adjustOffset = .zero
        adjustRotation = 0
        guard let composed = compositor.compose(baseImage: image, quad: confirmedQuad, cutout: mask) else {
            screen = .error("이미지를 합성하지 못했어요.")
            return
        }
        resultImage = composed
        screen = .result
    }

    /// 결과 화면에서 드래그/핀치로 위치·크기를 조정할 때마다 호출한다. 조정값을 반영해
    /// 즉시 재합성한다 — 원본 사진/사각형/마스크는 그대로 두고 배치만 다시 계산하므로
    /// Vision을 다시 호출하지 않는다(빠름).
    func adjustmentChanged(scale: CGFloat, offset: CGPoint, rotation: CGFloat) {
        adjustScale = scale
        adjustOffset = offset
        adjustRotation = rotation
        guard let image = selectedImage, let cutout = maskedCutout else { return }
        if let composed = compositor.compose(
            baseImage: image, quad: quad, cutout: cutout,
            extraScale: scale, extraOffset: offset, extraRotation: rotation
        ) {
            resultImage = composed
        }
    }

    func retryFromError() {
        selectedImage = nil
        resultImage = nil
        maskedCutout = nil
        screen = .main
        isPickerPresented = true
    }

    func startOver() {
        selectedImage = nil
        resultImage = nil
        maskedCutout = nil
        screen = .main
        isPickerPresented = true
    }

    /// 결과 화면 우측 상단 X 버튼 전용 — 메인 화면에 머무르고, 사용자가 직접
    /// "사진 선택하기"를 눌러야 피커가 뜬다. 곧장 피커를 다시 여는 startOver()/
    /// retryFromError()와 의도적으로 다른 동작이다(디자인 리뷰 반영).
    func goHome() {
        selectedImage = nil
        resultImage = nil
        maskedCutout = nil
        screen = .main
        isPickerPresented = false
    }

    /// PopOutCompositor.boundingRect와 반드시 같은 계산이어야 한다 — compositor가 이
    /// 크롭과 같은 위치/크기의 cutout을 가정하고 원래 자리 위에 확대해서 그린다.
    private func croppedImage(from image: CGImage, quad: ScreenQuad) -> CGImage? {
        let rect = PopOutCompositor.boundingRect(for: quad, imageWidth: image.width, imageHeight: image.height)
        return image.cropping(to: rect)
    }
}
