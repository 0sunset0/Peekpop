# Phase 8: BoundaryConfirmView

## 사전 준비

먼저 아래 문서들을 반드시 읽어라:

- `docs/flow.md` — "3. 화면 경계 확인": 대상은 폰 화면 전체가 아니라 카메라 UI 제외한 사진 부분만. 자동 검출 프리필 + 사용자 드래그 확인. 뒤로가기 가능.
- `docs/ade.md` — 왜 "사진 부분만"인지(카메라 UI 포함 시 세그멘테이션이 망가짐).

그리고 이전 phase의 작업물을 반드시 확인하라:

- `Peekpop/Flow/CreationFlowViewModel.swift` — `@Published var selectedImage: CGImage?`, `@Published var quad: ScreenQuad`, `func confirmBoundary(_ quad: ScreenQuad) async`, `func startOver()`
- `Peekpop/Views/MainView.swift` — `PrimaryButtonStyle` (재사용)

## 작업 내용

`Peekpop/Views/BoundaryConfirmView.swift`를 작성하라:

```swift
import SwiftUI

struct BoundaryConfirmView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var localQuad: ScreenQuad = .defaultRect

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let cgImage = viewModel.selectedImage {
                    Image(decorative: cgImage, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                QuadOverlay(quad: $localQuad, canvasSize: geo.size)

                VStack {
                    HStack {
                        Button("뒤로") { viewModel.startOver() }
                            .foregroundStyle(.white)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                    Text("화면에 보이는 사진(인물)에 맞춰주세요")
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)
                    Button("확인") {
                        Task { await viewModel.confirmBoundary(localQuad) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 48)
                    .padding(.bottom, 24)
                }
            }
        }
        .onChange(of: viewModel.quad) { _, newQuad in localQuad = newQuad }
        .onAppear { localQuad = viewModel.quad }
    }
}

/// 4개의 드래그 가능한 꼭짓점 핸들. 정규화(0...1), 원점 좌상단 — ScreenQuad와 동일 규약.
private struct QuadOverlay: View {
    @Binding var quad: ScreenQuad
    let canvasSize: CGSize
    private let handleRadius: CGFloat = 14

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: point(quad.topLeft))
                path.addLine(to: point(quad.topRight))
                path.addLine(to: point(quad.bottomRight))
                path.addLine(to: point(quad.bottomLeft))
                path.closeSubpath()
            }
            .stroke(Color.yellow, lineWidth: 2)

            handle(\.topLeft)
            handle(\.topRight)
            handle(\.bottomRight)
            handle(\.bottomLeft)
        }
    }

    private func point(_ normalized: CGPoint) -> CGPoint {
        CGPoint(x: normalized.x * canvasSize.width, y: normalized.y * canvasSize.height)
    }

    private func handle(_ keyPath: WritableKeyPath<ScreenQuad, CGPoint>) -> some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: handleRadius * 2, height: handleRadius * 2)
            .position(point(quad[keyPath: keyPath]))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let normalized = CGPoint(
                            x: min(max(value.location.x / canvasSize.width, 0), 1),
                            y: min(max(value.location.y / canvasSize.height, 0), 1)
                        )
                        quad[keyPath: keyPath] = normalized
                    }
            )
    }
}
```

## Acceptance Criteria

```bash
xcodegen generate
xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## AC 검증 방법

빌드가 성공하면 `tasks/0-mvp-v0/index.json`의 phase 8 status를 `"completed"`로 변경하라. `RootView`가 아직 없어(Phase 9) 시뮬레이터에서 직접 조작 확인은 불가하다 — 빌드 성공만으로 충분하다. 3회 이상 빌드 실패하면 status를 `"error"`로.

## 주의사항

- `QuadOverlay`의 좌표 변환에서 x/y 스케일을 뒤바꾸지 마라 — `ScreenQuad`는 원점 좌상단, y 아래로 증가 규약을 쓴다(Phase 2 참고).
- "뒤로" 버튼은 `startOver()`를 재사용한다 — 별도 메서드를 새로 만들지 마라. 둘 다 "지금 사진 버리고 다시 고르기"라는 같은 의미이기 때문이다.
