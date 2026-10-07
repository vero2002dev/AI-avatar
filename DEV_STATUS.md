# Development Status

Current scope: Milestone 1, native camera capture. Processing development is gated on compile/test validation and the physical camera checklist.

## WORKING

- Repository now contains a native SwiftUI/AVFoundation implementation rather than the original README-only repository.
- Validation results will be recorded here after the compiler and tests complete. Physical capture has not been marked working.

## PARTIAL

- Native camera capture is implemented: permission handling, discovery, iPhone preference, preview, live input switching, disconnect fallback/reconnect, camera controls and delivered-frame diagnostics.
- Camera selection and frame-rate calculation have unit tests; the first CI run is pending.
- Xcode project, shared scheme, sandbox camera entitlement, usage description and Continuity Camera opt-in are present; full `xcodebuild` validation is pending.
- GitHub Actions is configured for macOS Debug build, XCTest, Release build and test result upload.
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
