import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = CreationFlowViewModel()

    var body: some View {
        Group {
            switch viewModel.screen {
            case .main:
                MainView(viewModel: viewModel)
            case .boundaryConfirm:
                BoundaryConfirmView(viewModel: viewModel)
            case .processing:
                ProcessingView()
            case .result:
                ResultView(viewModel: viewModel)
            case .error(let message):
                ErrorView(message: message, viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
    }
}
