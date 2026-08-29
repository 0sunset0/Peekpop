# Peekpop MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Peekpop iOS MVP — a login-free, on-device app that turns a photo of a phone screen showing a person into a "pop out of the frame" composite.

**Architecture:** SwiftUI views (one per screen) observe a single `CreationFlowViewModel`. Three stateless services (`PhoneFrameDetector`, `SubjectSegmenter`, `PopOutCompositor`) wrap Vision/Core Graphics. Screen navigation is a plain `enum Screen` switch, not `NavigationStack`. No backend, no database — two `@AppStorage` keys are the only persisted state.

**Tech Stack:** Swift 5, SwiftUI, Vision, Core Graphics/Core Image, PhotosUI, Photos, iOS 17.0+ deployment target, Swift Concurrency (`async`/`await`). XCTest for unit tests.

**Spec:** `docs/prd.md`, `docs/flow.md`, `docs/data-schema.md`, `docs/code-architecture.md`, `docs/ade.md` — read all five before starting; this plan implements them and does not repeat their rationale except where a task needs a specific number or string.

## Global Constraints

- Minimum iOS 17.0 (required by `VNGenerateForegroundInstanceMaskRequest`).
- No network calls anywhere in the app. No login, no backend, no database.
- No `NavigationStack` — screen switching goes through `CreationFlowViewModel.screen: Screen`.
- Services (`PhoneFrameDetector`, `SubjectSegmenter`, `PopOutCompositor`) are concrete structs, no protocols, no dependency injection framework.
- No UI tests. Unit tests only for the three services, using the bundled fixture images in `TestFixtures/`.
- Dark color scheme fixed app-wide; portrait orientation only.
- `NSCameraUsageDescription`: "폰 화면에 보이는 사진을 촬영하기 위해 카메라 접근이 필요해요"
- `NSPhotoLibraryAddUsageDescription`: "완성된 사진을 앨범에 저장하기 위해 접근이 필요해요"
- Photo picking uses `PHPickerViewController` (no permission prompt); saving uses `PHPhotoLibrary` add-only access, not full library access.

---

## File Structure

```
Peekpop.xcodeproj
Peekpop/
  PeekpopApp.swift
  Shared/
    ScreenQuad.swift
    Screen.swift
  Services/
    PhoneFrameDetector.swift
    SubjectSegmenter.swift
    PopOutCompositor.swift
  Flow/
    CreationFlowViewModel.swift
  Views/
    RootView.swift
    OnboardingView.swift
    MainView.swift
    PhotoPicker.swift
    CameraPicker.swift
    BoundaryConfirmView.swift
    LoadingView.swift
    BrushRefineView.swift
    ResultView.swift
    ErrorView.swift
  Info.plist
  PrivacyInfo.xcprivacy
PeekpopTests/
  ScreenQuadTests.swift
  PhoneFrameDetectorTests.swift
  SubjectSegmenterTests.swift
  PopOutCompositorTests.swift
  CreationFlowViewModelTests.swift
TestFixtures/                      (already in repo, added to PeekpopTests target)
  phone-front-facing.png
  phone-tilted-landscape.png
  phone-recording.png
  phone-in-flight.png
```

---

### Task 1: Xcode project scaffolding

**Files:**
- Create: `Peekpop.xcodeproj`, `Peekpop/PeekpopApp.swift`, `Peekpop/Info.plist`, `Peekpop/PrivacyInfo.xcprivacy`
- Modify: none

**Interfaces:**
- Produces: a buildable, empty SwiftUI app target `Peekpop` and a test target `PeekpopTests`, both targeting iOS 17.0.

- [ ] **Step 1: Create the Xcode project**

In Xcode: File → New → Project → iOS → App.
- Product Name: `Peekpop`
- Team: (your team)
- Organization Identifier: `com.peekpop`
- Interface: SwiftUI
- Language: Swift
- Storage: None
- Include Tests: checked (this creates the `PeekpopTests` target)

Save it as `Peekpop` inside `/Users/sunset/Desktop/노을/프로젝트/Peekpop` (the existing git repo — do not create a nested git repo, decline if Xcode offers to initialize git).

- [ ] **Step 2: Set the deployment target**

Select the `Peekpop` project → target `Peekpop` → General → Minimum Deployments → iOS 17.0. Repeat for the `PeekpopTests` target.

- [ ] **Step 3: Add the permission usage strings**

