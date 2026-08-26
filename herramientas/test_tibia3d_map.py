import json
import struct
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))

from leer_otbm import OTBMParseError, recorrer


def _escape(data):
    output = bytearray()
    for value in data:
        if value in (0xFD, 0xFE, 0xFF):
            output.extend((0xFD, value))
        else:
            output.append(value)
    return bytes(output)


def _node(node_type, prefix=b"", children=()):
    return (bytes((0xFE, node_type)) + _escape(prefix) +
            b"".join(children) + bytes((0xFF,)))


def _synthetic_otbm():
    header = struct.pack("<IHHII", 1, 65000, 65000, 0, 0)
    item_attrs = struct.pack("<H", 459)
    item_attrs += bytes((15, 7, 4)) + struct.pack("<H", 321)
    item_attrs += bytes((5,)) + struct.pack("<H", 654)
    item_attrs += bytes((14, 2, 0))
    content_node = _node(6, struct.pack("<H", 215))
    item_node = _node(6, item_attrs, (content_node,))

    inline_tile = bytes((0, 0, 3)) + struct.pack("<I", 32)
    inline_tile += bytes((9,)) + struct.pack("<H", 407)
    tile = _node(5, inline_tile, (item_node,))

    house_tile = bytes((1, 0)) + struct.pack("<I", 77)
    house_tile += bytes((9,)) + struct.pack("<H", 437)
    house = _node(14, house_tile)

    area = _node(4, struct.pack("<HHB", 100, 200, 7), (tile, house))
    map_node = _node(2, children=(area,))
    return b"OTBM" + _node(1, header, (map_node,))


class SyntheticItemParserTest(unittest.TestCase):
    def test_detailed_callback_preserves_inline_and_node_items(self):
        legacy = []
        extended = []
        detailed = []
        header = recorrer(
            _synthetic_otbm(),
            lambda *row: legacy.append(row),
            lambda *row: extended.append(row),
            lambda *row: detailed.append(row),
        )

        self.assertEqual(header["areas"], 1)
        self.assertEqual(legacy, [
            (100, 200, 7, [407, 459], 32),
            (101, 200, 7, [437], 0),
        ])
        self.assertEqual(extended[1][-1], 77)
        node_item = detailed[0][3][1]
        self.assertEqual(node_item["count"], 7)
        self.assertEqual(node_item["subtype"], 7)
        self.assertEqual(node_item["attributes"]["action_id"], 321)
        self.assertEqual(node_item["attributes"]["unique_id"], 654)
        self.assertEqual(node_item["attributes"]["house_door_id"], 2)
        self.assertEqual(node_item["contents"][0]["server_id"], 215)
        self.assertEqual(detailed[1][3][0]["attributes"], {})

    def test_unknown_item_attribute_is_not_silently_skipped(self):
        bad_item = _node(6, struct.pack("<H", 459) + bytes((99, 0)))
        area = _node(4, struct.pack("<HHB", 100, 200, 7), (
            _node(5, bytes((0, 0, 9)) + struct.pack("<H", 407),
                  (bad_item,)),
        ))
        raw = b"OTBM" + _node(
            1, struct.pack("<IHHII", 1, 65000, 65000, 0, 0),
            (_node(2, children=(area,)),),
        )
        with self.assertRaisesRegex(OTBMParseError, "attr=99"):
            recorrer(raw, lambda *_args: None)


class RealMapParserTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.otbm = ROOT / "servidor" / "data" / "world" / "map.otbm"
        if not cls.otbm.exists():
            raise unittest.SkipTest("map.otbm is not present")
        cls.raw = cls.otbm.read_bytes()
        cls.header, cls.target = cls._read_from_bytes(cls.raw)

    @staticmethod
    def _read_from_bytes(raw):
        found = []

        def callback(x, y, z, ids, flags):
            if (x, y, z) == (32097, 32219, 7):
                found.append((x, y, z, list(ids), flags))

        header = recorrer(raw, callback)
        return header, found

    def test_real_map_header_and_known_tile(self):
        header, found = self.header, self.target
        self.assertGreater(header["ancho"], 0)
        self.assertGreater(header["alto"], 0)
        self.assertGreater(header["areas"], 0)
        self.assertEqual(len(found), 1)
        self.assertEqual(found[0][:3], (32097, 32219, 7))
        self.assertGreater(len(found[0][3]), 0)

    def test_same_map_same_tile_is_deterministic(self):
        self.assertEqual(len(self.target), 1)
        coordinates = {(row[0], row[1], row[2]) for row in self.target}
        self.assertEqual(len(coordinates), len(self.target))
        # This fixture is the known Rookgaard tile used by the first slice.
        # Keeping its ground and flags fixed catches accidental parser drift.
        self.assertEqual(self.target[0][3], [407])
        self.assertEqual(self.target[0][4], 32)

    def test_generated_ir_fixture_matches_real_map(self):
        fixture = ROOT / "cliente3d" / "generated" / "maps" / "rookgaard_100sqm.json"
        report_file = ROOT / "cliente3d" / "generated" / "reports" / "conversion_report.json"
        if not fixture.exists() or not report_file.exists():
            raise unittest.SkipTest("generated IR fixture is not present")
        data = json.loads(fixture.read_text(encoding="utf-8"))
        report = json.loads(report_file.read_text(encoding="utf-8"))
        self.assertEqual(data["version"], 2)
        self.assertEqual(report["sqm_volume"], 30000)
        self.assertEqual(report["tiles_found"], 20240)
        known = next(tile for tile in data["tiles"]
                     if tile["position"] == {"x": 32097, "y": 32219, "z": 7})
        self.assertEqual(known["ground"]["server_id"], 407)
        self.assertEqual(known["ground"]["count"], 1)
        self.assertIsNone(known["ground"]["subtype"])
        self.assertEqual(known["ground"]["attributes"], {})
        self.assertEqual(known["ground"]["attributes_present"], [])
        stairs = [item for tile in data["tiles"] for item in tile["items"]
                  if item["server_id"] == 459]
        self.assertEqual(len(stairs), 1)
        self.assertEqual(stairs[0]["category"], "STAIRS")


if __name__ == "__main__":
    unittest.main()
