"""Reglas compartidas para la referencia estatica de Tile::queryAdd."""

import xml.etree.ElementTree as ET


def leer_comportamiento_xml(xml_path):
    """Lee propiedades de items que cambian queryAdd en pathfinding."""
    root = ET.parse(xml_path).getroot()
    result = {}
    for node in root.findall("item"):
        try:
            server_id = int(node.attrib["id"])
        except (KeyError, ValueError):
            continue

        floor_changes = []
        teleport = False
        for attribute in node.findall("attribute"):
            key = attribute.attrib.get("key", "").strip().lower()
            value = attribute.attrib.get("value", "").strip().lower()
            if key == "floorchange":
                floor_changes.append(value)
            elif key == "type" and value == "teleport":
                teleport = True
        result[server_id] = {
            "floor_changes": floor_changes,
            "teleport": teleport,
        }
    return result


def _item_reasons(item, catalog, xml_behavior):
    server_id = int(item.get("server_id", 0))
    metadata = catalog.get(server_id)
    if metadata is None:
        return ["missing_items_otb:%d" % server_id], False

    reasons = []
    if metadata.get("block_pathfind", False):
        reasons.append("block_pathfind:%d" % server_id)

    behavior = xml_behavior.get(server_id)
    if behavior is None:
        return reasons + ["missing_items_xml:%d" % server_id], False
    if behavior["floor_changes"]:
        reasons.append("floorchange:%d" % server_id)
    if behavior["teleport"]:
        reasons.append("teleport:%d" % server_id)
    return reasons, True


def server_queryadd_reference(tile, catalog, xml_behavior):
    """Devuelve la decision estatica y sus razones, sin mutar el IR.

    Corresponde a las condiciones de Tile::queryAdd para un jugador con
    FLAG_PATHFINDING: ground obligatorio, sin BLOCKPATH, FLOORCHANGE o
    TELEPORT. El resultado de una casa se deja a la autoridad del servidor.
    """
    if int(tile.get("house_id", 0)) != 0:
        return {
            "walkable": None,
            "complete": False,
            "excluded": "house_access_dynamic",
            "reasons": [],
        }

    reasons = []
    complete = True
    if tile.get("ground") is None:
        reasons.append("no_ground")

    for item in tile.get("items", []):
        item_reasons, item_complete = _item_reasons(
            item, catalog, xml_behavior)
        reasons.extend(item_reasons)
        complete = complete and item_complete

    return {
        "walkable": not reasons if complete else None,
        "complete": complete,
        "excluded": None,
        "reasons": reasons,
    }