Open `Peekpop/Info.plist` (or the target's Info tab) and add:

```xml
<key>NSCameraUsageDescription</key>
<string>폰 화면에 보이는 사진을 촬영하기 위해 카메라 접근이 필요해요</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>완성된 사진을 앨범에 저장하기 위해 접근이 필요해요</string>
<key>UIRequiresFullScreen</key>
<true/>
<key>UISupportedInterfaceOrientations</key>
<array>
  <string>UIInterfaceOrientationPortrait</string>
</array>
```

- [ ] **Step 4: Add the Privacy Manifest**

In Xcode: File → New → File → Resource → App Privacy File, save as `Peekpop/PrivacyInfo.xcprivacy`. Add one entry under `NSPrivacyAccessedAPITypes` for `NSPrivacyAccessedAPICategoryUserDefaults` with reason code `CA92.1` (app's own on-device data storage). Leave `NSPrivacyCollectedDataTypes` empty (the app collects nothing).

- [ ] **Step 5: Add the test fixtures to the test target**

Drag the existing `TestFixtures/` folder (already at the repo root, contains `phone-front-facing.png`, `phone-tilted-landscape.png`, `phone-recording.png`, `phone-in-flight.png`) into the `PeekpopTests` target in Xcode, choosing "Create folder references" and checking only the `PeekpopTests` target membership.

- [ ] **Step 6: Verify the project builds**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: Commit**

```bash
git add Peekpop.xcodeproj Peekpop PeekpopTests TestFixtures
git commit -m "Scaffold Peekpop Xcode project"
```

---

### Task 2: Shared types — ScreenQuad and Screen

**Files:**
- Create: `Peekpop/Shared/ScreenQuad.swift`, `Peekpop/Shared/Screen.swift`
- Test: `PeekpopTests/ScreenQuadTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct ScreenQuad: Equatable {
      var topLeft: CGPoint
      var topRight: CGPoint
      var bottomRight: CGPoint
      var bottomLeft: CGPoint
      static let defaultRect: ScreenQuad
  }
  enum Screen: Equatable {
      case onboarding(page: Int), main, boundaryConfirm, generating,
           brushRefine, compositing, result, error(String)
  }
  ```
  Coordinates are normalized (0...1), origin top-left, y increasing downward — matches ordinary image pixel coordinates, not Vision's bottom-left convention.

- [ ] **Step 1: Write the failing test**

```swift
// PeekpopTests/ScreenQuadTests.swift
import XCTest
@testable import Peekpop

final class ScreenQuadTests: XCTestCase {
    func test_defaultRect_isCenteredAndPortrait() {
        let quad = ScreenQuad.defaultRect
        let width = quad.topRight.x - quad.topLeft.x
        let height = quad.bottomLeft.y - quad.topLeft.y
        XCTAssertGreaterThan(height, width, "default rect should be taller than wide")
        XCTAssertEqual(quad.topLeft.x, 1 - quad.topRight.x, accuracy: 0.001, "should be horizontally centered")
        XCTAssertEqual(quad.topLeft.y, 1 - quad.bottomLeft.y, accuracy: 0.001, "should be vertically centered")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/ScreenQuadTests`
Expected: FAIL (compile error — `ScreenQuad` doesn't exist yet)

- [ ] **Step 3: Write the implementation**

```swift
// Peekpop/Shared/ScreenQuad.swift
import CoreGraphics

/// The photo-display area the user marks on a phone-screen photo.
/// Normalized to the source image, origin top-left, y down.
struct ScreenQuad: Equatable {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    /// Centered portrait rectangle (~1:1.6), used when auto-detection finds
    /// nothing plausible. See docs/ade.md.
    static let defaultRect: ScreenQuad = {
        let halfW: CGFloat = 0.25
        let halfH: CGFloat = 0.4
        let midX: CGFloat = 0.5
        let midY: CGFloat = 0.5
        return ScreenQuad(
            topLeft: CGPoint(x: midX - halfW, y: midY - halfH),
            topRight: CGPoint(x: midX + halfW, y: midY - halfH),
            bottomRight: CGPoint(x: midX + halfW, y: midY + halfH),
            bottomLeft: CGPoint(x: midX - halfW, y: midY + halfH)
        )
    }()
}
```

```swift
// Peekpop/Shared/Screen.swift
enum Screen: Equatable {
    case onboarding(page: Int)
    case main
    case boundaryConfirm
    case generating
    case brushRefine
    case compositing
    case result
    case error(String)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/ScreenQuadTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Peekpop/Shared PeekpopTests/ScreenQuadTests.swift
git commit -m "Add ScreenQuad and Screen shared types"
```

---

### Task 3: PhoneFrameDetector

**Files:**
- Create: `Peekpop/Services/PhoneFrameDetector.swift`
- Test: `PeekpopTests/PhoneFrameDetectorTests.swift`

**Interfaces:**
- Consumes: `ScreenQuad` (Task 2)
- Produces: `struct PhoneFrameDetector { func detectQuad(in image: CGImage) async -> ScreenQuad? }`

- [ ] **Step 1: Write the failing test**

```swift
// PeekpopTests/PhoneFrameDetectorTests.swift
import XCTest
@testable import Peekpop

final class PhoneFrameDetectorTests: XCTestCase {
    private func loadFixture(_ name: String) -> CGImage {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: name, withExtension: "png")!
        let data = try! Data(contentsOf: url)
        let uiImage = UIImage(data: data)!
        return uiImage.cgImage!
    }

    func test_detectQuad_findsPlausibleRectangle_onFrontFacingPhoto() async {
        let detector = PhoneFrameDetector()
        let image = loadFixture("phone-front-facing")
        let quad = await detector.detectQuad(in: image)
        XCTAssertNotNil(quad, "should detect the screen on a straight-on phone photo")
        guard let quad else { return }
        let width = quad.topRight.x - quad.topLeft.x
        let height = quad.bottomLeft.y - quad.topLeft.y
        let aspect = width / height
        XCTAssertTrue((0.35...0.65).contains(aspect), "detected aspect \(aspect) should look like a phone screen")
    }

    func test_detectQuad_returnsNil_whenNoPlausibleRectangle() async {
        let detector = PhoneFrameDetector()
        let image = loadFixture("phone-in-flight")
        let quad = await detector.detectQuad(in: image)
        XCTAssertNil(quad, "no confident, plausible-aspect rectangle should be found in this photo")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/PhoneFrameDetectorTests`
Expected: FAIL (compile error — `PhoneFrameDetector` doesn't exist yet)

- [ ] **Step 3: Write the implementation**

```swift
// Peekpop/Services/PhoneFrameDetector.swift
import Vision
import CoreGraphics

/// Best-effort auto-detection of the photo-display rectangle inside a
/// phone-screen photo. Never trust this result outright — it is a prefill
/// hint the user always confirms or corrects (docs/ade.md: this request
/// can return a wrong rectangle with confidence 1.0).
struct PhoneFrameDetector {
    /// Only rectangles whose aspect ratio looks like a phone screen are
    /// accepted; anything else (or nothing found) returns nil.
    private static let plausibleAspectRange: ClosedRange<CGFloat> = 0.4...0.6

    func detectQuad(in image: CGImage) async -> ScreenQuad? {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.3
        request.maximumAspectRatio = 1.0
        request.minimumConfidence = 0.5
        request.maximumObservations = 5

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results else { return nil }

        for observation in results {
            let width = hypot(
                observation.topRight.x - observation.topLeft.x,
                observation.topRight.y - observation.topLeft.y
            )
            let height = hypot(
                observation.topLeft.x - observation.bottomLeft.x,
                observation.topLeft.y - observation.bottomLeft.y
            )
            guard height > 0 else { continue }
            let aspect = width / height
            guard Self.plausibleAspectRange.contains(aspect) else { continue }

            // Vision points are normalized, origin bottom-left, y up.
            // Flip to our top-left-origin, y-down convention.
            return ScreenQuad(
                topLeft: CGPoint(x: observation.topLeft.x, y: 1 - observation.topLeft.y),
                topRight: CGPoint(x: observation.topRight.x, y: 1 - observation.topRight.y),
                bottomRight: CGPoint(x: observation.bottomRight.x, y: 1 - observation.bottomRight.y),
                bottomLeft: CGPoint(x: observation.bottomLeft.x, y: 1 - observation.bottomLeft.y)
            )
        }
        return nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/PhoneFrameDetectorTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Peekpop/Services/PhoneFrameDetector.swift PeekpopTests/PhoneFrameDetectorTests.swift
git commit -m "Add PhoneFrameDetector with aspect-ratio plausibility filter"
```

---

### Task 4: SubjectSegmenter

**Files:**
- Create: `Peekpop/Services/SubjectSegmenter.swift`
- Test: `PeekpopTests/SubjectSegmenterTests.swift`

**Interfaces:**
- Consumes: nothing new
- Produces:
  ```swift
  struct SubjectSegmenter {
      static let plausibleCoverageRange: ClosedRange<CGFloat>
      func generateMask(croppedImage: CGImage) async -> CGImage?
      func isPlausible(_ cutout: CGImage) -> Bool
  }
  ```

- [ ] **Step 1: Write the failing test**

```swift
// PeekpopTests/SubjectSegmenterTests.swift
import XCTest
@testable import Peekpop

final class SubjectSegmenterTests: XCTestCase {
    private func loadFixture(_ name: String) -> CGImage {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(forResource: name, withExtension: "png")!
        let data = try! Data(contentsOf: url)
        return UIImage(data: data)!.cgImage!
    }

    /// Crops out the camera-app UI chrome, leaving only the displayed photo
    /// — this is the exact crop validated in docs/ade.md to produce a clean
    /// person silhouette.
    private func innerPhotoCrop(of image: CGImage, x0: CGFloat, y0: CGFloat, x1: CGFloat, y1: CGFloat) -> CGImage {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let rect = CGRect(x: x0 * w, y: y0 * h, width: (x1 - x0) * w, height: (y1 - y0) * h)
        return image.cropping(to: rect)!
    }

    func test_generateMask_producesPlausibleCutout_onFrontFacingPhoto() async {
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-front-facing")
        let cropped = innerPhotoCrop(of: full, x0: 0.238, y0: 0.25, x1: 0.696, y1: 0.65)

        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask, "should find a foreground instance in the cropped photo area")
        guard let mask else { return }
        XCTAssertTrue(segmenter.isPlausible(mask), "the person cutout should pass the plausibility check")
    }

    func test_generateMask_producesPlausibleCutout_onTiltedLandscapePhoto() async {
        let segmenter = SubjectSegmenter()
        let full = loadFixture("phone-tilted-landscape")
        let cropped = innerPhotoCrop(of: full, x0: 0.291, y0: 0.395, x1: 0.692, y1: 0.86)

        let mask = await segmenter.generateMask(croppedImage: cropped)
        XCTAssertNotNil(mask)
        guard let mask else { return }
        XCTAssertTrue(segmenter.isPlausible(mask))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/SubjectSegmenterTests`
Expected: FAIL (compile error — `SubjectSegmenter` doesn't exist yet)

- [ ] **Step 3: Write the implementation**

```swift
// Peekpop/Services/SubjectSegmenter.swift
import Vision
import CoreImage

/// Extracts a foreground cutout from an already-cropped "photo area" image.
/// MUST be called with the camera-app UI chrome already excluded — running
/// this on a full, uncropped photo produces unusable results (docs/ade.md).
/// Uses the class-agnostic foreground request, not a person-specific one:
/// person-specific segmentation failed even on the cleanest sample because
/// the "person" is a photo shown on a screen, not a real photographed body.
struct SubjectSegmenter {
    /// Fraction of the crop's pixels the cutout must cover to be treated as
    /// a plausible subject rather than noise or a near-empty/near-total
    /// mask. Initial values from the spike in docs/ade.md — tune with more
    /// real photos during implementation.
    static let plausibleCoverageRange: ClosedRange<CGFloat> = 0.15...0.85

    private let ciContext = CIContext()

    func generateMask(croppedImage: CGImage) async -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: croppedImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first,
              let topInstance = observation.allInstances.sorted().first else {
            return nil
        }
        guard let pixelBuffer = try? observation.generateMaskedImage(
            ofInstances: [topInstance], from: handler, croppedToInstancesExtent: true
        ) else { return nil }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    /// Fraction of non-transparent pixels in `cutout`, sampled every 4th
    /// pixel in each dimension for speed.
    func isPlausible(_ cutout: CGImage) -> Bool {
        Self.plausibleCoverageRange.contains(alphaCoverage(of: cutout))
    }

    private func alphaCoverage(of image: CGImage) -> CGFloat {
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return 0 }
        var data = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &data, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue
        ) else { return 0 }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var opaqueCount = 0
        var sampledCount = 0
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                sampledCount += 1
                if data[y * width + x] > 40 { opaqueCount += 1 }
            }
        }
        guard sampledCount > 0 else { return 0 }
        return CGFloat(opaqueCount) / CGFloat(sampledCount)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/SubjectSegmenterTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Peekpop/Services/SubjectSegmenter.swift PeekpopTests/SubjectSegmenterTests.swift
git commit -m "Add SubjectSegmenter with plausibility check"
```

---

### Task 5: PopOutCompositor

**Files:**
- Create: `Peekpop/Services/PopOutCompositor.swift`
- Test: `PeekpopTests/PopOutCompositorTests.swift`

**Interfaces:**
- Consumes: `ScreenQuad` (Task 2)
- Produces: `struct PopOutCompositor { func compose(baseImage: CGImage, quad: ScreenQuad, cutout: CGImage) -> CGImage? }`

- [ ] **Step 1: Write the failing test**

```swift
// PeekpopTests/PopOutCompositorTests.swift
import XCTest
@testable import Peekpop

final class PopOutCompositorTests: XCTestCase {
    func test_compose_producesImageMatchingBaseDimensions() {
        let compositor = PopOutCompositor()

        // 200x300 solid base image.
        let base = Self.solidImage(width: 200, height: 300, gray: 0.8)
        // 80x160 solid cutout, with alpha so it's a valid "masked" cutout.
        let cutout = Self.solidImage(width: 80, height: 160, gray: 0.2, alpha: 1.0)
        let quad = ScreenQuad(
            topLeft: CGPoint(x: 0.25, y: 0.1), topRight: CGPoint(x: 0.75, y: 0.1),
            bottomRight: CGPoint(x: 0.75, y: 0.6), bottomLeft: CGPoint(x: 0.25, y: 0.6)
        )

        let result = compositor.compose(baseImage: base, quad: quad, cutout: cutout)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.width, base.width)
        XCTAssertEqual(result?.height, base.height)
    }

    private static func solidImage(width: Int, height: Int, gray: CGFloat, alpha: CGFloat = 1.0) -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.setFillColor(CGColor(red: gray, green: gray, blue: gray, alpha: alpha))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()!
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/PopOutCompositorTests`
Expected: FAIL (compile error — `PopOutCompositor` doesn't exist yet)

- [ ] **Step 3: Write the implementation**

```swift
// Peekpop/Services/PopOutCompositor.swift
import CoreGraphics

/// Composites the extracted subject enlarged and repositioned so it appears
/// to pop out past the bottom edge of the user-marked quad, rotated to
/// match the quad's own tilt (docs/ade.md — a fixed, non-rotated placement
/// only looks right when the phone is held near-vertical).
struct PopOutCompositor {
    /// How much larger the cutout is drawn than its extracted size.
    /// Initial value from the spike — tune with more samples.
    private let popOutScale: CGFloat = 1.3
    /// Fraction of the enlarged cutout's height that stays above the quad's
    /// bottom edge (the rest extends past it). Initial value — tune later.
    private let insideFraction: CGFloat = 0.42

    func compose(baseImage: CGImage, quad: ScreenQuad, cutout: CGImage) -> CGImage? {
        let outW = baseImage.width, outH = baseImage.height
        guard let ctx = CGContext(
            data: nil, width: outW, height: outH, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Base image, in image-pixel (top-left origin, y-down) coordinates
        // converted to CGContext's native bottom-left/y-up coordinates.
        ctx.draw(baseImage, in: topDownRectToContext(CGRect(x: 0, y: 0, width: outW, height: outH), canvasH: outH))

        // Bottom edge of the quad, in pixel space.
        let bottomLeftPx = CGPoint(x: quad.bottomLeft.x * CGFloat(outW), y: quad.bottomLeft.y * CGFloat(outH))
        let bottomRightPx = CGPoint(x: quad.bottomRight.x * CGFloat(outW), y: quad.bottomRight.y * CGFloat(outH))
        let edgeVector = CGVector(dx: bottomRightPx.x - bottomLeftPx.x, dy: bottomRightPx.y - bottomLeftPx.y)
        let angle = atan2(edgeVector.dy, edgeVector.dx)
        let bottomMid = CGPoint(x: (bottomLeftPx.x + bottomRightPx.x) / 2, y: (bottomLeftPx.y + bottomRightPx.y) / 2)

        let cutoutW = CGFloat(cutout.width) * popOutScale
        let cutoutH = CGFloat(cutout.height) * popOutScale

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 24, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))

        // Position and rotate around the quad's bottom-edge midpoint: the
        // cutout's top sits `insideFraction` of its height above the edge,
        // the rest extends below it, then the whole thing is rotated by
        // the edge's own tilt around that midpoint.
        ctx.translateBy(x: bottomMid.x, y: CGFloat(outH) - bottomMid.y)
        ctx.rotate(by: -angle)
        let drawRect = CGRect(
            x: -cutoutW / 2,
            y: -(cutoutH * insideFraction),
            width: cutoutW,
            height: cutoutH
        )
        ctx.draw(cutout, in: drawRect)
        ctx.restoreGState()

        return ctx.makeImage()
    }

    private func topDownRectToContext(_ rect: CGRect, canvasH: Int) -> CGRect {
        CGRect(x: rect.origin.x, y: CGFloat(canvasH) - rect.origin.y - rect.height, width: rect.width, height: rect.height)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/PopOutCompositorTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Peekpop/Services/PopOutCompositor.swift PeekpopTests/PopOutCompositorTests.swift
git commit -m "Add PopOutCompositor with rotation-aware placement"
```

---

### Task 6: CreationFlowViewModel

**Files:**
- Create: `Peekpop/Flow/CreationFlowViewModel.swift`
- Test: `PeekpopTests/CreationFlowViewModelTests.swift`

**Interfaces:**
- Consumes: `Screen`, `ScreenQuad` (Task 2), `PhoneFrameDetector` (Task 3), `SubjectSegmenter` (Task 4), `PopOutCompositor` (Task 5)
- Produces:
  ```swift
  @MainActor final class CreationFlowViewModel: ObservableObject {
      @Published var screen: Screen
      @Published var isPickerPresented: Bool
      @Published var selectedImage: CGImage?
      @Published var quad: ScreenQuad
      @Published var maskedCutout: CGImage?
      @Published var resultImage: CGImage?

      init(frameDetector: PhoneFrameDetector = .init(), segmenter: SubjectSegmenter = .init(), compositor: PopOutCompositor = .init())
      func start(hasSeenOnboarding: Bool)
      func advanceOnboarding()
      func finishOnboarding()
      func mainButtonTapped()
      func photoSelected(_ image: CGImage)
      func confirmBoundary(_ quad: ScreenQuad) async
      func finishBrushRefine() async
      func retryFromError()
      func startOver()
  }
  ```

- [ ] **Step 1: Write the failing test**

```swift
// PeekpopTests/CreationFlowViewModelTests.swift
import XCTest
@testable import Peekpop

@MainActor
final class CreationFlowViewModelTests: XCTestCase {
    func test_start_goesToOnboarding_whenNotSeenBefore() {
        let vm = CreationFlowViewModel()
        vm.start(hasSeenOnboarding: false)
        XCTAssertEqual(vm.screen, .onboarding(page: 0))
    }

    func test_start_goesToMain_whenAlreadySeen() {
        let vm = CreationFlowViewModel()
        vm.start(hasSeenOnboarding: true)
        XCTAssertEqual(vm.screen, .main)
    }

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
        if case .error = vm.screen {
            // expected
        } else {
            XCTFail("expected .error, got \(vm.screen)")
        }
    }

    func test_retryFromError_returnsToMainAndPresentsPicker() {
        let vm = CreationFlowViewModel()
        vm.screen = .error("test")
        vm.retryFromError()
        XCTAssertEqual(vm.screen, .main)
        XCTAssertTrue(vm.isPickerPresented)
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/CreationFlowViewModelTests`
Expected: FAIL (compile error — `CreationFlowViewModel` doesn't exist yet)

- [ ] **Step 3: Write the implementation**

```swift
// Peekpop/Flow/CreationFlowViewModel.swift
import CoreGraphics
import Foundation

/// Single source of truth for the whole creation flow. Not split per
/// screen — the flow is linear, one shared ObservableObject is simpler
/// (docs/code-architecture.md).
@MainActor
final class CreationFlowViewModel: ObservableObject {
    @Published var screen: Screen = .main
    @Published var onboardingPage: Int = 0
    @Published var isPickerPresented: Bool = false
    @Published var selectedImage: CGImage?
    @Published var quad: ScreenQuad = .defaultRect
    @Published var maskedCutout: CGImage?
    @Published var resultImage: CGImage?

    private let frameDetector: PhoneFrameDetector
    private let segmenter: SubjectSegmenter
    private let compositor: PopOutCompositor

    init(
        frameDetector: PhoneFrameDetector = PhoneFrameDetector(),
        segmenter: SubjectSegmenter = SubjectSegmenter(),
        compositor: PopOutCompositor = PopOutCompositor()
    ) {
        self.frameDetector = frameDetector
        self.segmenter = segmenter
        self.compositor = compositor
    }

    func start(hasSeenOnboarding: Bool) {
        screen = hasSeenOnboarding ? .main : .onboarding(page: 0)
    }

    func advanceOnboarding() {
        onboardingPage += 1
        screen = .onboarding(page: onboardingPage)
    }

    func finishOnboarding() {
        screen = .main
    }

    func mainButtonTapped() {
        isPickerPresented = true
    }

    func photoSelected(_ image: CGImage) {
        selectedImage = image
        quad = .defaultRect
        screen = .boundaryConfirm
        Task { await detectInitialQuad() }
    }

    private func detectInitialQuad() async {
        guard let image = selectedImage else { return }
        if let detected = await frameDetector.detectQuad(in: image) {
            quad = detected
        }
    }

    func confirmBoundary(_ confirmedQuad: ScreenQuad) async {
        quad = confirmedQuad
        screen = .generating
        guard let image = selectedImage, let cropped = croppedImage(from: image, quad: confirmedQuad) else {
            screen = .error("사진을 처리하지 못했어요.")
            return
        }
        guard let mask = await segmenter.generateMask(croppedImage: cropped) else {
            screen = .error("튀어나올 부분을 찾지 못했어요.")
            return
        }
        maskedCutout = mask
        if segmenter.isPlausible(mask) {
            await compose()
        } else {
            screen = .brushRefine
        }
    }

    func brushMaskUpdated(_ mask: CGImage) {
        maskedCutout = mask
    }

    func finishBrushRefine() async {
        await compose()
    }

    private func compose() async {
        screen = .compositing
        guard let base = selectedImage, let cutout = maskedCutout,
              let composed = compositor.compose(baseImage: base, quad: quad, cutout: cutout) else {
            screen = .error("이미지를 합성하지 못했어요.")
            return
        }
        resultImage = composed
        screen = .result
    }

    func retryFromError() {
        selectedImage = nil
        maskedCutout = nil
        resultImage = nil
        screen = .main
        isPickerPresented = true
    }

    func startOver() {
        selectedImage = nil
        maskedCutout = nil
        resultImage = nil
        screen = .main
        isPickerPresented = true
    }

    private func croppedImage(from image: CGImage, quad: ScreenQuad) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let minX = min(quad.topLeft.x, quad.bottomLeft.x) * w
        let maxX = max(quad.topRight.x, quad.bottomRight.x) * w
        let minY = min(quad.topLeft.y, quad.topRight.y) * h
        let maxY = max(quad.bottomLeft.y, quad.bottomRight.y) * h
        let rect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return image.cropping(to: rect)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:PeekpopTests/CreationFlowViewModelTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Peekpop/Flow/CreationFlowViewModel.swift PeekpopTests/CreationFlowViewModelTests.swift
git commit -m "Add CreationFlowViewModel"
```

---

### Task 7: Onboarding and Main views

**Files:**
- Create: `Peekpop/Views/OnboardingView.swift`, `Peekpop/Views/MainView.swift`

**Interfaces:**
- Consumes: `CreationFlowViewModel` (Task 6)
- Produces: `struct OnboardingView: View { init(viewModel: CreationFlowViewModel) }`, `struct MainView: View { init(viewModel: CreationFlowViewModel) }`

No unit tests (UI views are excluded from automated testing per docs/code-architecture.md) — verify manually in Step 3.

- [ ] **Step 1: Write OnboardingView**

```swift
// Peekpop/Views/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: CreationFlowViewModel

    private static let captions = [
        "phone-front-facing": "폰 카메라 앱을 켜고,\n화면에 인물이 보이게 찍어주세요",
        "phone-recording": "폰 카메라 앱을 켜고,\n화면에 인물이 보이게 찍어주세요",
        "phone-in-flight": "폰 카메라 앱을 켜고,\n화면에 인물이 보이게 찍어주세요"
    ]
    private static let images = ["phone-front-facing", "phone-recording", "phone-in-flight"]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $viewModel.onboardingPage) {
                ForEach(0..<Self.images.count, id: \.self) { index in
                    VStack(spacing: 16) {
                        Image(Self.images[index])
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 480)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Text(Self.captions[Self.images[index]] ?? "")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)

            if viewModel.onboardingPage == Self.images.count - 1 {
                Button("시작하기") {
                    viewModel.finishOnboarding()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
```

- [ ] **Step 2: Write MainView**

```swift
// Peekpop/Views/MainView.swift
import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: CreationFlowViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Button("사진 선택하기") {
                viewModel.mainButtonTapped()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 48)
        }
    }
}
```

- [ ] **Step 3: Verify it builds**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **` (the `Image(Self.images[index])` calls will show blank placeholders until Task 8 adds them to the asset catalog — that's expected and fixed next task)

- [ ] **Step 4: Commit**

```bash
git add Peekpop/Views/OnboardingView.swift Peekpop/Views/MainView.swift
git commit -m "Add OnboardingView and MainView"
```

---

### Task 8: Photo picker (camera + library) and onboarding assets

**Files:**
- Create: `Peekpop/Views/PhotoPicker.swift`, `Peekpop/Views/CameraPicker.swift`
- Modify: `Peekpop/Views/MainView.swift`
- Modify: `Peekpop.xcodeproj/.../Assets.xcassets` (add onboarding images)

**Interfaces:**
- Consumes: `CreationFlowViewModel.photoSelected(_:)`, `CreationFlowViewModel.isPickerPresented` (Task 6)
- Produces: `struct PhotoPicker: UIViewControllerRepresentable`, `struct CameraPicker: UIViewControllerRepresentable`, both taking an `onImagePicked: (CGImage) -> Void` closure.

- [ ] **Step 1: Add the onboarding images to the asset catalog**

In Xcode, open `Assets.xcassets`, add three new Image Sets named `phone-front-facing`, `phone-recording`, `phone-in-flight`, and drag in `TestFixtures/phone-front-facing.png`, `TestFixtures/phone-recording.png`, `TestFixtures/phone-in-flight.png` respectively (1x slot is enough).

- [ ] **Step 2: Write PhotoPicker (library)**

```swift
// Peekpop/Views/PhotoPicker.swift
import SwiftUI
import PhotosUI

/// Wraps PHPickerViewController. Picking a photo this way needs no
/// permission prompt (docs/ade.md).
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
                guard let uiImage = object as? UIImage, let cgImage = uiImage.cgImage else { return }
                DispatchQueue.main.async { onImagePicked(cgImage) }
            }
        }
    }
}
```

- [ ] **Step 3: Write CameraPicker**

```swift
// Peekpop/Views/CameraPicker.swift
import SwiftUI

/// Wraps UIImagePickerController in camera mode. Triggers the
/// NSCameraUsageDescription prompt the first time it's presented.
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
```

- [ ] **Step 4: Wire the picker into MainView**

```swift
// Peekpop/Views/MainView.swift
import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var showCameraOrLibraryChoice = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Button("사진 선택하기") {
                viewModel.mainButtonTapped()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 48)
        }
        .confirmationDialog("사진 선택", isPresented: $viewModel.isPickerPresented, titleVisibility: .hidden) {
            Button("카메라로 촬영") { showCameraOrLibraryChoice = false; presentCamera = true }
            Button("앨범에서 선택") { showCameraOrLibraryChoice = false; presentLibrary = true }
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

    @State private var presentCamera = false
    @State private var presentLibrary = false
}
```

- [ ] **Step 5: Verify it builds**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Manual check on simulator**

Run the app on the iPhone 17 simulator (`⌘R` in Xcode). Confirm: onboarding shows the three real photos with captions, "시작하기" reaches the main screen, tapping "사진 선택하기" offers camera/album, and picking a library photo (simulator has no camera) transitions to a blank boundary-confirm screen (expected — built in Task 9).

- [ ] **Step 7: Commit**

```bash
git add Peekpop/Views/PhotoPicker.swift Peekpop/Views/CameraPicker.swift Peekpop/Views/MainView.swift Peekpop/Assets.xcassets
git commit -m "Add camera/library photo picker"
```

---

### Task 9: BoundaryConfirmView

**Files:**
- Create: `Peekpop/Views/BoundaryConfirmView.swift`

**Interfaces:**
- Consumes: `CreationFlowViewModel.selectedImage`, `.quad`, `.confirmBoundary(_:)` (Task 6)
- Produces: `struct BoundaryConfirmView: View { init(viewModel: CreationFlowViewModel) }`

- [ ] **Step 1: Write BoundaryConfirmView**

```swift
// Peekpop/Views/BoundaryConfirmView.swift
import SwiftUI

struct BoundaryConfirmView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var localQuad: ScreenQuad = .defaultRect

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let cgImage = viewModel.selectedImage {
                    Image(decorative: cgImage, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                QuadOverlay(quad: $localQuad, canvasSize: geo.size)

                VStack {
                    HStack {
                        Button("뒤로") { viewModel.startOver() }
                            .foregroundStyle(.white)
                            .padding()
                        Spacer()
                    }
                    Spacer()
                    Text("화면에 보이는 사진(인물)에 맞춰주세요")
                        .foregroundStyle(.white)
                        .padding(.bottom, 8)
                    Button("확인") {
                        Task { await viewModel.confirmBoundary(localQuad) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 48)
                    .padding(.bottom, 24)
                }
            }
        }
        .onChange(of: viewModel.quad) { _, newQuad in localQuad = newQuad }
        .onAppear { localQuad = viewModel.quad }
    }
}

/// Four draggable corner handles over the photo, normalized (0...1),
/// origin top-left, matching ScreenQuad's convention.
private struct QuadOverlay: View {
    @Binding var quad: ScreenQuad
    let canvasSize: CGSize
    private let handleRadius: CGFloat = 14

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: point(quad.topLeft))
                path.addLine(to: point(quad.topRight))
                path.addLine(to: point(quad.bottomRight))
                path.addLine(to: point(quad.bottomLeft))
                path.closeSubpath()
            }
            .stroke(Color.yellow, lineWidth: 2)

            handle(\.topLeft)
            handle(\.topRight)
            handle(\.bottomRight)
            handle(\.bottomLeft)
        }
    }

    private func point(_ normalized: CGPoint) -> CGPoint {
        CGPoint(x: normalized.x * canvasSize.width, y: normalized.y * canvasSize.height)
    }

    private func handle(_ keyPath: WritableKeyPath<ScreenQuad, CGPoint>) -> some View {
        Circle()
            .fill(Color.yellow)
            .frame(width: handleRadius * 2, height: handleRadius * 2)
            .position(point(quad[keyPath: keyPath]))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let normalized = CGPoint(
                            x: min(max(value.location.x / canvasSize.width, 0), 1),
                            y: min(max(value.location.y / canvasSize.height, 0), 1)
                        )
                        quad[keyPath: keyPath] = normalized
                    }
            )
    }
}
```

- [ ] **Step 2: Verify it builds**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Manual check on simulator**

Pick a library photo, confirm the four yellow handles appear over the image, drag each one, tap "확인" — the app should move to a blank loading screen (Task 10 makes it a real spinner). Tap "뒤로" — should return to the main screen and re-open the picker.

- [ ] **Step 4: Commit**

```bash
git add Peekpop/Views/BoundaryConfirmView.swift
git commit -m "Add BoundaryConfirmView with draggable quad"
```

---

### Task 10: LoadingView and RootView wiring

**Files:**
- Create: `Peekpop/Views/LoadingView.swift`, `Peekpop/Views/RootView.swift`
- Modify: `Peekpop/PeekpopApp.swift`

**Interfaces:**
- Consumes: `Screen`, `CreationFlowViewModel` (Tasks 2, 6), all views built so far
- Produces: `struct LoadingView: View { init(message: String) }`, `struct RootView: View`

- [ ] **Step 1: Write LoadingView**

```swift
// Peekpop/Views/LoadingView.swift
import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView()
                    .tint(.white)
                Text(message)
                    .foregroundStyle(.white)
            }
        }
    }
}
```

- [ ] **Step 2: Write RootView**

```swift
// Peekpop/Views/RootView.swift
import SwiftUI

