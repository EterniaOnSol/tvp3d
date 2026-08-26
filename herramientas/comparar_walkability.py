"""Compara la walkability del IR con la regla estatica de Tile::queryAdd.

La comparacion modela el caso de un jugador que intenta pathfinding sobre un
tile estatico. No crea criaturas ni un jugador real: casas y estado vivo se
reportan como excluidos porque dependen de la autoridad del servidor.

Ejemplo:
    python herramientas/comparar_walkability.py
"""

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extraer_items772 import leer_otb
from walkability import leer_comportamiento_xml, server_queryadd_reference


ROOT = Path(__file__).resolve().parent.parent
ITEMS_XML = ROOT / "servidor" / "data" / "items" / "items.xml"
DEFAULT_IR = ROOT / "cliente3d" / "generated" / "maps" / "rookgaard_100sqm.json"
DEFAULT_OUTPUT = ROOT / "cliente3d" / "generated" / "reports" / "walkability_parity.json"


def comparar(ir, catalog, xml_behavior):
    summary = {
        "tiles_total": len(ir.get("tiles", [])),
        "compared_tiles": 0,
        "excluded_house_tiles": 0,
        "unmodeled_tiles": 0,
        "matches": 0,
        "mismatches": 0,
        "ir_conservative": 0,
        "ir_permissive": 0,
        "ir_walkable": 0,
        "server_walkable": 0,
        "queryadd_field_matches": 0,
        "queryadd_field_mismatches": 0,
        "queryadd_field_missing": 0,
    }
    mismatches = []
    unmodeled = []

    for tile in ir.get("tiles", []):
        position = tile.get("position", {})
        reference = server_queryadd_reference(tile, catalog, xml_behavior)
        if reference["excluded"]:
            summary["excluded_house_tiles"] += 1
            continue
        if not reference["complete"]:
            summary["unmodeled_tiles"] += 1
            unmodeled.append({
                "position": position,
                "reasons": reference["reasons"],
            })
            continue

        summary["compared_tiles"] += 1
        ir_walkable = bool(tile.get("walkable", False))
        server_walkable = bool(reference["walkable"])
        summary["ir_walkable"] += int(ir_walkable)
        summary["server_walkable"] += int(server_walkable)
        queryadd_value = tile.get("queryadd_walkable")
        if queryadd_value is None:
            summary["queryadd_field_missing"] += 1
        elif bool(queryadd_value) == server_walkable:
            summary["queryadd_field_matches"] += 1
        else:
            summary["queryadd_field_mismatches"] += 1
        if ir_walkable == server_walkable:
            summary["matches"] += 1
            continue

        summary["mismatches"] += 1
        direction = ("ir_conservative"
                     if not ir_walkable and server_walkable
                     else "ir_permissive")
        summary[direction] += 1
        mismatches.append({
            "position": position,
            "ir_walkable": ir_walkable,
            "server_walkable": server_walkable,
            "direction": direction,
            "reasons": reference["reasons"],
            "items": [int(item.get("server_id", 0))
                      for item in tile.get("items", [])],
        })

    compared = summary["compared_tiles"]
    summary["match_ratio"] = (
        summary["matches"] / compared if compared else None)
    return summary, mismatches, unmodeled


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ir", type=Path, default=DEFAULT_IR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args(argv)

    ir = json.loads(args.ir.read_text(encoding="utf-8"))
    catalog = leer_otb()
    xml_behavior = leer_comportamiento_xml(ITEMS_XML)
    summary, mismatches, unmodeled = comparar(ir, catalog, xml_behavior)
    report = {
        "version": 1,
        "oracle": {
            "name": "Tile::queryAdd",
            "mode": "player_pathfinding_static",
            "flags": ["FLAG_PATHFINDING", "FLAG_IGNOREFIELDDAMAGE"],
            "source": ["servidor/src/tile.cpp", "servidor/src/map.cpp"],
        },
        "input": {
            "ir": str(args.ir.relative_to(ROOT)),
            "ir_version": ir.get("version"),
            "region": ir.get("region", {}),
        },
        "summary": summary,
        "mismatches": mismatches,
        "unmodeled": unmodeled,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    print("-> %s" % args.output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
