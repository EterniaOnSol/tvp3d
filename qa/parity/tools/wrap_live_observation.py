"""Wrap a tagged OBSERVATION_JSON line from a QA live capture scene into a
full OracleObservationV1 document.

QA-owned. Consumes exactly one line prefixed with 'OBSERVATION_JSON: ' from a
capture log (produced by a Godot capture scene under cliente3d/pruebas/), and
writes the versioned observation file. Never touches credentials: the
capture scene only emits normalized observed facts, never account/password
values, so this wrapper has nothing credential-shaped to avoid in the first
place other than defending against surprises via a generic secret-pattern
scan.

Hardened in Phase 2B.2.1: the capture log MUST contain exactly one tagged
line (zero or two-or-more are both rejected as errors, never silently
resolved by picking the first match), the tagged payload MUST be a JSON
object, every --source-evidence path is validated against the same
repository-relative rules already published for OracleObservationV1, and the
destination file is written atomically (temp file in the same directory,
then os.replace) so a failure never leaves a truncated/partial output and
never overwrites a pre-existing output on error.

Usage:
    py -3 qa/parity/tools/wrap_live_observation.py \
        --capture-log PATH \
        --fixture-id PARITY-MONSTER-CORPSE-001 \
        --oracle TVP_772 --oracle-version 7.72 \
        --source-evidence docs/qa/PARITY_PHASE2B21_CAPTURE_HARDENING.md \
        --output qa/parity/observations/tvp772/death_corpse_loot/live/parity-monster-corpse-001.observation.json
    py -3 qa/parity/tools/wrap_live_observation.py --selftest
"""

import argparse
import json
import os
import re
import sys
import tempfile

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

TAG = "OBSERVATION_JSON: "

