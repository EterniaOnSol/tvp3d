import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from comparar_walkability import comparar, server_queryadd_reference


def _item(server_id, block_pathfind=False):
    return {
        "server_id": server_id,
        "flags": {"block_pathfind": block_pathfind},
    }


def _tile(items, ground=True, house_id=0, walkable=True,
          queryadd_walkable=None):
    tile = {
        "house_id": house_id,
        "ground": {} if ground else None,
        "items": items,
        "walkable": walkable,
    }
    if queryadd_walkable is not None:
        tile["queryadd_walkable"] = queryadd_walkable
    return tile


class StaticQueryAddReferenceTest(unittest.TestCase):
    def setUp(self):
        self.catalog = {
            100: {"block_pathfind": False},
            200: {"block_pathfind": True},
            300: {"block_pathfind": False},
        }
        self.xml = {
            100: {"floor_changes": [], "teleport": False},
            200: {"floor_changes": [], "teleport": False},
            300: {"floor_changes": ["down"], "teleport": False},
        }

    def test_plain_ground_is_walkable(self):
        result = server_queryadd_reference(
            _tile([_item(100)]), self.catalog, self.xml)
        self.assertTrue(result["complete"])
        self.assertTrue(result["walkable"])
        self.assertEqual(result["reasons"], [])

    def test_block_pathfind_rejects_player_pathfinding(self):
        result = server_queryadd_reference(
            _tile([_item(200)]), self.catalog, self.xml)
        self.assertFalse(result["walkable"])
        self.assertEqual(result["reasons"], ["block_pathfind:200"])

    def test_floorchange_ground_is_not_walkable_for_pathfinding(self):
        result = server_queryadd_reference(
            _tile([_item(300)]), self.catalog, self.xml)
        self.assertFalse(result["walkable"])
        self.assertEqual(result["reasons"], ["floorchange:300"])

    def test_house_result_is_dynamic_and_excluded(self):
        result = server_queryadd_reference(
            _tile([_item(100)], house_id=77), self.catalog, self.xml)
        self.assertIsNone(result["walkable"])
        self.assertFalse(result["complete"])
        self.assertEqual(result["excluded"], "house_access_dynamic")

    def test_missing_ground_rejects(self):
        result = server_queryadd_reference(
            _tile([_item(100)], ground=False), self.catalog, self.xml)
        self.assertFalse(result["walkable"])
        self.assertEqual(result["reasons"], ["no_ground"])

    def test_compare_reports_direction_of_mismatch(self):
        ir = {"tiles": [
            _tile([_item(100)], walkable=False),
            _tile([_item(200)], walkable=True),
        ]}
        summary, mismatches, unmodeled = comparar(ir, self.catalog, self.xml)
        self.assertEqual(summary["matches"], 0)
        self.assertEqual(summary["mismatches"], 2)
        self.assertEqual(summary["ir_conservative"], 1)
        self.assertEqual(summary["ir_permissive"], 1)
        self.assertEqual(len(unmodeled), 0)
        self.assertEqual({row["direction"] for row in mismatches}, {
            "ir_conservative", "ir_permissive"})

    def test_compare_validates_queryadd_field(self):
        ir = {"tiles": [
            _tile([_item(100)], queryadd_walkable=True),
            _tile([_item(200)], walkable=False, queryadd_walkable=False),
        ]}
        summary, mismatches, unmodeled = comparar(ir, self.catalog, self.xml)
        self.assertEqual(summary["queryadd_field_matches"], 2)
        self.assertEqual(summary["queryadd_field_mismatches"], 0)
        self.assertEqual(summary["queryadd_field_missing"], 0)
        self.assertEqual(len(mismatches), 0)
        self.assertEqual(len(unmodeled), 0)


if __name__ == "__main__":
    unittest.main()
