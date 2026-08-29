"""Regresion de cobertura para corpses y sus transformaciones de decay."""

import json
import sys
import unittest
from pathlib import Path


RAIZ = Path(__file__).resolve().parent.parent
HERRAMIENTAS = RAIZ / "herramientas"
if str(HERRAMIENTAS) not in sys.path:
    sys.path.insert(0, str(HERRAMIENTAS))

import extraer_items772 as extractor  # noqa: E402


CATALOGO = RAIZ / "cliente3d" / "assets" / "items772.json"


class CorpseDecayCoverageTests(unittest.TestCase):
    def test_cadena_del_rat_conserva_ids_y_nombre(self):
        otb = extractor.leer_otb()
        nombres = extractor.leer_nombres()
        decay = extractor.leer_decay()

        self.assertEqual(2814, decay[2813])
        self.assertEqual(2815, decay[2814])
        self.assertEqual(0, decay[2815])
        self.assertEqual([3994, 3995, 3996], [otb[sid]["cid"] for sid in
            (2813, 2814, 2815)])
        self.assertEqual(
            ["dead rat", "dead rat", "dead rat"],
            [nombres[sid] for sid in (2813, 2814, 2815)])

    def test_toda_etapa_producible_tiene_nombre_resoluble(self):
        otb = extractor.leer_otb()
        catalogo = json.loads(CATALOGO.read_text(encoding="utf-8"))
        catalogo_por_cid = {int(cid): ficha for cid, ficha in catalogo.items()}
        _raices, _etapas, errores = extractor.auditar_corpses(
            otb, catalogo_por_cid)

        self.assertEqual([], errores, "\n" + "\n".join(errores))

    def test_auditoria_rechaza_etapa_sin_nombre(self):
        original_raices = extractor.leer_raices_corpse
        original_decay = extractor.leer_decay
        try:
            extractor.leer_raices_corpse = lambda: {10}
            extractor.leer_decay = lambda: {10: 11, 11: 0}
            items = {10: {"cid": 100}, 11: {"cid": 101}}
            catalogo = {100: {"nombre": "dead test"}, 101: {"nombre": ""}}

            _raices, etapas, errores = extractor.auditar_corpses(items, catalogo)
        finally:
            extractor.leer_raices_corpse = original_raices
            extractor.leer_decay = original_decay

        self.assertEqual({10, 11}, etapas)
        self.assertEqual(
            ["server id 11 / client id 101 llega sin nombre"], errores)


if __name__ == "__main__":
    unittest.main()
