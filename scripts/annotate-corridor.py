#!/usr/bin/env python3
"""annotate-corridor: drive the docs-health annotate.go pipeline end to end.

Encodes the 2026-10-30 pass's manual loop (emit-keys -> verdict map ->
spec.tsv -> --verify -> apply -> check-rows) and its pitfalls:

- emit-keys prints KEYS to stdout and the matched LINES to stderr; the
  driver pairs them by order and asserts equal lengths BEFORE zip (a
  silent zip truncation once dropped items).
- emit-keys only keys NUMBERED rows, TABLE rows, and CHECKBOXES. Prose
  needs the manual house grammar (`~~line~~ **-> routed ...**`); the
  driver fails loudly listing those lines instead of silently skipping.
- emitted keys are `token@32-char-prefix` substrings; the spec uses them
  verbatim (resolve() prefix/substring-matches them against the file).
- status-items --verify runs FIRST (nothing written); apply only on a
  green verify; check-rows runs last as the table-shape gate.

Usage:
  scripts/annotate-corridor.py FILE VERDICTS.tsv [--dry-run]
      [--allow-missing] [--annotate BIN] [--skip-check-rows]

VERDICTS.tsv: one `LINENO<TAB>verdict` per line; `#` comments allowed.
`--self-test` runs the built-in fixture end to end.
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile

DEFAULT_ANNOTATE = os.path.expanduser(
    "~/.config/crush/skills/docs-health/annotate"
)
SKILL_SOURCE = os.path.expanduser(
    "~/.config/crush/skills/docs-health/assets/annotate.go"
)

KEYED_STDERR = re.compile(r"^(\d+): ")
UNKEYED_STDERR = re.compile(r"^--emit-keys: line (\d+) is not a ")


def find_annotate(override):
    if override:
        return override.split()
    if os.path.isfile(DEFAULT_ANNOTATE) and os.access(DEFAULT_ANNOTATE, os.X_OK):
        return [DEFAULT_ANNOTATE]
    if os.path.isfile(SKILL_SOURCE):
        return ["go", "run", SKILL_SOURCE]
    die(
        "no annotate tool: pass --annotate PATH, or install the docs-health"
        " skill (expected %s)" % DEFAULT_ANNOTATE
    )


def die(msg, code=1):
    print("annotate-corridor: %s" % msg, file=sys.stderr)
    sys.exit(code)


def run_annotate(argv, expect_ok=True):
    proc = subprocess.run(
        argv, capture_output=True, text=True
    )
    if expect_ok and proc.returncode != 0:
        die(
            "annotate %s failed (%d):\n%s%s"
            % (
                " ".join(argv[:2]),
                proc.returncode,
                proc.stdout,
                proc.stderr,
            )
        )
    return proc


def load_verdicts(path):
    verdicts = {}
    with open(path, encoding="utf-8") as fh:
        for lineno, raw in enumerate(fh, 1):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t", 1)
            if len(parts) != 2 or not parts[0].strip().isdigit():
                die(
                    "%s:%d: expected `LINENO<TAB>verdict`, got %r"
                    % (path, lineno, line)
                )
            no = int(parts[0].strip())
            verdict = parts[1].strip()
            if not verdict:
                die("%s:%d: empty verdict" % (path, lineno))
            if no in verdicts:
                die("%s:%d: duplicate line number %d" % (path, lineno, no))
            verdicts[no] = verdict
    if not verdicts:
        die("%s: no verdicts loaded" % path)
    return verdicts


def emit_keys(annotate, path, linenos):
    proc = run_annotate(
        annotate + ["emit-keys", path] + [str(n) for n in sorted(linenos)],
        expect_ok=False,
    )
    if proc.returncode != 0:
        die("emit-keys failed (%d):\n%s%s" % (proc.returncode, proc.stdout, proc.stderr))
    keys = [k for k in proc.stdout.splitlines() if k.strip()]
    keyed, unkeyed = [], []
    for serr in proc.stderr.splitlines():
        m = KEYED_STDERR.match(serr)
        if m:
            keyed.append(int(m.group(1)))
            continue
        m = UNKEYED_STDERR.match(serr)
        if m:
            unkeyed.append(int(m.group(1)))
    if len(keys) != len(keyed):
        die(
            "emit-keys stream desync: %d stdout keys vs %d keyed stderr"
            " lines - refusing to zip (truncation hazard)"
            % (len(keys), len(keyed))
        )
    return dict(zip(keyed, keys)), sorted(unkeyed)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", help="corridor file to annotate")
    ap.add_argument("verdicts", help="LINENO<TAB>verdict spec")
    ap.add_argument("--dry-run", action="store_true", help="verify only, write nothing")
    ap.add_argument(
        "--allow-missing",
        action="store_true",
        help="proceed with keyable lines when some requested lines are prose (manual house-grammar strikes)",
    )
    ap.add_argument("--annotate", default=None, help="annotate binary override")
    ap.add_argument("--skip-check-rows", action="store_true", help="skip the final check-rows gate")
    args = ap.parse_args()

    annotate = find_annotate(args.annotate)
    verdicts = load_verdicts(args.verdicts)

    keyed, unkeyed = emit_keys(annotate, args.file, sorted(verdicts))
    if unkeyed:
        recipe = "\n".join(
            "  line %d: ~~<line text>~~ **-> <verdict>** (manual house grammar)"
            % n for n in unkeyed
        )
        msg = (
            "%d requested line(s) are prose (no mechanical key):\n%s\n"
            "strike those by hand, then re-run without them"
            % (len(unkeyed), recipe)
        )
        if not args.allow_missing:
            die(msg)
        print(msg + "\nproceeding with the %d keyable lines" % len(keyed), file=sys.stderr)

    spec = tempfile.NamedTemporaryFile(
        "w", suffix=".tsv", prefix="annotate-spec-", delete=False
    )
    with spec:
        for no in sorted(keyed):
            spec.write("%s\t%s\n" % (keyed[no], verdicts[no]))
    spec_path = spec.name

    verify = run_annotate(
        annotate + ["status-items", "--verify", args.file, spec_path],
        expect_ok=False,
    )
    if verify.returncode != 0:
        die("verify failed:\n%s%s" % (verify.stdout, verify.stderr))
    print(verify.stdout.strip())

    if args.dry_run:
        os.unlink(spec_path)
        print("dry-run: nothing written")
        return

    apply_res = run_annotate(
        annotate + ["status-items", args.file, spec_path], expect_ok=False
    )
    if apply_res.returncode != 0:
        die("apply failed:\n%s%s" % (apply_res.stdout, apply_res.stderr))
    print(apply_res.stdout.strip())

    if not args.skip_check_rows:
        check = run_annotate(
            annotate + ["check-rows", args.file], expect_ok=False
        )
        if check.returncode != 0:
            die("check-rows gate failed:\n%s%s" % (check.stdout, check.stderr))
        print(check.stdout.strip() or "check-rows: OK")
    os.unlink(spec_path)


def self_test():
    """Run the pipeline against a synthetic fixture and assert shapes."""
    tmp = tempfile.mkdtemp(prefix="annotate-corridor-selftest-")
    corridor = os.path.join(tmp, "corridor.md")
    with open(corridor, "w", encoding="utf-8") as fh:
        fh.write(
            "# report\n\n"
            "1. first numbered item\n"
            "2. second numbered item\n"
            "prose line that no key can match\n"
            "3. third numbered item\n\n"
            "| a | b |\n| --- | --- |\n| k1 | v1 |\n| k2 | v2 |\n\n"
            "- [ ] checkbox one\n"
            "- [x] checkbox two\n"
        )
    # Lines: 3,4 items; 5 prose; 7 item; 10,11 table; 14,15 checkboxes.
    with open(corridor, encoding="utf-8") as fh:
        lines = fh.read().splitlines()
    first_table = next(i for i, ln in enumerate(lines, 1) if ln.startswith("| k1")) 
    first_box = next(i for i, ln in enumerate(lines, 1) if "checkbox one" in ln)
    vpath = os.path.join(tmp, "verdicts.tsv")
    with open(vpath, "w", encoding="utf-8") as fh:
        fh.write("3\tdone\n4\trouted\n%d\tdone\n%d\tdone\n" % (first_table, first_box))

    annotate = find_annotate(None)
    keys, unkeyed = None, None

    proc = subprocess.run(
        annotate + ["emit-keys", corridor, "3", "4", "5", str(first_table), str(first_box)],
        capture_output=True, text=True,
    )
    keys = [k for k in proc.stdout.splitlines() if k.strip()]
    keyed_lines = [
        int(m.group(1))
        for m in (KEYED_STDERR.match(sl) for sl in proc.stderr.splitlines())
        if m
    ]
    unkeyed = [
        int(m.group(1))
        for m in (UNKEYED_STDERR.match(sl) for sl in proc.stderr.splitlines())
        if m
    ]
    assert len(keys) == len(keyed_lines) == 4, (keys, keyed_lines)
    assert unkeyed == [5], unkeyed

    spec = os.path.join(tmp, "spec.tsv")
    with open(spec, "w", encoding="utf-8") as fh:
        for no, key in zip(keyed_lines, keys):
            verdict = {3: "done", 4: "routed", first_table: "done", first_box: "done"}[no]
            fh.write("%s\t%s\n" % (key, verdict))

    v = subprocess.run(
        annotate + ["status-items", "--verify", corridor, spec],
        capture_output=True, text=True,
    )
    assert v.returncode == 0 and "VERIFY OK" in v.stdout, (v.stdout, v.stderr)

    a = subprocess.run(
        annotate + ["status-items", corridor, spec],
        capture_output=True, text=True,
    )
    assert a.returncode == 0 and "annotated 4 items" in a.stdout, (a.stdout, a.stderr)

    with open(corridor, encoding="utf-8") as fh:
        out = fh.read()
    assert "~~1. first numbered item~~ done" in out, out
    assert "~~2. second numbered item~~ routed" in out, out
    assert "prose line that no key can match" in out and "~~prose" not in out, out
    assert out.count("~~") >= 8, out

    c = subprocess.run(
        annotate + ["check-rows", corridor], capture_output=True, text=True
    )
    assert c.returncode == 0, (c.stdout, c.stderr)

    print("self-test PASS: 4 keys, prose refused, verify->apply->check-rows green")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.argv.remove("--self-test")
        self_test()
    else:
        main()
