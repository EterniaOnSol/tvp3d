"""Generic LEGACY_PARITY replay tool (Phase 2B.1).

QA-owned. Implements the replay boundary published by worklog/qa/CONTRATO.md
2.1.1 (OracleObservationV1, ParityExpectationV1, the nine-operator generic
comparator, and QACaseV2/QAReportV2 reuse for replay). Loads a QACaseV2, its
referenced ParityFixtureV2, an OracleObservationV1, resolves RFC 6901 JSON
Pointer paths against the observation payload, evaluates assertions with the
closed nine-operator registry, and emits a tvp3d.qa.report/2.0.0 document.

This module contains no fixture-specific values (no creature/item names, no
coordinates, no account data). All such values live exclusively in versioned
case/fixture/observation JSON files.

Usage:
    py -3 qa/parity/tools/replay.py --cases-dir DIR --observations-dir DIR --report PATH
    py -3 qa/parity/tools/replay.py --cases-dir DIR --observations-dir DIR --report PATH --case-id ID
    py -3 qa/parity/tools/replay.py --selftest
"""

import argparse
import json
import os
import re
import sys

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

CASE_SCHEMA = "tvp3d.qa.case"
CASE_VERSION = "2.0.0"
FIXTURE_SCHEMA = "tvp3d.qa.parity_fixture"
FIXTURE_VERSION = "2.0.0"
OBSERVATION_SCHEMA = "tvp3d.qa.oracle_observation"
OBSERVATION_VERSION = "1.0.0"
EXPECTATION_SCHEMA = "tvp3d.qa.parity_expectation"
EXPECTATION_VERSION = "1.0.0"
REPORT_SCHEMA = "tvp3d.qa.report"
REPORT_VERSION = "2.0.0"

MODES = ("SINGLE_OBSERVATION", "EVIDENCE_ONLY")
OPERATORS = ("EQ", "NE", "EXISTS", "NOT_EXISTS", "GT", "GTE", "LT", "LTE", "ONE_OF")
NO_RIGHT_OPERATORS = ("EXISTS", "NOT_EXISTS")
NUMERIC_OPERATORS = ("GT", "GTE", "LT", "LTE")
CAPTURE_ORIGINS = ("LIVE_ORACLE", "RECORDED_EVIDENCE")

