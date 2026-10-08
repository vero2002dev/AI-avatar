# AI Avatar

Native SwiftUI / AVFoundation macOS app for **one fixed identity**, now with an
actual local neural head-animation path. Not a static face sticker or web UI.
This is experimental: **not yet a photorealistic, stable, low-latency livestream product**.

Current scope: finish the native Mac app, with iPhone available as its Continuity
camera. Standalone iPhone/Android apps and cloud GPU integration are deferred;
neither is currently implemented.

## Implemented

- Real permission, Mac/Continuity/external/Desk View discovery, iPhone preference, input switching/rollback, reconnect and interruption handling.
- Physical Mac capture observed on M2 / 8 GB at 1920 x 1080, approximately 30 FPS; real dimensions, FPS and drop counts. Continuity/external hardware checks remain pending.
- Vision face ROIs, separate inference queue, one retained frame in flight, no backlog, stale-generation rejection.
- Five pinned human LivePortrait MLX models: cached appearance, motion/3D keypoints, stitching, neural warping and SPADE decoding. Real expressions/rotation drive generated face/head pixels.
- Vision generated-head segmentation and Metal-backed Core Image composition onto the matching **live camera frame**, not the source photo's body/background.
- Generated/live eye-landmark alignment corrects translation, scale and roll, with face-box fallback when eye landmarks are unreliable. Latest live validation is pending.
- Original/AI diagnostics, actual AI timing/FPS/GPU peak memory, explicit tracking/error fallback.
- Fixed-reference import into private app-container storage. No generic avatar selector, browser camera, microphone, cloud inference or photo upload.
- App Sandbox retained; bundled Python helper inherits it. UI/capture/tracking/composition are Swift; inference is Python/MLX, **not yet CoreML or pure Swift**.

An actual neutral-to-smile test on M2 took about **734 ms per frame** and
**1676 MB peak MLX GPU allocations**. This is not total RAM or end-to-end latency.
Concurrent camera/benchmark load was slower. **The model does not meet 30 FPS.**
See [DEV_STATUS.md](DEV_STATUS.md) for validation boundaries.
The [performance audit](docs/PERFORMANCE.md) isolates warping/decoding and records
why the lower-resolution experiment is not enabled in the app.

## Build

Camera: macOS 14+, Xcode 16+ or Command Line Tools for the bootstrap.
Neural runtime: **Apple Silicon, macOS 15+, relocatable Python 3.11+**.

```sh
xcodebuild -project AIAvatar.xcodeproj -scheme AIAvatar \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
xcodebuild -project AIAvatar.xcodeproj -scheme AIAvatar \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
python3 -m unittest discover -s neural -p 'test_*.py'
```

For a runnable, locally signed neural app:

```sh
bash scripts/setup-neural-runtime.sh /absolute/path/to/relocatable/python3
bash scripts/build-local-camera.sh
bash scripts/package-neural-runtime.sh
open build/AIAvatar.app
```

Setup downloads only five human weights and pins upstream code/model revisions.
Packaging includes the interpreter, dependencies, models and license notices,
signs the helper with sandbox inheritance and verifies the app.
Framework/system Python may not be relocatable; this remains a developer
workflow, not a public installer. Xcode-built apps can be passed as the optional
bundle path to the packaging script. Unsigned CI archives have no model runtime
or private reference photos. Full Xcode is required for local XCTest.

Import one well-lit photo showing the complete face and hairstyle. The fixed
reference and derived crop stay in Application Support/AIAvatar/Identity inside
the app container. Development originals are in ignored private-assets/, never
GitHub. Camera permission requires a locally signed app.

For iPhone, follow Apple's [Continuity Camera requirements](https://support.apple.com/en-us/102546).
Discovery uses [native AVFoundation](https://developer.apple.com/documentation/avfoundation/supporting-continuity-camera-in-your-macos-app).

## Architecture

CameraCapture -> FrameProcessor -> FaceIdentityProcessor -> HeadHairProcessor ->
native processed preview. A 256-square RGB driving crop travels through a local
framed pipe; a 512-square neural head returns for segmentation/composition with
the original frame. Metal/Core Image/model resources are reused.

See [architecture](docs/ARCHITECTURE.md),
[license provenance](neural/THIRD_PARTY.md) and
[hardware checklist](docs/HARDWARE_VALIDATION.md).

## Limitations and Roadmap

- Model is far too slow for 30 FPS: profile warping/decoder, compare lower-resolution rendering, then CoreML/MLX-Swift conversion or a lighter licensed renderer.
- Hair is neurally animated, not a sticker. Profile/back-of-head geometry, original-hair remnants, light matching, fast motion and occlusion handling remain incomplete.
- Person segmentation clipped to the head is not semantic hair/skin/hand segmentation. Backlit faces can lose tracking. Live composition quality needs validation.
- Body/tattoos/background outside the head matte are unchanged. Whole-body chocolate tone, explicit tattoo masks and subtle tracked abs/torso enhancement are **not implemented**.
- Expression smoothing/resets exist; full temporal stabilization/adaptive quality remain partial.
- Syphon, OBS transport, virtual camera, recording, notarization and installer are **not implemented**. 1080p capture does not establish 1080p/30 processed output.

GitHub Actions builds Debug/Release with xcodebuild, runs Swift and IPC tests,
and fails on errors. CI never uses private photos and cannot test physical
Continuity Camera, picture quality or sustained M2 performance.
