import CoreGraphics

/// 오려낸 피사체를 화면 경계 밖으로 확대·재배치하고 그림자를 넣어 "튀어나온" 합성 이미지를
/// 만든다. `cutout`은 `SubjectSegmenter`가 `croppedToInstancesExtent: false`로 생성한,
/// 크롭 영역과 같은 크기의 이미지다(피사체가 원래 있던 자리 그대로, 나머지는 투명) — 이
/// 성질을 이용해 확대된 피사체를 원본 사진 속 피사체 위치에 그대로 겹쳐 그린다("도려낸
/// 피사체가 원본 피사체를 가리며 튀어나오는" 효과, 사용자 피드백 반영). 배치는 사용자가
/// 지정한 사각형의 기울기를 반영한다 — 고정 비율 배치는 폰이 기울어진 사진에서
/// 부자연스러웠다 (docs/ade.md).
struct PopOutCompositor {
    /// 확대된 피사체의 렌더링 크기 — 크롭(=cutout) 크기의 몇 배로 키울지. 크롭 중심을
    /// 기준으로 사방으로 커지기 때문에, 피사체가 크롭 안 어디에 있었든 자연스럽게 화면
    /// 경계 밖으로 삐져나온다("항상 아래쪽에만 나온다"던 이전 버전의 문제를 해결).
    private let enlargeScale: CGFloat = 1.4

    /// 사각형 아래쪽 변(bottomLeft→bottomRight)의 기울기를 라디안으로 반환한다.
    /// 순수 함수 — 이미지 좌표계(원점 좌상단, y 아래로 증가)를 그대로 쓴다.
    static func rotationAngle(bottomLeft: CGPoint, bottomRight: CGPoint) -> CGFloat {
        atan2(bottomRight.y - bottomLeft.y, bottomRight.x - bottomLeft.x)
    }

    /// `quad`를 감싸는 축 정렬 사각형(top-down, y 아래로 증가) — `CreationFlowViewModel`이
    /// 크롭할 때 쓴 것과 동일한 계산이다. cutout이 이 rect와 같은 크기라는 전제로 배치한다.
    static func boundingRect(for quad: ScreenQuad, imageWidth: Int, imageHeight: Int) -> CGRect {
        let w = CGFloat(imageWidth), h = CGFloat(imageHeight)
        let minX = min(quad.topLeft.x, quad.bottomLeft.x) * w
        let maxX = max(quad.topRight.x, quad.bottomRight.x) * w
        let minY = min(quad.topLeft.y, quad.topRight.y) * h
        let maxY = max(quad.bottomLeft.y, quad.bottomRight.y) * h
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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

        // Where the crop (and therefore the subject, at its natural position) sits
        // in the base photo — the enlargement grows outward from its center, so
        // the subject stays covering its own original spot as it pops out.
        let crop = Self.boundingRect(for: quad, imageWidth: outW, imageHeight: outH)
        let cropCenter = CGPoint(x: crop.midX, y: crop.midY)

        let cutoutW = CGFloat(cutout.width) * enlargeScale
        let cutoutH = CGFloat(cutout.height) * enlargeScale

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
        ctx.translateBy(x: cropCenter.x, y: CGFloat(outH) - cropCenter.y)
        ctx.rotate(by: -angle)
        let drawRect = CGRect(x: -cutoutW / 2, y: -cutoutH / 2, width: cutoutW, height: cutoutH)
        ctx.draw(cutout, in: drawRect)
        ctx.restoreGState()

        return ctx.makeImage()
    }

    private func topDownRectToContext(_ rect: CGRect, canvasH: Int) -> CGRect {
        CGRect(x: rect.origin.x, y: CGFloat(canvasH) - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }
}