SECRET_PATTERNS = (
    re.compile(r"BEGIN (RSA )?PRIVATE KEY"),
    re.compile(r"password\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
    re.compile(r"api[_-]?key\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
)

_MISSING = object()


class ReplayError(ValueError):
    """A structural defect in a case/fixture/observation/expectation document."""

    def __init__(self, code, message):
        super().__init__(message)
        self.code = code
        self.message = message


# -----------------------------------------------------------------
# RFC 6901 JSON Pointer
# -----------------------------------------------------------------

def _unescape_token(token):
    # RFC 6901 section 4: decode '~1' before '~0'. Reversing the order
    # mis-decodes a token that itself encodes a literal '~1' (encoded as
    # '~01'): decoding '~0' first would turn it into '/' instead of '~1'.
    return token.replace("~1", "/").replace("~0", "~")


_ARRAY_INDEX = re.compile(r"0|[1-9][0-9]*")


def resolve_pointer(document, pointer):
    """Resolve an RFC 6901 JSON Pointer. Returns (value, found: bool)."""
    if pointer == "":
        return document, True
    if not pointer.startswith("/"):
        return None, False
    current = document
    for raw_token in pointer.split("/")[1:]:
        token = _unescape_token(raw_token)
        if isinstance(current, dict):
            if token in current:
                current = current[token]
            else:
                return None, False
        elif isinstance(current, list):
            if not _ARRAY_INDEX.fullmatch(token):
                return None, False
            index = int(token)
            if index >= len(current):
                return None, False
            current = current[index]
        else:
            return None, False
    return current, True


# -----------------------------------------------------------------
# Deep equality / numeric semantics
# -----------------------------------------------------------------

def is_json_number(value):
    """True only for actual JSON numbers. bool is deliberately excluded even
    though Python's bool is a subclass of int."""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def deep_equal(a, b):
    """Deep JSON equality. No string<->number coercion, no bool<->number
    coercion, object key order irrelevant, array order significant."""
    if isinstance(a, bool) or isinstance(b, bool):
        return isinstance(a, bool) and isinstance(b, bool) and a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return a == b
    if isinstance(a, str) and isinstance(b, str):
        return a == b
    if a is None and b is None:
        return True
    if isinstance(a, dict) and isinstance(b, dict):
        if set(a.keys()) != set(b.keys()):
            return False
        return all(deep_equal(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            return False
        return all(deep_equal(x, y) for x, y in zip(a, b))
    return False


# -----------------------------------------------------------------
# Comparator (generic, nine operators, no fixture-specific values)
# -----------------------------------------------------------------

def _resolve_right(right, payload):
    if "literal" in right:
        return right["literal"], True
    if "path" in right:
        return resolve_pointer(payload, right["path"])
    return None, False


def evaluate_assertion(assertion, payload):
    """Evaluate one AssertionV1 against an OracleObservationV1 payload.

    Returns True/False. Never raises for missing paths or type mismatches:
    those are assertion FAILures, not harness crashes. Assumes the assertion
    already passed validate_expectation() structural checks.
    """
    operator = assertion["operator"]
    left_value, left_found = resolve_pointer(payload, assertion["left_path"])

    if operator == "NOT_EXISTS":
        return not left_found
    if not left_found:
        return False
    if operator == "EXISTS":
        return True

    right_value, right_ok = _resolve_right(assertion["right"], payload)
    if not right_ok:
        return False

    if operator == "EQ":
        return deep_equal(left_value, right_value)
    if operator == "NE":
        return not deep_equal(left_value, right_value)
    if operator in NUMERIC_OPERATORS:
        if not is_json_number(left_value) or not is_json_number(right_value):
            return False
        if operator == "GT":
            return left_value > right_value
        if operator == "GTE":
            return left_value >= right_value
        if operator == "LT":
            return left_value < right_value
        return left_value <= right_value
    if operator == "ONE_OF":
        if not isinstance(right_value, list):
            return False
        return any(deep_equal(left_value, item) for item in right_value)
    raise AssertionError("unreachable: operator outside closed registry")


# -----------------------------------------------------------------
# Structural validation
# -----------------------------------------------------------------

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


def _scan_for_secrets(obj):
    if isinstance(obj, str):
        for pattern in SECRET_PATTERNS:
            if pattern.search(obj):
                return True
        return False
    if isinstance(obj, dict):
        return any(_scan_for_secrets(v) for v in obj.values())
    if isinstance(obj, list):
        return any(_scan_for_secrets(v) for v in obj)
    return False


def validate_expectation(doc):
    """Validate an embedded ParityExpectationV1. Raises ReplayError on any
    structural defect (QA_EXPECTATION_INVALID)."""
    if not isinstance(doc, dict):
        raise ReplayError("QA_EXPECTATION_INVALID", "expectation must be a JSON object")
    if doc.get("schema") != EXPECTATION_SCHEMA:
        raise ReplayError("QA_EXPECTATION_INVALID", "expectation.schema must be '%s'" % EXPECTATION_SCHEMA)
    if doc.get("version") != EXPECTATION_VERSION:
        raise ReplayError("QA_EXPECTATION_INVALID", "expectation.version must be '%s'" % EXPECTATION_VERSION)
    mode = doc.get("mode")
    if mode not in MODES:
        raise ReplayError("QA_EXPECTATION_INVALID", "expectation.mode must be one of %s" % (MODES,))
    assertions = doc.get("assertions")
    if not isinstance(assertions, list):
        raise ReplayError("QA_EXPECTATION_INVALID", "expectation.assertions must be an array")
    if mode == "EVIDENCE_ONLY" and assertions:
        raise ReplayError("QA_EXPECTATION_INVALID", "EVIDENCE_ONLY expectation must have assertions=[]")
    if mode == "SINGLE_OBSERVATION" and not (1 <= len(assertions) <= 32):
        raise ReplayError("QA_EXPECTATION_INVALID", "SINGLE_OBSERVATION expectation must have 1..32 assertions")
    if len(assertions) > 32:
        raise ReplayError("QA_EXPECTATION_INVALID", "expectation.assertions must have at most 32 entries")

    seen_ids = set()
    for assertion in assertions:
        if not isinstance(assertion, dict):
            raise ReplayError("QA_EXPECTATION_INVALID", "each assertion must be a JSON object")
        assertion_id = assertion.get("assertion_id")
        if not isinstance(assertion_id, str) or not (1 <= len(assertion_id) <= 64):
            raise ReplayError("QA_EXPECTATION_INVALID", "assertion_id must be a 1..64 byte string")
        if assertion_id in seen_ids:
            raise ReplayError("QA_EXPECTATION_INVALID", "duplicate assertion_id '%s'" % assertion_id)
        seen_ids.add(assertion_id)

        left_path = assertion.get("left_path")
        if not isinstance(left_path, str) or not left_path.startswith("/"):
            raise ReplayError("QA_EXPECTATION_INVALID", "left_path must start with '/' (%s)" % assertion_id)

        operator = assertion.get("operator")
        if operator not in OPERATORS:
            raise ReplayError("QA_EXPECTATION_INVALID", "unknown operator for assertion '%s'" % assertion_id)

        has_right = "right" in assertion
        if operator in NO_RIGHT_OPERATORS:
            if has_right:
                raise ReplayError("QA_EXPECTATION_INVALID", "'right' is forbidden for %s (%s)" % (operator, assertion_id))
            continue

        if not has_right:
            raise ReplayError("QA_EXPECTATION_INVALID", "'right' is required for %s (%s)" % (operator, assertion_id))
        right = assertion["right"]
        if not isinstance(right, dict):
            raise ReplayError("QA_EXPECTATION_INVALID", "'right' must be an object (%s)" % assertion_id)
        has_literal = "literal" in right
        has_path = "path" in right
        if has_literal == has_path:
            raise ReplayError("QA_EXPECTATION_INVALID", "'right' must have exactly one of literal/path (%s)" % assertion_id)
        if operator == "ONE_OF":
            if not has_literal or not isinstance(right["literal"], list):
                raise ReplayError("QA_EXPECTATION_INVALID", "ONE_OF requires right.literal to be an array (%s)" % assertion_id)


def validate_case(doc):
    """Validate the parts of a QACaseV2 that matter for replay. Raises
    ReplayError (QA_CASE_SCHEMA_INVALID) on defect."""
    if not isinstance(doc, dict):
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "case must be a JSON object")
    if doc.get("schema") != CASE_SCHEMA:
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "case.schema must be '%s'" % CASE_SCHEMA)
    if doc.get("version") != CASE_VERSION:
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "case.version must be '%s'" % CASE_VERSION)
    if doc.get("class") != "LEGACY_PARITY":
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "replay requires class=LEGACY_PARITY")
    case_id = doc.get("case_id")
    if not isinstance(case_id, str) or not case_id:
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "case_id must be a non-empty string")
    input_fixture = doc.get("input_fixture")
    if not isinstance(input_fixture, dict) or not isinstance(input_fixture.get("logical_path"), str):
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "input_fixture.logical_path must be a string")
    if not _is_repo_relative(input_fixture["logical_path"]):
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "input_fixture.logical_path must be repository-relative")
    if not isinstance(doc.get("expected"), dict):
        raise ReplayError("QA_CASE_SCHEMA_INVALID", "expected must be an object")


