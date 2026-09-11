"""Qualify isolated TVP 7.72 test terrain for the monster-reacquisition slice.

QA-owned, standard library only. Reuses `herramientas/leer_otbm.py` READ-ONLY
to parse the legacy map; it never writes to any legacy source file.

Why this tool exists
--------------------
Phase 2C could not certify `PARITY-MONSTER-REACQUISITION-001` live because
the historical test field sits inside natural cave-rat activity: wild cave
rats kept entering the measurement window, making attacker identity
ambiguous, and the accumulated damage killed a low-level test player. The
fix is NOT to clear wildlife (that mutates unrelated legacy state) but to
find a genuinely quiet pair of test positions in the EXISTING world.

Authoritative constants derived from the legacy source (never guessed)
---------------------------------------------------------------------
* Client visibility (`servidor/src/protocolgame.cpp:766-767`, using
  `Map::maxClientViewportX/Y` from `servidor/src/map.h:181-182`): on the same
  floor a position is visible when
  `dx in [-8, +9]` and `dy in [-6, +7]` relative to the observer.
* Server spectator range (`servidor/src/map.cpp:434-437` defaults, using
  `Map::maxViewportX/Y` from `servidor/src/map.h:179-180`): 11 on both axes.
  This is the wider of the two, so it is the one used as the visibility
  radius for safety math.
* Monster roaming bound (`Spawns::isInZone`,
  `servidor/src/spawn.cpp:222-231`): a CHEBYSHEV box, `dx <= radius` and
  `dy <= radius` around the spawn center. `servidor/config.lua` sets
  `allowMonsterOverspawn = true`, which makes `Monster::isInSpawnRange`
  (`servidor/src/monster.cpp:1727-1735`) actually apply that bound instead of
  short-circuiting, so spawn radius is a real static bound on where a spawned
  monster can be.

Static data sources parsed
--------------------------
* `servidor/data/world/map.otbm` (tile existence, protection-zone flag,
  house tiles) via `herramientas/leer_otbm.py`.
* `servidor/data/world/map-spawn.xml` (`tvpspawn` entries).
* `servidor/data/spawns.dat` (`Spawn (...)` / `Npc (...)` entries; note its
  radii differ from, and are often larger than, the XML ones, so both files
  are parsed and the union is used).
* `servidor/data/world/map-house.xml` (house ids, cross-check).
* `servidor/data/raids/*.xml` (`areaspawn` + `monster`).

Usage:
    py -3 qa/parity/tools/qualify_reacquisition_terrain.py \
        --center-x 32082 --center-y 32145 --radius 400 --floors 6,7 \
        --report qa/parity/reports/reacquisition_terrain_candidates.json
"""

import argparse
import hashlib
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO_ROOT, "herramientas"))

import leer_otbm  # noqa: E402  (read-only reuse of the published OTBM reader)

MAP_OTBM = os.path.join(REPO_ROOT, "servidor", "data", "world", "map.otbm")
MAP_SPAWN_XML = os.path.join(REPO_ROOT, "servidor", "data", "world", "map-spawn.xml")
MAP_HOUSE_XML = os.path.join(REPO_ROOT, "servidor", "data", "world", "map-house.xml")
SPAWNS_DAT = os.path.join(REPO_ROOT, "servidor", "data", "spawns.dat")
RAIDS_DIR = os.path.join(REPO_ROOT, "servidor", "data", "raids")

# --- constants derived from legacy source, see module docstring ---
CLIENT_VIEWPORT_X = 8   # Map::maxClientViewportX
CLIENT_VIEWPORT_Y = 6   # Map::maxClientViewportY
SERVER_VIEWPORT = 11    # Map::maxViewportX / maxViewportY (the wider bound)

# Extra margin on top of (spawn radius + visibility). Covers chase//pull
# behaviour that the static bound cannot fully model and the duration of a
# measurement run. Chosen conservatively, documented in the report.
SPAWN_SAFETY_MARGIN = 10

