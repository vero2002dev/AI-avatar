# Development Status

Neural integration pass, 2026-10-08. Actual inference is not a finished realtime avatar.

## WORKING

- Native SwiftUI/AVFoundation capture with camera permission and sandbox.
- Physical Mac preview observed on Apple M2 / 8 GB, macOS 15.6: real FaceTime HD device, 1920 x 1080, approximately 30 FPS, zero reported drops during the short check.
- Stop hides/stops capture; Start resumes real frames. Camera light/close/endurance still need checking.
- Actual local LivePortrait/MLX neutral-to-smile inference: nonblank 512-square output, changed-pixel mean absolute difference 13.05/255. Expression really changes, not a static overlay.
- Initial offline test: 25.95 s initialization, 734.15 ms median inference, 1675.79 MB peak MLX GPU allocations. These are not total RAM/end-to-end latency; concurrent-load test was slower. No 30 FPS claim.
- Five pinned human weights installed; restricted InsightFace/XPose detectors and extra generators excluded. Appearance extractor released after initialization.
- Bundled helper starts inside the app sandbox and reaches ready state. Identity/crop remain private in the container; originals are Git-ignored.
- Five Python IPC tests pass locally. Native sources compiled and the sandbox-inheriting bundle was locally signed/verified during this pass.

Previous camera-only CI: [run 37708367136](https://github.com/vero2002dev/AI-avatar/actions/runs/37708367136),
10 passing XCTest tests and Debug/Release builds. New neural tests/build need
their own new CI result; prior success does not validate new code.

## PARTIAL

- One-in-flight processor, generation rejection, native processed preview and ROI path implemented. Initial backlit live test correctly fell back to original because the face was not tracked; live transformed picture quality needs confirmation.
- Neural head/hair animation and Vision matte composition exist; silhouette/neck alignment, light matching, original hair, large rotations and hand occlusions remain incomplete.
- Expression smoothing and camera/tracking resets exist; full temporal stabilization/adaptive quality unfinished.
- Body/background outside head matte untouched, but explicit tattoo protection during body editing is not implemented.
- Continuity/external discovery/switch/reconnect implemented and policy-tested, not physically tested.
- Metal via MLX, but Python model runtime rather than CoreML/pure Swift. Packaging is a developer workflow, not notarized distribution.

## NOT IMPLEMENTED

- Whole-body semantic skin masks and chocolate tone preserving lighting/texture.
- Explicit tattoo protection masks.
- Body/torso tracking and subtle abs enhancement.
- Semantic hair/head/hand occlusion, complete multi-view head reconstruction.
- CoreML/MLX-Swift conversion, adaptive rendering, sustained 30 FPS transformation.
- Syphon, OBS receiving frames, CMIO virtual camera, recording/export.
- Distribution signing/notarization, installer and custom icon.

## NEEDS REAL MAC TEST

- Actual expressions/rotation, head alignment, hair edges, lighting, original body/background/tattoos and hand occlusion under useful frontal light.
- Sustained inference, capture-to-display latency, total resident RAM/swap with OBS on M2 / 8 GB.
- Fresh permission prompt, denial/re-enable and restrictions.
- iPhone Continuity USB/wireless/preference, live switching, disconnect/reconnect while running/paused.
- External cameras, formats, busy/rollback/interruption behavior.
- Quit/close/reopen, orphan-helper check, resize, repeated identity import.

Use [HARDWARE_VALIDATION.md](docs/HARDWARE_VALIDATION.md). CI is compile/test
validation, never proof of physical camera or visual quality.