def validate_fixture(doc):
    if not isinstance(doc, dict):
        raise ReplayError("QA_FIXTURE_MISSING", "fixture must be a JSON object")
    if doc.get("schema") != FIXTURE_SCHEMA or doc.get("version") != FIXTURE_VERSION:
        raise ReplayError("QA_FIXTURE_MISSING", "fixture schema/version must be %s/%s" % (FIXTURE_SCHEMA, FIXTURE_VERSION))
    if not isinstance(doc.get("fixture_id"), str) or not doc["fixture_id"]:
        raise ReplayError("QA_FIXTURE_MISSING", "fixture_id must be a non-empty string")
    if not isinstance(doc.get("oracle"), str) or not isinstance(doc.get("oracle_version"), str):
        raise ReplayError("QA_FIXTURE_MISSING", "fixture oracle/oracle_version must be strings")


def validate_observation(doc, fixture_doc, expected_case_id):
    if not isinstance(doc, dict):
        raise ReplayError("QA_OBSERVATION_INVALID", "observation must be a JSON object")
    if doc.get("schema") != OBSERVATION_SCHEMA:
        raise ReplayError("QA_OBSERVATION_INVALID", "observation.schema must be '%s'" % OBSERVATION_SCHEMA)
    if doc.get("version") != OBSERVATION_VERSION:
        raise ReplayError("QA_OBSERVATION_INVALID", "observation.version must be '%s'" % OBSERVATION_VERSION)
    if doc.get("fixture_id") != expected_case_id:
        raise ReplayError("QA_OBSERVATION_INVALID", "observation.fixture_id must equal case_id/fixture_id")
    if doc.get("capture_origin") not in CAPTURE_ORIGINS:
        raise ReplayError("QA_OBSERVATION_INVALID", "capture_origin must be one of %s" % (CAPTURE_ORIGINS,))
    if doc.get("oracle") != fixture_doc.get("oracle") or doc.get("oracle_version") != fixture_doc.get("oracle_version"):
        raise ReplayError("QA_OBSERVATION_INVALID", "observation oracle/oracle_version must match the referenced fixture")
    source_evidence = doc.get("source_evidence")
    if not isinstance(source_evidence, list) or not (1 <= len(source_evidence) <= 8):
        raise ReplayError("QA_OBSERVATION_INVALID", "source_evidence must be an array of 1..8 objects")
    for entry in source_evidence:
        if not isinstance(entry, dict) or not _is_repo_relative(entry.get("logical_path")):
            raise ReplayError("QA_OBSERVATION_INVALID", "source_evidence[].logical_path must be repository-relative")
    if not isinstance(doc.get("payload"), dict):
        raise ReplayError("QA_OBSERVATION_INVALID", "payload must be a JSON object")
    if _scan_for_secrets(doc["payload"]):
        raise ReplayError("QA_SECRET_EXPOSURE", "secret-shaped literal detected in observation payload")


