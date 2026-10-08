"""Actual neural inference test, using private local source/driving crops."""
import argparse
import json
import statistics
import time
from pathlib import Path

from worker import NeuralHead


def main():
    parser = argparse.ArgumentParser()
    for name in ("engine", "weights", "source", "driving", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    parser.add_argument("--profile", choices=("quality", "speed", "turbo"), default="quality")
    parser.add_argument("--profile-stages", action="store_true")
    parser.add_argument("--iterations", type=int, default=8)
    parser.add_argument("--render-size", type=int, choices=(256, 512), default=512)
    args = parser.parse_args()
    if args.iterations < 2:
        parser.error("At least two measured iterations are required")
    start = time.perf_counter()
    model = NeuralHead(args.engine, args.weights, args.source,
                       profile=args.profile, profile_stages=args.profile_stages,
                       render_size=args.render_size)
    load_seconds = time.perf_counter() - start
    cv2, np = model.cv2, model.np
    source = cv2.cvtColor(cv2.resize(cv2.imread(str(args.source)), (256, 256)), cv2.COLOR_BGR2RGB)
    driving = cv2.cvtColor(cv2.resize(cv2.imread(str(args.driving)), (256, 256)), cv2.COLOR_BGR2RGB)
    baseline = model.render(source, reset=True)
    model.render(driving)
    samples = []
    stages = {}
    for _ in range(args.iterations):
        start = time.perf_counter()
        result = model.render(driving)
        samples.append((time.perf_counter() - start) * 1000)
        for name, milliseconds in model.stage_ms.items():
            stages.setdefault(name, []).append(milliseconds)
    cv2.imwrite(str(args.output), cv2.cvtColor(result, cv2.COLOR_RGB2BGR))
    change = float(np.mean(np.abs(result.astype(np.float32) - baseline.astype(np.float32))))
    assert result.std() > 10 and change > 1, "Blank or unchanged neural output"
    print(json.dumps({"profile": args.profile, "internalRenderSize": args.render_size,
                      "freshWarpEveryFrame": True,
                      "stageSynchronization": args.profile_stages,
                      "loadSeconds": load_seconds, "medianMS": statistics.median(samples),
                      "stagesMedianMS": {name: statistics.median(values) for name, values in stages.items()},
                      "changedPixelsMAE": change, "peakGPU_MB": model.mx.get_peak_memory() / 1048576}))


if __name__ == "__main__":
    main()
