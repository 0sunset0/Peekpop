import SwiftUI
import Photos

/// 결과 화면. 자동 배치된 결과를 보여주고, 저장 전에 드래그(이동)/핀치(크기)로 손보게
/// 해준다(docs/flow.md "5. 결과" — tech-critic-lead가 처음엔 "더 싼 대안(알고리즘 튜닝)을
/// 먼저 시도"하라며 거부했지만, 알고리즘을 고친 뒤에도 실기기 사용자가 재요청해 v0에
/// 포함시킴, docs/ade.md 참고).
struct ResultView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var showSavedToast = false
    @State private var shareURL: URL?

    /// 직전 제스처들이 확정(commit)된 누적값.
    @State private var committedScale: CGFloat = 1.0
    @State private var committedOffset: CGPoint = .zero
    @State private var committedRotation: Angle = .zero
    /// 지금 진행 중인 제스처의 델타(제스처가 끝나면 committed로 합쳐지고 0으로 리셋).
    @State private var liveScaleDelta: CGFloat = 1.0
    @State private var liveOffsetDelta: CGSize = .zero
    @State private var liveRotationDelta: Angle = .zero

    var body: some View {
        ZStack {
            content
            VStack {
                HStack {
                    Button {
                        viewModel.backToBoundaryConfirm()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.peekpopSurface.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()

                    Spacer()
                    Button {
                        viewModel.goHome()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.peekpopSurface.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
            if showSavedToast {
                VStack {
                    Spacer()
                    Text("저장되었어요")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.peekpopSurface)
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedToast)
    }

    private var content: some View {
        VStack(spacing: 24) {
            if let result = viewModel.resultImage {
                GeometryReader { geo in
                    let imageSize = CGSize(width: result.width, height: result.height)
                    let displayed = Self.displayedSize(containerSize: geo.size, imageSize: imageSize)
                    let pixelsPerPoint = imageSize.width > 0 ? CGFloat(result.width) / max(displayed.width, 1) : 1

                    Image(decorative: result, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .gesture(
                            SimultaneousGesture(
                                SimultaneousGesture(
                                    DragGesture()
                                        .onChanged { value in
                                            liveOffsetDelta = value.translation
                                            applyAdjustment(pixelsPerPoint: pixelsPerPoint)
                                        }
                                        .onEnded { value in
                                            committedOffset.x += value.translation.width * pixelsPerPoint
                                            committedOffset.y += value.translation.height * pixelsPerPoint
                                            liveOffsetDelta = .zero
                                            applyAdjustment(pixelsPerPoint: pixelsPerPoint)
                                            prepareShareURL()
                                        },
                                    MagnificationGesture()
                                        .onChanged { value in
                                            liveScaleDelta = value
                                            applyAdjustment(pixelsPerPoint: pixelsPerPoint)
                                        }
                                        .onEnded { value in
                                            committedScale *= value
                                            liveScaleDelta = 1.0
                                            applyAdjustment(pixelsPerPoint: pixelsPerPoint)
                                            prepareShareURL()
                                        }
                                ),
                                RotationGesture()
                                    .onChanged { value in
                                        liveRotationDelta = value
                                        applyAdjustment(pixelsPerPoint: pixelsPerPoint)
                                    }
                                    .onEnded { value in
                                        committedRotation += value
                                        liveRotationDelta = .zero
                                        applyAdjustment(pixelsPerPoint: pixelsPerPoint)
                                        prepareShareURL()
                                    }
                            )
                        )
                }
                .padding()
            }

            // 경계확인 화면의 안내 카드와 같은 스타일(본문 크기 + 표면색 카드) — 이 힌트가
            // footnote로 너무 작아서 조작 가능하다는 걸 못 알아채는 사용자가 있었다(디자인
            // 리뷰 반영). 자동 배치가 항상 완벽하진 않은 만큼, 조정 가능하다는 사실 자체의
            // 발견 가능성이 "보조 힌트"보다 우선한다고 판단해 tier를 올렸다.
            Text("드래그로 위치, 두 손가락으로 크기·회전을 조정할 수 있어요")
                .font(.body)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.peekpopSurface.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

            // 저장이 이 화면의 메인 액션 — 꽉 찬 primary 버튼, 공유는 바로 옆에 붙는 작은
            // 원형 아이콘 버튼(같은 줄, 저장이 남은 공간을 채움). 홈으로 나가는 동작은
            // 우측 상단 X 버튼으로 옮겨서, 하단은 "이 사진으로 뭘 할지"에만 집중하게 한다.
            HStack(spacing: 12) {
                Button {
                    Task { await save() }
                } label: {
                    Label {
                        Text("저장")
                    } icon: {
                        // "square.and.arrow.down" 아이콘은 아래로 향한 화살표라 시각적
                        // 무게중심이 실제 바운딩 박스보다 낮다 — 텍스트와 나란히 두면
                        // 수학적으로는 가운데 정렬이어도 살짝 아래로 처져 보여서, 1pt
                        // 위로 올려 광학적으로 정렬되게 보정한다(디자인 리뷰, 2026-08-30).
                        Image(systemName: "square.and.arrow.down")
                            .offset(y: -1)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .task { prepareShareURL() }
    }

    private func applyAdjustment(pixelsPerPoint: CGFloat) {
        let scale = committedScale * liveScaleDelta
        let offset = CGPoint(
            x: committedOffset.x + liveOffsetDelta.width * pixelsPerPoint,
            y: committedOffset.y + liveOffsetDelta.height * pixelsPerPoint
        )
        // Negated: RotationGesture's sign reads backwards against
        // PopOutCompositor's rotation convention (confirmed on real device).
        let rotation = -(committedRotation + liveRotationDelta).radians
        viewModel.adjustmentChanged(scale: scale, offset: offset, rotation: rotation)
    }

    /// `.scaledToFit()`이 `imageSize`를 `containerSize` 안에 어떤 크기로 그리는지 계산한다.
    private static func displayedSize(containerSize: CGSize, imageSize: CGSize) -> CGSize {
        ImageLayout.displayedRect(containerSize: containerSize, imageSize: imageSize).size
    }

    private func prepareShareURL() {
        guard let result = viewModel.resultImage else { return }
        let uiImage = UIImage(cgImage: result)
        guard let data = uiImage.pngData() else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
        try? data.write(to: url)
        shareURL = url
    }

    private func save() async {
        guard let result = viewModel.resultImage else { return }
        let uiImage = UIImage(cgImage: result)
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            viewModel.screen = .error("설정에서 사진 저장 권한을 허용해주세요")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }
            showSavedToast = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            showSavedToast = false
        } catch {
            viewModel.screen = .error("저장하지 못했어요. 다시 시도해주세요.")
        }
    }
}
