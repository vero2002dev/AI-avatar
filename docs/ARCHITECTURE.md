# Realtime Processing Architecture

## Milestone Gate

The current app captures and previews unmodified camera video. The first processing pass begins only after the native build/tests and real Mac/iPhone camera checks pass. None of the future classes below exists as a no-op effect in the application.

## Frame Ownership and Budget

`CameraCapture` already provides NV12-first `CMSampleBuffer` delivery and discards late frames. Introduce a separate processing queue with one in-flight frame and at most one pending newest frame. Never enqueue an unbounded series of frames or execute model inference on the capture/configuration queue.

Retain the sample/pixel buffer until its GPU command buffer completes, reuse `CVMetalTextureCache`, texture pools and a single CoreML model instance, and publish frames with camera generation and timestamps. Drop results from a previous camera generation after switching. Preserve color space/range and source aspect ratio during compositing.

Start with 720p camera capture, lower-resolution tracking/segmentation and face/head ROIs. Quality decisions must follow measured GPU duration, delivery rate and memory, with hysteresis to avoid oscillation. A 30 FPS stream has a 33.3 ms frame interval; this is a target, not a demonstrated inference budget. Measure resident memory with Instruments on the actual 8 GB machine before enabling a model.

## Planned Components

| Component | Responsibility | Required evidence |
| --- | --- | --- |
| CameraCapture | Native permission/discovery/capture, input switching and event recovery | Physical camera checklist |
| FrameProcessor | Bounded scheduler, frame timestamps/generation, quality control and shared Metal resources | Synthetic backpressure/generation tests and hardware timings |
| FaceIdentityProcessor | Vision landmarks/pose, licensed CoreML identity inference in a tracked ROI, expression/lighting-aware composition | Correct identity data, model license, pose/expression/occlusion tests |
| HeadHairProcessor | Head segmentation and pose; tracked finger-coil geometry or neural head renderer | View-consistent silhouette, realistic occlusion and temporal tests |
| SkinToneProcessor | Semantic skin mask, luminance/texture-preserving chroma mapping to fixed chocolate tone | Face/hands/torso consistency under changing illumination |
| TattooProtectionProcessor | Explicit protected tattoo regions and temporally tracked mask | Tattoo detail/color comparisons before and after tone/body processing |
| BodyDefinitionProcessor | Tracked torso ROI, subtle local contrast/shading on the actual body | Motion, clothing and tattoo preservation checks |
| TemporalStabilizer | Motion-compensated masks/pose/tone confidence smoothing | Low ghosting and stable occlusion recovery without a large frame buffer |
| OutputPipeline | Processed preview and real OBS output transport | Receiving frames in OBS, color/latency and reconnect tests |

Tracking and protection masks are dependencies, not just sequential image filters. Compute tattoo protection before skin/body modifications, then apply it to both stages. Pass scene lighting and head/body tracking to the relevant processors. Preserve the source background, clothing and unmodified body pixels outside validated masks.

## One Identity

Use one immutable identity configuration: fixed identity model/reference, defined finger coils, chocolate skin tone and conservative torso enhancement. Internal debug flags may disable a processor independently. Do not expose identity selection. Missing weights or unsupported effects must report unavailable, not silently substitute a static overlay.

No identity dataset is present. Training/conversion and license review remain necessary before an actual transformation can be claimed. The M2 memory budget rules out loading several large generators together; validate one compact ROI model first.

## Hair Intermediate Path

Full neural head rendering may not fit the measured budget. The intermediate candidate is a tracked head mesh, real strand/coil geometry, head segmentation, occlusion and camera-aware lighting. This requires person-specific head/hair assets and stable pose; segmentation alone does not generate photorealistic finger coils. Do not promise the intermediate appearance until render comparisons succeed.

## Output

Keep an unmodified capture preview as a diagnostic view and introduce a separate processed renderer. Evaluate Syphon only after checking its license and demonstrating receiving frames in OBS. A virtual camera requires a real Core Media I/O extension and separate signing/install approval; an app button alone does not implement it. 1080p output may composite/upscale lower-resolution inference, subject to measured quality and latency.