struct RootView: View {
    @StateObject private var viewModel = CreationFlowViewModel()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            switch viewModel.screen {
            case .onboarding:
                OnboardingView(viewModel: viewModel)
            case .main:
                MainView(viewModel: viewModel)
            case .boundaryConfirm:
                BoundaryConfirmView(viewModel: viewModel)
            case .generating:
                LoadingView(message: "만드는 중...")
            case .brushRefine:
                LoadingView(message: "만드는 중...") // replaced by BrushRefineView in Task 11
            case .compositing:
                LoadingView(message: "만드는 중...")
            case .result:
                LoadingView(message: "만드는 중...") // replaced by ResultView in Task 12
            case .error(let message):
                LoadingView(message: message) // replaced by ErrorView in Task 13
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { viewModel.start(hasSeenOnboarding: hasSeenOnboarding) }
        .onChange(of: viewModel.screen) { _, newScreen in
            if case .main = newScreen { hasSeenOnboarding = true }
        }
    }
}
```

- [ ] **Step 3: Wire it into the app entry point**

```swift
// Peekpop/PeekpopApp.swift
import SwiftUI

@main
struct PeekpopApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 4: Verify it builds and runs end to end (through the loading placeholder)**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

Run the app: onboarding → main → pick photo → confirm boundary → should now show a real spinner with "만드는 중...".

