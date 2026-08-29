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
                        Button { viewModel.startOver() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.peekpopSurface.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding()
                        Spacer()
                    }
                    Spacer()
                    Text("노란 점을 움직여서 폰 화면 테두리에 맞춰주세요")
                        .font(.title3.weight(.medium))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(Color.peekpopSurface.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                    Button("확인") {
                        Task { await viewModel.confirmBoundary(localQuad) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 24)
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
