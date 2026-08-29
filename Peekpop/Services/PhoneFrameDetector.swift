import Vision
import CoreGraphics

/// 사진 속 "사진이 표시되는 영역"을 자동으로 추정한다. 이 결과는 절대 그대로 신뢰하지
/// 않는다 — 사용자가 항상 확인/조정하는 초안(프리필) 용도다 (docs/ade.md: 신뢰도 1.0으로
/// 확신에 찬 오탐이 나온 사례 있음).
struct PhoneFrameDetector {
    private static let plausibleAspectRange: ClosedRange<CGFloat> = 0.4...0.6

    func detectQuad(in image: CGImage) async -> ScreenQuad? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumConfidence = 0.5
        request.maximumObservations = 5

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results else { return nil }

        for observation in results {
            let width = hypot(
                observation.topRight.x - observation.topLeft.x,
                observation.topRight.y - observation.topLeft.y
            )
            let height = hypot(
                observation.topLeft.x - observation.bottomLeft.x,
                observation.topLeft.y - observation.bottomLeft.y
            )
            guard height > 0 else { continue }
            let aspect = width / height
            guard Self.plausibleAspectRange.contains(aspect) else { continue }

            // Vision 좌표는 원점 좌하단, y 위로 증가 — ScreenQuad 규약(원점 좌상단, y 아래로
            // 증가)에 맞게 y를 뒤집는다.
            return ScreenQuad(
                topLeft: CGPoint(x: observation.topLeft.x, y: 1 - observation.topLeft.y),
                topRight: CGPoint(x: observation.topRight.x, y: 1 - observation.topRight.y),
                bottomRight: CGPoint(x: observation.bottomRight.x, y: 1 - observation.bottomRight.y),
                bottomLeft: CGPoint(x: observation.bottomLeft.x, y: 1 - observation.bottomLeft.y)
            )
        }
        return nil
    }
}
