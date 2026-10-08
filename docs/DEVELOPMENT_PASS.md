# Neural Development Pass

## Actual Changes

Two implementation commits: 0790dbb (real MLX neural integration) and abce399
(live-observed alignment fixes, backpressure/generation tests, matched mirroring
and internal per-module debug switches).

The native app can run an actual neural face/head renderer using one private
reference. Reference 6 is installed privately as the fixed identity; reference 8
was used for an offline expression test. All eight originals are locally backed
up in Git-ignored storage, never uploaded to GitHub. No other identity selectors,
fake skin/abs buttons or no-op transformation modules were added.

The generated head was observed on physical Mac video. Initial alignment was
wrong and was corrected in code using generated/live face bounding boxes. This
correction has unit tests; final live visual confirmation is still pending a
macOS camera authorization after rebuilding/re-signing.

## Validation

- M2 / 8 GB, macOS 15.6: real Mac camera roughly 30 FPS at 1920 x 1080.
- Offline neural neutral-to-smile output: 512-square, nonblank, changed-pixel MAE 13.05/255, median 734 ms, peak MLX GPU allocations 1676 MB.
- Initial live processed output: about 0.7 FPS, 1331-1383 ms processing time, GPU peak about 1680 MB. This is **not suitable for livestreaming yet**.
- Locally compiled native bundle and sandbox-inheriting helper have a verified signature; final runtime reaches identity-ready state.
- [Alignment CI](https://github.com/vero2002dev/AI-avatar/actions/runs/37712514266): xcodebuild Debug/Release, 21 XCTest tests, 5 Python IPC tests, bootstrap build all pass.
- CI does not load private photos/models or validate physical Continuity Camera, visual quality, total RAM or end-to-end latency.

## Real Versus Missing

Real: native camera, bounded scheduling, Vision face detection, local neural
motion/appearance/stitching/warping/decoding, generated-head segmentation,
Metal-backed camera composition and private fixed-reference storage.

Partial: head scale/pose/edges/lighting, temporal consistency and physical live
validation. Inference is currently Python/MLX inside the native app, not CoreML
or pure Swift. Body/background outside the head matte remain original, but
hands crossing the head are not robustly handled.

Missing: semantic whole-body chocolate skin processing, tattoo protection masks,
torso/abs enhancement, full multi-view hair reconstruction, adaptive quality,
OBS/Syphon/virtual camera, installer/notarization. No working claims for these.

Next: validate corrected alignment/pose under usable frontal lighting, profile
warping and decoder separately, compare lower-resolution/native model paths,
then add semantic occlusion/skin/tattoo masks before any body processing.

## Files Changed

- .github/workflows/macos.yml
- .gitignore
- AIAvatar.xcodeproj/project.pbxproj
- AIAvatar/AIAvatar.entitlements
- AIAvatar/Camera/CameraCapture.swift
- AIAvatar/Camera/CameraPreviewView.swift
- AIAvatar/ContentView.swift
- AIAvatar/Processing/FrameProcessor.swift
- AIAvatar/Processing/HeadGeometry.swift
- AIAvatar/Processing/HeadHairProcessor.swift
- AIAvatar/Processing/NeuralClient.swift
- AIAvatarTests/HeadGeometryTests.swift
- DEV_STATUS.md
- README.md
- docs/ARCHITECTURE.md
- docs/DEVELOPMENT_PASS.md
- neural/Helper.entitlements
- neural/THIRD_PARTY.md
- neural/requirements.txt
- neural/setup_runtime.py
- neural/smoke.py
- neural/test_protocol.py
- neural/worker.py
- scripts/package-neural-runtime.sh
- scripts/prepare-reference.swift
- scripts/setup-neural-runtime.sh
