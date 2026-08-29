import SwiftUI

/// UIImagePickerController(카메라 모드) 래핑. 처음 표시될 때 NSCameraUsageDescription
/// 프롬프트를 띄운다.
struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (CGImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onImagePicked: onImagePicked) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImagePicked: (CGImage) -> Void
        init(onImagePicked: @escaping (CGImage) -> Void) { self.onImagePicked = onImagePicked }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let uiImage = info[.originalImage] as? UIImage, let cgImage = uiImage.cgImage else { return }
            onImagePicked(cgImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
