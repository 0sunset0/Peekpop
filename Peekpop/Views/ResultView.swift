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
            if showSavedToast {
                VStack {
                    Spacer()
                    Text("저장되었어요")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.85))
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

            Text("드래그로 위치, 두 손가락으로 크기·회전을 조정할 수 있어요")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))

            // 저장이 이 화면의 메인 액션 — 꽉 찬 primary 버튼, 공유는 바로 옆에 붙는 작은
            // 원형 아이콘 버튼(같은 줄, 저장이 남은 공간을 채움). 다시 만들기는 되돌리는
            // 행동이라 따로 아래에 배경 없는 텍스트 링크로 격을 낮춘다.
            HStack(spacing: 12) {
                Button {
                    Task { await save() }
                } label: {
                    Label("저장", systemImage: "square.and.arrow.down")
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

            Button("다시 만들기") {
                viewModel.startOver()
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
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
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return containerSize
        }
        let containerAspect = containerSize.width / containerSize.height
        let imageAspect = imageSize.width / imageSize.height
        if imageAspect > containerAspect {
            let w = containerSize.width
            return CGSize(width: w, height: w / imageAspect)
        } else {
            let h = containerSize.height
            return CGSize(width: h * imageAspect, height: h)
        }
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
