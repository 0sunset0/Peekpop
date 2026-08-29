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
            // 이 버튼에 직접 붙여야 iOS가 팝업(iOS 26 Liquid Glass 스타일 confirmationDialog는
            // 하단 시트가 아니라 앵커 위치에 뜨는 말풍선 형태)을 이 버튼 기준으로 띄운다.
            // 바깥 VStack에 붙어 있으면 화면 전체를 앵커로 잡아서 엉뚱하게(예시 사진 위)
            // 뜬다 — 실기기 QA로 발견.
            .confirmationDialog("사진 선택", isPresented: $viewModel.isPickerPresented, titleVisibility: .hidden) {
                Button("카메라로 촬영") { presentCamera = true }
                Button("앨범에서 선택") { presentLibrary = true }
                Button("취소", role: .cancel) {}
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
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
