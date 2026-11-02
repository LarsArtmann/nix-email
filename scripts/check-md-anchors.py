#!/usr/bin/env python3
"""Front-door integrity lint: in-file anchors and `## Contents` completeness.

The README is 1600+ lines and 39% of it is the verified-facts ledger (owner
decision C52 keeps it there), so the `## Contents` table is the only
navigation. It is load-bearing and must fail a build when it rots instead of
needing a session to notice.

Two independent checks per file, both scoped to links that point INSIDE the
same file (a `README.md#anchor` cross-file destination is another file's
problem and is not inspected):

1. ANCHOR RESOLUTION. Every in-file anchor must match a heading. Recognised
   anchor forms:
     * inline link destinations - `[text](#slug)`, with an optional
       `"title"` after the destination;
     * reference definitions - `[label]: #slug`;
     * HTML links - `href="#slug"` (single or double quotes).
   Percent-encoded destinations are decoded before comparison. Fenced code
   blocks and inline code spans are ignored; indented (4-space) code blocks
   and HTML comments are NOT modelled (see "Known blind spots").

2. TOC COMPLETENESS. When the file carries a `## Contents` heading, every
   other level-2 heading must be listed EXACTLY ONCE between that heading and
   the next level-1/2 heading. A missing row hides a section; a duplicated
   row is drift; a row that names no heading is caught by check 1.

Slugs follow the GitHub slugger: lowercase, strip everything that is not a
Unicode letter, mark or number, nor a space, hyphen or underscore, then turn
each space into a hyphen (so `## Grüße & Maß` is `#grüße--maß` and
`## Errata — corrections` is `#errata--corrections`). Repeated headings get
`-1`, `-2`, ... suffixes.

Known blind spots, stated rather than hidden: cross-file `path#anchor` links,
Setext (`===`/`---`) headings, 4-space indented code blocks, HTML comments,
and anchors inside `<code>` elements. Archived corridors are linted like
everything else; if a future rule ever makes a frozen snapshot fail, the
corridor's append-only policy wins (add a correction note, or exclude that
file here with the reason written down) - never rewrite the snapshot.

Fail-closed: prints every offender as `file:line` and exits 1.

Usage:
  check-md-anchors.py                     # every git-tracked *.md
  check-md-anchors.py README.md docs/...  # exactly these files
  check-md-anchors.py --self-test         # prove both directions still fire
  check-md-anchors.py --quiet README.md   # offenders only, no success line
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
import unicodedata
from pathlib import Path
from urllib.parse import unquote

FENCE_RE = re.compile(r"^\s*(```|~~~)")
HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.*)$")
INLINE_ANCHOR_RE = re.compile(r"\]\(\s*(#[^)\s]*)")
REF_DEF_ANCHOR_RE = re.compile(r"^\s{0,3}\[[^\]]+\]:\s*(#[^\s]*)")
HTML_ANCHOR_RE = re.compile(r"""href\s*=\s*["'](#[^"']*)["']""")
CODE_SPAN_RE = re.compile(r"`[^`]*`")
LIST_ROW_RE = re.compile(r"^\s*[-*][ \t]+")
CLOSING_HASHES_RE = re.compile(r"[ \t]+#+[ \t]*$")

TOC_HEADING = "Contents"

KEPT_CATEGORIES = frozenset("LMN")


def slugify(heading: str) -> str:
    """GitHub's heading slug: unicode-aware, punctuation stripped."""
    text = heading.replace("\t", " ").strip().lower()
    kept = "".join(
        char
        for char in text
        if char in " -_" or unicodedata.category(char)[0] in KEPT_CATEGORIES
    )
    return kept.replace(" ", "-")


def strip_inline_code(line: str) -> str:
    return CODE_SPAN_RE.sub("", line)


def read_lines(path: str) -> list[str]:
    with open(path, encoding="utf-8") as handle:
        return handle.read().splitlines()


