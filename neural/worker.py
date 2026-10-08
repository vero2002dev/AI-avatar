"""Local Metal inference. Camera acquisition/detection/compositing stay in Swift.

Wire format: little-endian uint32 JSON length + JSON + optional RGB payload.
Only one request is outstanding; stdout is reserved for the binary protocol.
"""
import argparse
import contextlib
import json
import struct
import sys
import time
import os
import threading
from pathlib import Path

MAX_HEADER = 4096
PIXELS = 256 * 256 * 3


def read_exact(stream, size):
    data = bytearray()
    while len(data) < size:
        chunk = stream.read(size - len(data))
        if not chunk:
            raise EOFError("Incomplete neural packet")
        data.extend(chunk)
    return bytes(data)


def read_packet(stream):
    prefix = stream.read(4)
    if not prefix:
        return None
    if len(prefix) != 4:
        prefix += read_exact(stream, 4 - len(prefix))
    length = struct.unpack("<I", prefix)[0]
    if not 0 < length <= MAX_HEADER:
        raise ValueError("Invalid neural header size")
    header = json.loads(read_exact(stream, length))
    size = header.get("bytes", 0)
    if not isinstance(size, int) or size not in (0, PIXELS):
        raise ValueError("Invalid camera crop size")
    return header, read_exact(stream, size)


def write_packet(stream, header, payload=b""):
    header = {**header, "bytes": len(payload)}
    raw = json.dumps(header, separators=(",", ":")).encode()
    stream.write(struct.pack("<I", len(raw)) + raw + payload)
    stream.flush()


class NeuralHead:
    def __init__(self, engine, weights, source):
        import cv2
        import mlx.core as mx
        import numpy as np
        sys.path.insert(0, str(engine))
        from src.utils.mlx_profiles import apply_mlx_profile
        apply_mlx_profile("quality")
        from src.models.mlx_motion_extractor_model import MlxMotionExtractorModel
        from src.models.mlx_appearance_feature_extractor_model import MlxAppearanceFeatureExtractorModel
        from src.models.mlx_warping_spade_model import MlxWarpingSpadeModel
        from src.models.mlx_stitching_model import MlxStitchingModel
        self.cv2, self.np, self.mx = cv2, np, mx
        mx.set_cache_limit(128 * 1024 * 1024)
        # Avoid the upstream face detectors/landmark weights with separate licenses.
        self.motion = MlxMotionExtractorModel(model_path=str(weights / "motion_extractor.npz"), dtype="bf16")
        appearance = MlxAppearanceFeatureExtractorModel(model_path=str(weights / "appearance_feature_extractor.npz"), dtype="bf16")
        self.renderer = MlxWarpingSpadeModel(model_path=[str(weights / "warping_module.npz"), str(weights / "spade_generator.npz")], dtype="bf16")
        self.stitch = MlxStitchingModel(model_path=str(weights / "stitching.npz"), dtype="fp32")
        image = cv2.imread(str(source))
        if image is None:
            raise ValueError("Cannot read the private identity crop")
        rgb = cv2.cvtColor(cv2.resize(image, (256, 256)), cv2.COLOR_BGR2RGB)
        self.source = self.info(rgb)
        self.feature = appearance.predict(rgb)
        del appearance
        self.rotation_source = self.rotation(self.source)
        s = self.source
        self.keypoints = s["scale"] * (s["kp"] @ self.rotation_source + s["exp"]) + s["t"]
        self.baseline = None
        self.previous_expression = None
        self.renderer.predict(self.feature, self.keypoints, self.keypoints, return_numpy=True, return_uint8=True)
        mx.clear_cache()

    def info(self, image):
        keys = ("pitch", "yaw", "roll", "t", "exp", "scale", "kp")
        return dict(zip(keys, self.motion.predict(image)))

    def rotation(self, info):
        np = self.np
        x, y, z = [float(info[k].flat[0]) * np.pi / 180 for k in ("pitch", "yaw", "roll")]
        rx = np.array([[1, 0, 0], [0, np.cos(x), -np.sin(x)], [0, np.sin(x), np.cos(x)]])
        ry = np.array([[np.cos(y), 0, np.sin(y)], [0, 1, 0], [-np.sin(y), 0, np.cos(y)]])
        rz = np.array([[np.cos(z), -np.sin(z), 0], [np.sin(z), np.cos(z), 0], [0, 0, 1]])
        return (rz @ ry @ rx).T[None].astype(np.float32)

    def render(self, rgb, reset=False):
        np = self.np
        driving = self.info(rgb)
        if self.baseline is None or reset:
            self.baseline = {k: v.copy() for k, v in driving.items()}
            self.previous_expression = None
            self.renderer.reset_temporal_cache()
        s, d0 = self.source, self.baseline
        rotation = self.rotation(driving) @ self.rotation(d0).transpose(0, 2, 1) @ self.rotation_source
        expression = s["exp"] + driving["exp"] - d0["exp"]
        if self.previous_expression is not None:
            expression = 0.8 * expression + 0.2 * self.previous_expression
        self.previous_expression = expression.copy()
        # Translation and scale come from the native ROI, not from source-body pixels.
        translation = s["t"].copy()
        translation[..., 2] = 0
        points = s["scale"] * (s["kp"] @ rotation + expression) + translation
        correction = self.stitch.predict(np.concatenate([self.keypoints.reshape(1, -1), points.reshape(1, -1)], axis=1))
        points += correction[:, :63].reshape(1, 21, 3) + np.pad(correction[:, 63:65], ((0, 0), (0, 1)))[:, None]
        result = self.renderer.predict(self.feature, self.keypoints, points, return_numpy=True, return_uint8=True)
        return np.ascontiguousarray(result)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", type=Path, required=True)
    parser.add_argument("--weights", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    parent = os.getppid()
    def watch_parent():
        while os.getppid() == parent:
            time.sleep(1)
        os._exit(0)
    threading.Thread(target=watch_parent, daemon=True).start()
    output = sys.stdout.buffer
    try:
        with contextlib.redirect_stdout(sys.stderr):
            model = NeuralHead(args.engine, args.weights, args.source)
        write_packet(output, {"type": "ready"})
        while (packet := read_packet(sys.stdin.buffer)) is not None:
            header, payload = packet
            if header.get("type") != "frame" or len(payload) != PIXELS:
                raise ValueError("Expected one 256x256 RGB camera frame")
            start = time.perf_counter()
            with contextlib.redirect_stdout(sys.stderr):
                result = model.render(model.np.frombuffer(payload, dtype=model.np.uint8).reshape(256, 256, 3), header.get("reset", False))
            write_packet(output, {"type": "frame", "id": header["id"], "width": 512, "height": 512,
                                  "milliseconds": (time.perf_counter() - start) * 1000,
                                  "memoryMB": model.mx.get_active_memory() / 1048576,
                                  "peakMemoryMB": model.mx.get_peak_memory() / 1048576}, result.tobytes())
    except Exception as exc:
        write_packet(output, {"type": "error", "message": str(exc)})
        raise


if __name__ == "__main__":
    main()
