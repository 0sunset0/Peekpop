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
                .font(.title3.weight(.medium))
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
        .confirmationDialog("사진 선택", isPresented: $viewModel.isPickerPresented, titleVisibility: .hidden) {
            Button("카메라로 촬영") { presentCamera = true }
            Button("앨범에서 선택") { presentLibrary = true }
            Button("취소", role: .cancel) {}
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
