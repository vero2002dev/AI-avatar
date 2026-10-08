# AI Avatar

Native macOS live camera application, built with SwiftUI and AVFoundation. The product goal is a photorealistic, temporally stable transformation for **one fixed identity** on Apple M2 with 8 GB RAM.

The current development pass implements Milestone 1: camera capture. The preview is real camera video. Identity, hair, skin, tattoo, torso and OBS processing are not implemented yet. See [DEV_STATUS.md](DEV_STATUS.md) for validation status.

## Current Features

- Requests macOS camera permission, handles denial/restriction and opens Camera privacy settings.
- Discovers real Mac cameras, iPhone Continuity Cameras, external cameras and Desk View devices using AVFoundation.
- Prefers iPhone Continuity Camera automatically; manual selection remains pinned during the session.
- Displays a native `AVCaptureVideoPreviewLayer` and the actual device name/type.
- Switches inputs without blocking the UI. If a new camera cannot be attached, restores the previous input where possible.
- Observes device discovery and connect/disconnect notifications. Falls back when a device disappears and restores a pinned camera when it reconnects.
- Starts/stops capture, reports interruptions, retries a runtime failure once, and detects missing video frames.
- Requests 1280 x 720 and 30 FPS when supported; reports actual delivered dimensions, measured FPS and dropped frames.
- Uses a serial capture queue, drops late frames and prefers NV12 pixel buffers. No microphone capture, network video transmission or third-party models.

Implementation does not establish hardware compatibility or sustained performance. Follow the [hardware validation checklist](docs/HARDWARE_VALIDATION.md) on a real Mac before treating Milestone 1 as complete.

## Build and Run

Requirements: macOS 14 or later and full Xcode 16 or later. Apple M2 / 8 GB is the target, not a measured performance result. The command line tools alone do not provide `xcodebuild`.

1. Open `AIAvatar.xcodeproj` in Xcode and select the shared `AIAvatar` scheme.
2. For local development, choose **Sign to Run Locally** or your development team in Signing & Capabilities. Keep the App Sandbox camera entitlement enabled.
3. Run the app and grant camera access. The camera menu contains only devices AVFoundation currently exposes.

For iPhone, configure Apple's [Continuity Camera requirements](https://support.apple.com/en-us/102546), enable Continuity Camera on the iPhone, and keep the phone nearby and available. USB is useful for the first hardware test. This app opts into the modern Continuity Camera device type and uses Apple's [AVFoundation discovery/capture approach](https://developer.apple.com/documentation/avfoundation/supporting-continuity-camera-in-your-macos-app).

Build and test without a developer account:

```sh
xcodebuild -project AIAvatar.xcodeproj -scheme AIAvatar \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build

xcodebuild -project AIAvatar.xcodeproj -scheme AIAvatar \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

Unsigned output is intended for compile/test validation. Use a locally signed build for camera permission and normal application use.

For camera testing on a Mac with only Apple's Command Line Tools, the bootstrap script compiles the same app sources with `swiftc`, resolves the bundle metadata and signs the app locally:

```sh
bash scripts/build-local-camera.sh
open build/AIAvatar.app
```

This produces a runnable native app but does not run XCTest or replace the Xcode CI checks. CI also uploads an unsigned Apple Silicon app archive for inspection.

## Architecture

- `AIAvatarApp` / `ContentView`: one native window, camera controls, permission and capture status. Unit tests use an inert host window to avoid camera permission dialogs on CI.
- `CameraCapture`: owns AVFoundation discovery, session/input/output, serial queue, device events, input rollback and frame callbacks.
- `CameraPreviewView`: AppKit-backed native video preview, preserving the source aspect ratio.
- `CameraDevice` / `CameraSelectionPolicy`: typed device metadata and deterministic automatic/manual/fallback selection.
- `FrameRateMeter`: measures delivered frames and drops without retaining sample buffers.

The next processing architecture is specified in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Processor names there describe planned components, not implemented effects. The hardware milestone gates processing development.

## Validation

GitHub Actions uses a macOS runner to build Debug, run XCTest and build Release with `xcodebuild`. Failures fail the workflow; test result bundles are uploaded. Tests cover automatic preference, manual selection, disconnect/reconnect policy, deterministic ordering and real frame-rate calculations.

CI cannot test physical cameras, Continuity availability, permission dialogs, picture quality, lighting, latency or M2 memory consumption. Those results must be recorded separately in [DEV_STATUS.md](DEV_STATUS.md).

## Limitations and Roadmap

- Milestone 1: finish compile/test validation and the real Mac/iPhone/external camera checklist.
- Milestone 2: bounded processing scheduler, Metal texture reuse, Vision tracking/segmentation and measured latency/memory budgets. Keep camera preview operational during processing failures.
- Milestone 3: integrate a licensed, fixed-identity model and real identity data; add temporally stable face/head/hair compositing. No identity model or reference dataset is present in this repository.
- Milestone 4: validated skin masks, lighting-preserving deep chocolate tone mapping, explicit tattoo protection and subtle tracked torso contrast. Preserve clothing, background, tattoos, gestures and actual body motion.
- Milestone 5: processed output suitable for OBS, initially evaluate Syphon; virtual camera requires a real Core Media I/O camera extension, signing and user approval. Measure whether 1080p output fits M2 / 8 GB; lower internal resolution must remain available.

Finger-coil hair needs tracked geometry or a neural head solution with view/expression consistency. A static sticker cannot satisfy that requirement. No claim of photorealistic transformation, 1080p/30 performance, tattoo preservation or livestream output is made at this stage.
