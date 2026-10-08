import io
import json
import struct
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch
from worker import read_packet, write_packet, PIXELS, NeuralHead


class ProtocolTests(unittest.TestCase):
    def test_requested_profile_used_without_stale_warp_reuse(self):
        apply_profile = Mock()
        renderer = Mock()
        metal = Mock()
        modules = {"cv2": SimpleNamespace(imread=Mock(return_value=None)),
                   "numpy": Mock(), "mlx": SimpleNamespace(core=metal), "mlx.core": metal,
                   "src.utils.mlx_profiles": SimpleNamespace(apply_mlx_profile=apply_profile)}
        for module, name, constructor in (
            ("mlx_motion_extractor_model", "MlxMotionExtractorModel", Mock()),
            ("mlx_appearance_feature_extractor_model", "MlxAppearanceFeatureExtractorModel", Mock()),
            ("mlx_warping_spade_model", "MlxWarpingSpadeModel", renderer),
            ("mlx_stitching_model", "MlxStitchingModel", Mock()),
        ):
            modules[f"src.models.{module}"] = SimpleNamespace(**{name: constructor})
        with patch.dict(sys.modules, modules), patch.object(sys, "path", sys.path.copy()):
            # Stop before reading a reference or allocating any model tensors.
            with self.assertRaisesRegex(ValueError, "Cannot read"):
                NeuralHead(Path("engine"), Path("weights"), Path("private.png"), profile="speed")
        apply_profile.assert_called_once_with("speed")
        self.assertEqual(renderer.call_args.kwargs["temporal_warp_interval"], 1)

    def test_invalid_internal_resolution_rejected_before_loading(self):
        with self.assertRaises(ValueError):
            NeuralHead(None, None, None, render_size=128)

    def test_profile_evaluates_lazy_result_and_records_stage(self):
        model = NeuralHead.__new__(NeuralHead)
        model.mx = Mock()
        model.stage_ms = {}
        pixels = object()
        operation = Mock(return_value=pixels)
        with patch("worker.time.perf_counter", side_effect=[10, 10.025]):
            result = model.timed("generator", operation)("input", fresh=True)
        self.assertIs(result, pixels)
        operation.assert_called_once_with("input", fresh=True)
        model.mx.eval.assert_called_once_with(pixels)
        self.assertAlmostEqual(model.stage_ms["generator"], 25)

    def test_round_trip(self):
        stream = io.BytesIO()
        payload = bytes(PIXELS)
        write_packet(stream, {"type": "frame", "id": 1}, payload)
        stream.seek(0)
        header, output = read_packet(stream)
        self.assertEqual(header["id"], 1)
        self.assertEqual(output, payload)

    def test_eof(self):
        self.assertIsNone(read_packet(io.BytesIO()))

    def test_unbounded_header_rejected(self):
        with self.assertRaises(ValueError):
            read_packet(io.BytesIO(struct.pack("<I", 2**31)))

    def test_unbounded_payload_rejected(self):
        raw = json.dumps({"bytes": 2**31}).encode()
        with self.assertRaises(ValueError):
            read_packet(io.BytesIO(struct.pack("<I", len(raw)) + raw))

    def test_truncated_payload_rejected(self):
        raw = json.dumps({"bytes": PIXELS}).encode()
        with self.assertRaises(EOFError):
            read_packet(io.BytesIO(struct.pack("<I", len(raw)) + raw))


if __name__ == "__main__":
    unittest.main()
