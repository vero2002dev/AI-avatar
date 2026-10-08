# Development Status

Current scope: Milestone 1, native camera capture. Compile/tests are green; completion and processing development remain gated on the physical camera checklist.

## WORKING

- Native app compiles with Xcode 16.4 on the macOS GitHub Actions runner, in Debug and optimized Apple Silicon Release configurations.
- All 10 XCTest tests pass: automatic preference, manual selection, disconnect/reconnect policy, deterministic sorting and delivered frame-rate/drop calculations.
- Shared Xcode scheme, camera usage description, sandbox entitlement and Continuity Camera device type opt-in compile successfully.
- GitHub Actions builds/tests with `xcodebuild` and uploads test results plus an unsigned Apple Silicon app archive.
- Local Swift type checking against the installed macOS 15.5 SDK passes. Property list/project syntax validation passes.
- The bootstrap script compiles and links a real native arm64 `.app` on this Mac with Command Line Tools, resolves bundle metadata and creates a verified local signature with camera/sandbox entitlements.

Evidence: [successful CI run](https://github.com/vero2002dev/AI-avatar/actions/runs/37552416691) for commit `8b97cc7024a565edfe81b0b75a776f051d47a1d0`. This proves compile/unit-test validation, not physical video capture.

## PARTIAL

- Native camera capture is implemented: permission handling, discovery, iPhone preference, preview, live input switching, disconnect fallback/reconnect, camera controls and delivered-frame diagnostics.
- Camera discovery, permission dialogs, switching/rollback, interruption and frame delivery behavior still need physical validation.
- The locally signed app is available at `build/AIAvatar.app`. Runtime validation is blocked by the Mac's locked screen; no preview, permission dialog or camera has been observed yet. Full Xcode remains required to run the project's tests locally.
- The future processing architecture and hardware test procedure are documented. No transformation processors are represented as working implementations.

## NOT IMPLEMENTED

- Fixed-identity face transformation; no model weights, license review or identity reference data.
- Vision face/expression/head/body tracking.
- Head/hair segmentation, thick finger-coil geometry or neural head rendering.
- Deep chocolate skin-tone remapping and semantic skin masks.
- Tattoo masks and protection.
- Subtle tracked torso/abs enhancement.
- Temporal stabilization and adaptive processing quality.
- Metal/CoreML processing, processed preview and profiling.
- Syphon output, OBS integration, virtual camera, recording and 1080p processing/output.
- Distribution signing/notarization, installer and custom app icon.

## NEEDS REAL MAC TEST

- First-run camera permission grant, denial, restriction and re-enabling permission in System Settings.
- Physical Mac camera discovery, opening and continuous live preview.
- iPhone Continuity Camera discovery/preference and USB/wireless behavior.
- External camera discovery, supported formats and live switching.
- Connect/disconnect/reconnect while live, paused and manually pinned.
- Unavailable/busy camera errors, rollback, interruptions and missing-frame recovery.
- Camera stops after Stop/window close; reconnect does not restart a paused stream.
- Resize/aspect ratio, long device names and multiple cameras with identical names.
- Sustained capture rate, drops, end-to-end latency and memory usage on M2 / 8 GB.

Use [docs/HARDWARE_VALIDATION.md](docs/HARDWARE_VALIDATION.md) and record the exact build, OS/devices, results and measurements. CI success is compile/test validation, not a physical camera result.