- [ ] **Step 5: Commit**

```bash
git add Peekpop/Views/LoadingView.swift Peekpop/Views/RootView.swift Peekpop/PeekpopApp.swift
git commit -m "Wire RootView and app entry point"
```

---

### Task 11: BrushRefineView

**Files:**
- Create: `Peekpop/Views/BrushRefineView.swift`
- Modify: `Peekpop/Views/RootView.swift`

**Interfaces:**
- Consumes: `CreationFlowViewModel.maskedCutout`, `.brushMaskUpdated(_:)`, `.finishBrushRefine()` (Task 6)
- Produces: `struct BrushRefineView: View { init(viewModel: CreationFlowViewModel) }`

- [ ] **Step 1: Write BrushRefineView**

```swift
// Peekpop/Views/BrushRefineView.swift
import SwiftUI

private struct Stroke {
    var points: [CGPoint]
    var isErase: Bool
    var lineWidth: CGFloat
}

struct BrushRefineView: View {
    @ObservedObject var viewModel: CreationFlowViewModel
    @State private var strokes: [Stroke] = []
    @State private var currentStroke: Stroke?
    @State private var isEraseMode = false
    @State private var brushWidth: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let cutout = viewModel.maskedCutout {
                    Image(decorative: cutout, scale: 1)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay(
                            Canvas { context, _ in
                                for stroke in strokes + (currentStroke.map { [$0] } ?? []) {
                                    var path = Path()
                                    guard let first = stroke.points.first else { continue }
                                    path.move(to: first)
                                    for point in stroke.points.dropFirst() { path.addLine(to: point) }
                                    context.stroke(
                                        path,
                                        with: .color(stroke.isErase ? .black.opacity(0.85) : .yellow.opacity(0.6)),
                                        style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
                                    )
                                }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if currentStroke == nil {
                                            currentStroke = Stroke(points: [], isErase: isEraseMode, lineWidth: brushWidth)
                                        }
                                        currentStroke?.points.append(value.location)
                                    }
                                    .onEnded { _ in
                                        if let stroke = currentStroke { strokes.append(stroke) }
                                        currentStroke = nil
                                    }
                            )
                        )
                }

                VStack {
                    Text("튀어나오게 하고 싶은 부분을 칠해주세요")
                        .foregroundStyle(.white)
                        .padding(.top, 24)
                    Spacer()
                    HStack {
                        Button {
                            isEraseMode.toggle()
                        } label: {
                            Image(systemName: isEraseMode ? "eraser.fill" : "eraser")
                                .foregroundStyle(.white)
                        }
                        Slider(value: $brushWidth, in: 8...60)
                        Button("초기화") { strokes = [] }
                            .foregroundStyle(.white)
                    }
                    .padding()

                    Button("완료") {
                        let finalMask = renderFinalMask(canvasSize: geo.size)
                        viewModel.brushMaskUpdated(finalMask)
                        Task { await viewModel.finishBrushRefine() }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 48)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    /// Rasterizes the AI-suggested cutout plus the user's brush strokes
    /// into a single alpha mask cutout the same size as the original crop.
    private func renderFinalMask(canvasSize: CGSize) -> CGImage {
        guard let base = viewModel.maskedCutout else {
            return blankImage(size: canvasSize)
        }
        let width = base.width, height = base.height
        let scaleX = CGFloat(width) / canvasSize.width
        let scaleY = CGFloat(height) / canvasSize.height

        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return base }

        ctx.draw(base, in: CGRect(x: 0, y: 0, width: width, height: height))

        for stroke in strokes {
            guard let first = stroke.points.first else { continue }
            ctx.setLineWidth(stroke.lineWidth * max(scaleX, scaleY))
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setBlendMode(stroke.isErase ? .clear : .normal)
            if !stroke.isErase { ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)) }
            ctx.beginPath()
            ctx.move(to: CGPoint(x: first.x * scaleX, y: CGFloat(height) - first.y * scaleY))
            for point in stroke.points.dropFirst() {
                ctx.addLine(to: CGPoint(x: point.x * scaleX, y: CGFloat(height) - point.y * scaleY))
            }
            ctx.strokePath()
        }
        ctx.setBlendMode(.normal)
        return ctx.makeImage() ?? base
    }

    private func blankImage(size: CGSize) -> CGImage {
        let ctx = CGContext(
            data: nil, width: max(Int(size.width), 1), height: max(Int(size.height), 1),
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }
}
```

