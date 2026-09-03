import UIKit

extension UIImage {
    /// `UIImage.cgImage`는 카메라 센서가 실제로 기록한 원본 픽셀 버퍼라
    /// `imageOrientation`을 무시한다 — 세로로 찍은 사진도 센서 버퍼 자체는 대부분
    /// 가로로 저장되고 `.right`/`.left` 태그로 "회전해서 보여줘"라고만 표시된다.
    /// `PhotoPicker`/`CameraPicker`가 곧바로 `.cgImage`만 꺼내 쓰면 그 태그가
    /// 사라져서, 세로 사진을 넣어도 앱 전체에서 가로로 보이는 문제가 있었다
    /// (GitHub #8). `UIGraphicsImageRenderer`는 `draw(in:)` 경로에서
    /// `imageOrientation`을 반영해 다시 그리므로, 이 결과를 새 `CGImage`로 만들면
    /// 이후 파이프라인(BoundaryConfirmView, PopOutCompositor 등)은 orientation을
    /// 전혀 몰라도 항상 올바르게 세워진 이미지를 받는다.
    var orientedCGImage: CGImage? {
        guard imageOrientation != .up else { return cgImage }
        // scale must stay 1 — UIGraphicsImageRenderer defaults to the current
        // device's screen scale (e.g. 3x), which would silently blow up the
        // photo's actual pixel dimensions instead of just fixing orientation.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let normalized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.cgImage
    }
}
