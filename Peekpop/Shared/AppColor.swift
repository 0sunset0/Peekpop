import SwiftUI

extension Color {
    /// 브랜드 포인트 컬러 — Primary 버튼(메인 액션)에만 쓴다. 순정 검정(#000000) 배경
    /// 위에서 발광하듯 보이도록 다크 테마 전용으로 고른 값(디자인 리뷰, docs/ade.md 참고).
    /// Share/홈으로 같은 보조 액션에는 일부러 쓰지 않는다 — 색을 아껴야 "이게 메인
    /// 액션이다"라는 위계 신호가 유지된다.
    static let peekpopAccent = Color(red: 0xFF / 255, green: 0x5C / 255, blue: 0x7A / 255)

    /// 순정 검정 배경과 구분되는 표면색 — 토스트처럼 배경 위에 "떠 있는" 요소에 쓴다.
    static let peekpopSurface = Color(red: 0x1C / 255, green: 0x1C / 255, blue: 0x1E / 255)
}
