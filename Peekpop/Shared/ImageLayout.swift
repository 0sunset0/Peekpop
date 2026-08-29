import CoreGraphics

/// `.scaledToFit()`이 이미지를 `containerSize` 안에 실제로 그리는 위치/크기(레터박싱
/// 포함)를 계산한다. `BoundaryConfirmView`(사각형 오버레이 좌표 변환)와 `ResultView`
/// (제스처 픽셀 변환)가 공유한다 — 각자 따로 계산하면 둘이 어긋날 수 있어서 한 곳으로 합쳤다.
enum ImageLayout {
    static func displayedRect(containerSize: CGSize, imageSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }
        let containerAspect = containerSize.width / containerSize.height
        let imageAspect = imageSize.width / imageSize.height
        let size: CGSize
        if imageAspect > containerAspect {
            let w = containerSize.width
            size = CGSize(width: w, height: w / imageAspect)
        } else {
            let h = containerSize.height
            size = CGSize(width: h * imageAspect, height: h)
        }
        let origin = CGPoint(x: (containerSize.width - size.width) / 2, y: (containerSize.height - size.height) / 2)
        return CGRect(origin: origin, size: size)
    }
}
