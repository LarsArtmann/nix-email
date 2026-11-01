#!/usr/bin/env python3
"""Fail when repo Nix code references a deprecated nixpkgs attribute.

Why this exists: nixpkgs retires an attribute by aliasing it through
`warnAlias` in `pkgs/top-level/aliases.nix`. The alias still evaluates,
but forcing ANY attribute of it (`.outPath`, `.version`, `.drvPath`)
prints an evaluation warning. A wrapper default naming a bare alias is
therefore a per-rebuild tax on every consumer: `package = pkgs.stalwart;`
in the 0.15 migration default printed "`stalwart` is currently pinned to
`0.15.5` ..." on every pbx-artmann switch, while the deployed server was
already `stalwart_0_16` (2026-11-01). Nothing failed - the gate and the
deployment were green - so the noise survived until someone asked.

The check: parse every `warnAlias` name out of the SAME nixpkgs pin the
build uses, then reject any code reference to it. Only the code is
scanned: comments and string literals are masked first, while Nix string
interpolations (`${...}`) stay visible because they are code. Versioned
attrs (`stalwart_0_15`, `stalwart_0_16`), hyphenated siblings
(`stalwart-cli`) and longer identifiers (`stalwartx`) are unaffected, so
the fix is always to name the versioned attribute.

Dotted aliases (`gnome2.gtkglext`) and aliases nested inside an attrset
block (`intel-oneapi.base`) are both parsed; the parser is line-shape
based, which is why it reads nixpkgs' own formatting.

Usage:
    python3 scripts/check-deprecated-aliases.py --aliases PATH [ROOT ...]
    python3 scripts/check-deprecated-aliases.py --self-test

ROOT defaults to the current directory and is scanned recursively for
`*.nix`. `--aliases` must point at `pkgs/top-level/aliases.nix` from the
pinned nixpkgs (the flake check passes `pkgs.path`, so it can never
drift from the pin that builds the system).

Exit 0 when clean, 1 on any offender (or a failed self-test).
"""

from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

TOP_LEVEL_ALIAS = re.compile(r"^ {2}(?P<name>[A-Za-z0-9_.'-]+) = warnAlias (?P<rest>.*)$")
NESTED_ALIAS = re.compile(r"^ {4}(?P<name>[A-Za-z0-9_.'-]+) = warnAlias (?P<rest>.*)$")
BLOCK_OPEN = re.compile(r"^ {2}(?P<name>[A-Za-z0-9_.'-]+) = \{\s*$")
BLOCK_CLOSE = re.compile(r"^ {2}\};")
QUOTED_MESSAGE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def deprecation_message(rest: str) -> str:
    """Extract nixpkgs' human-readable deprecation sentence."""
    match = QUOTED_MESSAGE.search(rest)
    if match is None:
        return ""
    return match.group(1).replace('\\"', '"').replace("\\'", "'")


def parse_warn_aliases(aliases_file: Path) -> dict[str, str]:
    """Map every deprecated attribute name to its nixpkgs message."""
    aliases: dict[str, str] = {}
    prefix: list[str] = []
    for line in aliases_file.read_text(errors="replace").splitlines():
        block = BLOCK_OPEN.match(line)
        if block is not None:
            prefix.append(block.group("name"))
            continue
        if BLOCK_CLOSE.match(line):
            if prefix:
                prefix.pop()
            continue
        match = NESTED_ALIAS.match(line) if prefix else TOP_LEVEL_ALIAS.match(line)
        if match is None:
            continue
        name = match.group("name")
        if prefix:
            name = ".".join([*prefix, name])
        aliases[name] = deprecation_message(match.group("rest"))
    return aliases


def _blank(char: str) -> str:
    return "\n" if char == "\n" else " "


