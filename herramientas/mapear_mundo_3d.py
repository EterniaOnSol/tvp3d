"""Construye un mapa semántico para el renderer 3D de TVP3D.

El mapa visual no se clasifica por intuición ni por el color del minimapa.
Se cruzan tres fuentes del mismo servidor:

* ``map.otbm``: coordenadas, pisos, house_id y atributos de cada objeto;
* ``items.otb/items.xml``: ids servidor -> cliente, grupo, flags y nombre;
* ``items772.json``: metadatos ya usados por el cliente 7.72.

Salida:
    cliente3d/generated/world_mapper/report.json
    cliente3d/generated/world_mapper/houses.json
    cliente3d/generated/world_mapper/house_tiles.jsonl
    cliente3d/generated/world_mapper/world_objects.jsonl

La salida JSONL conserva la geometria tile por tile para que el siguiente
paso pueda reemplazar cada categoria por una escena/modelo 3D real.
"""

from __future__ import annotations

import json
import re
import sys
from collections import Counter
from pathlib import Path
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parent))

from extraer_items772 import leer_nombres, leer_otb
from leer_otbm import recorrer


ROOT = Path(__file__).resolve().parent.parent
OTBM = ROOT / "servidor" / "data" / "world" / "map.otbm"
HOUSE_XML = ROOT / "servidor" / "data" / "world" / "map-house.xml"
ITEMS_JSON = ROOT / "cliente3d" / "assets" / "items772.json"
OUT = ROOT / "cliente3d" / "generated" / "world_mapper"

# El primer inventario no debe convertir cada arbusto decorativo en cientos
# de megabytes de JSON. Estas son las categorias que necesitan una escena o
# un modelo 3D propio en la siguiente etapa. Los conteos globales siguen
# incluyendo decoration/nature para no perder informacion estadistica.
CATEGORIAS_MODELABLES = {
    "wall", "door", "stair", "mailbox", "sign", "window", "roof",
    "crate", "furniture", "container", "interactive",
}


def nombre_normalizado(nombre: str) -> str:
    return re.sub(r"\s+", " ", nombre.lower().strip())


def clasificar(nombre: str, grupo: int, flags: dict, attrs: dict) -> str:
    """Clasificacion visual estable, de lo mas especifico a lo generico."""
    n = nombre_normalizado(nombre)
    es_puerta = bool(attrs.get("house_door_id") is not None)
    es_puerta = es_puerta or bool(re.search(r"(^| )door( |$)", n))
    es_puerta = es_puerta or n.endswith("trapdoor")
    es_puerta = es_puerta or any(palabra in n for palabra in ("gate",))
    if es_puerta:
        return "door"
    if any(palabra in n for palabra in ("stair", "stairs", "ladder", "ramp")):
        return "stair"
    if any(palabra in n for palabra in ("mailbox", "mail box", "letter box")):
        return "mailbox"
    if any(palabra in n for palabra in ("sign", "notice board", "signpost")):
        return "sign"
    if any(palabra in n for palabra in ("window", "shutter", "glass wall")):
        return "window"
    if any(palabra in n for palabra in ("roof", "awning", "roof tile")):
        return "roof"
    # A wall-mounted lamp is decoration, despite containing the word wall.
    if any(palabra in n for palabra in ("lamp", "torch", "lantern")):
        return "decoration"
    # Railings and pillars are structural 3D pieces, not vegetation.
    if any(palabra in n for palabra in ("railing", "pillar", "fence", "bars")):
        return "structure"
    # The item group/ground flag is more authoritative than a material word.
    # Without this rule "stone tile" was incorrectly classified as nature.
    if grupo == 1 or flags.get("suelo"):
        return "ground"
    if any(palabra in n for palabra in ("wall", "brickwork", "stonework")):
        return "wall"
    if any(palabra in n for palabra in ("crate", "barrel", "box", "chest")):
        return "crate"
    if any(palabra in n for palabra in (
        "bed", "table", "chair", "bench", "counter", "bookcase",
        "bookshelf", "cabinet", "dresser", "oven", "fireplace",
        "carpet", "cooking", "furnace", "well", "cask",
    )):
        return "furniture"
    if any(palabra in n for palabra in (
        "tree", "bush", "flower", "grass", "mushroom", "cactus",
        "plant", "bamboo", "palm", "weed", "rock",
    )):
        return "nature"
    if flags.get("bloquea") and flags.get("frena_vista"):
        return "structure"
    if flags.get("contenedor"):
        return "container"
    if flags.get("levantable") or flags.get("movible"):
        return "interactive"
    return "decoration"


