import SwiftUI

struct BoundaryConfirmView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var localQuad: ScreenQuad = .defaultRect

    var body: some View {
        VStack(spacing: 16) {
            GeometryReader { geo in
                ZStack {
                    if let cgImage = viewModel.selectedImage {
                        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                        let displayed = ImageLayout.displayedRect(containerSize: geo.size, imageSize: imageSize)

                        Image(decorative: cgImage, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)

                        // 사각형 오버레이는 프레임 전체가 아니라 실제로 그려진(레터박싱
                        // 반영된) 이미지 영역을 기준으로 좌표를 맞춘다 — 안 그러면 사진
                        // 비율이 화면 비율과 다를 때 사용자가 맞춘 사각형이랑 실제 크롭
                        // 영역이 어긋난다.
                        QuadOverlay(quad: $localQuad, displayedRect: displayed)
                    }

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
                    }
                }
            }
            .frame(maxHeight: .infinity)

            // 사진(+사각형 조정 영역), 안내 문구, 버튼을 서로 겹치지 않게 세로로 분리한다
            // — 안내 카드가 조정 중인 사진 위에 떠 있으면 사진 내용이나 핸들을 가릴 수
            // 있어서, 각자 자기 영역을 갖게 했다(디자인 리뷰 반영).
            Text("노란 점을 움직여서 폰 화면 테두리에 맞춰주세요")
                .font(.body)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.peekpopSurface.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

            Button("확인") {
                Task { await viewModel.confirmBoundary(localQuad) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: viewModel.quad) { _, newQuad in localQuad = newQuad }
        .onAppear { localQuad = viewModel.quad }
    }
}

/// 4개의 드래그 가능한 꼭짓점 핸들. 정규화(0...1), 원점 좌상단 — ScreenQuad와 동일 규약.
/// `displayedRect`는 레터박싱을 반영해 실제로 그려진 이미지 영역이며, 정규화 좌표는 이
/// 사각형 기준으로 변환한다(전체 컨테이너 기준이 아님).
private struct QuadOverlay: View {
    @Binding var quad: ScreenQuad
    let displayedRect: CGRect
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
        CGPoint(
            x: displayedRect.minX + normalized.x * displayedRect.width,
            y: displayedRect.minY + normalized.y * displayedRect.height
        )
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
                            x: min(max((value.location.x - displayedRect.minX) / displayedRect.width, 0), 1),
                            y: min(max((value.location.y - displayedRect.minY) / displayedRect.height, 0), 1)
                        )
                        quad[keyPath: keyPath] = normalized
                    }
            )
    }
}
