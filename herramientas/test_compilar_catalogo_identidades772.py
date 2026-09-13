import unittest
from pathlib import Path

from compilar_catalogo_identidades772 import (
    ASSETS_CONTRACT,
    MAX_POR_CASILLA,
    audit_map_items,
    build_alias_index,
    canonical_id,
    canonical_json_bytes,
    derive_render_flags,
    sha256_bytes,
)
from extraer_items772 import leer_otb
from leer_dat_spr import cargar_dat
from leer_otbm import recorrer


class CatalogStage1Tests(unittest.TestCase):
    def test_canonical_id_is_not_numeric_alias(self):
        value = canonical_id("tvp3d", "item", "Gold Coin")
        self.assertEqual(value, "tvp3d:item:gold_coin")
        self.assertNotIn("server", value)

    def test_canonical_serialization_has_stable_lf(self):
        self.assertEqual(canonical_json_bytes({"b": 2, "a": 1})[-1:], b"\n")
        self.assertEqual(sha256_bytes(b"abc"), (
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))

    def test_parser_reuse_and_contract_version(self):
        self.assertEqual(ASSETS_CONTRACT, "2.0.0")
        self.assertTrue(callable(leer_otb))
        self.assertTrue(callable(cargar_dat))
        self.assertTrue(callable(recorrer))

    def test_alias_conflict_is_ambiguous(self):
        def mapping(canonical):
            return {
                "canonical_id": canonical,
                "aliases": [{
                    "system": "OTB", "source_version": "7.72",
                    "kind": "CLIENT_ID", "value": "425"}]}
        entries, statuses = build_alias_index([
            mapping("tvp3d:item:first"), mapping("tvp3d:item:second")])
        self.assertEqual(statuses[("OTB", "7.72", "CLIENT_ID", "425")],
                         "AMBIGUOUS")
        resolution = next(iter(entries.values()))
        self.assertIsNone(resolution["canonical_id"])
        self.assertEqual(len(resolution["candidates"]), 2)

    def test_many_to_one_does_not_make_fake_inverse(self):
        report = audit_map_items([(1, 2, 3, [100, 101, 100])],
                                 {100: 200, 101: 200})
        self.assertEqual(report["unresolved_source_ids"], [])
        self.assertEqual(report["source_id_counts"]["100"], 2)
        self.assertEqual(report["source_id_counts"]["101"], 1)

    def test_unresolved_and_tile_truncation_are_reported(self):
        ids = list(range(MAX_POR_CASILLA + 1))
        report = audit_map_items([(4, 5, 6, ids + [999])], {})
        self.assertEqual(
            [item["source_id"] for item in report["unresolved_source_ids"]],
            ids + [999])
        self.assertEqual(len(report["truncated_tiles"]), 1)
        self.assertEqual(report["truncated_tiles"][0]["emitted_limit"],
                         MAX_POR_CASILLA)

    def test_flags_projection_uses_otb_semantics(self):
        item = {
            "grupo": 1, "liquido": False, "bloquea": True, "frena_vista": False,
            "apilable": False, "levantable": True, "movible": False,
            "orden_arriba": 1, "velocidad_suelo": 110, "color_mapa": 7}
        flags = derive_render_flags(item)
        self.assertEqual(flags["suelo"], True)
        self.assertEqual(flags["clavado"], True)
        self.assertEqual(flags["borde_suelo"], True)
        self.assertEqual(flags["velocidad_suelo"], 110)


if __name__ == "__main__":
    unittest.main()