def item_info(server_id: int, by_server: dict, by_client: dict,
              names: dict) -> dict:
    server = by_server.get(server_id, {})
    client_id = int(server.get("cid", 0))
    client = by_client.get(str(client_id), {})
    nombre = names.get(server_id) or client.get("nombre", "") or "unknown"
    flags = dict(client)
    flags.update({
        "grupo": server.get("grupo", client.get("grupo", 0)),
        "suelo": bool(client.get("suelo", server.get("suelo", False))),
        "contenedor": bool(client.get(
            "contenedor", server.get("contenedor", False))),
        "bloquea": bool(client.get("bloquea", server.get("bloquea", False))),
        "frena_vista": bool(client.get(
            "frena_vista", server.get("frena_vista", False))),
        "levantable": bool(client.get(
            "levantable", server.get("levantable", False))),
        "movible": bool(client.get("movible", server.get("movible", False))),
    })
    return {
        "server_id": server_id,
        "client_id": client_id,
        "name": nombre,
        "category": clasificar(
            nombre, int(flags.get("grupo", 0)), flags, {}),
        "flags": {
            key: flags.get(key, False)
            for key in ("suelo", "contenedor", "bloquea", "frena_vista",
                        "levantable", "movible", "tiene_alto",
                        "siempre_arriba")
        },
    }


def actualizar_casa(casas: dict, house_id: int, x: int, y: int, z: int,
                    categorias: list[str], objetos: list[dict]) -> None:
    casa = casas.setdefault(str(house_id), {
        "house_id": house_id,
        "tile_count": 0,
        "min": {"x": x, "y": y, "z": z},
        "max": {"x": x, "y": y, "z": z},
        "floors": Counter(),
        "categories": Counter(),
        "objects": Counter(),
        "doors": [],
    })
    casa["tile_count"] += 1
    casa["floors"][str(z)] += 1
    for eje, valor in (("x", x), ("y", y), ("z", z)):
        casa["min"][eje] = min(casa["min"][eje], valor)
        casa["max"][eje] = max(casa["max"][eje], valor)
    for categoria in categorias:
        casa["categories"][categoria] += 1
    for objeto in objetos:
        casa["objects"][objeto["category"]] += 1
        if objeto["category"] == "door":
            casa["doors"].append({
                "x": x, "y": y, "z": z,
                "client_id": objeto["client_id"],
                "name": objeto["name"],
                "house_door_id": objeto.get("attributes", {}).get(
                    "house_door_id"),
            })


def serializar_contadores(valor):
    if isinstance(valor, Counter):
        return dict(sorted(valor.items()))
    if isinstance(valor, dict):
        return {str(k): serializar_contadores(v) for k, v in valor.items()}
    if isinstance(valor, list):
        return [serializar_contadores(v) for v in valor]
    return valor


def leer_definiciones_casas() -> dict:
	"""Lee el catalogo oficial de casas, independiente de su geometria."""
	if not HOUSE_XML.exists():
		return {}
	raiz = ET.parse(HOUSE_XML).getroot()
	definiciones = {}
	for nodo in raiz.findall("house"):
		house_id = int(nodo.get("houseid", "0"))
		if house_id <= 0:
			continue
		definiciones[str(house_id)] = {
			"name": nodo.get("name", ""),
			"entry": {
				"x": int(nodo.get("entryx", "0")),
				"y": int(nodo.get("entryy", "0")),
				"z": int(nodo.get("entryz", "0")),
			},
			"rent": int(nodo.get("rent", "0")),
			"town_id": int(nodo.get("townid", "0")),
			"declared_size": int(nodo.get("size", "0")),
		}
	return definiciones


