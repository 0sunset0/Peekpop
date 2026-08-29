import Vision
import CoreImage

/// 이미 크롭된 "사진 영역" 이미지에서 전경 피사체를 오려낸다. 반드시 카메라 UI가 제외된
/// 크롭 이미지로 호출해야 한다 — 그렇지 않으면 인물이 아니라 "UI 대비 밝은 사각형 영역
/// 전체"를 하나의 덩어리로 오려낸다 (docs/ade.md). "사람" 카테고리로 특정하는 인식기는
/// 쓰지 않는다 — 화면에 "찍힌 사진 속 인물"이라 실물 사람과 다르게 인식돼 신뢰도가 낮았다.
struct SubjectSegmenter {
    /// 이 범위 밖이면 degenerate(비정상)로 판정한다. docs/ade.md 스파이크의 실측값
    /// (25~56% 커버리지)을 감싸는 초기값 — 실사용 데이터로 추후 튜닝 필요.
    static let plausibleCoverageRange: ClosedRange<CGFloat> = 0.15...0.85

    private let ciContext = CIContext()

    func generateMask(croppedImage: CGImage) async -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: croppedImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let topInstance = observation.allInstances.sorted().first else {
            return nil
        }
        // croppedToInstancesExtent: false — keep the mask at the SAME size/position as
        // `croppedImage`, with the subject left in its natural place and everything
        // else transparent. PopOutCompositor relies on this to place the pop-out
        // directly over where the subject already is in the photo (docs/ade.md) —
        // a tightly-cropped cutout (true) throws that position away.
        guard let pixelBuffer = try? observation.generateMaskedImage(
            ofInstances: [topInstance], from: handler, croppedToInstancesExtent: false
        ) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    /// `cutout`의 불투명 픽셀 비율이 plausibleCoverageRange 안에 있는지. 4픽셀 간격으로
    /// 샘플링한다(속도).
    func isPlausible(_ cutout: CGImage) -> Bool {
        Self.plausibleCoverageRange.contains(alphaCoverage(of: cutout))
    }

    private func alphaCoverage(of image: CGImage) -> CGFloat {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return 0 }
        var data = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var opaqueCount = 0
        var sampledCount = 0
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                sampledCount += 1
                if data[y * width + x] > 40 { opaqueCount += 1 }
            }
        }
        guard sampledCount > 0 else { return 0 }
        return CGFloat(opaqueCount) / CGFloat(sampledCount)
    }
}
