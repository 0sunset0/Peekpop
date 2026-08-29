# Peekpop — Design Spec

Date: 2026-08-29
Status: Approved (MVP scope)

## 1. Overview

Peekpop is an iOS app (SwiftUI) that takes a single photo of a phone with its
screen on, showing a person, and generates a composited image where the
person (or an object they're holding, e.g. food) appears to pop out of the
phone screen into the real world — an exaggerated 3D "breaking through the
frame" effect, matching a popular photo-editing trend.

No accounts, no login. MVP ships fully free with no monetization.

## 2. Requirements

### 2.1 Functional requirements

- FR1: User selects a photo via camera capture or photo library (single photo, one input).
- FR2: App automatically detects the phone-screen rectangle within the photo.
- FR3: If FR2 fails, user manually marks the screen boundary by tapping its four corners.
- FR4: App automatically detects the foreground object (hand, food, etc.) that should appear to pop out, based on what overlaps or sits near the screen boundary.
- FR5: If FR4 fails, user manually selects the pop-out region with a finger-drag brush/mask tool.
- FR6: App cuts out the selected object and composites it enlarged/repositioned outside the screen boundary, with shadow/blur added for depth, producing an exaggerated pop-out illusion (not a flush overlay).
- FR7: User previews the result and can save it to Photos and/or share it via the iOS share sheet. No further in-app editing of the result in MVP.

### 2.2 Non-functional requirements

- NFR1: All image processing (detection, segmentation, compositing) runs on-device. No network calls are required for the core feature.
- NFR2: No user accounts, no login, no server-side storage of user photos.
- NFR3: iOS only, built with SwiftUI.

## 3. Implementation details

### 3.1 Core flow

1. `PhotoPickerView` — wraps `PHPickerViewController` (library) and camera capture; returns a single `UIImage`.
2. `PhoneFrameDetector` — uses Vision (`VNDetectRectanglesRequest` or similar) to find the phone-screen quadrilateral in the photo. On low-confidence/no result, flow routes to `ManualSelectionView` in corner-tap mode (FR3).
3. `SubjectSegmenter` — uses `VNGenerateForegroundInstanceMaskRequest` (iOS 17+) to find foreground object instances, and selects the instance that overlaps/borders the detected screen boundary. On no usable instance, flow routes to `ManualSelectionView` in brush-mask mode (FR5).
4. `PopOutCompositor` — using Core Graphics/Core Image: cuts out the selected object via its mask, enlarges and repositions it outside the screen boundary, and renders a drop shadow / slight blur differential between the "inside screen" and "popped out" regions to sell the depth illusion. Produces the final composited `UIImage`.
5. `ResultView` — shows the composited result with Save (Photos) and Share (share sheet) actions.

### 3.2 Components

| Component | Responsibility | Depends on |
|---|---|---|
| `PhotoPickerView` | Camera/library photo input | PhotosUI, UIKit camera bridge |
| `PhoneFrameDetector` | Auto-detect screen rectangle | Vision |
| `SubjectSegmenter` | Auto-detect pop-out object mask | Vision (iOS 17+) |
| `ManualSelectionView` | Fallback UI: 4-corner tap (frame) and brush mask (subject) | SwiftUI gestures |
| `PopOutCompositor` | Cutout + resize/reposition + shadow rendering | Core Graphics / Core Image |
| `ResultView` | Preview, save, share | PhotosUI (save), UIActivityViewController (share) |

### 3.3 Error handling

- Screen-rectangle detection fails or low confidence → user is told detection failed and is routed to manual 4-corner tap (`ManualSelectionView`, frame mode). Flow continues from the user-supplied rectangle.
- Foreground-object detection fails (no usable instance near the boundary) → user is told and routed to manual brush masking (`ManualSelectionView`, subject mode). Flow continues from the user-supplied mask.
- Both detections succeed but the composited result looks visually off → not validated in MVP; shown as-is. Quality scoring/rejection is a future-version concern.

### 3.4 Testing plan

- Unit tests for `PhoneFrameDetector` and `SubjectSegmenter` against a fixed set of sample images with known expected regions.
- Manual QA on a real device (not simulator, for camera/Vision accuracy) using ~10 sample trend-style photos covering the full flow, including forcing both manual fallback paths at least once each.

## 4. Constraints

- iOS only, SwiftUI. Minimum iOS 17 (required for `VNGenerateForegroundInstanceMaskRequest`).
- No login/accounts — any future usage-limiting logic must be device-local (see 5.3), not account-based.
- No backend/server component for the core feature — all processing on-device.
- MVP has no monetization; must not block or degrade the core flow for a future paywall.
- No decorative stickers/overlays in MVP.
- No post-generation manual adjustment (position/intensity sliders) in MVP — only the pre-generation manual fallbacks (FR3, FR5) exist.

## 5. Out of scope (future versions)

- 5.1 Automatic decorative sticker placement (food emoji, sparkles, etc. as seen in reference trend photos).
- 5.2 Post-result manual adjustment: position/scale/pop-out-intensity sliders.
- 5.3 Monetization: one free generation per day, paid for subsequent attempts on the same day. Since there's no login, this must be tracked via on-device local state (e.g. last-used date), which is trivially resettable by reinstalling — acceptable limitation, to be revisited if abuse becomes a problem.
- 5.4 Server-based higher-precision segmentation (trade-off: better accuracy vs. needing backend infra, API cost, and photo transmission).

## 6. Completion criteria (MVP done when)

- [ ] User can pick a phone-screen photo from camera or photo library.
- [ ] App auto-detects the phone screen rectangle; when detection fails, user can manually tap 4 corners to specify it.
- [ ] App auto-detects the pop-out foreground object; when detection fails, user can manually brush-select the region.
- [ ] App renders a composited image where the selected object appears to pop out beyond the phone frame with a shadow/depth effect.
- [ ] User can save the result to Photos and/or share it via the system share sheet.
- [ ] All processing happens on-device; the app functions with no network connection.
- [ ] Manually QA'd on a real device against ~10 sample trend-style photos with acceptable results, including both manual fallback paths exercised at least once.