def mask_comments_and_strings(source: str) -> str:
    """Blank comments and string bodies, keeping code (and line count)."""
    out: list[str] = []
    index = 0
    length = len(source)
    state = "code"
    interpolations: list[tuple[str, int]] = []
    while index < length:
        char = source[index]
        following = source[index + 1] if index + 1 < length else ""
        if state == "code":
            if char == "#":
                state, index = "line", index + 1
                out.append(" ")
                continue
            if char == "/" and following == "*":
                state, index = "block", index + 2
                out.append("  ")
                continue
            if char == '"':
                state, index = "double", index + 1
                out.append(" ")
                continue
            if char == "'" and following == "'":
                state, index = "indented", index + 2
                out.append("  ")
                continue
            if interpolations:
                return_state, depth = interpolations[-1]
                if char == "{":
                    interpolations[-1] = (return_state, depth + 1)
                elif char == "}":
                    if depth == 0:
                        state = interpolations.pop()[0]
                        index += 1
                        out.append(" ")
                        continue
                    interpolations[-1] = (return_state, depth - 1)
            out.append(char)
            index += 1
            continue
        if state == "line":
            if char == "\n":
                state = "code"
            out.append(_blank(char))
            index += 1
            continue
        if state == "block":
            if char == "*" and following == "/":
                state, index = "code", index + 2
                out.append("  ")
                continue
            out.append(_blank(char))
            index += 1
            continue
        if state == "double":
            if char == "\\":
                out.append("  " if following else " ")
                index += 2
                continue
            if char == '"':
                state, index = "code", index + 1
                out.append(" ")
                continue
            if char == "$" and following == "{":
                interpolations.append(("double", 0))
                state, index = "code", index + 2
                out.append("  ")
                continue
            out.append(_blank(char))
            index += 1
            continue
        # Nix indented string: ''...'' with ''' (quote) and ''$ / ''\ escapes.
        if char == "'" and following == "'":
            third = source[index + 2] if index + 2 < length else ""
            if third == "'":
                out.append("   ")
                index += 3
                continue
            if third in ("$", "\\"):
                out.append("   ")
                index += 3
                continue
            state, index = "code", index + 2
            out.append("  ")
            continue
        if char == "$" and following == "{":
            interpolations.append(("indented", 0))
            state, index = "code", index + 2
            out.append("  ")
            continue
        out.append(_blank(char))
        index += 1
    return "".join(out)


def reference_pattern(aliases: dict[str, str]) -> re.Pattern[str]:
    """Match `pkgs.<deprecated-name>` with an identifier boundary."""
    alternatives = "|".join(
        re.escape(name) for name in sorted(aliases, key=len, reverse=True)
    )
    return re.compile(rf"\bpkgs\.({alternatives})(?![A-Za-z0-9_'-])")


def scan(
    root: Path, aliases: dict[str, str]
) -> list[tuple[Path, int, str, str]]:
    """Return (file, line, attr, message) for every deprecated reference."""
    pattern = reference_pattern(aliases)
    findings: list[tuple[Path, int, str, str]] = []
    for path in sorted(root.rglob("*.nix")):
        original = path.read_text(errors="replace").splitlines()
        masked = mask_comments_and_strings("\n".join(original))
        for line_number, line in enumerate(masked.splitlines(), start=1):
            for match in pattern.finditer(line):
                name = match.group(1)
                findings.append((path, line_number, name, aliases[name]))
    return findings


SELF_TEST_ALIASES = """\
{ lib }:
let
  warnAlias = msg: v: v;
in
{
  stalwart = warnAlias "`stalwart` is currently pinned to `0.15.5`." stalwart_0_15;
  stalwart-mail = warnAlias "'stalwart-mail' has been renamed" stalwart;
  gnome2.gtkglext = warnAlias "'gnome2.gtkglext' has been renamed" gtkglext;
  intel-oneapi = {
    base = warnAlias "'intel-oneapi.base' merged away" intel-oneapi-toolkit;
  };
  helper-renamed = warnAlias "helper moved" helper;
}
"""


