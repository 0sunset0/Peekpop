import CoreGraphics

/// 사용자가 화면에서 지정하는 "사진이 보이는 영역". 정규화(0...1), 원점 좌상단, y 아래로 증가.
struct ScreenQuad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// 자동 검출이 실패했을 때 쓰는 기본값: 화면 중앙의 세로로 긴(~1:1.3) 사각형.
    static let defaultRect: ScreenQuad = {
        let halfW: CGFloat = 0.25
        let halfH: CGFloat = 0.33
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
