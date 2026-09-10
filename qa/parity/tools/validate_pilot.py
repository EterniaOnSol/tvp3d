"""Deterministic validator for the Phase 2A LEGACY_PARITY pilot fixtures.

QA-owned pilot harness. Validates tvp3d.qa.parity_fixture/2.0.0 documents
already published by worklog/qa/CONTRATO.md. Does not execute TVP, does not
touch Docker, does not require credentials, and does not mutate any fixture.

Usage:
    py -3 qa/parity/tools/validate_pilot.py
    py -3 qa/parity/tools/validate_pilot.py --selftest
"""

import hashlib
import json
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PILOT_DIR = os.path.join(REPO_ROOT, "qa", "parity", "fixtures", "tvp772", "death_corpse_loot")
MANIFEST_PATH = os.path.join(PILOT_DIR, "manifest.json")
REPORT_PATH = os.path.join(REPO_ROOT, "qa", "parity", "reports", "pilot_death_corpse_loot_report.json")

EXPECTED_SCHEMA = "tvp3d.qa.parity_fixture"
EXPECTED_VERSION = "2.0.0"
EXPECTED_ORACLE = "TVP_772"
EXPECTED_ORACLE_VERSION = "7.72"
CLOSED_CLASSIFICATIONS = (
    "MATCH_EXPECTED",
    "KNOWN_LEGACY_BUG",
    "DELIBERATE_V2_DIFFERENCE",
    "UNRESOLVED",
)
REQUIRED_STRING_FIELDS = (
    "schema",
    "version",
    "fixture_id",
    "oracle",
    "oracle_version",
    "input_action",
    "observed_authoritative_result",
    "determinism_notes",
    "classification",
)
REQUIRED_STRING_LIST_FIELDS = (
    "preconditions",
    "normalization_rules",
    "excluded_nondeterministic_fields",
)
SECRET_PATTERNS = (
    re.compile(r"BEGIN (RSA )?PRIVATE KEY"),
    re.compile(r"password\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
    re.compile(r"api[_-]?key\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
)


class FixtureError(ValueError):
    """Raised when a parity fixture document fails validation."""


def _fail(fixture_id_hint, message):
    raise FixtureError("%s: %s" % (fixture_id_hint or "<unknown>", message))


def _is_repo_relative(path_str):
    if not isinstance(path_str, str) or not path_str:
        return False
    if path_str.startswith("/"):
        return False
    if re.match(r"^[A-Za-z]:[\\/]", path_str):
        return False
    if "\\" in path_str:
        return False
    if ".." in path_str.split("/"):
        return False
    return True


def _scan_for_secrets(obj, fixture_id_hint):
    if isinstance(obj, str):
        for pattern in SECRET_PATTERNS:
            if pattern.search(obj):
                _fail(fixture_id_hint, "secret-shaped literal detected in fixture content")
    elif isinstance(obj, dict):
        for value in obj.values():
            _scan_for_secrets(value, fixture_id_hint)
    elif isinstance(obj, list):
        for value in obj:
            _scan_for_secrets(value, fixture_id_hint)


def validate_fixture_dict(doc):
    """Validate a single parsed ParityFixtureV2 document.

    Raises FixtureError on any violation. Returns nothing on success.
    """
    if not isinstance(doc, dict):
        _fail(None, "fixture document must be a JSON object")

    fixture_id_hint = doc.get("fixture_id") if isinstance(doc.get("fixture_id"), str) else None

    for field in REQUIRED_STRING_FIELDS:
        if field not in doc:
            _fail(fixture_id_hint, "missing required field '%s'" % field)
        if not isinstance(doc[field], str) or not doc[field]:
            _fail(fixture_id_hint, "field '%s' must be a non-empty string" % field)

    for field in REQUIRED_STRING_LIST_FIELDS:
        if field not in doc:
            _fail(fixture_id_hint, "missing required field '%s'" % field)
        value = doc[field]
        if not isinstance(value, list):
            _fail(fixture_id_hint, "field '%s' must be an array" % field)
        for item in value:
            if not isinstance(item, str) or not item:
                _fail(fixture_id_hint, "field '%s' must contain only non-empty strings" % field)

    if doc.get("schema") != EXPECTED_SCHEMA:
        _fail(fixture_id_hint, "schema must be exactly '%s'" % EXPECTED_SCHEMA)
    if doc.get("version") != EXPECTED_VERSION:
        _fail(fixture_id_hint, "version must be exactly '%s'" % EXPECTED_VERSION)
    if doc.get("oracle") != EXPECTED_ORACLE:
        _fail(fixture_id_hint, "oracle must be exactly '%s'" % EXPECTED_ORACLE)
    if doc.get("oracle_version") != EXPECTED_ORACLE_VERSION:
        _fail(fixture_id_hint, "oracle_version must be exactly '%s'" % EXPECTED_ORACLE_VERSION)
    if doc.get("classification") not in CLOSED_CLASSIFICATIONS:
        _fail(fixture_id_hint, "classification must be one of %s" % (CLOSED_CLASSIFICATIONS,))

    source_evidence = doc.get("source_evidence")
    if not isinstance(source_evidence, dict):
        _fail(fixture_id_hint, "source_evidence must be an object")
    logical_path = source_evidence.get("logical_path")
    if not _is_repo_relative(logical_path):
        _fail(fixture_id_hint, "source_evidence.logical_path must be a repository-relative path")
    resolved = os.path.join(REPO_ROOT, logical_path.replace("/", os.sep))
    if not os.path.isfile(resolved):
        _fail(fixture_id_hint, "source_evidence.logical_path does not resolve to an existing file")

    _scan_for_secrets(doc, fixture_id_hint)


def _sha256_of_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        digest.update(handle.read())
    return digest.hexdigest()


def run(write_report=True):
    """Validate the pilot fixture set. Returns (exit_code, report_dict)."""
    if not os.path.isfile(MANIFEST_PATH):
        print("FAIL manifest not found: %s" % MANIFEST_PATH)
        return 1, None

    with open(MANIFEST_PATH, "r", encoding="utf-8") as handle:
        manifest = json.load(handle)

    expected_ids = manifest.get("fixture_ids")
    if not isinstance(expected_ids, list) or not expected_ids:
        print("FAIL manifest.fixture_ids must be a non-empty array")
        return 1, None

    sorted_ids = sorted(expected_ids)
    if expected_ids != sorted_ids:
        print("FAIL manifest.fixture_ids must already be listed in sorted order")
        return 1, None

    seen_ids = set()
    fixtures_report = []
    failures = []

    for fixture_id in sorted_ids:
        filename = fixture_id.lower() + ".json"
        path = os.path.join(PILOT_DIR, filename)
        if not os.path.isfile(path):
            failures.append("%s: expected file %s not found" % (fixture_id, filename))
            continue

        try:
            with open(path, "r", encoding="utf-8") as handle:
                doc = json.load(handle)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            failures.append("%s: invalid UTF-8 JSON (%s)" % (fixture_id, exc))
            continue

        doc_id = doc.get("fixture_id") if isinstance(doc, dict) else None
        if doc_id != fixture_id:
            failures.append(
                "%s: fixture_id in file ('%s') does not match manifest entry" % (fixture_id, doc_id)
            )
            continue

        if doc_id in seen_ids:
            failures.append("%s: duplicate fixture_id" % doc_id)
            continue
        seen_ids.add(doc_id)

        try:
            validate_fixture_dict(doc)
        except FixtureError as exc:
            failures.append(str(exc))
            continue

        fixtures_report.append(
            {
                "fixture_id": fixture_id,
                "logical_path": os.path.relpath(path, REPO_ROOT).replace(os.sep, "/"),
                "sha256": _sha256_of_file(path),
                "classification": doc["classification"],
                "status": "VALID",
            }
        )

    if len(fixtures_report) != manifest.get("fixture_count"):
        failures.append(
            "manifest.fixture_count (%s) does not match validated fixture count (%s)"
            % (manifest.get("fixture_count"), len(fixtures_report))
        )

    report = {
        "pilot_id": manifest.get("pilot_id"),
        "harness": "qa/parity/tools/validate_pilot.py",
        "fixture_schema_checked": "%s/%s" % (EXPECTED_SCHEMA, EXPECTED_VERSION),
        "oracle": EXPECTED_ORACLE,
        "oracle_version": EXPECTED_ORACLE_VERSION,
        "fixtures_validated": len(fixtures_report),
        "fixtures": fixtures_report,
        "failures": failures,
        "result": "VALID" if not failures else "INVALID",
    }

    if write_report:
        os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
        with open(REPORT_PATH, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(report, handle, indent=2, ensure_ascii=False, sort_keys=False)
            handle.write("\n")

    for failure in failures:
        print("FAIL " + failure)
    if not failures:
        print("OK %d fixtures validated (%s/%s)" % (len(fixtures_report), EXPECTED_SCHEMA, EXPECTED_VERSION))

    return (0 if not failures else 1), report


def _selftest():
    """Exercise validate_fixture_dict() against deliberately malformed
    in-memory documents. Never writes a malformed file to disk.

    Exits non-zero if the validator FAILS to reject any malformed case
    (i.e. the validator itself is broken), 0 if every malformed case was
    correctly rejected.
    """
    base = {
        "schema": EXPECTED_SCHEMA,
        "version": EXPECTED_VERSION,
        "fixture_id": "PARITY-SELFTEST-000",
        "oracle": EXPECTED_ORACLE,
        "oracle_version": EXPECTED_ORACLE_VERSION,
        "source_evidence": {"logical_path": "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"},
        "preconditions": ["x"],
        "input_action": "x",
        "observed_authoritative_result": "x",
        "normalization_rules": ["x"],
        "determinism_notes": "x",
        "excluded_nondeterministic_fields": ["x"],
        "classification": "MATCH_EXPECTED",
    }

    def _mutate(**overrides):
        doc = dict(base)
        doc.update(overrides)
        return doc

    malformed_cases = [
        ("wrong schema", _mutate(schema="tvp3d.qa.something_else")),
        ("wrong version", _mutate(version="2.0.1")),
        ("wrong oracle", _mutate(oracle="TVP_774")),
        ("wrong oracle_version", _mutate(oracle_version="7.4")),
        ("unknown classification", _mutate(classification="MATCH_NATIVE_V2")),
        ("missing input_action", {k: v for k, v in base.items() if k != "input_action"}),
        ("absolute windows path", _mutate(source_evidence={"logical_path": "C:\\Users\\dell\\secret.md"})),
        ("absolute posix path", _mutate(source_evidence={"logical_path": "/etc/passwd"})),
        ("nonexistent evidence file", _mutate(source_evidence={"logical_path": "docs/qa/DOES_NOT_EXIST.md"})),
        ("secret literal", _mutate(determinism_notes="password: 'hunter2'")),
        ("preconditions not a list", _mutate(preconditions="not-a-list")),
    ]

    all_rejected = True
    for label, doc in malformed_cases:
        try:
            validate_fixture_dict(doc)
        except FixtureError:
            print("OK selftest correctly rejected: %s" % label)
        else:
            print("FAIL selftest did NOT reject: %s" % label)
            all_rejected = False

    return 0 if all_rejected else 1


if __name__ == "__main__":
    if "--selftest" in sys.argv:
        sys.exit(_selftest())
    exit_code, _ = run()
    sys.exit(exit_code)
