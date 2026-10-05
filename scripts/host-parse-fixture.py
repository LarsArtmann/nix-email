#!/usr/bin/env python3
"""Host-side dry-run of the PINNED parsedmarc parser on a fixture.

The VM tests (tests/parsedmarc-e2e.nix) parse fixtures inside a NixOS VM;
each red costs ~5 minutes. The parser itself is a pure library - this
script runs the EXACT pinned nixpkgs parsedmarc (from the check
derivation's closure) on the host in ~30 s, so parser-vs-fixture blame is
settled before any VM run. Verified live 2026-10-05 on the pinned
forensic fixture (see AGENTS.md dry-run rule).

Usage:
  host-parse-fixture.py <fixture-file> [--check parsedmarc-e2e]
                        [--out /tmp/parse-result.json]

The fixture may be an aggregate .zip, a forensic/failure .eml, or a
TLS-RPT .json. Exit 0 when parsing produced at least one report of the
detected kind; the parsed JSON is written to --out and printed.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def sh(*cmd: str) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        raise SystemExit(
            f"command failed ({result.returncode}): {' '.join(cmd)}\n"
            f"{result.stderr.strip()}"
        )
    return result.stdout.strip()


def check_drv(check: str, system: str) -> str:
    return sh("nix", "eval", "--raw",
              f".#checks.{system}.{check}.drvPath")


def find_parser_env(drv: str) -> tuple[Path, Path]:
    """Return (python binary, site-packages dir) from the drv closure."""
    refs = sh("nix-store", "-q", "--references", drv).splitlines()
    site_packages = None
    python_bin = None
    for ref in refs:
        candidate = Path(ref) / "lib"
        if candidate.is_dir():
            for pydir in sorted(candidate.glob("python3.*")):
                sp = pydir / "site-packages"
                if (sp / "parsedmarc").is_dir():
                    site_packages = sp
                break
        bin_dir = Path(ref) / "bin"
        if bin_dir.is_dir():
            for py in sorted(bin_dir.glob("python3.*")):
                if py.is_file() and not py.is_symlink() or py.is_symlink():
                    python_bin = py
    if not site_packages or not python_bin:
        raise SystemExit(
            "parsedmarc site-packages or python binary not found in "
            f"closure of {drv}\n(is the check realized? run "
            "`nix build .#checks.x86_64-linux.<check>` first)"
        )
    return python_bin, site_packages


def parse_fixture(python: Path, site_packages: Path, fixture: Path) -> dict:
    env = dict(os.environ, PYTHONPATH=str(site_packages))
    code = f"""
import json, sys
import parsedmarc

data = open({str(fixture)!r}, "rb").read()
suffix = {str(fixture)!r}.lower()
if suffix.endswith(".zip") or suffix.endswith(".xml"):
    reports = parsedmarc.parse_report_file({str(fixture)!r})
    out = {{"aggregate_reports": reports[0], "forensic_reports": reports[1]}}
elif suffix.endswith(".json"):
    out = {{"smtp_tls_reports": [parsedmarc.parse_smtp_tls_report_json(
        data.decode())]}}
else:
    aggregate, forensic = parsedmarc.parse_email(data)
    out = {{"aggregate_reports": aggregate, "forensic_reports": forensic}}
print(json.dumps({{"parsedmarc_version": parsedmarc.__version__,
                   **out}}, default=str))
"""
    result = subprocess.run(
        [str(python), "-c", code], capture_output=True, text=True, env=env)
    if result.returncode != 0:
        print(result.stdout, file=sys.stderr)
        raise SystemExit(f"parse FAILED under pinned parser:\n{result.stderr}")
    return json.loads(result.stdout)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("fixture", type=Path)
    ap.add_argument("--check", default="parsedmarc-e2e",
                    help="check whose closure supplies the pinned parser")
    ap.add_argument("--system", default="x86_64-linux")
    ap.add_argument("--out", type=Path, default=Path("/tmp/parse-result.json"))
    args = ap.parse_args()

    if not args.fixture.is_file():
        raise SystemExit(f"fixture not found: {args.fixture}")
    drv = check_drv(args.check, args.system)
    python, site_packages = find_parser_env(drv)
    print(f"pinned env: python={python}", file=sys.stderr)
    print(f"site-packages={site_packages}", file=sys.stderr)
    parsed = parse_fixture(python, site_packages, args.fixture)
    args.out.write_text(json.dumps(parsed, indent=2, default=str) + "\n")
    print(json.dumps(parsed, indent=2, default=str))

    kinds = [k for k, v in parsed.items()
             if k.endswith("_reports") and v] + (
        ["smtp_tls_reports"] if parsed.get("smtp_tls_reports") else [])
    if not any(k in ("aggregate_reports", "forensic_reports",
                     "smtp_tls_reports") and parsed.get(k)
               for k in parsed):
        raise SystemExit(f"no reports recognized in {args.fixture}")


if __name__ == "__main__":
    main()