def scan(path: str, lines: list[str]) -> list[str]:
    """Return findings for one file body."""
    findings: list[str] = []

    in_fence = [False] * len(lines)
    fence_open = False
    for index, line in enumerate(lines):
        if FENCE_RE.match(line):
            in_fence[index] = True
            fence_open = not fence_open
            continue
        in_fence[index] = fence_open

    headings: list[tuple[int, int, str, str]] = []  # (line, level, text, slug)
    seen: dict[str, int] = {}
    for index, line in enumerate(lines):
        if in_fence[index]:
            continue
        match = HEADING_RE.match(line)
        if not match:
            continue
        level = len(match.group(1))
        text = CLOSING_HASHES_RE.sub("", match.group(2)).strip()
        base = slugify(text)
        if base in seen:
            seen[base] += 1
            slug = f"{base}-{seen[base]}"
        else:
            seen[base] = 0
            slug = base
        headings.append((index + 1, level, text, slug))

    resolved = {slug for _, _, _, slug in headings}

    for index, line in enumerate(lines):
        if in_fence[index]:
            continue
        stripped = strip_inline_code(line)
        destinations = []
        for pattern in (INLINE_ANCHOR_RE, REF_DEF_ANCHOR_RE, HTML_ANCHOR_RE):
            destinations.extend(match.group(1) for match in pattern.finditer(stripped))
        for destination in destinations:
            anchor = unquote(destination[1:])
            if anchor not in resolved:
                findings.append(
                    f"{path}:{index + 1}: anchor #{anchor} does not resolve to a heading"
                )

    toc = next(
        (
            (line, text, slug)
            for line, level, text, slug in headings
            if level == 2 and text == TOC_HEADING
        ),
        None,
    )
    if toc is None:
        return findings

    toc_line = toc[0]
    end = len(lines) + 1
    for line, level, _, _ in headings:
        if line > toc_line and level <= 2:
            end = line
            break

    counts: dict[str, int] = {}
    for index in range(toc_line, end - 1):
        if in_fence[index] or not LIST_ROW_RE.match(lines[index]):
            continue
        for match in INLINE_ANCHOR_RE.finditer(strip_inline_code(lines[index])):
            anchor = unquote(match.group(1)[1:])
            counts[anchor] = counts.get(anchor, 0) + 1

    for line, level, text, slug in headings:
        if level != 2 or text == TOC_HEADING:
            continue
        listed = counts.get(slug, 0)
        if listed == 0:
            findings.append(
                f'{path}:{line}: heading "{text}" (#{slug}) is missing from Contents'
            )
        elif listed > 1:
            findings.append(
                f'{path}:{line}: heading "{text}" (#{slug}) is listed {listed} times in Contents'
            )

    return findings


def check_file(path: str) -> list[str]:
    try:
        lines = read_lines(path)
    except OSError as error:
        return [f"{path}: cannot read ({error.strerror})"]
    return scan(path, lines)


def tracked_markdown() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files", "-z", "--", "*.md"],
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise RuntimeError(
            "git ls-files failed - argless mode must run inside the repository"
        )
    paths = [chunk for chunk in result.stdout.decode("utf-8").split("\0") if chunk]
    return paths


