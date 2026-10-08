import io
import json
import struct
import unittest
from worker import read_packet, write_packet, PIXELS


class ProtocolTests(unittest.TestCase):
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
