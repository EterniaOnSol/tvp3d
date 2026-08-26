import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ir_chunks import clave_chunk, escribir_chunks, partir_ir


class IrChunksTest(unittest.TestCase):
    def setUp(self):
        self.ir = {
            "version": 2,
            "region": {"min_x": 32000, "max_x": 32064},
            "tiles": [
                {"position": {"x": 32000, "y": 32192, "z": 7},
                 "items": [{"server_id": 100}]},
                {"position": {"x": 32032, "y": 32192, "z": 7},
                 "items": [{"server_id": 101}, {"server_id": 102}]},
                {"position": {"x": 32032, "y": 32192, "z": 6},
                 "items": []},
            ],
        }

    def test_key_uses_spatial_chunk_and_floor(self):
        self.assertEqual(clave_chunk(32000, 32192, 7, 32), "1000_1006_7")
        self.assertEqual(clave_chunk(32032, 32192, 6, 32), "1001_1006_6")

    def test_partition_preserves_tiles_and_separates_floors(self):
        index, chunks = partir_ir(self.ir, 32, "full.json")
        self.assertEqual(index["summary"], {"chunks": 3, "tiles": 3,
                                             "items": 3})
        recovered = []
        for document in chunks.values():
            recovered.extend(document["tiles"])
        key = lambda tile: (tile["position"]["x"], tile["position"]["y"],
                            tile["position"]["z"])
        self.assertEqual(sorted(recovered, key=key),
                         sorted(self.ir["tiles"], key=key))
        self.assertEqual(index["source"]["ir"], "full.json")

    def test_write_index_and_files_are_readable(self):
        with tempfile.TemporaryDirectory() as temporary:
            index = escribir_chunks(self.ir, temporary, 32, "full.json")
            index_path = Path(temporary) / "index.json"
            loaded = json.loads(index_path.read_text(encoding="utf-8"))
            self.assertEqual(loaded["summary"], index["summary"])
            for metadata in loaded["chunks"].values():
                chunk = json.loads((Path(temporary) / metadata["file"])
                                   .read_text(encoding="utf-8"))
                self.assertEqual(chunk["version"], 1)
                self.assertEqual(len(chunk["tiles"]), metadata["tile_count"])


if __name__ == "__main__":
    unittest.main()
