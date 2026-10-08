# Neural Development Pass

## Follow-Up: Mac Quality and Performance

2026-10-08. Scope remains the Mac app with iPhone Continuity camera. Standalone
mobile support and remote GPU deployment are deferred. No rental, external
image upload or unrelated repository edits.

- Corrected smoke-test profile selection; regression test prevents forced quality overriding speed. Every benchmark frame uses fresh warping.
- Added diagnostic synchronization/timing of real motion, stitching, warping and decoding. Quality/512 measured 765 ms: 403 ms warping, 341 ms generator. Fresh-warp speed mode measured 761 ms, not a meaningful improvement.
- Experimental 256 rendering measured 241 ms/903 MB peak MLX allocations but lost expression/detail on visual inspection. Not enabled in the app. No realtime/30 FPS claim.
- Real Vision eye landmarks now align generated/live eye positions with uniform scale and roll; unreliable eyes fall back to face-box alignment.
- Cleared stale AI FPS/latency on fallback, stop, disable and initialization; reset completion timing after gaps. Initialization no longer schedules a delayed reset over its ready state.
- Added native alignment/fallback tests and a reproducible offline compositor checker. Actual 960 x 1280 Vision/Metal composition passed with lower-body maximum pixel difference 0/255 and was visually inspected.
- Eight Python tests pass locally; native app compiles and the sandbox-inheriting neural bundle signature verifies. CI builds/tests the native app and compiles the offline checker.
- Physical live validation could not proceed because the Mac session is locked. Prior camera-authorization issue is not declared resolved. Still-image composition is not proof of realtime realism, stability or iPhone hardware support.

Next: validate the changed alignment in live video, then correct light/neck
matching and semantic occlusion while measuring capture-to-display latency.
The existing renderer is too slow; backend/model replacement needs its own
measured quality and latency gate before OBS output or a mobile version.

### Follow-Up Files

- .github/workflows/macos.yml
- AIAvatar/ContentView.swift
- AIAvatar/Processing/FrameProcessor.swift
- AIAvatar/Processing/HeadGeometry.swift
- AIAvatar/Processing/HeadHairProcessor.swift
- AIAvatarTests/HeadGeometryTests.swift
- neural/worker.py
- neural/smoke.py
- neural/test_protocol.py
- scripts/check-head-composition.swift
- README.md
- DEV_STATUS.md
- docs/ARCHITECTURE.md
- docs/PERFORMANCE.md
- docs/DEVELOPMENT_PASS.md

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
