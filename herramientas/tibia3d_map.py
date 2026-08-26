"""Inspector y exportador del mapa real de TVP3D.

Usa el mismo lector OTBM y la misma tabla items.otb que el extractor actual.
No genera un mapa manual: cada tile de la salida viene de map.otbm.

Ejemplos:
    py -3 herramientas/tibia3d_map.py inspect --x 32097 --y 32219 --z 7
    py -3 herramientas/tibia3d_map.py export-region --center 32097,32219 --size 100
"""

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extraer_items772 import leer_nombres, leer_otb
from ir_chunks import escribir_chunks
from leer_otbm import recorrer
from walkability import leer_comportamiento_xml, server_queryadd_reference


ROOT = Path(__file__).resolve().parent.parent
OTBM = ROOT / "servidor" / "data" / "world" / "map.otbm"
ITEMS_XML = ROOT / "servidor" / "data" / "items" / "items.xml"
OUTPUT = ROOT / "cliente3d" / "generated"
SPRITE_INDEX = ROOT / "cliente3d" / "assets" / "sprites772" / "indice.json"

TILE_FLAGS = {
    1 << 0: "PROTECTION_ZONE",
    1 << 2: "NO_PVP_ZONE",
    1 << 3: "NO_LOGOUT",
    1 << 4: "PVP_ZONE",
    1 << 5: "REFRESH",
}


def _parse_position(text):
    try:
        x, y, z = (int(part.strip()) for part in text.split(","))
        return x, y, z
    except (TypeError, ValueError):
        raise argparse.ArgumentTypeError("position must be X,Y,Z")


def _parse_center(text):
    try:
        x, y = (int(part.strip()) for part in text.split(","))
        return x, y
    except (TypeError, ValueError):
        raise argparse.ArgumentTypeError("center must be X,Y")


def _flags(value):
    return [name for bit, name in TILE_FLAGS.items() if value & bit]


def _load_sources():
    if not OTBM.exists():
        raise FileNotFoundError("Missing map: %s" % OTBM)
    items = leer_otb()
    names = leer_nombres()
    xml_behavior = leer_comportamiento_xml(ITEMS_XML)
    sprite_items = set()
    if SPRITE_INDEX.exists():
        sprite_data = json.loads(SPRITE_INDEX.read_text(encoding="utf-8"))
        sprite_items = set(sprite_data.get("items", {}).keys())
    return items, names, sprite_items, xml_behavior


def _category(item, display_name=""):
    if item is None:
        return "UNKNOWN"
    name = str(display_name or item.get("nombre", "")).lower()
    # Some old maps mark stairs as a ground item. The connector semantics
    # are more useful to the 3D converter than the generic ground flag.
    if any(word in name for word in ("ladder", "stairs", "stair", "ramp")):
        return "STAIRS"
    if item.get("suelo"):
        if any(word in name for word in ("water", "river", "sea", "ice")):
            return "WATER"
        return "GROUND"
    if "door" in name:
        return "DOOR"
    if any(word in name for word in ("tree", "bush", "grass", "flower", "mushroom")):
        return "VEGETATION"
    if any(word in name for word in ("wall", "fence", "brick", "stone wall", "bars")):
        return "WALL"
    if item.get("contenedor"):
        return "CONTAINER"
    if item.get("tiene_alto"):
        return "FURNITURE"
    if item.get("bloquea"):
        return "DECORATION"
    return "DECORATION"


def _item_record(raw_item, items, names, sprite_items):
    server_id = raw_item["server_id"]
    item = items.get(server_id)
    client_id = item.get("cid") if item else None
    known_sprite = client_id is not None and str(client_id) in sprite_items
    display_name = names.get(server_id, "")
    return {
        "server_id": server_id,
        "client_id": client_id,
        "name": names.get(server_id, ""),
        "category": _category(item, display_name),
        "count": raw_item["count"],
        "subtype": raw_item["subtype"],
        "attributes": raw_item["attributes"],
        "attributes_present": raw_item["attributes_present"],
        "mapped": bool(known_sprite),
        "flags": {
            "ground": bool(item and item.get("suelo")),
            "blocking": bool(item and item.get("bloquea")),
            "block_pathfind": bool(item and item.get("block_pathfind")),
            "block_projectile": bool(item and item.get("frena_vista")),
            "stackable": bool(item and item.get("apilable")),
            "liquid": bool(item and item.get("liquido")),
            "movable": bool(item and item.get("movible")),
            "pickupable": bool(item and item.get("levantable")),
            "has_height": bool(item and item.get("tiene_alto")),
        },
    }


