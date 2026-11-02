#!/usr/bin/env python3
"""README version lockstep lint.

The README's status block is the one place that states WHICH versions this
flake is verified against ("Stalwart **0.16.26**, parsedmarc **11.0.2**").
Historically that sentence was hand-maintained prose, so a pin advance could
land in flake.lock and in the module defaults while the README kept claiming
the old pair - a front door that lies about what it ships.

This check compares the two canonical anchors in the status blockquote
against the versions the flake actually builds. Deliberately scoped: only the
status block is canonical. Other `0.16.x` mentions in the README are HISTORY
("0.16.22 until the 2026-10-28 advance", the delta table) and must stay
untouched - a blanket textual check would fail on correct prose.

Fail-closed on absence: if the anchors cannot be found the check fails, so a
rewording cannot silently disable it.

Usage:
  check-readme-versions.py --readme README.md \\
      --stalwart 0.16.26 --parsedmarc 11.0.2
  check-readme-versions.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys

STATUS_MARKER = "**Status ("
STALWART_RE = re.compile(r"Stalwart \*\*(\d+\.\d+\.\d+)\*\*")
PARSEDMARC_RE = re.compile(r"parsedmarc \*\*(\d+\.\d+\.\d+)\*\*")


def status_block(text: str) -> list[str]:
    """Return the blockquote lines that carry the status block."""
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if STATUS_MARKER in line and line.lstrip().startswith(">"):
            block = []
            for follow in lines[index:]:
                if not follow.lstrip().startswith(">"):
                    break
                block.append(follow)
            return block
    return []


def anchor(block: list[str], pattern: re.Pattern[str], label: str) -> tuple[str | None, str | None]:
    """Return (version, error) for one canonical version anchor."""
    joined = "\n".join(block)
    matches = pattern.findall(joined)
    if not matches:
        return None, f"status block does not state {label} (no `{label} **x.y.z**` anchor)"
    if len(set(matches)) > 1:
        return None, f"status block states {label} more than once with different values: {sorted(set(matches))}"
    return matches[0], None


def check(text: str, stalwart: str, parsedmarc: str) -> list[str]:
    """Return the list of findings for one README body."""
    block = status_block(text)
    if not block:
        return ["no status blockquote (`> **Status (`...) found - the version anchors are gone"]
    findings = []
    for pattern, label, expected in (
        (STALWART_RE, "Stalwart", stalwart),
        (PARSEDMARC_RE, "parsedmarc", parsedmarc),
    ):
        found, error = anchor(block, pattern, label)
        if error:
            findings.append(error)
        elif found != expected:
            findings.append(f"README says {label} {found}, the flake builds {label} {expected}")
    return findings


def self_test() -> int:
    good = (
        "# T\n\n"
        "> **Status (2026-10-28 pin advance):** Stalwart **0.16.26**,\n"
        "> parsedmarc **11.0.2**, full check set green.\n"
        "> The delta table below keeps 0.16.22 as history.\n"
    )
    cases = [
        ("correct pair", good, "0.16.26", "11.0.2", []),
        (
            "drifted stalwart",
            good,
            "0.16.27",
            "11.0.2",
            ["README says Stalwart 0.16.26, the flake builds Stalwart 0.16.27"],
        ),
        (
            "drifted parsedmarc",
            good,
            "0.16.26",
            "11.0.3",
            ["README says parsedmarc 11.0.2, the flake builds parsedmarc 11.0.3"],
        ),
        (
            "missing anchors",
            "# T\n\nno status block here\n",
            "0.16.26",
            "11.0.2",
            [
                "no status blockquote (`> **Status (`...) found - the version anchors are gone"
            ],
        ),
        (
            "partially missing anchor",
            "# T\n\n> **Status (2026-10-28):** Stalwart **0.16.26** only.\n",
            "0.16.26",
            "11.0.2",
            ["status block does not state parsedmarc (no `parsedmarc **x.y.z**` anchor)"],
        ),
    ]
    failed = 0
    for name, text, stalwart, parsedmarc, expected in cases:
        actual = check(text, stalwart, parsedmarc)
        if actual != expected:
            print(f"FATAL: self-test case {name!r} produced {actual!r}, expected {expected!r}")
            failed = 1
    if failed:
        return 1
    print(f"check-readme-versions: self-test passed ({len(cases)} cases)")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--readme", help="README to check")
    parser.add_argument("--stalwart", help="Stalwart version the flake builds")
    parser.add_argument("--parsedmarc", help="parsedmarc version the flake builds")
    parser.add_argument("--self-test", action="store_true", help="prove the check can fail")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    missing = [
        flag
        for flag, value in (
            ("--readme", args.readme),
            ("--stalwart", args.stalwart),
            ("--parsedmarc", args.parsedmarc),
        )
        if not value
    ]
    if missing:
        print(f"check-readme-versions: missing required {', '.join(missing)}", file=sys.stderr)
        return 2

    with open(args.readme, encoding="utf-8") as handle:
        text = handle.read()

    findings = check(text, args.stalwart, args.parsedmarc)
    for finding in findings:
        print(f"offender: {args.readme}: {finding}")
    if findings:
        return 1
    print(
        "check-readme-versions: README status block matches the pin "
        f"(Stalwart {args.stalwart}, parsedmarc {args.parsedmarc})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
