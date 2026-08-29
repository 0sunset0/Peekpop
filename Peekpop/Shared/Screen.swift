/// v0 화면 상태. 온보딩·브러시 보정 화면은 없다 (tech-critic-lead 게이트, docs/prd.md 참고).
enum Screen: Equatable {
    case main
    case boundaryConfirm
    case processing
    case result
    case error(String)
}
