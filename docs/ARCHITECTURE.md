# Realtime Architecture

## Current Path

AVFoundation -> bounded FrameProcessor -> Vision face ROI -> local MLX
FaceIdentityProcessor -> Vision HeadHairProcessor -> Core Image/Metal composition
-> native processed preview.

Matched reference/driving crops feed cached appearance and live pose/expression
extraction. Implicit 3D keypoints drive stitching, neural warping and SPADE
decoding. Scale/position come from the camera ROI. The generated head is segmented
and trimmed below the neck, then composited on the matching **camera frame**.
Source-photo body/background is never the output body/background.

## Ownership and Budget

- Capture/configuration and inference have separate serial queues.
- One retained read-only pixel buffer in flight; busy frames dropped, no backlog.
- Switch/stop/restart invalidates generation; obsolete results cannot publish.
- One Metal Core Image context, one segmentation request, one loaded renderer. Appearance extractor released after source preparation; MLX allocation cache capped at 128 MB.
- Local framed stdin/stdout: little-endian uint32 JSON size, bounded header and fixed RGB payload, matched response ID. Logs on stderr; no server/network.
- Startup/frame timeouts terminate stuck helper. Helper exits if its parent disappears.
- Bundled interpreter is signed with sandbox inheritance; weights in bundle, identity in private container. No expanded home-directory access.
- Tracking/error fallback explicitly displays original. AI timing/FPS is distinct from capture FPS.

Current model is far outside the 33.3 ms 30 FPS budget. Frame dropping/raw preview
at 30 FPS is not realtime inference. Output updates at processing speed; displayed
processing duration includes tracking/copies/inference/segmentation/composition.

## Boundaries

| Component | Current state |
| --- | --- |
| CameraCapture | Real capture; Mac tested, Continuity/external pending |
| FrameProcessor | Bounded scheduling, Vision ROI, generation/error handling |
| FaceIdentityProcessor | Real persistent IPC to pinned MLX appearance/motion/stitching/warping/decoder |
| HeadHairProcessor | Generated-head person matte, empty-matte rejection, neck trim, Metal-backed composition; internal debug switch |
| Temporal stabilization | Expression smoothing/resets; pose/ROI/motion-compensated matte stabilization pending |
| SkinToneProcessor | Not implemented; needs semantic skin masks, not global RGB heuristics |
| TattooProtectionProcessor | Not implemented; body remains untouched |
| BodyDefinitionProcessor | Not implemented; must preserve actual torso motion/ink/clothing |
| OutputPipeline | Native processed preview only; OBS/Syphon/CMIO pending |

Missing processors are documented, not no-op effects or fake buttons. UI has
one fixed reference import and Original/AI diagnostics, no identity library.

## Next Work

1. Validate native RGB orientation, matte/neck alignment, actual expression/rotation and hand occlusions.
2. Profile warping/decoder, compare lower-resolution features, convert to CoreML/MLX-Swift or use a lighter licensed renderer. Do not load multiple huge models.
3. Motion-aware pose/ROI/matte stabilization, lighting harmonization and semantic head/hair/skin/hand masks. Multiple photos alone do not produce 3D geometry.
4. Explicit tattoo protection before tone/torso edits; leave background/clothing untouched.
5. Physically validate OBS output; a CMIO virtual camera needs its own signed/approved extension.

Full Milestone 1 hardware checklist remains incomplete for iPhone/external.
Processing advanced after real Mac preview/Stop/Start and prior CI passed,
without claiming untested devices are validated.
