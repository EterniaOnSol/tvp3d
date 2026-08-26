"""Particion espacial del IR JSON sin cambiar sus registros de tiles."""

import json
from collections import OrderedDict
from pathlib import Path


def clave_chunk(x, y, z, tamano):
    """Devuelve una clave estable para un chunk espacial y un piso."""
    return "%d_%d_%d" % (x // tamano, y // tamano, z)


def partir_ir(ir, chunk_size=32, source_ir=""):
    """Construye indice y documentos de chunks en memoria.

    El documento completo sigue siendo la fuente auditable. Cada chunk solo
    reubica referencias completas a tiles; no normaliza ni elimina campos.
    """
    if int(chunk_size) <= 0:
        raise ValueError("chunk_size must be positive")

    groups = OrderedDict()
    for tile in ir.get("tiles", []):
        position = tile.get("position", {})
        try:
            x = int(position["x"])
            y = int(position["y"])
            z = int(position["z"])
        except (KeyError, TypeError, ValueError) as error:
            raise ValueError("tile without valid position") from error

        tx = x // chunk_size
        ty = y // chunk_size
        key = clave_chunk(x, y, z, chunk_size)
        if key not in groups:
            groups[key] = {
                "key": key,
                "x": tx,
                "y": ty,
                "z": z,
                "min_x": tx * chunk_size,
                "max_x": (tx + 1) * chunk_size - 1,
                "min_y": ty * chunk_size,
                "max_y": (ty + 1) * chunk_size - 1,
                "tiles": [],
            }
        groups[key]["tiles"].append(tile)

    chunks = OrderedDict()
    total_items = 0
    for key, group in groups.items():
        tiles = group.pop("tiles")
        filename = "chunk_%s.json" % key
        total_items += sum(len(tile.get("items", [])) for tile in tiles)
        chunks[key] = {
            "version": 1,
            "chunk": group,
            "tiles": tiles,
        }
        group["tile_count"] = len(tiles)
        group["item_count"] = sum(len(tile.get("items", [])) for tile in tiles)
        group["file"] = filename

    index = {
        "version": 1,
        "source": {
            "ir": source_ir,
            "ir_version": ir.get("version"),
        },
        "region": ir.get("region", {}),
        "chunk_size": int(chunk_size),
        "chunks": OrderedDict(
            (key, {key2: value for key2, value in chunk["chunk"].items()})
            for key, chunk in chunks.items()),
        "summary": {
            "chunks": len(chunks),
            "tiles": len(ir.get("tiles", [])),
            "items": total_items,
        },
    }
    return index, chunks


def escribir_chunks(ir, output_dir, chunk_size=32, source_ir=""):
    """Escribe el indice y todos los documentos de chunks."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    index, chunks = partir_ir(ir, chunk_size, source_ir)
    for key, document in chunks.items():
        filename = index["chunks"][key]["file"]
        (output_dir / filename).write_text(
            json.dumps(document, ensure_ascii=False, indent=2),
            encoding="utf-8")
    (output_dir / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
    return index
