import CoreGraphics

/// 사용자가 화면에서 지정하는 "사진이 보이는 영역". 정규화(0...1), 원점 좌상단, y 아래로 증가.
struct ScreenQuad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// 자동 검출이 실패했을 때 쓰는 기본값: 인물 사진 비율(~4:5)에 가까운 사각형.
    /// 주의: halfW는 컨테이너 "가로" 기준, halfH는 컨테이너 "세로" 기준 프랙션이라
    /// 서로 다른 축이다 — 실제 화면비는 (halfW*containerWidth):(halfH*containerHeight)로
    /// 계산해야 하며, 두 숫자를 그대로 비교하면 안 된다(이전 버전의 실수). iPhone
    /// 기준(약 393x852pt 세로 컨테이너)으로 halfH=0.15면 실제 시각적 비율이 대략 4:5.
    static let defaultRect: ScreenQuad = {
        let halfW: CGFloat = 0.25
        let halfH: CGFloat = 0.15
        let midX: CGFloat = 0.5
        let midY: CGFloat = 0.5
        return ScreenQuad(
            topLeft: CGPoint(x: midX - halfW, y: midY - halfH),
            topRight: CGPoint(x: midX + halfW, y: midY - halfH),
            bottomRight: CGPoint(x: midX + halfW, y: midY + halfH),
            bottomLeft: CGPoint(x: midX - halfW, y: midY + halfH)
        )
    }()
}