- [ ] **Step 2: Wire it into RootView**

```swift
// Peekpop/Views/RootView.swift — replace the .brushRefine case
case .brushRefine:
    BrushRefineView(viewModel: viewModel)
```

- [ ] **Step 3: Verify it builds**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Peekpop/Views/BrushRefineView.swift Peekpop/Views/RootView.swift
git commit -m "Add BrushRefineView"
```

---

### Task 12: ResultView

**Files:**
- Create: `Peekpop/Views/ResultView.swift`
- Modify: `Peekpop/Views/RootView.swift`

**Interfaces:**
- Consumes: `CreationFlowViewModel.resultImage`, `.startOver()` (Task 6)
- Produces: `struct ResultView: View { init(viewModel: CreationFlowViewModel) }`

- [ ] **Step 1: Write ResultView**

```swift
// Peekpop/Views/ResultView.swift
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
```

- [ ] **Step 2: Wire it into RootView**

```swift
// Peekpop/Views/RootView.swift — replace the .result case
case .result:
    ResultView(viewModel: viewModel)
```

- [ ] **Step 3: Verify it builds**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Peekpop/Views/ResultView.swift Peekpop/Views/RootView.swift
git commit -m "Add ResultView with save/share/retry"
```

---

### Task 13: ErrorView

**Files:**
- Create: `Peekpop/Views/ErrorView.swift`
- Modify: `Peekpop/Views/RootView.swift`