def load_region(bounds):
    """Read only tiles inside bounds, while still scanning the real OTBM."""
    min_x, max_x, min_y, max_y, min_z, max_z = bounds
    items, names, sprite_items, xml_behavior = _load_sources()
    tiles = {}

    def on_tile(x, y, z, raw_items, flags, house_id):
        if not (min_x <= x <= max_x and min_y <= y <= max_y and min_z <= z <= max_z):
            return
        tile_items = [_item_record(raw_item, items, names, sprite_items)
                      for raw_item in raw_items]
        ground = next(
            (item for item in tile_items if item["flags"]["ground"]), None)
        blocking_items = [item for item in tile_items if item is not ground]
        static_tile = {
            "house_id": house_id,
            "ground": ground,
            "items": tile_items,
        }
        queryadd = server_queryadd_reference(
            static_tile, items, xml_behavior)
        tiles[(x, y, z)] = {
            "position": {"x": x, "y": y, "z": z},
            "house_id": house_id,
            "tile_flags": _flags(flags),
            "tile_flags_value": flags,
            "ground": ground,
            "items": tile_items,
            "walkable": not any(item["flags"]["blocking"]
                                 for item in blocking_items),
            "queryadd_walkable": queryadd["walkable"],
            "blocking": any(item["flags"]["blocking"]
                             for item in blocking_items),
            "source": {"file": "servidor/data/world/map.otbm"},
        }

    raw = OTBM.read_bytes()
    header = recorrer(raw, None, por_casilla_detalle=on_tile)
    return tiles, header


def _region_from_args(args):
    if args.min_x is not None:
        return (args.min_x, args.max_x, args.min_y, args.max_y, args.min_z, args.max_z)
    cx, cy = args.center
    half = args.size // 2
    return (cx - half, cx + half - 1, cy - half, cy + half - 1,
            args.min_z, args.max_z)


def _print_tile(tile):
    if tile is None:
        print("Tile: no existe en el OTBM")
        return
    pos = tile["position"]
    print("Position:")
    print("  X: %d\n  Y: %d\n  Z: %d" % (pos["x"], pos["y"], pos["z"]))
    ground = tile.get("ground")
    if ground:
        print("Ground: server=%s client=%s name=%s" % (
            ground["server_id"], ground["client_id"], ground["name"]))
    else:
        print("Ground: none")
    print("Items:")
    for item in tile["items"]:
        print("  - server=%s client=%s category=%s mapped=%s name=%s" % (
            item["server_id"], item["client_id"], item["category"],
            item["mapped"], item["name"]))
    print("Flags: %s" % (", ".join(tile["tile_flags"]) or "none"))
    print("House: %s" % tile["house_id"])
    print("Walkable (derived): %s" % tile["walkable"])
    print("Blocking (derived): %s" % tile["blocking"])


def inspect(args):
    tiles, header = load_region((args.x, args.x, args.y, args.y, args.z, args.z))
    tile = tiles.get((args.x, args.y, args.z))
    if args.json:
        print(json.dumps({"header": header, "tile": tile}, indent=2, sort_keys=True))
    else:
        print("Map: %dx%d, areas=%d" % (header["ancho"], header["alto"], header["areas"]))
        _print_tile(tile)
    return 0 if tile else 2