SELF_TEST_CASES: list[tuple[str, str, list[str]]] = [
    (
        "broken inline anchor",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n\n## Alpha\n\n"
        "See [Beta](#beta).\n",
        ["anchor #beta does not resolve"],
    ),
    (
        "heading missing from Contents",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n\n## Alpha\n\nbody\n\n## Beta\n\nbody\n",
        ['heading "Beta" (#beta) is missing from Contents'],
    ),
    (
        "heading listed twice",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n- [Alpha](#alpha)\n\n## Alpha\n\nbody\n",
        ["(#alpha) is listed 2 times in Contents"],
    ),
    (
        "clean ascii file with literal link in code",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n"
        "- [Module: `services.x`](#module-servicesx)\n\n"
        "## Alpha\n\nSee [the module](#module-servicesx) and the literal "
        "`](#not-a-link)`.\n\n```\n[ignored](#inside-a-fence)\n```\n\n"
        "## Module: `services.x`\n\nbody\n",
        [],
    ),
    (
        "unicode heading resolves against the GitHub slug",
        "# T\n\n## Contents\n\n- [Grüße & Maß](#grüße--maß)\n\n"
        "## Grüße & Maß\n\nbody\n",
        [],
    ),
    (
        "unicode heading rejects the ascii-stripped slug",
        "# T\n\n## Contents\n\n- [Grüße & Maß](#grüße--ma)\n\n"
        "## Grüße & Maß\n\nbody\n",
        ["anchor #grüße--ma does not resolve"],
    ),
    (
        "reference-style definition pointing nowhere",
        "# T\n\nSee [Beta][beta].\n\n[beta]: #beta\n",
        ["anchor #beta does not resolve"],
    ),
    (
        "reference-style definition that resolves",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n\n"
        "See [it][a].\n\n[a]: #alpha\n\n## Alpha\n\nbody\n",
        [],
    ),
    (
        "html href pointing nowhere",
        '# T\n\n<a href="#nope">x</a>\n',
        ["anchor #nope does not resolve"],
    ),
    (
        "html href that resolves",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n\n"
        '<a href="#alpha">x</a>\n\n## Alpha\n\nbody\n',
        [],
    ),
    (
        "duplicate headings get numeric suffixes",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n- [Alpha](#alpha-1)\n\n"
        "## Alpha\n\nbody\n\n## Alpha\n\nbody\n",
        [],
    ),
    (
        "duplicate heading linked without its suffix",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n- [Alpha](#alpha)\n\n"
        "## Alpha\n\nbody\n\n## Alpha\n\nbody\n",
        ['heading "Alpha" (#alpha-1) is missing from Contents'],
    ),
    (
        "anchor in a table cell",
        "# T\n\n| a | b |\n| - | - |\n| [x](#gone) | y |\n",
        ["anchor #gone does not resolve"],
    ),
    (
        "inline anchor carrying a title",
        '# T\n\n## Contents\n\n- [Alpha](#alpha)\n\n## Alpha\n\n[x](#alpha "t")\n',
        [],
    ),
    (
        "percent-encoded unicode anchor",
        "# T\n\n## Contents\n\n- [Grüße](#gr%C3%BC%C3%9Fe)\n\n## Grüße\n\nbody\n",
        [],
    ),
    (
        "file without Contents only checks anchors",
        "# T\n\n## Alpha\n\nSee [Alpha](#alpha).\n",
        [],
    ),
    (
        "fenced block hides both headings and links",
        "# T\n\n## Contents\n\n- [Alpha](#alpha)\n\n## Alpha\n\nbody\n\n"
        "~~~\n## Not a heading\n[not a link](#nowhere)\n~~~\n",
        [],
    ),
]


def self_test() -> int:
    failed = 0
    for name, text, expected in SELF_TEST_CASES:
        findings = scan("<fixture>", text.splitlines())
        if expected:
            missing = [fragment for fragment in expected if not any(fragment in f for f in findings)]
            if missing or not findings:
                print(
                    f"FATAL: self-test case {name!r}: expected {expected!r}, got {findings!r}"
                )
                failed = 1
        elif findings:
            print(f"FATAL: self-test case {name!r} flagged a clean file: {findings!r}")
            failed = 1
    if failed:
        return 1
    print(
        f"check-md-anchors: self-test passed ({len(SELF_TEST_CASES)} cases, "
        "negative and positive)"
    )
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Lint in-file markdown anchors and Contents completeness.",
        epilog="Exit codes: 0 clean, 1 offenders, 2 usage/IO error.",
    )
    parser.add_argument("files", nargs="*", help="markdown files (default: git-tracked)")
    parser.add_argument("--self-test", action="store_true", help="prove the lint can fail")
    parser.add_argument("--quiet", action="store_true", help="no success summary line")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    if args.files:
        paths = list(args.files)
    else:
        try:
            paths = tracked_markdown()
        except RuntimeError as error:
            print(f"check-md-anchors: {error}", file=sys.stderr)
            return 2
        if not paths:
            print("check-md-anchors: no markdown files tracked - nothing to check")
            return 0

    findings: list[str] = []
    for path in paths:
        if not Path(path).exists():
            print(f"check-md-anchors: {path}: no such file", file=sys.stderr)
            return 2
        findings.extend(check_file(path))

    for finding in findings:
        print(f"offender: {finding}")
    if findings:
        return 1
    if not args.quiet:
        print(f"check-md-anchors: {len(paths)} file(s) clean")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
