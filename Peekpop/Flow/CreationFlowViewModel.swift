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
