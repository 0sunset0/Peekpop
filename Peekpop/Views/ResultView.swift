import SwiftUI
import Photos

struct ResultView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var justSaved = false
    @State private var shareURL: URL?

    var body: some View {
        VStack(spacing: 24) {
            if let result = viewModel.resultImage {
                Image(decorative: result, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }

            HStack(spacing: 16) {
                Button {
                    Task { await save() }
                } label: {
                    Image(systemName: justSaved ? "checkmark" : "square.and.arrow.down")
                }
                .buttonStyle(PrimaryButtonStyle())

                if let shareURL {
                    ShareLink(item: shareURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }

                Button("다시 만들기") {
                    viewModel.startOver()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 24)
        }
        .background(Color.black.ignoresSafeArea())
        .task { prepareShareURL() }
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
            justSaved = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            justSaved = false
        } catch {
            viewModel.screen = .error("저장하지 못했어요. 다시 시도해주세요.")
        }
    }
}
