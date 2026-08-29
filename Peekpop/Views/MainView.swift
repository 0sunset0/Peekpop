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

    var body: some View {
        VStack(spacing: 24) {
            Image("phone-front-facing")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 420)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            Text("폰 카메라 앱을 켜고,\n화면에 인물이 보이게 찍어주세요")
                .font(.body)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
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
                },
                onCancel: { viewModel.isPickerPresented = false }
            )
            .presentationDetents([.height(200)])
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

/// iOS 표준 액션시트를 흉내낸 커스텀 하단 시트 — 카메라/앨범 두 옵션 + 취소, 언제나
/// 화면 하단에 그룹 카드로 뜬다(MainView 상단 주석 참고).
private struct PhotoSourceSheet: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 0) {
                Button("카메라로 촬영", action: onCamera)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                Divider().background(Color.white.opacity(0.15))
                Button("앨범에서 선택", action: onLibrary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(Color.peekpopSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button("취소", action: onCancel)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.peekpopSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .font(.body)
        .foregroundStyle(.white)
        .padding()
    }
}
