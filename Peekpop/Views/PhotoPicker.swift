import SwiftUI
import PhotosUI

/// PHPickerViewController 래핑. 이 방식은 권한 프롬프트가 없다(docs/ade.md).
struct PhotoPicker: UIViewControllerRepresentable {
    var onImagePicked: (CGImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagePicked: (CGImage) -> Void
        init(onImagePicked: @escaping (CGImage) -> Void) { self.onImagePicked = onImagePicked }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [onImagePicked] object, _ in
                guard let uiImage = object as? UIImage, let cgImage = uiImage.orientedCGImage else { return }
                DispatchQueue.main.async { onImagePicked(cgImage) }
            }
        }
    }
}
