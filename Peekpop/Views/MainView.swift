import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.peekpopAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct MainView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var presentCamera = false
    @State private var presentLibrary = false

    /// 사용 흐름을 3단계로 미리 보여주는 예시 캐러셀. ①어떤 사진을 찍어야 하는지
    /// ②노란 점을 어디에 맞춰야 하는지 ③어떤 결과가 나오는지(디자인 리뷰, 2026-08-30 —
    /// docs/flow.md "1. 메인" 참고). 2·3페이지 이미지는 실제 서비스 코드
    /// (PhoneFrameDetector/SubjectSegmenter/PopOutCompositor)로 TestFixtures 샘플
    /// 사진을 처리해서 만든 실물 결과다, 손으로 그린 목업이 아니다.
    private let carouselPages: [(image: String, caption: String)] = [
        ("phone-front-facing", "폰 카메라 앱을 켜고,\n화면에 인물이 보이게 찍어주세요"),
        ("carousel-boundary-example", "노란 점을 움직여서\n폰 화면 테두리에 맞춰주세요"),
        ("carousel-result-example", "이렇게 화면 밖으로\n튀어나온 것처럼 나와요")
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView {
                ForEach(carouselPages, id: \.image) { page in
                    VStack(spacing: 16) {
                        Image(page.image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Text(page.caption)
                            .font(.body)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                    }
                    .padding(.bottom, 24)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .frame(height: 480)

            Button("사진 선택하기") {
                viewModel.mainButtonTapped()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        // 커스텀 하단 시트. 시스템 `.confirmationDialog`는 iOS 26 Liquid Glass에서 항상
        // 하단 시트가 아니라 앵커 위치에 뜨는 말풍선(팝오버) 형태로 바뀌어서, 위치를
        // 우리가 보장할 수 없었다 — 항상 화면 하단에서 뜨는 걸 확실히 하려고 직접 만든
        // 시트로 교체했다(실기기 QA 반영, docs/ade.md 참고).
        .sheet(isPresented: $viewModel.isPickerPresented) {
            PhotoSourceSheet(
                onCamera: {
                    viewModel.isPickerPresented = false
                    presentCamera = true
                },
                onLibrary: {
                    viewModel.isPickerPresented = false
                    presentLibrary = true
                }
            )
            .presentationDetents([.height(160)])
            .presentationDragIndicator(.hidden)
            .presentationBackground(.clear)
        }
        .fullScreenCover(isPresented: $presentCamera) {
            CameraPicker { image in
                presentCamera = false
                viewModel.photoSelected(image)
            }
        }
        .sheet(isPresented: $presentLibrary) {
            PhotoPicker { image in
                presentLibrary = false
                viewModel.photoSelected(image)
            }
        }
    }
}

/// iOS 표준 액션시트를 흉내낸 커스텀 하단 시트 — 카메라/앨범 두 옵션만 두고, 취소는
/// 별도 버튼 없이 시트 바깥을 탭하거나 아래로 스와이프해서 닫는다(`.sheet` 기본 동작).
private struct PhotoSourceSheet: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            sheetRow("카메라로 촬영", action: onCamera)
            Divider().background(Color.white.opacity(0.15))
            sheetRow("앨범에서 선택", action: onLibrary)
        }
        .font(.body)
        .foregroundStyle(.white)
        .background(Color.peekpopSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding()
    }

    /// `.contentShape(Rectangle())`가 핵심 — 없으면 텍스트 글자 위에서만 탭이 먹고,
    /// 나머지 여백(패딩 포함 행 전체)은 탭해도 반응하지 않는다.
    private func sheetRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
        }
    }
}