# Minimum per-axis separation between the two test points. Both axes must
# exceed this. It is far beyond the widest visibility bound (11), so the
# target is guaranteed to leave the visible set when the player relocates.
DEFAULT_MIN_SEPARATION = 30

SPAWN_DAT_RE = re.compile(
    r'^(Spawn|Npc)\s*\(\s*\[\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*\]\s*,\s*"([^"]*)"(.*)$'
)


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def cheb(ax, ay, bx, by):
    return max(abs(ax - bx), abs(ay - by))


# -----------------------------------------------------------------
# Spawn sources
# -----------------------------------------------------------------

def parse_map_spawn_xml(path):
    """Returns (monster_spawns, npc_spawns, problems)."""
    monsters, npcs, problems = [], [], []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        problems.append("map-spawn.xml unparseable: %s" % exc)
        return monsters, npcs, problems

    for node in root.iter():
        if node.tag != "tvpspawn":
            continue
        try:
            x = int(node.attrib["centerx"])
            y = int(node.attrib["centery"])
            z = int(node.attrib["centerz"])
            radius = int(node.attrib.get("radius", 0))
        except (KeyError, ValueError) as exc:
            problems.append("tvpspawn with unusable attributes: %s" % exc)
            continue
        if "monstername" in node.attrib:
            monsters.append({"x": x, "y": y, "z": z, "radius": radius,
                             "name": node.attrib["monstername"],
                             "source": "map-spawn.xml"})
        elif "npcname" in node.attrib:
            npcs.append({"x": x, "y": y, "z": z, "radius": radius,
                         "name": node.attrib["npcname"],
                         "source": "map-spawn.xml"})
        else:
            problems.append("tvpspawn without monstername/npcname at (%d,%d,%d)" % (x, y, z))
    return monsters, npcs, problems


