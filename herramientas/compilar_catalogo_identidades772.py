"""Compilador determinista del catalogo de identidades legacy 7.72.

Compone los parsers existentes de OTBM, OTB, DAT y SPR. No reemplaza ningun
extractor runtime: publica manifests, mappings, indices y auditoria en
assets/importados/.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path
from typing import Iterable

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extraer_items772 import (  # noqa: E402
    GRUPO_CONTENEDOR,
    GRUPO_FLUIDO,
    GRUPO_SPLASH,
    GRUPO_SUELO,
    leer_nombres,
    leer_otb,
)
from leer_dat_spr import cargar_dat  # noqa: E402
from leer_otbm import recorrer  # noqa: E402


ASSETS_CONTRACT = "2.0.0"
MODEL_CONTRACT = "2.1.0"
COMPILER_VERSION = "1.0.0"
PROFILE_ID = "TVP772_BASELINE"
PROFILE_VERSION = "1.0.0"
MAX_POR_CASILLA = 32
SOURCE_VERSION = "7.72"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def canonical_json_bytes(value: object, compact: bool = False) -> bytes:
    if compact:
        text = json.dumps(
            value, ensure_ascii=False, separators=(",", ":"), sort_keys=False
        )
    else:
        text = json.dumps(
            value, ensure_ascii=False, indent=2, sort_keys=False
        )
    return (text + "\n").encode("utf-8")


def ordered_map(values: dict[str, object]) -> dict[str, object]:
    return {
        key: values[key]
        for key in sorted(values, key=lambda item: item.encode("utf-8"))
    }


def slug_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    ascii_text = normalized.encode("ascii", "ignore").decode("ascii").lower()
    slug = re.sub(r"[^a-z0-9]+", "_", ascii_text).strip("_")
    return slug or "unnamed"


def canonical_id(
    namespace: str, kind: str, base: str, digest: str | None = None
) -> str:
    key = slug_text(base)
    if digest:
        key = f"{key}_{digest[:16]}"
    key = key[:63].rstrip("_")
    if not key or not key[0].isalpha():
        key = "unnamed_" + key
    result = f"{namespace}:{kind}:{key}"
    if len(result.encode("ascii")) > 130:
        key = key[: max(1, 130 - len(namespace) - len(kind) - 2)]
        result = f"{namespace}:{kind}:{key}"
    return result


def alias(system: str, kind: str, value: str) -> dict[str, str]:
    return {
        "system": system,
        "source_version": SOURCE_VERSION,
        "kind": kind,
        "value": value,
    }


def alias_sort_key(item: dict[str, str]) -> tuple[bytes, bytes, bytes, bytes]:
    return tuple(
        item[name].encode("utf-8")
        for name in ("system", "source_version", "kind", "value")
    )


def alias_key(item: dict[str, str]) -> str:
    return "|".join(
        item[name] for name in ("system", "source_version", "kind", "value")
    )


def source_ref(
    artifact_id: str, manifest: dict[str, object], locator: str
) -> dict[str, str]:
    return {
        "artifact_id": artifact_id,
        "sha256": str(manifest["sha256"]),
        "locator": locator,
    }


def source_artifact_ref(
    artifact_id: str, manifest: dict[str, object]
) -> dict[str, str]:
    return {"artifact_id": artifact_id, "sha256": str(manifest["sha256"])}


def artifact_id_for_monster(relative_path: str, used: set[str]) -> str:
    base = "legacy/tvp772/monster/" + slug_text(Path(relative_path).stem)
    candidate = base
    if candidate in used:
        candidate = base + "_" + sha256_bytes(relative_path.encode("utf-8"))[:8]
    used.add(candidate)
    return candidate


def _manifest(
    artifact_id: str,
    system: str,
    kind: str,
    repository_relative_path: str,
    data: bytes,
) -> dict[str, object]:
    return {
        "schema": "tvp3d.assets.source_artifact",
        "version": ASSETS_CONTRACT,
        "artifact_id": artifact_id,
        "system": system,
        "source_version": SOURCE_VERSION,
        "kind": kind,
        "repository_relative_path": repository_relative_path,
        "sha256": sha256_bytes(data),
        "size_bytes": str(len(data)),
    }


def build_source_manifests(
    root: Path,
) -> tuple[list[dict[str, object]], dict[str, dict[str, object]]]:
    base_specs = [
        ("legacy/tvp772/world-map", "OTBM", "OTBM", "servidor/data/world/map.otbm"),
        ("legacy/tvp772/items-otb", "OTB", "OTB", "servidor/data/items/items.otb"),
        ("legacy/tvp772/items-xml", "XML", "XML", "servidor/data/items/items.xml"),
        ("legacy/tvp772/client-dat", "DAT", "DAT", "cliente3d/assets/cliente772/Tibia.dat"),
        ("legacy/tvp772/client-spr", "SPR", "SPR", "cliente3d/assets/cliente772/Tibia.spr"),
    ]
    specs = list(base_specs)
    used = {item[0] for item in specs}
    monster_dir = root / "servidor" / "data" / "monster" / "monsters"
    for path in sorted(
        monster_dir.glob("*.xml"),
        key=lambda item: item.as_posix().encode("utf-8"),
    ):
        try:
            parsed = ET.parse(path).getroot()
        except ET.ParseError as error:
            raise ValueError(f"SOURCE_FORMAT_UNSUPPORTED {path}: {error}") from error
        look = parsed.find("look")
        if parsed.get("name") is None or look is None or look.get("type") is None:
            continue
        relative = path.relative_to(root).as_posix()
        specs.append((artifact_id_for_monster(relative, used), "XML", "XML", relative))

    manifests: list[dict[str, object]] = []
    by_id: dict[str, dict[str, object]] = {}
    for artifact_id, system, kind, relative in specs:
        path = root / Path(relative)
        if not path.is_file():
            raise FileNotFoundError(f"SOURCE_ARTIFACT_MISSING {relative}")
        item = _manifest(artifact_id, system, kind, relative, path.read_bytes())
        manifests.append(item)
        by_id[artifact_id] = item
    manifests.sort(key=lambda item: str(item["artifact_id"]).encode("utf-8"))
    return manifests, by_id


def verify_source_snapshot(
    root: Path, manifests: Iterable[dict[str, object]]
) -> None:
    for manifest in manifests:
        path = root / Path(str(manifest["repository_relative_path"]))
        if not path.is_file():
            raise RuntimeError(
                f"SOURCE_ARTIFACT_MISSING {manifest['repository_relative_path']}"
            )
        data = path.read_bytes()
        actual_hash = sha256_bytes(data)
        actual_size = str(len(data))
        if actual_hash != manifest["sha256"] or actual_size != manifest["size_bytes"]:
            raise RuntimeError(
                "SOURCE_HASH_MISMATCH "
                f"{manifest['repository_relative_path']} "
                f"expected={manifest['sha256']}/{manifest['size_bytes']} "
                f"actual={actual_hash}/{actual_size}"
            )


def _item_signature(name: str, item: dict[str, object]) -> str:
    data = {"name": name, "item": ordered_map(item)}
    return sha256_bytes(canonical_json_bytes(data, compact=True))


def _outfit_signature(name: str, record: dict[str, object]) -> str:
    return sha256_bytes(
        canonical_json_bytes({"name": name, "record": record}, compact=True)
    )


def derive_render_flags(item: dict[str, object]) -> dict[str, object]:
    """Proyeccion exacta de los campos observables de items772_flags."""

    group = int(item["grupo"])
    flags = {
        "suelo": group == GRUPO_SUELO,
        "contenedor": group == GRUPO_CONTENEDOR,
        "splash": group == GRUPO_SPLASH,
        "liquido": group == GRUPO_FLUIDO,
        "bloquea": bool(item["bloquea"]),
        "frena_vista": bool(item["frena_vista"]),
        "apilable": bool(item["apilable"]),
        "levantable": bool(item["levantable"]),
        "clavado": not bool(item["movible"]),
        "borde_suelo": int(item["orden_arriba"]) == 1,
        "velocidad_suelo": int(item["velocidad_suelo"]),
        "color_mapa": int(item["color_mapa"]),
    }
    return {
        key: value
        for key, value in flags.items()
        if value is not False and value != 0
    }


def audit_items772_flags(
    root: Path, items: dict[int, dict[str, object]]
) -> dict[str, object]:
    path = root / "cliente3d" / "assets" / "items772_flags.json"
    if not path.is_file():
        return {
            "status": "ITEMS772_FLAGS_PROVENANCE_UNRESOLVED",
            "path": path.relative_to(root).as_posix(),
            "reason": "artifact missing",
            "fields": [],
            "conflicts": [],
            "mismatches": [],
        }
    current = json.loads(path.read_text(encoding="utf-8"))
    current_items = current.get("items", {})
    by_client: dict[int, list[tuple[int, dict[str, object]]]] = defaultdict(list)
    for server_id, item in sorted(items.items()):
        by_client[int(item["cid"])].append((server_id, item))

    conflicts: list[dict[str, object]] = []
    mismatches: list[dict[str, object]] = []
    derived_clients: dict[str, dict[str, object]] = {}
    for client_id, records in sorted(by_client.items()):
        projections: dict[str, dict[str, object]] = {}
        for _, item in records:
            projection = derive_render_flags(item)
            projections[json.dumps(projection, sort_keys=True)] = projection
        if len(projections) > 1:
            conflicts.append({
                "client_id": client_id,
                "server_records": [
                    {"server_id": sid, "flags": derive_render_flags(item)}
                    for sid, item in records
                ],
                "legacy_value": current_items.get(str(client_id), {}),
            })
        projection = derive_render_flags(records[0][1])
        derived_clients[str(client_id)] = projection
        if current_items.get(str(client_id), {}) not in projections.values():
            mismatches.append({
                "client_id": client_id,
                "legacy_value": current_items.get(str(client_id), {}),
                "derived_values": list(projections.values()),
            })

    fields = sorted(
        {key for value in current_items.values() for key in value},
        key=lambda item: item.encode("utf-8"),
    )
    status = "RESOLVED_PER_RECORD"
    if conflicts:
        status = "RESOLVED_PER_RECORD_LEGACY_CLIENT_INDEX_CONFLICT"
    if mismatches:
        status = "ITEMS772_FLAGS_PROVENANCE_UNRESOLVED"
    return {
        "status": status,
        "path": path.relative_to(root).as_posix(),
        "source_artifact_id": "legacy/tvp772/items-otb",
        "derivation": {
            "suelo": "grupo == GRUPO_SUELO",
            "contenedor": "grupo == GRUPO_CONTENEDOR",
            "splash": "grupo == GRUPO_SPLASH",
            "bloquea": "FLAG_BLOCK_SOLID",
            "frena_vista": "FLAG_BLOCK_PROJECTILE",
            "apilable": "FLAG_STACKABLE",
            "levantable": "FLAG_PICKUPABLE",
            "clavado": "not FLAG_MOVEABLE",
            "borde_suelo": "ATTR_TOPORDER == 1",
            "velocidad_suelo": "ATTR_SPEED",
            "color_mapa": "ATTR_MINIMAPCOLOR",
        },
        "fields": fields,
        "legacy_entry_count": len(current_items),
        "derived_entry_count": len(derived_clients),
        "conflicts": conflicts,
        "mismatches": mismatches,
    }
def _mapping_record(canonical, aliases, sources):
    unique_aliases = {
        (item["system"], item["source_version"], item["kind"], item["value"]): item
        for item in aliases
    }
    unique_sources = {
        (item["artifact_id"], item["sha256"], item["locator"]): item
        for item in sources
    }
    alias_list = [
        unique_aliases[key] for key in sorted(unique_aliases, key=lambda value: tuple(
            part.encode("utf-8") for part in value))]
    source_list = [
        unique_sources[key] for key in sorted(unique_sources, key=lambda value: tuple(
            part.encode("utf-8") for part in value))]
    return {
        "schema": "tvp3d.assets.identity_mapping",
        "version": ASSETS_CONTRACT,
        "canonical_id": canonical,
        "aliases": alias_list,
        "mapping_profile": {"id": PROFILE_ID, "version": PROFILE_VERSION},
        "provenance": {
            "class": "RESOLVED_DOMAIN",
            "sources": source_list,
            "method": "TVP772_LEGACY_IDENTITY_CATALOG",
            "method_version": "1.0.0",
        },
    }


def _sprite_aliases(thing):
    return [
        alias("SPR", "SPRITE_ID", str(sprite_id))
        for sprite_id in sorted({int(value) for value in thing.get("indices", [])
                                 if int(value) > 0})
    ]


def build_item_mappings(items, names, dat, manifests):
    groups = defaultdict(list)
    for server_id, item in sorted(items.items()):
        name = names.get(server_id, "item_%d" % server_id)
        groups[name].append((server_id, item))
    records = []
    for name in sorted(groups, key=lambda value: value.encode("utf-8")):
        variants = groups[name]
        signatures = sorted({_item_signature(name, item)
                             for _, item in variants})
        for signature in signatures:
            variant = [(sid, item) for sid, item in variants
                       if _item_signature(name, item) == signature]
            digest = hashlib.sha256(signature.encode("utf-8")).hexdigest()
            suffix = digest if len(signatures) > 1 else None
            canonical = canonical_id("tvp3d", "item", name, suffix)
            aliases = []
            sources = []
            for server_id, item in sorted(variant):
                client_id = int(item["cid"])
                aliases.extend([
                    alias("OTB", "OTB_SERVER_ID", str(server_id)),
                    alias("TIBIA_CLIENT", "CLIENT_ID", str(client_id)),
                    alias("DAT", "DAT_THING_ID", str(client_id)),
                    alias("XML", "XML_NAME", name),
                ])
                sources.extend([
                    source_ref(manifests["legacy/tvp772/items-otb"],
                               "record/server_id=%d" % server_id),
                    source_ref(manifests["legacy/tvp772/items-xml"],
                               "item/name=%s" % name),
                ])
                dat_item = dat["items"].get(client_id)
                if dat_item is not None:
                    aliases.extend(_sprite_aliases(dat_item))
                    sources.extend([
                        source_ref(manifests["legacy/tvp772/client-dat"],
                                   "thing/item_id=%d" % client_id),
                        source_ref(manifests["legacy/tvp772/client-spr"], "header"),
                    ])
            records.append(_mapping_record(canonical, aliases, sources))
    return sorted(records, key=lambda item: str(item["canonical_id"]).encode("utf-8"))
def build_creature_mappings(root, manifests, dat):
    monster_dir = root / "servidor" / "data" / "monster" / "monsters"
    groups = defaultdict(list)
    by_path = {
        str(manifest["repository_relative_path"]): artifact_id
        for artifact_id, manifest in manifests.items()
    }
    for path in sorted(monster_dir.glob("*.xml"),
                       key=lambda value: value.as_posix().encode("utf-8")):
        node = ET.parse(path).getroot()
        name = node.get("name")
        look = node.find("look")
        if not name or look is None or look.get("type") is None:
            continue
        look_data = {
            "looktype": int(look.get("type", "0")),
            "head": int(look.get("head", "0")),
            "body": int(look.get("body", "0")),
            "legs": int(look.get("legs", "0")),
            "feet": int(look.get("feet", "0")),
        }
        rel = path.relative_to(root).as_posix()
        groups[name].append((rel, int(look_data["looktype"]), look_data))

    records = []
    for name in sorted(groups, key=lambda value: value.encode("utf-8")):
        variants = groups[name]
        signatures = sorted({_outfit_signature(name, data)
                             for _, _, data in variants})
        for signature in signatures:
            variant = [(rel, looktype, data) for rel, looktype, data in variants
                       if _outfit_signature(name, data) == signature]
            digest = hashlib.sha256(signature.encode("utf-8")).hexdigest()
            suffix = digest if len(signatures) > 1 else None
            canonical = canonical_id("tvp3d", "creature", name, suffix)
            aliases = []
            sources = []
            for rel, looktype, _ in sorted(variant):
                aliases.extend([
                    alias("TFS", "LOOKTYPE", str(looktype)),
                    alias("XML", "XML_NAME", name),
                    alias("DAT", "DAT_THING_ID", str(looktype)),
                ])
                dat_outfit = dat["outfits"].get(looktype)
                if dat_outfit is not None:
                    aliases.extend(_sprite_aliases(dat_outfit))
                    sources.extend([
                        source_ref(manifests["legacy/tvp772/client-dat"],
                                   "thing/outfit_id=%d" % looktype),
                        source_ref(manifests["legacy/tvp772/client-spr"], "header"),
                    ])
                artifact_id = by_path[rel]
                sources.append(source_ref(
                    manifests[artifact_id],
                    "monster/name=%s/look/type=%d" % (name, looktype)))
            records.append(_mapping_record(canonical, aliases, sources))
    return sorted(records, key=lambda item: str(item["canonical_id"]).encode("utf-8"))
def build_alias_index(mappings):
    targets = defaultdict(set)
    values = {}
    for mapping in mappings:
        canonical = str(mapping["canonical_id"])
        for item in mapping["aliases"]:
            key = (item["system"], item["source_version"],
                   item["kind"], item["value"])
            targets[key].add(canonical)
            values[key] = item
    entries = {}
    statuses = {}
    for key in sorted(targets, key=lambda value: tuple(
            part.encode("utf-8") for part in value)):
        candidates = sorted(targets[key], key=lambda value: value.encode("utf-8"))
        status = "RESOLVED" if len(candidates) == 1 else "AMBIGUOUS"
        statuses[key] = status
        entries[alias_key(values[key])] = {
            "schema": "tvp3d.assets.identity_resolution",
            "version": ASSETS_CONTRACT,
            "status": status,
            "canonical_id": candidates[0] if len(candidates) == 1 else None,
            "aliases": [values[key]],
            "candidates": candidates,
        }
    return ordered_map(entries), statuses
def source_ref(artifact_or_manifest, manifest_or_locator, locator=None):
    if locator is None:
        artifact_id = str(artifact_or_manifest["artifact_id"])
        manifest = artifact_or_manifest
        actual_locator = str(manifest_or_locator)
    else:
        artifact_id = str(artifact_or_manifest)
        manifest = manifest_or_locator
        actual_locator = locator
    return {
        "artifact_id": artifact_id,
        "sha256": str(manifest["sha256"]),
        "locator": actual_locator,
    }
def _observe_map_tile(state, x, y, z, ids, server_to_client, max_per_tile):
    state["tile_count"] += 1
    state["source_item_count"] += len(ids)
    counts = state["source_id_counts"]
    unresolved = state["unresolved_source_ids"]
    unresolved_counts = state["unresolved_counts"]
    if len(ids) > max_per_tile:
        state["truncated_tiles"].append({
            "x": x, "y": y, "z": z,
            "source_count": len(ids), "emitted_limit": max_per_tile})
    for index, source_id in enumerate(ids):
        counts[source_id] += 1
        if source_id not in server_to_client:
            if source_id not in unresolved:
                unresolved[source_id] = {
                    "source_id": source_id,
                    "occurrences": 0,
                    "first_locator": {
                        "x": x, "y": y, "z": z, "item_index": index}}
            unresolved_counts[source_id] += 1


def _finish_map_audit(state, max_per_tile):
    unresolved = state["unresolved_source_ids"]
    for source_id, record in unresolved.items():
        record["occurrences"] = state["unresolved_counts"][source_id]
    return {
        "max_per_tile": max_per_tile,
        "tile_count": state["tile_count"],
        "source_item_count": state["source_item_count"],
        "source_id_counts": ordered_map({
            str(key): value for key, value in state["source_id_counts"].items()}),
        "unresolved_source_ids": [
            unresolved[key] for key in sorted(unresolved)],
        "truncated_tiles": sorted(
            state["truncated_tiles"],
            key=lambda item: (item["z"], item["y"], item["x"]))}


def scan_real_map(root, server_to_client, max_per_tile=MAX_POR_CASILLA):
    state = {
        "tile_count": 0, "source_item_count": 0,
        "source_id_counts": defaultdict(int),
        "unresolved_source_ids": {},
        "unresolved_counts": defaultdict(int),
        "truncated_tiles": []}
    map_path = root / "servidor" / "data" / "world" / "map.otbm"

    def on_tile(x, y, z, ids, *_flags):
        _observe_map_tile(
            state, x, y, z, ids, server_to_client, max_per_tile)

    recorrer(map_path.read_bytes(), on_tile)
    return _finish_map_audit(state, max_per_tile)
def validation_error(code, severity, stage, artifact_id, record_id,
                     locator, message, details=None):
    return {
        "schema": "tvp3d.assets.import_error",
        "version": ASSETS_CONTRACT,
        "code": code, "severity": severity, "stage": stage,
        "artifact_id": artifact_id, "record_id": record_id,
        "locator": locator, "message": message, "details": details or {}}


def make_validation_report(map_audit, alias_statuses, flags_audit):
    findings = []
    unresolved = map_audit["unresolved_source_ids"]
    if unresolved:
        findings.append(validation_error(
            "IDENTITY_UNRESOLVED", "WARNING", "IDENTITY_RESOLUTION",
            "legacy/tvp772/world-map", "map", "map.otbm",
            "unmapped OTBM ids", {"source_ids": unresolved}))
    for tile in map_audit["truncated_tiles"]:
        record_id = "tile:%d,%d,%d" % (
            tile["x"], tile["y"], tile["z"])
        findings.append(validation_error(
            "DERIVATION_FAILED", "WARNING", "NORMALIZATION",
            "legacy/tvp772/world-map", record_id, record_id,
            "tile exceeds MAX_POR_CASILLA", tile))
    ambiguous = [key for key, status in alias_statuses.items()
                 if status == "AMBIGUOUS"]
    for key in ambiguous:
        alias_object = {
            "system": key[0], "source_version": key[1],
            "kind": key[2], "value": key[3]}
        findings.append(validation_error(
            "IDENTITY_AMBIGUOUS", "WARNING", "IDENTITY_RESOLUTION",
            "legacy/tvp772/identity", alias_key(alias_object),
            alias_key(alias_object),
            "Alias resolves to incompatible canonical targets",
            {"alias": alias_object}))
    if flags_audit.get("status") == "ITEMS772_FLAGS_PROVENANCE_UNRESOLVED":
        findings.append(validation_error(
            "DERIVATION_FAILED", "ERROR", "NORMALIZATION",
            "legacy/tvp772/items-otb", "items772_flags", flags_audit["path"],
            "items772_flags does not match OTB projection",
            {"mismatches": flags_audit.get("mismatches", [])}))
    findings.sort(key=lambda item: (
        str(item["severity"]), str(item["code"]), str(item["locator"])))
    errors = sum(item["severity"] == "ERROR" for item in findings)
    warnings = sum(item["severity"] == "WARNING" for item in findings)
    return {
        "schema": "tvp3d.assets.validation_result", "version": "1.0.0",
        "result": "FAILED" if errors else "SUCCESS",
        "findings": findings, "map_audit": map_audit,
        "items772_flags_provenance": flags_audit,
        "summary": {
            "warnings": warnings, "errors": errors, "fatals": 0,
            "unresolved": len(unresolved), "ambiguous": len(ambiguous)}}
import shutil
import tempfile


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    data = canonical_json_bytes(value)
    path.write_bytes(data)
    return data


def _artifact_output(logical_path, schema, version, data):
    return {
        "logical_path": logical_path,
        "schema": schema,
        "version": version,
        "sha256": sha256_bytes(data),
        "size_bytes": str(len(data)),
        "publication_class": "DERIVED_CACHE",
    }


def build_once(root, output_root):
    if output_root.exists() and any(output_root.iterdir()):
        raise RuntimeError("OUTPUT_MUST_BE_EMPTY %s" % output_root)
    output_root.mkdir(parents=True, exist_ok=True)
    manifests, by_id = build_source_manifests(root)
    verify_source_snapshot(root, manifests)
    items = leer_otb()
    names = leer_nombres()
    dat = cargar_dat(root / "cliente3d" / "assets" / "cliente772" / "Tibia.dat")
    item_records = build_item_mappings(items, names, dat, by_id)
    creature_records = build_creature_mappings(root, by_id, dat)
    records = item_records + creature_records
    records.sort(key=lambda item: str(item["canonical_id"]).encode("utf-8"))
    alias_entries, alias_statuses = build_alias_index(records)
    canonical_identities = ordered_map({
        str(item["canonical_id"]): {
            "schema": "tvp3d.domain_identity",
            "version": MODEL_CONTRACT,
            "canonical_id": item["canonical_id"],
            "aliases": item["aliases"],
        }
        for item in records
    })
    server_to_client = {
        int(server_id): int(item["cid"])
        for server_id, item in items.items()
    }
    map_audit = scan_real_map(root, server_to_client)
    flags_audit = audit_items772_flags(root, items)
    validation = make_validation_report(
        map_audit, alias_statuses, flags_audit)
    mapping_doc = {
        "schema": "tvp3d.assets.identity_mapping_catalog",
        "version": "1.0.0",
        "mapping_profile": {"id": PROFILE_ID, "version": PROFILE_VERSION},
        "records": records,
    }
    alias_doc = {
        "schema": "tvp3d.assets.alias_index",
        "version": "1.0.0",
        "identity_resolution": "tvp3d.assets.identity_resolution/2.0.0",
        "entries": alias_entries,
    }
    canonical_doc = {
        "schema": "tvp3d.assets.canonical_identity_index",
        "version": "1.0.0",
        "identities": canonical_identities,
    }
    output_specs = []
    source_dir = output_root / "source_artifacts"
    for manifest in manifests:
        filename = str(manifest["artifact_id"]).replace("/", "__") + ".json"
        relative = "source_artifacts/" + filename
        data = write_json(source_dir / filename, manifest)
        output_specs.append(_artifact_output(
            relative, manifest["schema"], manifest["version"], data))
    aggregate_specs = [
        ("identity_mappings.json", mapping_doc),
        ("alias_index.json", alias_doc),
        ("canonical_index.json", canonical_doc),
        ("validation.json", validation),
    ]
    for filename, document in aggregate_specs:
        data = write_json(output_root / filename, document)
        output_specs.append(_artifact_output(
            filename, document["schema"], document["version"], data))
    output_specs.sort(key=lambda item: str(item["logical_path"]).encode("utf-8"))
    inputs = [
        source_artifact_ref(manifest["artifact_id"], manifest)
        for manifest in manifests
    ]
    descriptor = {
        "tool": {"id": "tvp3d.assets.legacy_identity_catalog", "version": COMPILER_VERSION},
        "inputs": sorted(inputs, key=lambda item: (
            item["artifact_id"].encode("utf-8"), item["sha256"].encode("utf-8"))),
        "contracts": sorted([
            {"name": "assets", "version": ASSETS_CONTRACT},
            {"name": "modelo-comun", "version": MODEL_CONTRACT},
        ], key=lambda item: item["name"]),
        "normalization_profile": {
            "id": PROFILE_ID, "version": PROFILE_VERSION},
    }
    import_run_id = "sha256:" + sha256_bytes(
        canonical_json_bytes(descriptor, compact=True))
    summary = validation["summary"]
    import_run = {
        "schema": "tvp3d.assets.import_run",
        "version": ASSETS_CONTRACT,
        "import_run_id": import_run_id,
        "tool": descriptor["tool"],
        "inputs": descriptor["inputs"],
        "contracts": descriptor["contracts"],
        "normalization_profile": descriptor["normalization_profile"],
        "outputs": output_specs,
        "result": "SUCCESS" if validation["result"] == "SUCCESS" else "FAILED",
        "summary": summary,
    }
    import_data = write_json(output_root / "import_run.json", import_run)
    verify_source_snapshot(root, manifests)
    return {
        "import_run_id": import_run_id,
        "import_run": import_run,
        "manifests": manifests,
        "items": items,
        "mappings": records,
        "alias_statuses": alias_statuses,
        "map_audit": map_audit,
        "flags_audit": flags_audit,
        "validation": validation,
        "output_hashes": {
            item["logical_path"]: item["sha256"] for item in output_specs
        } | {"import_run.json": sha256_bytes(import_data)},
    }
def build_creature_mappings(root, manifests, dat):
    monster_dir = root / "servidor" / "data" / "monster" / "monsters"
    groups = defaultdict(list)
    by_path = {
        str(manifest["repository_relative_path"]): artifact_id
        for artifact_id, manifest in manifests.items()
    }
    for path in sorted(monster_dir.glob("*.xml"),
                       key=lambda value: value.as_posix().encode("utf-8")):
        node = ET.parse(path).getroot()
        name = node.get("name")
        look = node.find("look")
        if not name or look is None or look.get("type") is None:
            continue
        look_data = {
            "looktype": int(look.get("type", "0")),
            "head": int(look.get("head", "0")),
            "body": int(look.get("body", "0")),
            "legs": int(look.get("legs", "0")),
            "feet": int(look.get("feet", "0")),
        }
        rel = path.relative_to(root).as_posix()
        groups[name].append((rel, int(look_data["looktype"]), look_data))
    records = []
    for name in sorted(groups, key=lambda value: value.encode("utf-8")):
        variants = groups[name]
        signatures = sorted({_outfit_signature(name, data)
                             for _, _, data in variants})
        for signature in signatures:
            variant = [(rel, looktype, data) for rel, looktype, data in variants
                       if _outfit_signature(name, data) == signature]
            digest = hashlib.sha256(signature.encode("utf-8")).hexdigest()
            suffix = digest if len(signatures) > 1 else None
            canonical = canonical_id("tvp3d", "creature", name, suffix)
            aliases = []
            sources = []
            for rel, looktype, _ in sorted(variant):
                aliases.extend([
                    alias("TFS", "LOOKTYPE", str(looktype)),
                    alias("XML", "XML_NAME", name),
                    alias("DAT", "DAT_THING_ID", str(looktype)),
                ])
                dat_outfit = dat["outfits"].get(looktype)
                if dat_outfit is not None:
                    aliases.extend(_sprite_aliases(dat_outfit))
                    sources.extend([
                        source_ref(manifests["legacy/tvp772/client-dat"],
                                   "thing/outfit_id=%d" % looktype),
                        source_ref(manifests["legacy/tvp772/client-spr"], "header"),
                    ])
                artifact_id = by_path[rel]
                sources.append(source_ref(
                    manifests[artifact_id],
                    "monster/name=%s/look/type=%d" % (name, looktype)))
            records.append(_mapping_record(canonical, aliases, sources))
    return sorted(records, key=lambda item: str(item["canonical_id"]).encode("utf-8"))
def compare_trees(left, right):
    left_files = sorted(
        path.relative_to(left).as_posix() for path in left.rglob("*")
        if path.is_file())
    right_files = sorted(
        path.relative_to(right).as_posix() for path in right.rglob("*")
        if path.is_file())
    if left_files != right_files:
        return False
    return all(
        (left / relative).read_bytes() == (right / relative).read_bytes()
        for relative in left_files)


def result_summary(result, run1_hashes=None, run2_hashes=None):
    return {
        "import_run_id": result["import_run_id"],
        "canonical_identities": len(result["mappings"]),
        "aliases_by_kind": {
            kind: sum(1 for item in result["mappings"]
                      for alias_item in item["aliases"]
                      if alias_item["kind"] == kind)
            for kind in sorted({
                alias_item["kind"] for item in result["mappings"]
                for alias_item in item["aliases"]})},
        "many_to_one_otb": sum(
            1 for values in _client_groups(result["items"]).values()
            if len(values) > 1),
        "unresolved_source_mappings": result["validation"]["summary"]["unresolved"],
        "ambiguous_mappings": result["validation"]["summary"]["ambiguous"],
        "otbm_untranslatable_ids": len(
            result["map_audit"]["unresolved_source_ids"]),
        "tiles_above_max": len(result["map_audit"]["truncated_tiles"]),
        "items772_flags": result["flags_audit"]["status"],
        "validation": result["validation"]["result"],
        "run1_hashes": run1_hashes,
        "run2_hashes": run2_hashes,
    }


def _client_groups(items):
    groups = defaultdict(list)
    for server_id, item in items.items():
        groups[int(item["cid"])].append(int(server_id))
    return groups


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--verify-determinism", action="store_true")
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[1]
    output = args.output or root / "assets" / "importados" / "v2" / "legacy_identity_catalog"
    if not args.verify_determinism:
        result = build_once(root, output)
        print(json.dumps(result_summary(result), ensure_ascii=False, indent=2))
        return 0 if result["validation"]["result"] == "SUCCESS" else 2
    with tempfile.TemporaryDirectory(prefix="tvp3d-assets-stage1-") as temp:
        first_path = Path(temp) / "run1"
        second_path = Path(temp) / "run2"
        first = build_once(root, first_path)
        second = build_once(root, second_path)
        identical = compare_trees(first_path, second_path)
        if not identical:
            raise RuntimeError("OUTPUT_NONDETERMINISTIC")
        if output.exists() and any(output.iterdir()):
            raise RuntimeError("OUTPUT_MUST_BE_EMPTY %s" % output)
        shutil.copytree(first_path, output)
        summary = result_summary(
            first, first["output_hashes"], second["output_hashes"])
        summary["byte_identical"] = identical
        print(json.dumps(summary, ensure_ascii=False, indent=2))
        return 0 if first["validation"]["result"] == "SUCCESS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
def audit_map_items(tiles, server_to_client, max_per_tile=MAX_POR_CASILLA):
    state = {
        "tile_count": 0, "source_item_count": 0,
        "source_id_counts": defaultdict(int),
        "unresolved_source_ids": {},
        "unresolved_counts": defaultdict(int),
        "truncated_tiles": []}
    for x, y, z, ids in tiles:
        _observe_map_tile(
            state, x, y, z, ids, server_to_client, max_per_tile)
    return _finish_map_audit(state, max_per_tile)