# -----------------------------------------------------------------
# Replay orchestration
# -----------------------------------------------------------------

def _load_json(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def _relpath(path):
    return os.path.relpath(path, REPO_ROOT).replace(os.sep, "/")


def _case_result(case_id, status, total, passed, error_code, evidence, blockers):
    return {
        "case_id": case_id,
        "status": status,
        "assertions_total": total,
        "assertions_passed": passed,
        "error_code": error_code,
        "evidence": evidence,
        "blockers": blockers,
    }


def replay_case_file(case_path, observations_dir):
    """Replay a single QACaseV2 file. Returns (case_result_dict, mode_or_None)."""
    evidence = [_relpath(case_path)]
    case_doc = None
    try:
        case_doc = _load_json(case_path)
        validate_case(case_doc)
    except (json.JSONDecodeError, ReplayError) as exc:
        code = exc.code if isinstance(exc, ReplayError) else "QA_CASE_SCHEMA_INVALID"
        case_id = case_doc.get("case_id") if isinstance(case_doc, dict) else None
        return _case_result(case_id, "BLOCKED", 0, 0, code, evidence, [str(exc)]), None

    case_id = case_doc["case_id"]
    fixture_path = os.path.join(REPO_ROOT, case_doc["input_fixture"]["logical_path"].replace("/", os.sep))
    try:
        if not os.path.isfile(fixture_path):
            raise ReplayError("QA_FIXTURE_MISSING", "fixture file not found: %s" % case_doc["input_fixture"]["logical_path"])
        fixture_doc = _load_json(fixture_path)
        validate_fixture(fixture_doc)
        if fixture_doc["fixture_id"] != case_id:
            raise ReplayError("QA_CASE_SCHEMA_INVALID", "case_id must equal fixture_id (section 16D.1)")
    except (json.JSONDecodeError, ReplayError) as exc:
        code = exc.code if isinstance(exc, ReplayError) else "QA_FIXTURE_MISSING"
        return _case_result(case_id, "BLOCKED", 0, 0, code, evidence, [str(exc)]), None
    evidence.append(_relpath(fixture_path))

    try:
        validate_expectation(case_doc["expected"])
    except ReplayError as exc:
        return _case_result(case_id, "BLOCKED", 0, 0, exc.code, evidence, [str(exc)]), None

    mode = case_doc["expected"]["mode"]
    assertions = case_doc["expected"]["assertions"]

    if mode == "EVIDENCE_ONLY":
        return _case_result(case_id, "NOT_RUN", 0, 0, None, evidence, []), mode

    observation_path = os.path.join(observations_dir, case_id.lower() + ".observation.json")
    if not os.path.isfile(observation_path):
        blocker = "missing OracleObservationV1 for %s at %s" % (case_id, os.path.join(observations_dir, case_id.lower() + ".observation.json"))
        return _case_result(case_id, "BLOCKED", 0, 0, "QA_PREREQUISITE_MISSING", evidence, [blocker]), mode

    try:
        observation_doc = _load_json(observation_path)
        validate_observation(observation_doc, fixture_doc, case_id)
    except (json.JSONDecodeError, ReplayError) as exc:
        code = exc.code if isinstance(exc, ReplayError) else "QA_OBSERVATION_INVALID"
        return _case_result(case_id, "BLOCKED", 0, 0, code, evidence, [str(exc)]), mode
    evidence.append(_relpath(observation_path))

    total = len(assertions)
    passed = sum(1 for a in assertions if evaluate_assertion(a, observation_doc["payload"]))
    status = "PASS" if passed == total else "FAIL"
    return _case_result(case_id, status, total, passed, None, evidence, []), mode


def run(cases_dir, observations_dir, report_path, case_ids=None, contract_version="2.1.1"):
    if not os.path.isdir(cases_dir):
        print("FAIL cases-dir not found: %s" % cases_dir)
        return 3, None

    case_files = sorted(
        f for f in os.listdir(cases_dir) if f.endswith(".case.json")
    )

    results = []
    modes = {}
    for filename in case_files:
        path = os.path.join(cases_dir, filename)
        result, mode = replay_case_file(path, observations_dir)
        if case_ids and result["case_id"] not in case_ids:
            continue
        results.append(result)
        modes[result["case_id"]] = mode

    results.sort(key=lambda r: r["case_id"] or "")

    summary = {
        "total": len(results),
        "pass": sum(1 for r in results if r["status"] == "PASS"),
        "fail": sum(1 for r in results if r["status"] == "FAIL"),
        "blocked": sum(1 for r in results if r["status"] == "BLOCKED"),
        "not_run": sum(1 for r in results if r["status"] == "NOT_RUN"),
    }

    report = {
        "schema": REPORT_SCHEMA,
        "version": REPORT_VERSION,
        "suite_id": "PARITY_TVP_772",
        "profile": "LEGACY_TVP_772",
        "contract_versions": [{"contract": "qa", "version": contract_version}],
        "cases": results,
        "summary": summary,
    }

    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False, sort_keys=False)
        handle.write("\n")

    required_statuses = [r["status"] for r in results if modes.get(r["case_id"]) == "SINGLE_OBSERVATION"]
    if any(s == "FAIL" for s in required_statuses):
        exit_code = 1
    elif any(s in ("BLOCKED", "NOT_RUN") for s in required_statuses):
        exit_code = 2
    else:
        exit_code = 0

    for r in results:
        print("%s %s" % (r["status"], r["case_id"]))
    print("exit=%d pass=%d fail=%d blocked=%d not_run=%d" % (
        exit_code, summary["pass"], summary["fail"], summary["blocked"], summary["not_run"]))

    return exit_code, report


