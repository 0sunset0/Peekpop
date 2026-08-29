import CoreGraphics

/// 오려낸 피사체를 화면 경계 밖으로 확대·재배치하고 그림자를 넣어 "튀어나온" 합성 이미지를
/// 만든다. 배치는 사용자가 지정한 사각형의 기울기를 반영한다 — 고정 비율 배치는 폰이
/// 기울어진 사진에서 부자연스러웠다 (docs/ade.md).
struct PopOutCompositor {
    private let popOutScale: CGFloat = 1.3
    private let insideFraction: CGFloat = 0.42

    /// 사각형 아래쪽 변(bottomLeft→bottomRight)의 기울기를 라디안으로 반환한다.
    /// 순수 함수 — 이미지 좌표계(원점 좌상단, y 아래로 증가)를 그대로 쓴다.
    static func rotationAngle(bottomLeft: CGPoint, bottomRight: CGPoint) -> CGFloat {
        atan2(bottomRight.y - bottomLeft.y, bottomRight.x - bottomLeft.x)
    }

    func compose(baseImage: CGImage, quad: ScreenQuad, cutout: CGImage) -> CGImage? {
        let outW = baseImage.width, outH = baseImage.height
        guard let ctx = CGContext(
            data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.draw(baseImage, in: topDownRectToContext(CGRect(x: 0, y: 0, width: outW, height: outH), canvasH: outH))

        let bottomLeftPx = CGPoint(x: quad.bottomLeft.x * CGFloat(outW), y: quad.bottomLeft.y * CGFloat(outH))
        let bottomRightPx = CGPoint(x: quad.bottomRight.x * CGFloat(outW), y: quad.bottomRight.y * CGFloat(outH))
        let angle = Self.rotationAngle(bottomLeft: bottomLeftPx, bottomRight: bottomRightPx)
        let bottomMid = CGPoint(x: (bottomLeftPx.x + bottomRightPx.x) / 2, y: (bottomLeftPx.y + bottomRightPx.y) / 2)

        let cutoutW = CGFloat(cutout.width) * popOutScale
        let cutoutH = CGFloat(cutout.height) * popOutScale

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
        ctx.translateBy(x: bottomMid.x, y: CGFloat(outH) - bottomMid.y)
        ctx.rotate(by: -angle)
        let drawRect = CGRect(x: -cutoutW / 2, y: -(cutoutH * insideFraction), width: cutoutW, height: cutoutH)
        ctx.draw(cutout, in: drawRect)
        ctx.restoreGState()

        return ctx.makeImage()
    }

    private func topDownRectToContext(_ rect: CGRect, canvasH: Int) -> CGRect {
        CGRect(x: rect.origin.x, y: CGFloat(canvasH) - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }
}
