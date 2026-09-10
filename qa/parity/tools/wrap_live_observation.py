"""Wrap a tagged OBSERVATION_JSON line from a QA live capture scene into a
full OracleObservationV1 document.

QA-owned. Consumes exactly one line prefixed with 'OBSERVATION_JSON: ' from a
capture log (produced by a Godot capture scene under cliente3d/pruebas/), and
writes the versioned observation file. Never touches credentials: the
capture scene only emits normalized observed facts, never account/password
values, so this wrapper has nothing credential-shaped to avoid in the first
place other than defending against surprises via a generic secret-pattern
scan.

Usage:
    py -3 qa/parity/tools/wrap_live_observation.py \
        --capture-log PATH \
        --fixture-id PARITY-MONSTER-CORPSE-001 \
        --oracle TVP_772 --oracle-version 7.72 \
        --source-evidence docs/qa/PARITY_PHASE2B2_LIVE_MONSTER_CORPSE.md \
        --output qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json
"""

import argparse
import json
import re
import sys

TAG = "OBSERVATION_JSON: "

SECRET_PATTERNS = (
    re.compile(r"BEGIN (RSA )?PRIVATE KEY"),
    re.compile(r"password\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
    re.compile(r"api[_-]?key\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
)


def _scan_for_secrets(obj):
    if isinstance(obj, str):
        return any(p.search(obj) for p in SECRET_PATTERNS)
    if isinstance(obj, dict):
        return any(_scan_for_secrets(v) for v in obj.values())
    if isinstance(obj, list):
        return any(_scan_for_secrets(v) for v in obj)
    return False


def extract_payload(capture_log_path):
    with open(capture_log_path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if line.startswith(TAG):
                return json.loads(line[len(TAG):])
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-log", required=True)
    parser.add_argument("--fixture-id", required=True)
    parser.add_argument("--oracle", required=True)
    parser.add_argument("--oracle-version", required=True)
    parser.add_argument("--source-evidence", action="append", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)

    payload = extract_payload(args.capture_log)
    if payload is None:
        print("FAIL no OBSERVATION_JSON line found in capture log")
        return 1

    if _scan_for_secrets(payload):
        print("FAIL secret-shaped literal detected in captured payload; refusing to write")
        return 1

    document = {
        "schema": "tvp3d.qa.oracle_observation",
        "version": "1.0.0",
        "fixture_id": args.fixture_id,
        "oracle": args.oracle,
        "oracle_version": args.oracle_version,
        "capture_origin": "LIVE_ORACLE",
        "source_evidence": [{"logical_path": p} for p in args.source_evidence],
        "payload": payload,
    }

    with open(args.output, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(document, handle, indent=2, ensure_ascii=False, sort_keys=False)
        handle.write("\n")

    print("OK wrote %s" % args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