def self_test() -> int:
    """Prove both directions: deprecated references fail, safe ones pass."""
    cases = {
        "violation.nix": "{ package = pkgs.stalwart; }\n",
        "violation_dotted.nix": "{ g = pkgs.gnome2.gtkglext; }\n",
        "violation_nested.nix": "{ t = pkgs.intel-oneapi.base; }\n",
        "violation_hyphen.nix": "{ m = pkgs.stalwart-mail; }\n",
        "violation_interp.nix": 'x = "v${pkgs.stalwart}";\n',
        "violation_line2.nix": "let\n  p = pkgs.stalwart;\nin p\n",
        "clean_versioned.nix": (
            "{ a = pkgs.stalwart_0_15; b = pkgs.stalwart_0_16;"
            " c = pkgs.stalwart-cli; d = pkgs.stalwartx; }\n"
        ),
        "clean_comment.nix": (
            "# pkgs.stalwart is a warnAlias\n"
            "/* pkgs.stalwart\n   pkgs.stalwart-mail */\n"
            "{ a = 1; }\n"
        ),
        "clean_strings.nix": (
            "{\n"
            '  a = "pkgs.stalwart";\n'
            "  b = ''\n"
            "    pkgs.stalwart-mail and ${toString 1}\n"
            "  '';\n"
            "  c = '''pkgs.stalwart''';\n"
            "  d = ''$pkgs.stalwart'';\n"
            "}\n"
        ),
        "clean_prefix.nix": "{ a = mypkgs.stalwart; }\n",
    }
    expected_violations = {
        ("violation.nix", 1, "stalwart"),
        ("violation_dotted.nix", 1, "gnome2.gtkglext"),
        ("violation_nested.nix", 1, "intel-oneapi.base"),
        ("violation_hyphen.nix", 1, "stalwart-mail"),
        ("violation_interp.nix", 1, "stalwart"),
        ("violation_line2.nix", 2, "stalwart"),
    }
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        aliases_file = root / "aliases.nix"
        aliases_file.write_text(SELF_TEST_ALIASES)
        aliases = parse_warn_aliases(aliases_file)
        expected_aliases = {
            "stalwart",
            "stalwart-mail",
            "gnome2.gtkglext",
            "intel-oneapi.base",
            "helper-renamed",
        }
        if set(aliases) != expected_aliases:
            print(f"self-test FAIL: parsed aliases {sorted(aliases)}")
            return 1
        if aliases["stalwart"] != "`stalwart` is currently pinned to `0.15.5`.":
            print(f"self-test FAIL: message {aliases['stalwart']!r}")
            return 1
        for name, body in cases.items():
            (root / name).write_text(body)
        found = {
            (path.name, line, attr)
            for path, line, attr, _ in scan(root, aliases)
            if path.name in cases
        }
        if found != expected_violations:
            print(f"self-test FAIL: found {sorted(found)}")
            print(f"self-test FAIL: want  {sorted(expected_violations)}")
            return 1
    print(f"self-test PASS: {len(expected_violations)} offenders, {len(cases)} cases")
    return 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--aliases",
        type=Path,
        help="pkgs/top-level/aliases.nix from the pinned nixpkgs",
    )
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("roots", nargs="*", type=Path)
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()
    if args.aliases is None:
        parser.error("--aliases is required (the pinned pkgs/top-level/aliases.nix)")
    if not args.aliases.is_file():
        parser.error(f"--aliases not found: {args.aliases}")

    aliases = parse_warn_aliases(args.aliases)
    roots = args.roots or [Path(".")]
    findings = [finding for root in roots for finding in scan(root, aliases)]
    if findings:
        for path, line, name, message in findings:
            print(f"offender: {path}:{line}: pkgs.{name} is a deprecated alias")
            if message:
                print(f"  nixpkgs: {message}")
        print(
            f"{len(findings)} deprecated nixpkgs alias reference(s);"
            " name the versioned attribute instead"
        )
        return 1
    print(f"no deprecated nixpkgs alias references ({len(aliases)} aliases checked)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
