# Development Status

Neural integration pass, 2026-10-08. Actual inference is not a finished realtime avatar.
Current priority: Mac app + iPhone Continuity camera. Standalone mobile and cloud
GPU deployment are deferred, not working features.

## WORKING

- Native SwiftUI/AVFoundation capture with camera permission and sandbox.
- Physical Mac preview observed on Apple M2 / 8 GB, macOS 15.6: real FaceTime HD device, 1920 x 1080, approximately 30 FPS, zero reported drops during the short check.
- Stop hides/stops capture; Start resumes real frames. Camera light/close/endurance still need checking.
- Actual local LivePortrait/MLX neutral-to-smile inference: nonblank 512-square output, changed-pixel mean absolute difference 13.05/255. Expression really changes, not a static overlay.
- Initial offline test: 25.95 s initialization, 734.15 ms median inference, 1675.79 MB peak MLX GPU allocations. These are not total RAM/end-to-end latency; concurrent-load test was slower. No 30 FPS claim.
- Five pinned human weights installed; restricted InsightFace/XPose detectors and extra generators excluded. Appearance extractor released after initialization.
- Bundled helper starts inside the app sandbox and reaches ready state. Identity/crop remain private in the container; originals are Git-ignored.
- Five Python IPC tests pass locally. Native sources compiled and the sandbox-inheriting bundle was locally signed/verified during this pass.
- Follow-up performance/quality pass: eight Python protocol/profiling tests pass locally; requested profile regression and fresh-warp safety covered. Native app compiles and signed neural bundle verifies.
- Separate real MLX stage profiling: quality/512 median 765 ms, warping 403 ms and decoder 341 ms. Fresh-warp speed mode 761 ms; no meaningful speed gain. See [PERFORMANCE.md](docs/PERFORMANCE.md).

Neural integration CI for commit 0790dbb passed Debug/Release xcodebuild,
15 XCTest tests, 5 Python IPC tests and locally signed bootstrap:
[run 37711978229](https://github.com/vero2002dev/AI-avatar/actions/runs/37711978229).
Follow-up commit abce399 also passed Debug/Release builds, 21 XCTest tests,
5 Python IPC tests and the signed bootstrap:
[run 37712514266](https://github.com/vero2002dev/AI-avatar/actions/runs/37712514266).
Quality/performance follow-up commit c3d0ba6 passed Debug/Release xcodebuild,
24 XCTest tests, 8 Python tests, signed bootstrap and offline checker compilation:
[run 37732301020](https://github.com/vero2002dev/AI-avatar/actions/runs/37732301020).
This run did not validate private images, camera hardware or visual quality.

## PARTIAL

- Live neural head was visibly observed on the Mac camera stream: approximately 0.7 processed FPS, 1331-1383 ms processing time, 1680 MB peak GPU allocations, while capture stayed around 30 FPS. This is far too slow for livestreaming.
- Initial head composition was too small/misaligned. A follow-up now aligns the detected generated face to the detected live face, preserving aspect ratio, and trims the matte using the generated chin. Updated physical visual validation still needed.
- New eye-landmark similarity alignment adds roll correction, with face-box fallback. Actual Vision/Metal offline composition inspected; unit tests cover both eyes, scale/roll and invalid inputs. This is not live-motion validation.
- Offline composition checker passed at 960 x 1280 with lower-body maximum pixel difference 0/255. This checks the lower 40% only, not all tattoos/occlusions/head edges.
- Fallback/stop/reinitialization now clears current AI FPS/latency and resets the timing interval, instead of displaying historical throughput while showing original video.
- Experimental 256 rendering measured 241 ms and 903 MB peak MLX allocations, but expression/detail regressed. Kept in the offline benchmark only; app remains quality/512, no adaptive-quality claim.
- Latest physical app validation is also blocked by a locked Mac session; camera permission/live alignment/lighting remain unverified. Offline neural and composition checks do not need camera access.
- Final rebuilt bundle's signature verifies and neural runtime reaches ready. Camera authorization became pending after rebuilding/re-signing, with no permission dialog observed in the app window. This blocks final live visual validation, not compilation or offline inference; do not report the final alignment as physically validated.
- One-in-flight processing/generation rejection/processed preview are real. Backlit or lost faces explicitly fall back to original video.
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
- Standalone iOS/Android/Windows applications and remote GPU transport.

## NEEDS REAL MAC TEST

- Actual expressions/rotation, head alignment, hair edges, lighting, original body/background/tattoos and hand occlusion under useful frontal light.
- Sustained inference, capture-to-display latency, total resident RAM/swap with OBS on M2 / 8 GB.
- Fresh permission prompt, denial/re-enable and restrictions.
- iPhone Continuity USB/wireless/preference, live switching, disconnect/reconnect while running/paused.
- External cameras, formats, busy/rollback/interruption behavior.
- Quit/close/reopen, orphan-helper check, resize, repeated identity import.

Use [HARDWARE_VALIDATION.md](docs/HARDWARE_VALIDATION.md). CI is compile/test
validation, never proof of physical camera or visual quality.