def main() -> None:
    if not OTBM.exists():
        raise SystemExit(f"No existe el mapa: {OTBM}")
    catalogo_servidor = leer_otb()
    nombres = leer_nombres()
    por_cliente = json.loads(ITEMS_JSON.read_text(encoding="utf-8"))
    definiciones_casas = leer_definiciones_casas()

    OUT.mkdir(parents=True, exist_ok=True)
    casas = {}
    categorias = Counter()
    pisos = Counter()
    conteo_tiles = 0
    conteo_objetos = 0
    objetos_especiales = Counter()

    with (OUT / "house_tiles.jsonl").open("w", encoding="utf-8") as casas_salida, \
            (OUT / "world_objects.jsonl").open("w", encoding="utf-8") as objetos_salida:

        def por_casilla(_x, _y, _z, _ids, _banderas):
            # El callback detallado es el que conserva house_id y atributos.
            pass

        def por_casilla_detalle(x, y, z, items, banderas, house_id):
            nonlocal conteo_tiles, conteo_objetos
            conteo_tiles += 1
            pisos[str(z)] += 1
            objetos = []
            cats = []
            for item in items:
                sid = int(item["server_id"])
                base = item_info(sid, catalogo_servidor, por_cliente, nombres)
                attrs = dict(item.get("attributes", {}))
                base["count"] = int(item.get("count", 1))
                base["attributes"] = attrs
                base["category"] = clasificar(
                    base["name"], int(base["flags"].get("grupo", 0)),
                    base["flags"], attrs)
                objetos.append(base)
                cats.append(base["category"])
                categorias[base["category"]] += 1
                conteo_objetos += 1
                if base["category"] != "ground":
                    objetos_especiales[base["category"]] += 1

            if house_id:
                actualizar_casa(casas, house_id, x, y, z, cats, objetos)
                casas_salida.write(json.dumps({
                    "house_id": house_id,
                    "position": {"x": x, "y": y, "z": z},
                    "tile_flags": banderas,
                    "categories": sorted(set(cats)),
                    "objects": objetos,
                }, ensure_ascii=False, separators=(",", ":")) + "\n")

            for objeto in objetos:
                if objeto["category"] not in CATEGORIAS_MODELABLES:
                    continue
                compacto = {
                    "p": [x, y, z],
                    "h": house_id,
                    "s": objeto["server_id"],
                    "i": objeto["client_id"],
                    "c": objeto["category"],
                }
                if objeto["name"]:
                    compacto["n"] = objeto["name"]
                if objeto.get("attributes"):
                    compacto["a"] = objeto["attributes"]
                objetos_salida.write(json.dumps(
                    compacto, ensure_ascii=False, separators=(",", ":")) + "\n")

        recorrer(bytes(OTBM.read_bytes()), por_casilla,
                 por_casilla_detalle=por_casilla_detalle)

    for casa in casas.values():
        definicion = definiciones_casas.get(str(casa["house_id"]), {})
        casa.update(definicion)
        casa["definition_match"] = bool(definicion)
        if definicion:
            casa["tile_count_delta_vs_declared"] = (
                casa["tile_count"] - definicion["declared_size"])
        casa["floors"] = dict(sorted(casa["floors"].items()))
        casa["categories"] = dict(sorted(casa["categories"].items()))
        casa["objects"] = dict(sorted(casa["objects"].items()))

    (OUT / "houses.json").write_text(
        json.dumps(sorted(casas.values(), key=lambda c: c["house_id"]),
                   ensure_ascii=False, indent=2), encoding="utf-8")

    report = {
        "format": "tvp3d.world-mapper.v1",
        "source": {
            "map": str(OTBM.relative_to(ROOT)),
            "items": "servidor/data/items/items.otb + items.xml",
            "coordinates": "Tibia x,y,z; z=7 surface in Rookgaard",
        },
        "summary": {
            "tiles": conteo_tiles,
            "objects": conteo_objetos,
            "houses": len(casas),
            "house_definitions": len(definiciones_casas),
            "houses_without_definition": sum(
                1 for casa in casas.values() if not casa["definition_match"]),
            "floors": dict(sorted(pisos.items())),
        },
        "semantic_categories": dict(sorted(categorias.items())),
        "non_ground_objects": dict(sorted(objetos_especiales.items())),
        "outputs": {
            "houses": "houses.json",
            "house_tiles": "house_tiles.jsonl",
            "world_objects": "world_objects.jsonl",
        },
    }
    (OUT / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