def export_region(args):
    bounds = _region_from_args(args)
    tiles, header = load_region(bounds)
    min_x, max_x, min_y, max_y, min_z, max_z = bounds
    sorted_tiles = [tiles[key] for key in sorted(tiles)]

    frequency = Counter()
    samples = {}
    for tile in sorted_tiles:
        pos = tile["position"]
        for item in tile["items"]:
            sid = str(item["server_id"])
            frequency[sid] += 1
            samples.setdefault(sid, []).append(pos)

    frequency_rows = []
    unmapped_rows = []
    for sid, count in frequency.most_common():
        item = next(item for tile in sorted_tiles for item in tile["items"]
                    if str(item["server_id"]) == sid)
        row = {
            "server_id": int(sid),
            "client_id": item["client_id"],
            "name": item["name"],
            "category": item["category"],
            "occurrence_count": count,
            "sample_coordinates": samples[sid][:8],
            "mapped": item["mapped"],
        }
        frequency_rows.append(row)
        if not item["mapped"]:
            unmapped_rows.append(row)

    OUTPUT_MAPS = OUTPUT / "maps"
    OUTPUT_REPORTS = OUTPUT / "reports"
    OUTPUT_MAPS.mkdir(parents=True, exist_ok=True)
    OUTPUT_REPORTS.mkdir(parents=True, exist_ok=True)
    region_name = args.name
    region_path = OUTPUT_MAPS / (region_name + ".json")
    ir_document = {
        "version": 2,
        "source": {"otbm": "servidor/data/world/map.otbm", "header": header},
        "region": {"min_x": min_x, "max_x": max_x, "min_y": min_y,
                    "max_y": max_y, "min_z": min_z, "max_z": max_z},
        "tiles": sorted_tiles,
    }
    region_path.write_text(json.dumps(ir_document, indent=2), encoding="utf-8")
    chunks_dir = OUTPUT_MAPS / (region_name + "_chunks")
    chunk_index = escribir_chunks(
        ir_document,
        chunks_dir,
        chunk_size=args.chunk_size,
        source_ir=str(region_path.relative_to(ROOT)).replace("\\", "/"),
    )

    (OUTPUT_REPORTS / "item_frequency.json").write_text(
        json.dumps(frequency_rows, indent=2), encoding="utf-8")
    (OUTPUT_REPORTS / "unmapped_items.json").write_text(
        json.dumps(unmapped_rows, indent=2), encoding="utf-8")
    area = (max_x - min_x + 1) * (max_y - min_y + 1) * (max_z - min_z + 1)
    report = {
        "region": bounds,
        "sqm_volume": area,
        "tiles_found": len(sorted_tiles),
        "empty_tiles": area - len(sorted_tiles),
        "items_found": sum(len(tile["items"]) for tile in sorted_tiles),
        "unique_items": len(frequency),
        "mapped_item_occurrences": sum(row["occurrence_count"] for row in frequency_rows if row["mapped"]),
        "unmapped_item_occurrences": sum(row["occurrence_count"] for row in unmapped_rows),
        "unmapped_unique_items": len(unmapped_rows),
        "output": str(region_path.relative_to(ROOT)),
        "chunks": {
            "directory": str(chunks_dir.relative_to(ROOT)),
            "index": str((chunks_dir / "index.json").relative_to(ROOT)),
            "chunk_size": args.chunk_size,
            "chunk_count": chunk_index["summary"]["chunks"],
        },
    }
    (OUTPUT_REPORTS / "conversion_report.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    inspect_parser = sub.add_parser("inspect", help="inspect one real Tibia tile")
    inspect_parser.add_argument("--x", type=int, required=True)
    inspect_parser.add_argument("--y", type=int, required=True)
    inspect_parser.add_argument("--z", type=int, required=True)
    inspect_parser.add_argument("--json", action="store_true")
    inspect_parser.set_defaults(func=inspect)

    export_parser = sub.add_parser("export-region", help="export a real OTBM region")
    export_parser.add_argument("--center", type=_parse_center, default=(32097, 32219))
    export_parser.add_argument("--size", type=int, default=100)
    export_parser.add_argument("--min-x", type=int)
    export_parser.add_argument("--max-x", type=int)
    export_parser.add_argument("--min-y", type=int)
    export_parser.add_argument("--max-y", type=int)
    export_parser.add_argument("--min-z", type=int, default=6)
    export_parser.add_argument("--max-z", type=int, default=8)
    export_parser.add_argument("--name", default="rookgaard_100sqm")
    export_parser.add_argument("--chunk-size", type=int, default=32)
    export_parser.set_defaults(func=export_region)

    args = parser.parse_args(argv)
    if args.command == "export-region" and args.min_x is not None and any(
            value is None for value in (args.max_x, args.min_y, args.max_y)):
        parser.error("explicit regions require min/max x and y")
    try:
        return args.func(args)
    except (FileNotFoundError, ValueError, json.JSONDecodeError) as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