**Interfaces:**
- Consumes: `CreationFlowViewModel.retryFromError()` (Task 6)
- Produces: `struct ErrorView: View { init(message: String, viewModel: CreationFlowViewModel) }`

- [ ] **Step 1: Write ErrorView**

```swift
// Peekpop/Views/ErrorView.swift
import SwiftUI

struct ErrorView: View {
    let message: String
    @ObservedObject var viewModel: CreationFlowViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 16) {
                Text(message)
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
```

- [ ] **Step 2: Wire it into RootView**

```swift
// Peekpop/Views/RootView.swift — replace the .error case
case .error(let message):
    ErrorView(message: message, viewModel: viewModel)
```

- [ ] **Step 3: Verify it builds**

Run: `xcodebuild -project Peekpop.xcodeproj -scheme Peekpop -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Peekpop/Views/ErrorView.swift Peekpop/Views/RootView.swift
git commit -m "Add ErrorView"
```

---

### Task 14: Full pipeline manual QA pass

**Files:** none (verification only)

**Interfaces:** none — this task exercises the whole app built in Tasks 1-13.

- [ ] **Step 1: Run the full test suite**

Run: `xcodebuild test -project Peekpop.xcodeproj -scheme Peekpop -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: all tests PASS (`ScreenQuadTests`, `PhoneFrameDetectorTests`, `SubjectSegmenterTests`, `PopOutCompositorTests`, `CreationFlowViewModelTests`)

- [ ] **Step 2: Manual QA on a real device**

The simulator has no camera and Vision's foreground-instance request behaves best on real hardware — install on a physical iPhone (⌘R with a device selected) and exercise the full flow with the 4 `TestFixtures/` photos (add them to the simulator/device Photos app first via AirDrop or Simulator drag-and-drop) plus 2-3 new real photos taken specifically for this app (phone-screen-showing-a-person shots):

- [ ] Onboarding shows all 3 pages, can't be skipped, "시작하기" reaches main
- [ ] "사진 선택하기" offers camera and album; camera prompts for permission with the configured string
- [ ] Boundary confirm: corners are draggable, "확인" proceeds, "뒤로" returns to picker
- [ ] At least one photo reaches `.result` via the "그럴싸함" fast path (no brush screen)
- [ ] At least one photo routes through `.brushRefine`; painting and erasing both visibly change the mask, "완료" proceeds
- [ ] Result screen: save shows the checkmark feedback and the photo appears in the camera roll (first save prompts for the configured permission string); share sheet opens with the image; "다시 만들기" goes straight back to the picker, not the main screen
- [ ] Force an error path (e.g. deny photo-save permission) and confirm the error screen's "설정으로 이동" opens Settings

- [ ] **Step 3: Fix any issues found, per-issue commit**

For each issue found in Step 2, make the smallest fix in the relevant existing file from Tasks 1-13, then commit with a message describing the fix. Do not batch unrelated fixes into one commit.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "Peekpop MVP: full pipeline QA pass complete"
```
