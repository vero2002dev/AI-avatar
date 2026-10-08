"""Install only the five human neural weights, never upload identity photos."""
import argparse
import json
from pathlib import Path
import sys

from huggingface_hub import snapshot_download

MODEL_REPO = "ivanfioravanti/FasterLivePortrait-MLX-weights"
MODEL_REVISION = "2cc2ac92c9fe65ca4fb68cb1a1556ead285e7391"
ENGINE_REVISION = "d5361f4806c14fe2051eecb1dd5a89930f46db0d"
WEIGHTS = ("appearance_feature_extractor", "motion_extractor", "warping_module", "spade_generator", "stitching")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, required=True)
    args = parser.parse_args()
    root = args.root.resolve()
    snapshot_download(repo_id=MODEL_REPO, revision=MODEL_REVISION,
                      local_dir=root / "weights",
                      allow_patterns=[f"liveportrait_mlx/{name}.npz" for name in WEIGHTS] + ["README.md"])
    config = {"python": sys.executable, "engine": str(root / "engine"),
              "weights": str(root / "weights/liveportrait_mlx"),
              "worker": str(Path(__file__).with_name("worker.py").resolve()),
              "engineRevision": ENGINE_REVISION, "modelRevision": MODEL_REVISION}
    (root.parent / "neural-runtime.json").write_text(json.dumps(config, indent=2))
    print("Neural runtime installed. Identity photos remain local and are imported in the native app.")


if __name__ == "__main__":
    main()