def parse_spawns_dat(path):
    """`Spawn ([x,y,z], "Name", amount, radius, spawntime)` / `Npc ([x,y,z], "name")`."""
    monsters, npcs, problems = [], [], []
    with open(path, "r", encoding="latin-1") as handle:
        for lineno, raw in enumerate(handle, start=1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            match = SPAWN_DAT_RE.match(line)
            if not match:
                problems.append("spawns.dat line %d not understood" % lineno)
                continue
            kind, xs, ys, zs, name, rest = match.groups()
            x, y, z = int(xs), int(ys), int(zs)
            if kind == "Npc":
                npcs.append({"x": x, "y": y, "z": z, "radius": 0,
                             "name": name, "source": "spawns.dat"})
                continue
            numbers = re.findall(r"-?\d+", rest)
            if len(numbers) < 2:
                problems.append("spawns.dat line %d: Spawn without amount/radius" % lineno)
                continue
            radius = int(numbers[1])
            monsters.append({"x": x, "y": y, "z": z, "radius": radius,
                             "name": name, "source": "spawns.dat"})
    return monsters, npcs, problems


def parse_raids(directory):
    """All raid files use only <areaspawn ...><monster .../></areaspawn>."""
    areas, problems = [], []
    known_tags = {"raid", "raids", "announce", "areaspawn", "monster", "loot"}
    for filename in sorted(os.listdir(directory)):
        if not filename.lower().endswith(".xml"):
            continue
        path = os.path.join(directory, filename)
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as exc:
            problems.append("raid file %s unparseable: %s" % (filename, exc))
            continue
        for node in root.iter():
            if node.tag not in known_tags:
                problems.append("raid file %s: unsupported element <%s>" % (filename, node.tag))
                continue
            if node.tag != "areaspawn":
                continue
            try:
                x = int(node.attrib["centerx"])
                y = int(node.attrib["centery"])
                z = int(node.attrib["centerz"])
                radius = int(node.attrib.get("radius", 0))
            except (KeyError, ValueError) as exc:
                problems.append("raid file %s: areaspawn with unusable attributes: %s" % (filename, exc))
                continue
            names = sorted({m.attrib.get("name", "?") for m in node.findall("monster")})
            areas.append({"x": x, "y": y, "z": z, "radius": radius,
                          "names": names, "source": "raids/" + filename})
    return areas, problems


def parse_house_xml(path):
    ids, problems = set(), []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as exc:
        problems.append("map-house.xml unparseable: %s" % exc)
        return ids, problems
    for node in root.iter("house"):
        try:
            ids.add(int(node.attrib["houseid"]))
        except (KeyError, ValueError):
            problems.append("house entry without usable houseid")
    return ids, problems


# -----------------------------------------------------------------
# Map scan
# -----------------------------------------------------------------

def scan_map(center_x, center_y, radius, floors):
    """Collect in-bounds tiles with their PZ/house status.

    Bounded traversal built on the PUBLISHED `leer_otbm` primitives
    (`Stream`, its escape handling, its node/attribute constants). The parser
    itself is not rewritten or modified: this only adds an area-level bounds
    filter so that tile areas outside the search window are skipped wholesale
    with `Stream.skip_node_body()` instead of being fully decoded.

    That filter matters: `leer_otbm.recorrer` decodes every item attribute of
    every tile in a 65000x65000 world, which does not finish in a practical
    time for this search. Inside the bounds we only need tile coordinates,
    tile flags and house id, so inline items are consumed as their bare
    server id (exactly what `_read_item(..., read_attributes=False)` does)
    and child item nodes are skipped.
    """
    lo_x, hi_x = center_x - radius, center_x + radius
    lo_y, hi_y = center_y - radius, center_y + radius
    wanted_floors = set(floors)
    tiles = {}

    with open(MAP_OTBM, "rb") as handle:
        data = handle.read()
    if len(data) < 4:
        raise leer_otbm.OTBMParseError("OTBM_TRUNCATED_HEADER")

    s = leer_otbm.Stream(data[4:])
    if not s.start_node():
        raise ValueError("no se pudo leer el nodo raiz")
    s.pos += 1
    s.get_u32()                 # version
    ancho = s.get_u16()
    alto = s.get_u16()
    s.get_u32()                 # item major version
    s.get_u32()                 # item minor version

    areas = 0
    areas_scanned = 0
    if s.start_node(leer_otbm.OTBM_MAP_DATA):
        while True:
            attr = s.get_u8()
            if attr in (1, 2, 11, 13):
                s.get_string()
            else:
                s.back()
                break

        while s.start_node(leer_otbm.OTBM_TILE_AREA):
            areas += 1
            base_x = s.get_u16()
            base_y = s.get_u16()
            base_z = s.get_u8()
            # An OTBM tile area addresses a 256x256 block from its base.
            if (base_z not in wanted_floors
                    or base_x > hi_x or base_x + 255 < lo_x
                    or base_y > hi_y or base_y + 255 < lo_y):
                s.skip_node_body()
                continue
            areas_scanned += 1
            _scan_area_tiles(s, base_x, base_y, base_z, lo_x, hi_x, lo_y, hi_y, tiles)

    return tiles, {"ancho": ancho, "alto": alto, "areas": areas,
                   "areas_scanned": areas_scanned}


def _scan_area_tiles(s, base_x, base_y, base_z, lo_x, hi_x, lo_y, hi_y, tiles):
    """Walk the tiles of one in-bounds area using `leer_otbm` primitives."""
    while s.start_node():
        node_type = s.get_u8()
        if node_type not in (leer_otbm.OTBM_TILE, leer_otbm.OTBM_HOUSETILE):
            s.skip_node_body()
            continue
        x = base_x + s.get_u8()
        y = base_y + s.get_u8()
        z = base_z
        house_id = 0
        if node_type == leer_otbm.OTBM_HOUSETILE:
            house_id = s.get_u32()

        flags = 0
        has_ground = False
        while True:
            attr = s.get_u8()
            if attr in (leer_otbm.START, leer_otbm.END):
                s.back()
                break
            if attr == leer_otbm.OTBM_ATTR_TILE_FLAGS:
                flags = s.get_u32()
            elif attr == leer_otbm.OTBM_ATTR_ITEM:
                s.get_u16()     # inline ground item: bare server id only
                has_ground = True
            else:
                raise leer_otbm.OTBMParseError(
                    "OTBM_UNSUPPORTED_ATTRIBUTE attr=%d context=tile(%d,%d,%d)"
                    % (attr, x, y, z))

        # Child item nodes carry no information this qualifier needs; their
        # presence still proves the tile has content. Both the children and
        # the tile's own END marker are consumed in one pass with the
        # published `skip_node_body()` primitive.
        saw_child = s.pos < len(s.data) and s.data[s.pos] == leer_otbm.START
        s.skip_node_body()

        if not (has_ground or saw_child):
            continue
        if lo_x <= x <= hi_x and lo_y <= y <= hi_y:
            tiles[(x, y, z)] = {
                "pz": bool(flags & leer_otbm.OTBM_TILEFLAG_PROTECTIONZONE),
                "house_id": int(house_id),
                "has_ground_item": has_ground,
            }

    if not s.end_node():
        raise leer_otbm.OTBMParseError("OTBM_INVALID_NODE area")


# -----------------------------------------------------------------
# Qualification
# -----------------------------------------------------------------

def nearest(entries, x, y, z):
    """Nearest same-floor entry by Chebyshev distance, and its clearance
    (distance minus that entry's roam radius)."""
    best = None
    for entry in entries:
        if entry["z"] != z:
            continue
        distance = cheb(x, y, entry["x"], entry["y"])
        clearance = distance - entry.get("radius", 0)
        if best is None or clearance < best["clearance"]:
            label = entry.get("name")
            if label is None:
                label = ",".join(entry.get("names", [])) or "?"
            best = {
                "distance": distance,
                "clearance": clearance,
                "radius": entry.get("radius", 0),
                "name": label,
                "source": entry["source"],
            }
    return best


def qualify_point(x, y, z, tiles, monsters, raids, npcs, required_clearance):
    """Returns (ok, record). `record` always explains rejections."""
    reasons = []
    tile = tiles.get((x, y, z))
    if tile is None:
        return False, {"x": x, "y": y, "z": z, "tile_exists": False,
                       "rejection_reasons": ["tile does not exist in map.otbm"]}
    if tile["pz"]:
        reasons.append("tile is a protection zone")
    if tile["house_id"] != 0:
        reasons.append("tile belongs to house id %d" % tile["house_id"])

    near_monster = nearest(monsters, x, y, z)
    near_raid = nearest(raids, x, y, z)
    near_npc = nearest(npcs, x, y, z)

    if near_monster is None:
        reasons.append("no static monster spawn on this floor to measure against")
    elif near_monster["clearance"] < required_clearance:
        reasons.append(
            "static monster spawn clearance %d < required %d (nearest '%s' r=%d at cheb %d)"
            % (near_monster["clearance"], required_clearance, near_monster["name"],
               near_monster["radius"], near_monster["distance"]))

    if near_raid is not None and near_raid["clearance"] < required_clearance:
        reasons.append(
            "raid spawn clearance %d < required %d (nearest '%s' r=%d at cheb %d)"
            % (near_raid["clearance"], required_clearance, near_raid["name"],
               near_raid["radius"], near_raid["distance"]))

    record = {
        "x": x, "y": y, "z": z,
        "tile_exists": True,
        "protection_zone": tile["pz"],
        "house_id": tile["house_id"],
        "nearest_static_monster_spawn": near_monster,
        "nearest_raid_spawn": near_raid,
        "nearest_npc_spawn": near_npc,
        "rejection_reasons": reasons,
    }
    return (not reasons), record


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--center-x", type=int, default=32082)
    parser.add_argument("--center-y", type=int, default=32145)
    parser.add_argument("--radius", type=int, default=400)
    parser.add_argument("--floors", default="6,7")
    parser.add_argument("--min-separation", type=int, default=DEFAULT_MIN_SEPARATION)
    parser.add_argument("--top", type=int, default=3)
    parser.add_argument("--pool", type=int, default=150,
                        help="most-isolated qualified tiles considered when forming pairs")
    parser.add_argument("--report", required=True)
    args = parser.parse_args(argv)

    floors = sorted({int(v) for v in args.floors.split(",") if v.strip()})

    xml_monsters, xml_npcs, problems_xml = parse_map_spawn_xml(MAP_SPAWN_XML)
    dat_monsters, dat_npcs, problems_dat = parse_spawns_dat(SPAWNS_DAT)
    raid_areas, problems_raids = parse_raids(RAIDS_DIR)
    house_ids, problems_house = parse_house_xml(MAP_HOUSE_XML)

    monsters = xml_monsters + dat_monsters
    npcs = xml_npcs + dat_npcs
    source_problems = problems_xml + problems_dat + problems_raids + problems_house

    max_radius = max([m["radius"] for m in monsters] + [r["radius"] for r in raid_areas] + [0])
    required_clearance = SERVER_VIEWPORT + SPAWN_SAFETY_MARGIN

    tiles, map_info = scan_map(args.center_x, args.center_y, args.radius, floors)

    qualified, rejected_sample = [], []
    for (x, y, z) in sorted(tiles.keys()):
        ok, record = qualify_point(x, y, z, tiles, monsters, raid_areas, npcs,
                                   required_clearance)
        if ok:
            near_m = record["nearest_static_monster_spawn"]
            near_r = record["nearest_raid_spawn"]
            clearances = [near_m["clearance"]]
            if near_r is not None:
                clearances.append(near_r["clearance"])
            record["isolation_score"] = min(clearances)
            qualified.append(record)
        elif len(rejected_sample) < 20:
            rejected_sample.append(record)

    # Deterministic ordering: most isolated first, then coordinates.
    qualified.sort(key=lambda r: (-r["isolation_score"], r["z"], r["x"], r["y"]))

    # Spatial bucketing before pairing. Without it the "most isolated" tiles
    # are all neighbours of one another (adjacent tiles share almost the same
    # clearance), so no two of them could ever satisfy the per-axis
    # separation requirement. One representative per bucket of
    # `min_separation` keeps the pool spread across the search window while
    # staying fully deterministic.
    bucket_size = max(1, args.min_separation)
    best_per_bucket = {}
    for record in qualified:
        key = (record["z"], record["x"] // bucket_size, record["y"] // bucket_size)
        if key not in best_per_bucket:
            best_per_bucket[key] = record
    pool = sorted(
        best_per_bucket.values(),
        key=lambda r: (-r["isolation_score"], r["z"], r["x"], r["y"]),
    )[: args.pool]

    pairs = []
    for i in range(len(pool)):
        for j in range(i + 1, len(pool)):
            a, b = pool[i], pool[j]
            if a["z"] != b["z"]:
                continue
            dx = abs(a["x"] - b["x"])
            dy = abs(a["y"] - b["y"])
            if dx < args.min_separation or dy < args.min_separation:
                continue
            pairs.append({
                "point_a": a,
                "point_b": b,
                "separation_dx": dx,
                "separation_dy": dy,
                "visibility_margin_x": dx - (CLIENT_VIEWPORT_X + 1),
                "visibility_margin_y": dy - (CLIENT_VIEWPORT_Y + 1),
                "server_spectator_margin": min(dx, dy) - SERVER_VIEWPORT,
                "pair_isolation_score": min(a["isolation_score"], b["isolation_score"]),
                "static_qualification": "CANDIDATE",
            })

    pairs.sort(key=lambda p: (
        -p["pair_isolation_score"],
        -min(p["separation_dx"], p["separation_dy"]),
        p["point_a"]["z"], p["point_a"]["x"], p["point_a"]["y"],
        p["point_b"]["x"], p["point_b"]["y"],
    ))
    top = pairs[: args.top]

    report = {
        "tool": "qa/parity/tools/qualify_reacquisition_terrain.py",
        "purpose": "qualify isolated TVP 7.72 terrain for PARITY-MONSTER-REACQUISITION-001",
        "derived_rules": {
            "client_viewport_x": CLIENT_VIEWPORT_X,
            "client_viewport_y": CLIENT_VIEWPORT_Y,
            "client_visible_dx_range": [-CLIENT_VIEWPORT_X, CLIENT_VIEWPORT_X + 1],
            "client_visible_dy_range": [-CLIENT_VIEWPORT_Y, CLIENT_VIEWPORT_Y + 1],
            "server_spectator_range": SERVER_VIEWPORT,
            "spawn_roam_bound": "chebyshev box of spawn radius (Spawns::isInZone)",
            "spawn_safety_margin": SPAWN_SAFETY_MARGIN,
            "required_spawn_clearance": required_clearance,
            "required_min_separation_per_axis": args.min_separation,
            "largest_spawn_radius_seen": max_radius,
            "source_references": [
                "servidor/src/map.h:179-182",
                "servidor/src/protocolgame.cpp:766-767",
                "servidor/src/map.cpp:434-437",
                "servidor/src/spawn.cpp:222-231",
                "servidor/src/monster.cpp:1727-1735",
                "servidor/config.lua allowMonsterOverspawn",
            ],
        },
        "search": {
            "center_x": args.center_x, "center_y": args.center_y,
            "radius": args.radius, "floors": floors,
            "tiles_in_bounds": len(tiles),
            "qualified_tiles": len(qualified),
            "pairs_evaluated": len(pairs),
            "pool_size_for_pairing": len(pool),
        },
        "sources": {
            "map_otbm": {"logical_path": "servidor/data/world/map.otbm",
                         "sha256": sha256_file(MAP_OTBM),
                         "areas": map_info["areas"],
                         "areas_scanned_in_bounds": map_info["areas_scanned"]},
            "map_spawn_xml": {"logical_path": "servidor/data/world/map-spawn.xml",
                              "sha256": sha256_file(MAP_SPAWN_XML),
                              "monster_spawns": len(xml_monsters),
                              "npc_spawns": len(xml_npcs)},
            "spawns_dat": {"logical_path": "servidor/data/spawns.dat",
                           "sha256": sha256_file(SPAWNS_DAT),
                           "monster_spawns": len(dat_monsters),
                           "npc_spawns": len(dat_npcs)},
            "map_house_xml": {"logical_path": "servidor/data/world/map-house.xml",
                              "sha256": sha256_file(MAP_HOUSE_XML),
                              "houses": len(house_ids)},
            "raids": {"logical_path": "servidor/data/raids/",
                      "files": len([f for f in sorted(os.listdir(RAIDS_DIR))
                                    if f.lower().endswith(".xml")]),
                      "areaspawns": len(raid_areas)},
        },
        "source_problems": sorted(source_problems),
        "top_candidate_pairs": top,
        "rejected_sample": rejected_sample,
    }

    os.makedirs(os.path.dirname(args.report), exist_ok=True)
    with open(args.report, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False, sort_keys=False)
        handle.write("\n")

    print("tiles in bounds: %d | qualified tiles: %d | pairs: %d | top: %d"
          % (len(tiles), len(qualified), len(pairs), len(top)))
    if source_problems:
        print("SOURCE PROBLEMS (%d) - full qualification is blocked until resolved:"
              % len(source_problems))
        for problem in sorted(source_problems)[:10]:
            print("  - %s" % problem)
    for index, pair in enumerate(top, start=1):
        a, b = pair["point_a"], pair["point_b"]
        print("#%d A=(%d,%d,%d) B=(%d,%d,%d) dx=%d dy=%d isolation=%d"
              % (index, a["x"], a["y"], a["z"], b["x"], b["y"], b["z"],
                 pair["separation_dx"], pair["separation_dy"],
                 pair["pair_isolation_score"]))
    print("report: %s" % args.report)
    return 0 if top else 1


if __name__ == "__main__":
    sys.exit(main())
