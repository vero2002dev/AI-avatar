"""Actual neural inference test, using private local source/driving crops."""
import argparse
import json
import statistics
import time
import sys
from pathlib import Path

from worker import NeuralHead


def main():
    parser = argparse.ArgumentParser()
    for name in ("engine", "weights", "source", "driving", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    parser.add_argument("--profile", choices=("quality", "speed", "turbo"), default="quality")
    args = parser.parse_args()
    sys.path.insert(0, str(args.engine.resolve()))
    from src.utils.mlx_profiles import apply_mlx_profile
    apply_mlx_profile(args.profile)
    start = time.perf_counter()
    model = NeuralHead(args.engine, args.weights, args.source)
    load_seconds = time.perf_counter() - start
    cv2, np = model.cv2, model.np
    source = cv2.cvtColor(cv2.resize(cv2.imread(str(args.source)), (256, 256)), cv2.COLOR_BGR2RGB)
    driving = cv2.cvtColor(cv2.resize(cv2.imread(str(args.driving)), (256, 256)), cv2.COLOR_BGR2RGB)
    baseline = model.render(source, reset=True)
    samples = []
    for _ in range(8):
        start = time.perf_counter()
        result = model.render(driving)
        samples.append((time.perf_counter() - start) * 1000)
    cv2.imwrite(str(args.output), cv2.cvtColor(result, cv2.COLOR_RGB2BGR))
    change = float(np.mean(np.abs(result.astype(np.float32) - baseline.astype(np.float32))))
    assert result.std() > 10 and change > 1, "Blank or unchanged neural output"
    print(json.dumps({"loadSeconds": load_seconds, "medianMS": statistics.median(samples),
                      "changedPixelsMAE": change, "peakGPU_MB": model.mx.get_peak_memory() / 1048576}))


if __name__ == "__main__":
    main()
