import XCTest
@testable import Peekpop

@MainActor
final class CreationFlowViewModelTests: XCTestCase {
    func test_mainButtonTapped_presentsPicker() {
        let vm = CreationFlowViewModel()
        vm.mainButtonTapped()
        XCTAssertTrue(vm.isPickerPresented)
    }

    func test_photoSelected_goesToBoundaryConfirm() {
        let vm = CreationFlowViewModel()
        let image = Self.solidImage(width: 10, height: 10)
        vm.photoSelected(image)
        XCTAssertEqual(vm.screen, .boundaryConfirm)
        XCTAssertNotNil(vm.selectedImage)
    }

    func test_confirmBoundary_withNoSelectedImage_goesToError() async {
        let vm = CreationFlowViewModel()
        await vm.confirmBoundary(.defaultRect)
        if case .error = vm.screen {} else {
            XCTFail("expected .error, got \(vm.screen)")
        }
    }

    func test_confirmBoundary_withDegenerateMask_goesToErrorNotBrush() async {
        // SubjectSegmenter의 실제 Vision 호출 결과는 크롭 대상에 따라 달라지므로, 여기서는
        // "선택된 이미지가 있고 크롭도 유효한데 세그멘테이션이 아무 인스턴스도 못 찾는" 경우를
        // 아주 작은 단색 이미지(피사체가 없어 인스턴스가 안 잡힘)로 재현한다.
        let vm = CreationFlowViewModel()
        let blank = Self.solidImage(width: 50, height: 50)
        vm.photoSelected(blank)
        await vm.confirmBoundary(.defaultRect)
        if case .error = vm.screen {} else {
            XCTFail("degenerate/empty segmentation should route to .error, not a brush screen (v0 has none), got \(vm.screen)")
        }
    }

    func test_retryFromError_returnsToMainAndPresentsPicker() {
        let vm = CreationFlowViewModel()
        vm.screen = .error("test")
        vm.retryFromError()
        XCTAssertEqual(vm.screen, .main)
        XCTAssertTrue(vm.isPickerPresented)
    }

    func test_goHome_returnsToMainWithoutPresentingPicker() {
        let vm = CreationFlowViewModel()
        vm.screen = .result
        vm.goHome()
        XCTAssertEqual(vm.screen, .main)
        XCTAssertFalse(vm.isPickerPresented)
    }

    func test_backToBoundaryConfirm_keepsSelectedImageAndReturnsToBoundaryConfirm() {
        let vm = CreationFlowViewModel()
        let image = Self.solidImage(width: 10, height: 10)
        vm.selectedImage = image
        vm.resultImage = image
        vm.screen = .result
        vm.backToBoundaryConfirm()
        XCTAssertEqual(vm.screen, .boundaryConfirm)
        XCTAssertNotNil(vm.selectedImage, "unlike goHome(), the original photo should be kept")
        XCTAssertNil(vm.resultImage)
    }

    private static func solidImage(width: Int, height: Int) -> CGImage {
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}
