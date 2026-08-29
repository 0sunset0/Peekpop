import SwiftUI

struct ErrorView: View {
    let message: String
    @ObservedObject var viewModel: CreationFlowViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(message)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if message.contains("설정") {
                    Button("설정으로 이동") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("다시 시도") {
                    viewModel.retryFromError()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 32)
        }
    }
}