SECRET_PATTERNS = (
    re.compile(r"BEGIN (RSA )?PRIVATE KEY"),
    re.compile(r"password\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
    re.compile(r"api[_-]?key\s*[:=]\s*['\"][^'\"]+['\"]", re.IGNORECASE),
)


class WrapError(ValueError):
    """A structural or validation defect. Caller must not write output."""


def _scan_for_secrets(obj):
    if isinstance(obj, str):
        return any(p.search(obj) for p in SECRET_PATTERNS)
    if isinstance(obj, dict):
        return any(_scan_for_secrets(v) for v in obj.values())
    if isinstance(obj, list):
        return any(_scan_for_secrets(v) for v in obj)
    return False


def _is_repo_relative(path_str):
    """Same repository-relative rules already published for
    OracleObservationV1.source_evidence[].logical_path: non-empty, no
    leading '/', no Windows drive letter, no backslash, no '..' segment."""
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


def validate_source_evidence(paths, repo_root=REPO_ROOT):
    """Raises WrapError on any invalid or non-existent evidence path."""
    if not paths:
        raise WrapError("--source-evidence requires at least one path")
    for path_str in paths:
        if not _is_repo_relative(path_str):
            raise WrapError(
                "source-evidence path is not repository-relative: %r" % (path_str,)
            )
        resolved = os.path.join(repo_root, path_str.replace("/", os.sep))
        if not os.path.isfile(resolved):
            raise WrapError(
                "source-evidence path does not resolve to an existing file: %r" % (path_str,)
            )


def extract_payload(capture_log_path):
    """Scan the complete capture log for tagged OBSERVATION_JSON lines.

    Raises WrapError if there are zero, more than one, or if the single
    tagged line is not valid JSON or not a JSON object. Never returns a
    silently-chosen "first match" when the log is ambiguous.
    """
    tagged_lines = []
    with open(capture_log_path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n").rstrip("\r")
            if line.startswith(TAG):
                tagged_lines.append(line[len(TAG):])

    if len(tagged_lines) == 0:
        raise WrapError("no OBSERVATION_JSON line found in capture log")
    if len(tagged_lines) > 1:
        raise WrapError(
            "capture log is ambiguous: found %d OBSERVATION_JSON lines, expected exactly 1"
            % len(tagged_lines)
        )

    try:
        payload = json.loads(tagged_lines[0])
    except json.JSONDecodeError as exc:
        raise WrapError("tagged OBSERVATION_JSON line is not valid JSON: %s" % exc)

    if not isinstance(payload, dict):
        raise WrapError("tagged OBSERVATION_JSON payload must be a JSON object")

    return payload


def build_document(payload, fixture_id, oracle, oracle_version, source_evidence_paths):
    return {
        "schema": "tvp3d.qa.oracle_observation",
        "version": "1.0.0",
        "fixture_id": fixture_id,
        "oracle": oracle,
        "oracle_version": oracle_version,
        "capture_origin": "LIVE_ORACLE",
        "source_evidence": [{"logical_path": p} for p in source_evidence_paths],
        "payload": payload,
    }


def write_atomic(document, output_path):
    """Write via a temp file in the same directory, then os.replace(). A
    failure mid-write never leaves a truncated file at output_path, and
    output_path is never touched until the full document is ready."""
    output_dir = os.path.dirname(output_path) or "."
    os.makedirs(output_dir, exist_ok=True)
    fd, tmp_path = tempfile.mkstemp(prefix=".wrap_live_observation_", dir=output_dir)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(document, handle, indent=2, ensure_ascii=False, sort_keys=False)
            handle.write("\n")
        os.replace(tmp_path, output_path)
    except BaseException:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        raise


def run(capture_log, fixture_id, oracle, oracle_version, source_evidence_paths, output_path,
        repo_root=REPO_ROOT):
    payload = extract_payload(capture_log)

    if _scan_for_secrets(payload):
        raise WrapError("secret-shaped literal detected in captured payload; refusing to write")

    validate_source_evidence(source_evidence_paths, repo_root=repo_root)

    document = build_document(payload, fixture_id, oracle, oracle_version, source_evidence_paths)
    write_atomic(document, output_path)
    return document


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-log")
    parser.add_argument("--fixture-id")
    parser.add_argument("--oracle")
    parser.add_argument("--oracle-version")
    parser.add_argument("--source-evidence", action="append")
    parser.add_argument("--output")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args(argv)

    if args.selftest:
        return _selftest()

    required = {
        "--capture-log": args.capture_log,
        "--fixture-id": args.fixture_id,
        "--oracle": args.oracle,
        "--oracle-version": args.oracle_version,
        "--source-evidence": args.source_evidence,
        "--output": args.output,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        parser.error("missing required arguments: %s" % ", ".join(missing))

    try:
        run(args.capture_log, args.fixture_id, args.oracle, args.oracle_version,
            args.source_evidence, args.output)
    except WrapError as exc:
        print("FAIL %s" % exc)
        return 1

    print("OK wrote %s" % args.output)
    return 0


# -----------------------------------------------------------------
# Self-test (in-memory / temp-dir only; never touches real repo files
# except reading existing ones for the positive evidence-path case)
# -----------------------------------------------------------------

def _selftest():
    import shutil

    failures = []

    def check(label, condition):
        if condition:
            print("OK selftest: %s" % label)
        else:
            print("FAIL selftest: %s" % label)
            failures.append(label)

    workdir = tempfile.mkdtemp(prefix="wrap_live_observation_selftest_")
    try:
        real_evidence_rel = "docs/qa/PRUEBA_VIVA_MUERTE_LOOT.md"

        def write_log(name, lines):
            path = os.path.join(workdir, name)
            with open(path, "w", encoding="utf-8", newline="\n") as handle:
                for line in lines:
                    handle.write(line + "\n")
            return path

        valid_payload_line = 'OBSERVATION_JSON: {"monster_kind": "rat", "corpse": {"present": true, "name": "dead rat", "openable_container": true}}'

        # zero tagged lines rejected
        log_zero = write_log("zero.log", ["hello", "world"])
        try:
            extract_payload(log_zero)
            check("zero tagged lines rejected", False)
        except WrapError:
            check("zero tagged lines rejected", True)

        # exactly one valid tagged line accepted
        log_one = write_log("one.log", ["noise", valid_payload_line, "trailing"])
        try:
            payload = extract_payload(log_one)
            check("exactly one valid tagged line accepted", payload.get("monster_kind") == "rat")
        except WrapError:
            check("exactly one valid tagged line accepted", False)

        # two tagged lines rejected
        log_two = write_log("two.log", [valid_payload_line, valid_payload_line])
        try:
            extract_payload(log_two)
            check("two tagged lines rejected", False)
        except WrapError:
            check("two tagged lines rejected", True)

        # malformed tagged JSON rejected
        log_malformed = write_log("malformed.log", ["OBSERVATION_JSON: {not valid json"])
        try:
            extract_payload(log_malformed)
            check("malformed tagged JSON rejected", False)
        except WrapError:
            check("malformed tagged JSON rejected", True)

        # tagged JSON array rejected; payload must be object
        log_array = write_log("array.log", ["OBSERVATION_JSON: [1, 2, 3]"])
        try:
            extract_payload(log_array)
            check("tagged JSON array rejected", False)
        except WrapError:
            check("tagged JSON array rejected", True)

        # secret-shaped payload rejected
        try:
            if _scan_for_secrets({"note": "password: 'hunter2'"}):
                raise WrapError("secret")
            check("secret-shaped payload rejected", False)
        except WrapError:
            check("secret-shaped payload rejected", True)

        # absolute POSIX evidence path rejected
        try:
            validate_source_evidence(["/etc/passwd"], repo_root=REPO_ROOT)
            check("absolute POSIX evidence path rejected", False)
        except WrapError:
            check("absolute POSIX evidence path rejected", True)

        # absolute Windows evidence path rejected
        try:
            validate_source_evidence(["C:\\Users\\dell\\secret.md"], repo_root=REPO_ROOT)
            check("absolute Windows evidence path rejected", False)
        except WrapError:
            check("absolute Windows evidence path rejected", True)

        # .. traversal rejected
        try:
            validate_source_evidence(["../outside.md"], repo_root=REPO_ROOT)
            check(".. traversal rejected", False)
        except WrapError:
            check(".. traversal rejected", True)

        # missing evidence file rejected
        try:
            validate_source_evidence(["docs/qa/DOES_NOT_EXIST_SELFTEST.md"], repo_root=REPO_ROOT)
            check("missing evidence file rejected", False)
        except WrapError:
            check("missing evidence file rejected", True)

        # valid evidence path accepted (reads a real, pre-existing repo file)
        try:
            validate_source_evidence([real_evidence_rel], repo_root=REPO_ROOT)
            check("valid repository-relative evidence path accepted", True)
        except WrapError:
            check("valid repository-relative evidence path accepted", False)

        # failure does not overwrite an existing sentinel output file
        output_path = os.path.join(workdir, "sub", "obs.json")
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        sentinel = '{"sentinel": true}\n'
        with open(output_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(sentinel)
        try:
            run(log_zero, "PARITY-SELFTEST-000", "TVP_772", "7.72",
                [real_evidence_rel], output_path, repo_root=REPO_ROOT)
            check("failure does not overwrite existing sentinel output", False)
        except WrapError:
            with open(output_path, "r", encoding="utf-8") as handle:
                content = handle.read()
            check("failure does not overwrite existing sentinel output", content == sentinel)

        # successful atomic output contains LIVE_ORACLE
        output_path2 = os.path.join(workdir, "sub2", "obs.json")
        document = run(log_one, "PARITY-SELFTEST-000", "TVP_772", "7.72",
                        [real_evidence_rel], output_path2, repo_root=REPO_ROOT)
        try:
            with open(output_path2, "r", encoding="utf-8") as handle:
                written = json.load(handle)
            check(
                "successful atomic output contains LIVE_ORACLE",
                written.get("capture_origin") == "LIVE_ORACLE" and document["capture_origin"] == "LIVE_ORACLE",
            )
        except (OSError, json.JSONDecodeError):
            check("successful atomic output contains LIVE_ORACLE", False)

        # no leftover temp files after successful write
        leftover = [f for f in os.listdir(os.path.dirname(output_path2)) if f.startswith(".wrap_live_observation_")]
        check("no leftover temp files after successful write", not leftover)

    finally:
        shutil.rmtree(workdir, ignore_errors=True)

    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
