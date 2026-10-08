# Processing Measurements

2026-10-08, Apple M2 / 8 GB, macOS 15.6. Private canonical reference and smile
driving crops, three measured iterations after warmup. These are short offline
tests, not capture-to-display latency or sustained live performance. Only one
benchmark model was loaded at a time.

## Stage Profiling

| Configuration | Total median | Motion | Stitching | Warping | Generator | Peak MLX allocations |
| --- | --- | --- | --- | --- | --- | --- |
| quality, 512 render | 765 ms | 19 ms | 0.6 ms | 403 ms | 341 ms | 1676 MB |
| speed, 512 render, fresh warp | 761 ms | 19 ms | 0.7 ms | 402 ms | 338 ms | 1676 MB |
| quality, experimental 256 render | 241 ms | 17 ms | 0.5 ms | 107 ms | 116 ms | 903 MB |

Profiling explicitly evaluates lazy MLX arrays at stage boundaries. This adds
synchronization; normal app inference does not use those extra barriers.
`rendering` includes warping and the generator, so do not sum all JSON fields.
Peak MLX allocations are not total resident memory or system memory pressure.

The previous smoke test silently replaced the requested profile with quality.
That bug is fixed and regression-tested. All configurations here recompute
warping every frame: no cached images counted as fresh neural motion.

Warping and decoding dominate this workload. The speed profile is not a useful
measured improvement on this Mac with fresh motion. Experimental 256 rendering
reduces the appearance-extractor input and spatial feature volume, then upsamples
the actual neural output to 512. Visual inspection found poorer expression and
detail. **It is not enabled in the app, not validated for identity quality and
not a working adaptive-quality feature.** Production remains quality/512.

Even 241 ms exceeds the 33.3 ms budget for 30 FPS. Increasing the camera preview
rate or replaying generated images does not fix this. No cloud GPU was rented,
no references uploaded and no mobile app created in this pass.

## Reproduce Locally

Use local private 256-square source/driving crops, not tracked repository assets:

```sh
build/neural-runtime/venv/bin/python neural/smoke.py \
  --engine build/neural-runtime/engine \
  --weights build/neural-runtime/weights/liveportrait_mlx \
  --source /absolute/private/source.png --driving /absolute/private/driving.png \
  --output /absolute/private/generated.png \
  --profile quality --profile-stages --iterations 3
```

For comparison use `--profile speed`, or experimental `--render-size 256`.
Run these sequentially, not simultaneously with other heavy model benchmarks.
Nonblank output/change assertions alone do not establish expression fidelity.

Compile/run the production Vision/Metal compositor independently of the camera:

```sh
xcrun swiftc -O AIAvatar/Processing/HeadGeometry.swift \
  AIAvatar/Processing/HeadHairProcessor.swift AIAvatar/Processing/NeuralClient.swift \
  scripts/check-head-composition.swift -o /tmp/ai-avatar-head-check
/tmp/ai-avatar-head-check /absolute/private/generated.png \
  /absolute/private/driving-photo.jpg /absolute/private/composited.png
```

The checker compares the lower 40% of the frame through identical color handling
and rejects differences greater than one 8-bit level. This is a limited body
preservation check, not proof of tattoo protection or hand occlusion at the head.
CI compiles the checker but cannot run private-image or physical camera checks.
The actual 960 x 1280 offline check on 2026-10-08 passed with lower-body maximum
pixel difference **0/255**. The generated/live eye alignment was visually
inspected in this still composition; motion/lighting/occlusion remain unverified.

## Next Gate

Keep Mac + iPhone Continuity as the product target. Before adding mobile support
or OBS output, validate eye alignment, expression, neck edges, illumination,
occlusions and capture-to-display latency on physical live video. The current
model path needs a substantially faster renderer/native backend to become
realtime; a remotely hosted CUDA backend would be a separate, consented test,
not something an account or GPU rental automatically enables.
