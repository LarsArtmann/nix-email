#!/usr/bin/env python3
"""Lint the shell fragments embedded in NixOS VM testScripts with `bash -n`.

Why this exists: a testScript is a Nix indented string containing Python;
the shell commands inside it are Python string constants. `nix eval`,
alejandra, and the CI awk lint all see a string literal, so an unbalanced
brace group is invisible until the VM boots and bash rejects the line
(commit 28e5dd7 shipped exactly that shape for ~10 minutes).

The check: extract every `testScript = ''...'';` block, parse it with
Python's `ast` (which correctly folds implicit string concatenation into
one constant), then run `bash -n` over every constant-string argument to
the machine shell helpers. Variables and other non-constant arguments are
skipped: they cannot be statically resolved.

Exit 1 on any failure. `--self-test` proves both directions against the
28e5dd7 shape (broken form must FAIL, closed form must PASS).
"""

from __future__ import annotations

import ast
import re
import subprocess
import sys
import textwrap
from pathlib import Path

SHELL_METHODS = {
    "succeed",
    "fail",
    "execute",
    "wait_until_succeeds",
    "wait_until_fails",
}
NIX_INTERPOLATION = re.compile(r"\$\{[^}]*\}")
TESTSCRIPT_START = re.compile(r"^\s*testScript = ''\s*$")
TESTSCRIPT_END = re.compile(r"^\s*'';")


def extract_testscripts(nix_text: str) -> list[tuple[int, str | None]]:
    """Return (first-content-line-index, python source) per testScript block.

    A `None` source means the block never closed.
    """
    lines = nix_text.splitlines()
    blocks: list[tuple[int, str | None]] = []
    index = 0
    while index < len(lines):
        if not TESTSCRIPT_START.match(lines[index]):
            index += 1
            continue
        start = index + 1
        index = start
        while index < len(lines) and not TESTSCRIPT_END.match(lines[index]):
            index += 1
        if index >= len(lines):
            blocks.append((start, None))
            break
        blocks.append((start, "\n".join(lines[start:index])))
        index += 1
    return blocks


def shell_fragments(tree: ast.AST) -> list[tuple[int, str]]:
    fragments: list[tuple[int, str]] = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or not node.args:
            continue
        func = node.func
        if isinstance(func, ast.Attribute):
            name = func.attr
        else:
            name = getattr(func, "id", None)
        if name not in SHELL_METHODS:
            continue
        arg = node.args[0]
        if isinstance(arg, ast.Constant) and isinstance(arg.value, str):
            fragments.append((node.lineno, arg.value))
    return fragments


def bash_syntax_error(fragment: str) -> str | None:
    proc = subprocess.run(
        ["bash", "-n"],
        input=fragment,
        text=True,
        capture_output=True,
        check=False,
    )
    if proc.returncode == 0:
        return None
    lines = [line for line in proc.stderr.strip().splitlines() if line.strip()]
    return lines[-1] if lines else "bash -n failed"


def check_text(nix_text: str, label: str) -> tuple[list[str], int]:
    failures: list[str] = []
    checked = 0
    for start, source in extract_testscripts(nix_text):
        if source is None:
            failures.append(f"{label}:{start + 1}: testScript '' block never closes")
            break
        source = textwrap.dedent(source)
        source = NIX_INTERPOLATION.sub("nixval", source)
        try:
            tree = ast.parse(source)
        except SyntaxError as exc:
            line = start + (exc.lineno or 1)
            failures.append(
                f"{label}:{line}: testScript is not valid Python: {exc.msg}"
            )
            continue
        for lineno, fragment in shell_fragments(tree):
            checked += 1
            error = bash_syntax_error(fragment)
            if error is not None:
                failures.append(f"{label}:{start + lineno}: shell syntax: {error}")
    return failures, checked


def check_paths(paths: list[Path]) -> tuple[list[str], int]:
    failures: list[str] = []
    checked = 0
    for path in paths:
        path_failures, path_checked = check_text(path.read_text(), str(path))
        failures.extend(path_failures)
        checked += path_checked
    return failures, checked


SELF_TEST_BROKEN = """testScript = ''
  machine.succeed(
      "journalctl -u dovecot -b 0 -o cat > /tmp/j.log && { "
      "cat /tmp/j.log >&2; "
      "grep -E 'imap-login: Logged in' /tmp/j.log; "
  )
'';
"""

SELF_TEST_FIXED = """testScript = ''
  machine.succeed(
      "journalctl -u dovecot -b 0 -o cat > /tmp/j.log && { "
      "cat /tmp/j.log >&2; "
      "grep -E 'imap-login: Logged in' /tmp/j.log; }"
  )
'';
"""


def self_test() -> int:
    broken, broken_checked = check_text(SELF_TEST_BROKEN, "broken.nix")
    fixed, fixed_checked = check_text(SELF_TEST_FIXED, "fixed.nix")
    ok = len(broken) == 1 and not fixed and broken_checked == 1 and fixed_checked == 1
    print(f"self-test broken-form findings: {len(broken)} (want 1)")
    print(f"self-test fixed-form findings: {len(fixed)} (want 0)")
    print(f"self-test fragments checked: {broken_checked}/{fixed_checked} (want 1/1)")
    if not ok:
        print("SELF-TEST FAILED", file=sys.stderr)
        return 1
    print("self-test OK")
    return 0


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    paths = [Path(arg) for arg in argv[1:]]
    if not paths:
        paths = sorted(Path("tests").glob("*.nix"))
    failures, checked = check_paths(paths)
    for failure in failures:
        print(failure, file=sys.stderr)
    if failures:
        print(f"{len(failures)} testScript shell syntax failure(s)", file=sys.stderr)
        return 1
    if checked == 0:
        print("no shell fragments found - extractor is broken", file=sys.stderr)
        return 1
    print(
        f"testScript shell syntax OK ({checked} fragment(s) in {len(paths)} nix file(s))"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