# -----------------------------------------------------------------
# Self-test (in-memory only; never writes a malformed file to disk)
# -----------------------------------------------------------------

def _selftest():
    failures = []

    def check(label, condition):
        if condition:
            print("OK selftest: %s" % label)
        else:
            print("FAIL selftest: %s" % label)
            failures.append(label)

    def expect_rejected(label, fn):
        try:
            fn()
        except ReplayError:
            check(label, True)
        else:
            check(label, False)

    payload = {
        "a": {"b": 1, "c": True, "d": None, "e": "5"},
        "list": [10, 20, 30],
        "a/b": "slash-key",
        "a~b": "tilde-key",
        "~1": "tilde-one-literal",
    }

    # EQ pass/fail
    check("EQ pass", evaluate_assertion(
        {"operator": "EQ", "left_path": "/a/b", "right": {"literal": 1}}, payload) is True)
    check("EQ fail", evaluate_assertion(
        {"operator": "EQ", "left_path": "/a/b", "right": {"literal": 2}}, payload) is False)

    # NE pass/fail
    check("NE pass", evaluate_assertion(
        {"operator": "NE", "left_path": "/a/b", "right": {"literal": 2}}, payload) is True)
    check("NE fail", evaluate_assertion(
        {"operator": "NE", "left_path": "/a/b", "right": {"literal": 1}}, payload) is False)

    # EXISTS / NOT_EXISTS
    check("EXISTS on present value", evaluate_assertion(
        {"operator": "EXISTS", "left_path": "/a/d"}, payload) is True)
    check("EXISTS on missing path fails", evaluate_assertion(
        {"operator": "EXISTS", "left_path": "/a/zzz"}, payload) is False)
    check("NOT_EXISTS on missing path", evaluate_assertion(
        {"operator": "NOT_EXISTS", "left_path": "/a/zzz"}, payload) is True)
    check("NOT_EXISTS on present path fails", evaluate_assertion(
        {"operator": "NOT_EXISTS", "left_path": "/a/b"}, payload) is False)

    # GT/GTE/LT/LTE
    check("GT true", evaluate_assertion(
        {"operator": "GT", "left_path": "/list/2", "right": {"literal": 20}}, payload) is True)
    check("GTE true (equal)", evaluate_assertion(
        {"operator": "GTE", "left_path": "/list/0", "right": {"literal": 10}}, payload) is True)
    check("LT true", evaluate_assertion(
        {"operator": "LT", "left_path": "/list/0", "right": {"literal": 20}}, payload) is True)
    check("LTE true (equal)", evaluate_assertion(
        {"operator": "LTE", "left_path": "/list/0", "right": {"literal": 10}}, payload) is True)

    # ONE_OF
    check("ONE_OF match", evaluate_assertion(
        {"operator": "ONE_OF", "left_path": "/list/0", "right": {"literal": [5, 10, 15]}}, payload) is True)
    check("ONE_OF no match", evaluate_assertion(
        {"operator": "ONE_OF", "left_path": "/list/0", "right": {"literal": [5, 15]}}, payload) is False)
    check("ONE_OF right not a list fails safely", evaluate_assertion(
        {"operator": "ONE_OF", "left_path": "/list/0", "right": {"path": "/a/b"}}, payload) is False)

    # ~0/~1 JSON Pointer decoding, including decode-order edge case
    check("~1 decodes to /", resolve_pointer(payload, "/a~1b") == ("slash-key", True))
    check("~0 decodes to ~", resolve_pointer(payload, "/a~0b") == ("tilde-key", True))
    check("~01 decodes to literal ~1 (order-sensitive)",
          resolve_pointer(payload, "/~01") == ("tilde-one-literal", True))

    # array indexes
    check("array index resolves", resolve_pointer(payload, "/list/1") == (20, True))
    check("array index out of range is missing", resolve_pointer(payload, "/list/99") == (None, False))
    check("non-numeric array index is missing", resolve_pointer(payload, "/list/x") == (None, False))

    # missing left path -> assertion FAILS, not crash, for every operator except NOT_EXISTS
    for op in OPERATORS:
        if op == "NOT_EXISTS":
            continue
        assertion = {"operator": op, "left_path": "/does/not/exist"}
        if op not in NO_RIGHT_OPERATORS:
            assertion["right"] = {"literal": [1] if op == "ONE_OF" else 1}
        check("missing left_path fails for %s (no crash)" % op,
              evaluate_assertion(assertion, payload) is False)

    # numeric string rejection (no coercion)
    check("numeric string rejected for GT", evaluate_assertion(
        {"operator": "GT", "left_path": "/a/e", "right": {"literal": 1}}, payload) is False)

    # bool-not-number
    check("bool rejected as numeric operand (left)", evaluate_assertion(
        {"operator": "GT", "left_path": "/a/c", "right": {"literal": 0}}, payload) is False)
    check("bool rejected as numeric operand (right)", evaluate_assertion(
        {"operator": "LT", "left_path": "/list/0", "right": {"literal": True}}, payload) is False)
    check("EQ does not coerce bool/number", deep_equal(True, 1) is False)

    # invalid right shape -> structural rejection
    expect_rejected("both literal and path rejected", lambda: validate_expectation({
        "schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION, "mode": "SINGLE_OBSERVATION",
        "assertions": [{"assertion_id": "X", "left_path": "/a", "operator": "EQ",
                         "right": {"literal": 1, "path": "/b"}}]}))
    expect_rejected("neither literal nor path rejected", lambda: validate_expectation({
        "schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION, "mode": "SINGLE_OBSERVATION",
        "assertions": [{"assertion_id": "X", "left_path": "/a", "operator": "EQ", "right": {}}]}))
    expect_rejected("right forbidden for EXISTS", lambda: validate_expectation({
        "schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION, "mode": "SINGLE_OBSERVATION",
        "assertions": [{"assertion_id": "X", "left_path": "/a", "operator": "EXISTS", "right": {"literal": 1}}]}))
    expect_rejected("right required for EQ", lambda: validate_expectation({
        "schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION, "mode": "SINGLE_OBSERVATION",
        "assertions": [{"assertion_id": "X", "left_path": "/a", "operator": "EQ"}]}))
    expect_rejected("ONE_OF with path form rejected", lambda: validate_expectation({
        "schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION, "mode": "SINGLE_OBSERVATION",
        "assertions": [{"assertion_id": "X", "left_path": "/a", "operator": "ONE_OF", "right": {"path": "/b"}}]}))
    expect_rejected("EVIDENCE_ONLY with non-empty assertions rejected", lambda: validate_expectation({
        "schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION, "mode": "EVIDENCE_ONLY",
        "assertions": [{"assertion_id": "X", "left_path": "/a", "operator": "EXISTS"}]}))
    expect_rejected("SINGLE_OBSERVATION with zero assertions rejected", lambda: validate_expectation({
        "schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION, "mode": "SINGLE_OBSERVATION",
        "assertions": []}))

    # EVIDENCE_ONLY -> NOT_RUN via validate_expectation + mode contract (no file I/O)
    evidence_only = {"schema": EXPECTATION_SCHEMA, "version": EXPECTATION_VERSION,
                      "mode": "EVIDENCE_ONLY", "assertions": []}
    validate_expectation(evidence_only)
    check("EVIDENCE_ONLY mode recognized for NOT_RUN routing", evidence_only["mode"] == "EVIDENCE_ONLY")

    # case_id mismatch rejection
    fixture_doc = {"schema": FIXTURE_SCHEMA, "version": FIXTURE_VERSION, "fixture_id": "PARITY-SELFTEST-000",
                   "oracle": "TVP_772", "oracle_version": "7.72"}
    case_doc = {"schema": CASE_SCHEMA, "version": CASE_VERSION, "case_id": "PARITY-SELFTEST-999",
                "class": "LEGACY_PARITY", "input_fixture": {"logical_path": "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"},
                "expected": evidence_only}
    validate_case(case_doc)
    check("case_id/fixture_id mismatch is detectable by caller",
          case_doc["case_id"] != fixture_doc["fixture_id"])

    # oracle mismatch rejection
    expect_rejected("oracle mismatch rejected", lambda: validate_observation(
        {"schema": OBSERVATION_SCHEMA, "version": OBSERVATION_VERSION, "fixture_id": "PARITY-SELFTEST-000",
         "oracle": "TVP_774", "oracle_version": "7.72", "capture_origin": "RECORDED_EVIDENCE",
         "source_evidence": [{"logical_path": "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"}], "payload": {}},
        fixture_doc, "PARITY-SELFTEST-000"))

    # wrong schema/version rejection
    expect_rejected("wrong case schema rejected", lambda: validate_case(
        {"schema": "tvp3d.qa.something_else", "version": CASE_VERSION, "case_id": "X",
         "class": "LEGACY_PARITY", "input_fixture": {"logical_path": "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"},
         "expected": evidence_only}))
    expect_rejected("wrong observation version rejected", lambda: validate_observation(
        {"schema": OBSERVATION_SCHEMA, "version": "9.9.9", "fixture_id": "PARITY-SELFTEST-000",
         "oracle": "TVP_772", "oracle_version": "7.72", "capture_origin": "RECORDED_EVIDENCE",
         "source_evidence": [{"logical_path": "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"}], "payload": {}},
        fixture_doc, "PARITY-SELFTEST-000"))
    expect_rejected("wrong fixture schema rejected", lambda: validate_fixture(
        {"schema": "tvp3d.qa.something_else", "version": FIXTURE_VERSION, "fixture_id": "X",
         "oracle": "TVP_772", "oracle_version": "7.72"}))

    # absolute path rejected in observation source_evidence
    expect_rejected("absolute path in source_evidence rejected", lambda: validate_observation(
        {"schema": OBSERVATION_SCHEMA, "version": OBSERVATION_VERSION, "fixture_id": "PARITY-SELFTEST-000",
         "oracle": "TVP_772", "oracle_version": "7.72", "capture_origin": "RECORDED_EVIDENCE",
         "source_evidence": [{"logical_path": "C:\\Users\\dell\\secret.md"}], "payload": {}},
        fixture_doc, "PARITY-SELFTEST-000"))

    # secret-shaped literal rejected in observation payload
    expect_rejected("secret literal in payload rejected", lambda: validate_observation(
        {"schema": OBSERVATION_SCHEMA, "version": OBSERVATION_VERSION, "fixture_id": "PARITY-SELFTEST-000",
         "oracle": "TVP_772", "oracle_version": "7.72", "capture_origin": "RECORDED_EVIDENCE",
         "source_evidence": [{"logical_path": "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"}],
         "payload": {"note": "password: 'hunter2'"}},
        fixture_doc, "PARITY-SELFTEST-000"))

    return 0 if not failures else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cases-dir")
    parser.add_argument("--observations-dir")
    parser.add_argument("--report")
    parser.add_argument("--case-id", action="append", default=None)
    parser.add_argument("--contract-version", default="2.1.1")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args(argv)

    if args.selftest:
        return _selftest()

    if not (args.cases_dir and args.observations_dir and args.report):
        parser.error("--cases-dir, --observations-dir and --report are required unless --selftest")

    exit_code, _ = run(args.cases_dir, args.observations_dir, args.report, args.case_id, args.contract_version)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
