#!/usr/bin/env python3
"""Export nix-email's EventCatalog source tree (services + ADRs).

Contract (hub: eventcatalog-hub build.sh + merge.py, verified 2026-10-24):
- Invoked as `python3 scripts/export-catalog.py -o <tree>` from the clone
  root. NEVER as `./scripts/...` - CI clone dirs are NOEXEC, only the
  interpreter (from PATH) executes.
- Emits ONLY services/<id>/index.mdx and adrs/<id>/index.mdx. No
  catalog.index.json (manifest-free sources render "-" in error
  insights; zero schemaVersion risk), no bootstrap files (hub owns
  them), no badges (deployment chips union in from the SystemNix
  inventory tree at merge time - merge.py unions by badge content,
  first source's body wins).
- Service `version` is LOCKSTEP with the hub's render-inventory.py
  (hardcoded 1.0.0): a mismatch forks the id's version set in the union.
- Deterministic: fixed data, fixed order, no timestamps - byte-stable
  across runs (the hub retries export jobs and diffs trees).
- Stdlib only (same contract as merge.py / render-inventory.py); the
  hub's python3 is a bare runner-PATH interpreter, no venv.

Usage:
  export-catalog.py -o <outdir>            # write tree (idempotent)
  export-catalog.py -o <outdir> --plain    # same tree; lint-tree parity
                                           # flag (no versioned outgoing
                                           # refs exist to strip)
  export-catalog.py --selftest             # golden test, no repo needed
"""

import argparse
import json
import re
import tempfile
from pathlib import Path

# LOCKSTEP with hub scripts/render-inventory.py ("version: 1.0.0").
RESOURCE_VERSION = "1.0.0"
OWNER = "lars"

SAFE_SCALAR_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9 ._/@()+-]*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
ADR_STATUSES = ("proposed", "accepted", "rejected", "deprecated", "superseded")


def yaml_str(value):
    """Quote a frontmatter scalar only when YAML would misparse it.

    Same contract as hub render-inventory.py: bare unless needed; anything
    with a `: `, a leading special, or non-ASCII rides as a JSON string
    (a valid YAML double-quoted scalar).
    """
    text = str(value)
    if SAFE_SCALAR_RE.match(text) and ": " not in text and not text.endswith(":"):
        return text
    return json.dumps(text, ensure_ascii=False)


MAIL_SERVER_BODY = """
NixOS wrapper module (`services.mail-server`) around the vendored Stalwart
0.16 module (`modules/stalwart-module/`, from nixpkgs PR #552103). The
wrapper owns NixOS wiring only - systemd credentials, firewall, provision
plan rendering - everything else passes through to Stalwart untouched
(thin-wrapper doctrine, see the ADRs below).

## Listeners (one RFC-compliant set)

| Port                                | Listener    | Notes                      |
| ----------------------------------- | ----------- | -------------------------- |
| 25                                  | smtp        | inbound MX, STARTTLS       |
| 587                                 | submission  | client auth + STARTTLS     |
| 465                                 | submissions | implicit TLS               |
| 993                                 | imaps       | implicit TLS               |
| httpBind (default `127.0.0.1:8080`) | http        | web admin / JMAP, proxy it |

## Option surface

`enable`, `hostname` (FQDN; on 0.16 it ALSO becomes the provisioned Domain
value, so account addresses synthesize as `name@<hostname>`), `httpBind`
(loopback default; never expose the admin listener raw - reverse-proxy
it; a non-8080 port bootstraps provisioning through the built-in 8080
endpoint and replaces it at apply), `publicUrl`, `admin`
(the 0.16 fallback admin is a REQUIRED systemd credential - the wrapper
refuses to eval without the secret), `stateVersion`, `relay` (outbound
smarthost), `metrics.enable` (`/metrics/prometheus` on the HTTP
listener), `certificate` (`self-signed | acme | manual` tier with
completeness assertions), and the opt-in hardening options `rateLimits`
and `spamFilter.dnsbl.servers`.

## Stalwart 0.16 doctrine

`services.stalwart.settings` is ONLY the config.json datastore descriptor;
domains, accounts, DKIM, routes and catch-all live in the datastore as
JMAP objects, provisioned declaratively via
`services.stalwart.provision.singletons/.objects` (consumer plans MERGE
into the wrapper's). Hardening defaults are OFF by design: the DNSBL plan
always carries an empty reconcile set destroying 0.16.22's 18
shipped-broken default rows at apply time.

The 0.15 to 0.16 store boundary is guarded (unit guard + migration script
preflight) - see the `store-boundary-guard` ADR. The full transcript-
pinned 0.16 dialect lives in the repo README's VERIFIED-FACTS LEDGER.

## Consumers

Consumed by SystemNix via hard-pinned release tags (currently v0.4.0; the
0.16 world lands at v0.5.0). Consumer layers (sops, ports, Gatus,
onFailure, backup-coordination) belong to the consumer wrapper, not here.

Source: [LarsArtmann/nix-email](https://github.com/LarsArtmann/nix-email)
README "Module: services.mail-server" and the VERIFIED-FACTS LEDGER own
the full detail.
"""

DMARC_MONITOR_BODY = """
NixOS wrapper module (`services.dmarc-monitor`) enabling nixpkgs
`services.parsedmarc` (11.0.1) with the heavy sinks OFF: parsedmarc polls
the `rua` mailboxes over IMAP and writes JSON+CSV reports to
`outputDirectory` (default `/var/lib/parsedmarc/reports`). Closes the
domains-repo findings that aggregate reports go nowhere today.

Options: `enable`, `outputDirectory`, `settings` (passthrough to the
parsedmarc ini).

## Keep-or-retire caveat (decision C42, status: proposed)

Stalwart 0.16 natively imports and ANALYZES inbound DMARC and TLS
aggregate reports (DMARCbis, 0.16.12+) plus authentication-failure
reports (ARF) - parsedmarc's parsing monopoly is gone. It still uniquely
owns file-sink outputs and arbitrary-mailbox IMAP polling. Retire-or-keep
is owner-gated decision C42; the module stands until that call (see the
`parsedmarc-keep-or-retire` ADR).

## Consumer wiring

The SystemNix consumer wrapper already exists (`nix-email.nix`: sops
secrets for the IMAP password, onFailure alert routing, the
integration-registry backup-freshness entry) and is eval-contract-tested;
enabling dmarc-monitor on a host is a consumer-config flip plus filling
the real secret, not new wiring. Deployment chips on this page come from
the SystemNix platform inventory.

Source: [LarsArtmann/nix-email](https://github.com/LarsArtmann/nix-email)
README "Module: services.dmarc-monitor" owns the full detail.
"""

SERVICES = [
    {
        "id": "mail-server",
        "name": "Mail Server (Stalwart 0.16)",
        "summary": (
            "NixOS wrapper around Stalwart 0.16 (SMTP, IMAP, JMAP, CardDAV)"
            " - thin wrapper, declarative provision plans, guarded 0.15 to"
            " 0.16 store boundary"
        ),
        "body": MAIL_SERVER_BODY,
    },
    {
        "id": "dmarc-monitor",
        "name": "DMARC Monitor (parsedmarc)",
        "summary": (
            "NixOS wrapper around parsedmarc 11.0.1 - polls rua mailboxes"
            " over IMAP, writes JSON+CSV aggregate reports (keep-or-retire"
            " decision C42 pending)"
        ),
        "body": DMARC_MONITOR_BODY,
    },
]

ADR_THIN_WRAPPER = """
## Context

Every option a wrapper adds is an option that must be tested, documented,
and reconciled when the upstream module moves. The nixos-mailserver
history lesson: broad wrapper surfaces (backup, monitoring, client
config) rot fastest because they duplicate what the platform already
owns. nixos-mailserver ended up REMOVING its backup and monitoring
options for exactly this class of reason.

## Decision

The nix-email wrappers wrap ONLY what needs NixOS wiring: systemd
credentials, firewall, provision plan rendering, secret file plumbing.
Everything else passes through `services.stalwart.settings` /
`services.stalwart.provision` untouched. Consumer-side concerns (sops
templates, port registration, Gatus checks, onFailure alerting,
backup-coordination) belong to the consumer wrapper (SystemNix), not
here.

## Consequences

- Small, auditable wrapper option surface; upstream module churn rarely
  touches it.
- Consumers compose their own layers instead of waiting for wrapper
  options.
- The README VERIFIED-FACTS LEDGER carries the full 0.16 provision
  dialect so passthrough stays safe (several obvious keys are wrong).
"""

ADR_VENDOR_MODULE = """
## Context

The nixpkgs Stalwart module only supports 0.16 as PR #552103
("nixos/stalwart: update module for 0.16+"); the nixpkgs rev this flake
pins ships the 0.15-era module. Waiting for the PR to merge would block
the 0.16 move (security window past CVE-2026-81036, the new provision
object model) on upstream timing.

## Decision

Vendor the module into `modules/stalwart-module/` at rev 9b15e1f0
(0x57e11a/nixpkgs), with the provenance header and a retirement
checklist in-file. The Stalwart binary is the pin's own `stalwart_0_16`
package (no binary overlay).

## Consequences

- The wrapper controls its module destiny; 0.16 semantics are pinned in
  tests regardless of nixpkgs merge timing.
- Drop-in retirement once the PR merges into the pinned nixpkgs rev
  (checklist in-file; the nixos/mail path replaces the vendored dir).
- Vendor drift is a tracked liability: the 0.16.22-to-0.16.26 overlay
  question (decision C45) must re-check the vendor against upstream.
"""

ADR_HARDENING_OFF = """
## Context

Stalwart 0.16 ships default inbound rate limiters and DNSBL rows. The 18
default DNSBL rows in 0.16.22 reference the `bit_and` expression
function - which the .22 parser itself rejects: the defaults are
shipped-broken. Silently enabling either class from a wrapper would make
a mail host emit unexpected outbound DNS queries and damp legitimate
burst traffic without an operator decision.

## Decision

`rateLimits` and `spamFilter.dnsbl` default OFF; both are deliberate
opt-ins. When a DNSBL plan is enabled it ALWAYS carries an empty
reconcile set that destroys 0.16.22's shipped-broken default rows at
apply time. Rate-limit sizing guidance (buckets, `authenticated_as`
vocabulary, verify-by-connection-count) lives in the README module docs.

## Consequences

- No silent hardening side effects; first enable is an explicit act with
  sizing responsibility on the operator.
- The e2e flood subtest pins the limiter shape (pre-SMTP hangup, never
  an SMTP code) so the opt-in stays honest.
- Do NOT "fix" these defaults to ON: the empty reconcile set is load-
  bearing against the shipped-broken rows.
"""

ADR_STORE_BOUNDARY = """
## Context

The 0.16 binary refuses to boot against a 0.15-era store: exit 101,
panic at `crates/migration/src/lib.rs:95`. Worse, every attempted boot
POISONS the settings subspace for 0.15.5 BEFORE panicking - a
crash-looping unit destroys its own recovery path, because the
sanctioned migration dumps old settings through a running 0.15.x
(pbx-artmann outage, 2026-10-17).

## Decision

The store boundary is a hard guard, not a runbook note:

- The systemd unit guard (`modules/stalwart-module/default.nix`) is the
  hard boundary refusing a 0.16 boot on an un-migrated store.
- The migration script's poison preflight is a hard stop.
- The dump runs from a pre-0.16 copy (`--backup-dir`) while recovery
  mode fixes the LIVE store; recovery port is
  `STALWART_RECOVERY_MODE_PORT` - never assume 8080.

## Consequences

- A fleet-safe 0.15-to-0.16 path that never depends on the panicking
  binary for its own recovery.
- Upgrades are owner-run events with the migration script, never a
  nixos-rebuild footgun.
"""

ADR_HARD_PIN = """
## Context

The wrapper is verified against a SPECIFIC Stalwart version (0.16.22 via
the vendored module and the pin's `stalwart_0_16`) at a specific nixpkgs
rev, and nix-email and SystemNix deliberately pin the SAME nixpkgs rev
(compat doctrine). A floating consumer (`?ref=master`) would decouple
that pair on every rebuild - the 2026-09-22 violation class.

## Decision

Consumers of this flake MUST pin it by a hard rev/tag, never
`?ref=master` (decision-batch C17a, executed 2026-10-05: SystemNix pins
`github:LarsArtmann/nix-email?ref=v0.4.0`). nixpkgs stays pinned to
SystemNix's lock rev; both repos bump together via the README
pin-advance runbook; Renovate PRs are approval-gated so a nixpkgs move
never lands unreviewed.

## Consequences

- Every release tag carries an implicit compat contract (wrapper binary
  x nixpkgs x consumer expectations); breaking changes ship as new major
  tags (the 0.16 world is v0.5.0).
- Floating consumers are acceptable ONLY where no nixpkgs-version-
  sensitive contract exists (InboxClean's `?ref=master` is fine; this
  repo's consumers are not).
"""

ADR_PARSEDMARC = """
## Context

Stalwart 0.16 natively imports and ANALYZES inbound DMARC and TLS
aggregate reports (DMARCbis, 0.16.12+) and authentication-failure
reports (DKIM/SPF/DMARC, ARF). parsedmarc's parsing monopoly is gone.
It still uniquely owns file-sink outputs (JSON+CSV trees other tools
read) and arbitrary-mailbox IMAP polling (evidence recorded 2026-10-17,
stalw.art/docs/mta/reports).

## Decision

UNDECIDED - owner-gated decision C42. The dmarc-monitor module stands
until that call: it closes the domains-repo findings that aggregate
reports go nowhere today, and the SystemNix consumer wiring already
exists.

## Consequences

- The catalog service page carries this ADR's proposed status; retiring
  the module flips the page and closes the findings differently (native
  Stalwart ingestion instead of file sinks).
- Until C42: no new parsedmarc-only features beyond what the findings
  require.
"""

ADR_PIN_VS_OVERLAY = """
## Context

The pin's nixpkgs ships Stalwart 0.16.22. The recorded 0.16.23-to-
0.16.26 delta (fetched 2026-10-18 from the upstream CHANGELOG/releases):

- 0.16.23 adds `bit_and` - the exact function 0.16.22's 18 shipped
  default DNSBL rows reference (the wrapper's empty-reconcile workaround
  predates this fix).
- 0.16.24 makes spam-rule updates insert-only on .22-.23 (an argument
  for the declarative reconcile posture).
- 0.16.25: DNSBL multi-return-code scoring, negative-TTL caching fixes.
- 0.16.26 is BREAKING for us: x86_64 builds (except musl) require
  x86-64-v2 CPUs and REFUSE to start otherwise - QEMU default CPU
  models are affected, so the wrapper's VM tests could not even boot it
  without a host cpu-type change.

No CVEs in the window (CVE-2026-81036 affects through 0.16.19 only).

## Decision

UNDECIDED - owner-gated decision C45: stay on the pin's 0.16.22 vs
overlay a newer 0.16.x. The delta above is the decision input; any
0.16.26+ overlay additionally needs a VM cpu-type change before the
gate can boot it.

## Consequences

- Until C45: the empty DNSBL reconcile set stays load-bearing on .22.
- An overlay decision must bundle the VM cpu-type change and a re-check
  of the vendored module against upstream.
"""

ADRS = [
    {
        "id": "thin-wrapper-doctrine",
        "name": "Thin wrapper doctrine",
        "summary": (
            "Wrap only what needs NixOS wiring; everything else passes"
            " through to Stalwart untouched"
        ),
        "status": "accepted",
        "date": "2026-09-14",
        "applies": [("service", "mail-server"), ("service", "dmarc-monitor")],
        "body": ADR_THIN_WRAPPER,
    },
    {
        "id": "vendor-stalwart-016-module",
        "name": "Vendor the Stalwart 0.16 nixpkgs module",
        "summary": (
            "Vendor nixpkgs PR #552103's 0.16 module with provenance and"
            " a retirement checklist instead of waiting on upstream"
        ),
        "status": "accepted",
        "date": "2026-10-17",
        "applies": [("service", "mail-server")],
        "body": ADR_VENDOR_MODULE,
    },
    {
        "id": "hardening-defaults-off",
        "name": "Hardening defaults OFF (opt-in rate limits and DNSBL)",
        "summary": (
            "rateLimits and spamFilter.dnsbl are deliberate opt-ins; the"
            " DNSBL plan always carries an empty reconcile set destroying"
            " 0.16.22's shipped-broken default rows"
        ),
        "status": "accepted",
        "date": "2026-09-14",
        "applies": [("service", "mail-server")],
        "body": ADR_HARDENING_OFF,
    },
    {
        "id": "store-boundary-guard",
        "name": "Hard guard on the 0.15 to 0.16 store boundary",
        "summary": (
            "The 0.16 binary panics on pre-0.16 stores and poisons the"
            " settings subspace first; the unit guard and migration"
            " preflight are hard stops"
        ),
        "status": "accepted",
        "date": "2026-10-17",
        "applies": [("service", "mail-server")],
        "body": ADR_STORE_BOUNDARY,
    },
    {
        "id": "hard-pin-compat-doctrine",
        "name": "Hard-pin consumers and nixpkgs (compat doctrine)",
        "summary": (
            "Consumers pin release tags, never master; nixpkgs pinned to"
            " SystemNix's lock rev and bumped together (C17a executed)"
        ),
        "status": "accepted",
        "date": "2026-10-05",
        "applies": [("service", "mail-server"), ("service", "dmarc-monitor")],
        "body": ADR_HARD_PIN,
    },
    {
        "id": "parsedmarc-keep-or-retire",
        "name": "parsedmarc keep-or-retire (decision C42)",
        "summary": (
            "Stalwart 0.16 ingests aggregate reports natively; parsedmarc"
            " keeps file sinks and IMAP polling - owner-gated call"
        ),
        "status": "proposed",
        "date": "2026-10-17",
        "applies": [("service", "dmarc-monitor")],
        "body": ADR_PARSEDMARC,
    },
    {
        "id": "stalwart-pin-vs-overlay",
        "name": "Stay on the pin's Stalwart 0.16.22 vs overlay newer (C45)",
        "summary": (
            "0.16.23-26 delta recorded (bit_and fix to x86-64-v2 BREAKING"
            " in .26); owner-gated whether to overlay"
        ),
        "status": "proposed",
        "date": "2026-10-18",
        "applies": [("service", "mail-server")],
        "body": ADR_PIN_VS_OVERLAY,
    },
]


def expected_paths():
    paths = [f"services/{s['id']}/index.mdx" for s in SERVICES]
    paths += [f"adrs/{a['id']}/index.mdx" for a in ADRS]
    return sorted(paths)


def render_service(svc):
    lines = [
        "---",
        f"id: {svc['id']}",
        f"name: {yaml_str(svc['name'])}",
        f"version: {RESOURCE_VERSION}",
        f"summary: {yaml_str(svc['summary'])}",
        "owners:",
        f"    - {OWNER}",
        "---",
        "",
    ]
    lines += svc["body"].strip("\n").split("\n")
    return "\n".join(lines) + "\n"


def render_adr(adr):
    lines = [
        "---",
        f"id: {adr['id']}",
        f"name: {yaml_str(adr['name'])}",
        f"summary: {yaml_str(adr['summary'])}",
        f"version: {RESOURCE_VERSION}",
        f"status: {adr['status']}",
        f"date: {adr['date']}",
        "owners:",
        f"    - {OWNER}",
        "appliesTo:",
    ]
    for kind, rid in adr["applies"]:
        lines += [f"  - type: {kind}", f"    id: {rid}"]
    lines += ["---", ""]
    lines += adr["body"].strip("\n").split("\n")
    return "\n".join(lines) + "\n"


def ensure_writable(outdir: Path) -> None:
    """Refuse to write into a dir that is not (a previous run of) ours.

    The hub retries export jobs, so re-exporting over our own tree must
    stay legal (idempotent overwrite); anything else (e.g. `-o .` in a
    checkout) is refused.
    """
    if not outdir.exists():
        return
    if not outdir.is_dir():
        raise SystemExit(f"output path exists and is not a directory: {outdir}")
    known = {"services", "adrs"}
    foreign = sorted(p.name for p in outdir.iterdir() if p.name not in known)
    if foreign:
        raise SystemExit(
            f"refusing to export into non-empty dir {outdir}: "
            f"unexpected entries {foreign} (only services/ and adrs/ are "
            "ever written; is -o pointing at a checkout?)"
        )


def export_tree(outdir: Path) -> None:
    ensure_writable(outdir)
    for svc in SERVICES:
        target = outdir / "services" / svc["id"] / "index.mdx"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render_service(svc))
    for adr in ADRS:
        target = outdir / "adrs" / adr["id"] / "index.mdx"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(render_adr(adr))


def frontmatter_of(text):
    if not text.startswith("---\n"):
        raise AssertionError("file does not start a frontmatter block")
    end = text.index("\n---\n", 4)
    return text[4:end].split("\n")


def assert_table_rows_balanced(rel, lines):
    for line in lines:
        if line.startswith("|") and line.count("|") % 2 != 0:
            raise AssertionError(f"{rel}: odd pipe count in table row: {line}")


def selftest() -> None:
    expected = expected_paths()
    service_ids = {s["id"] for s in SERVICES}
    adr_ids = {a["id"] for a in ADRS}
    assert len(service_ids) == len(SERVICES), "duplicate service ids"
    assert len(adr_ids) == len(ADRS), "duplicate adr ids"

    with tempfile.TemporaryDirectory() as tmp:
        first = Path(tmp) / "a"
        second = Path(tmp) / "b"
        export_tree(first)
        export_tree(second)

        walked = sorted(
            str(p.relative_to(first)) for p in first.rglob("*") if p.is_file()
        )
        assert walked == expected, f"file set drift: {walked} != {expected}"

        for svc in SERVICES:
            rel = f"services/{svc['id']}/index.mdx"
            text = (first / rel).read_text()
            fm = frontmatter_of(text)
            keys = [ln.split(":")[0] for ln in fm if not ln.startswith(" ")]
            for key in ("id", "name", "version", "summary", "owners"):
                assert key in keys, f"{rel}: missing frontmatter key {key}"
            assert "badges" not in keys, (
                f"{rel}: sources must not emit badges (deployment chips "
                "union in from the SystemNix inventory tree)"
            )
            assert f"version: {RESOURCE_VERSION}" in fm, (
                f"{rel}: version must stay lockstep {RESOURCE_VERSION} "
                "with hub render-inventory.py"
            )
            assert_table_rows_balanced(rel, text.split("\n"))

        for adr in ADRS:
            rel = f"adrs/{adr['id']}/index.mdx"
            text = (first / rel).read_text()
            fm = frontmatter_of(text)
            keys = [ln.split(":")[0] for ln in fm if not ln.startswith(" ")]
            for key in ("id", "name", "version", "status", "date"):
                assert key in keys, f"{rel}: missing frontmatter key {key}"
            assert adr["status"] in ADR_STATUSES, f"{rel}: bad status"
            assert DATE_RE.match(adr["date"]), f"{rel}: bad date {adr['date']}"
            # appliesTo gate mirror (merge.py validate_adr_refs): every
            # pointer must resolve in-union by construction.
            for kind, rid in adr["applies"]:
                assert kind == "service", f"{rel}: unexpected kind {kind}"
                assert rid in service_ids, (
                    f"{rel}: appliesTo id {rid} not exported by this tree"
                )

        for rel in expected:
            assert (first / rel).read_bytes() == (second / rel).read_bytes(), (
                f"{rel}: export is not byte-deterministic"
            )

    print(
        f"selftest PASS: {len(SERVICES)} services, {len(ADRS)} adrs, "
        f"{len(expected)} files, deterministic, appliesTo resolves in-tree"
    )


def main() -> None:
    ap = argparse.ArgumentParser(
        description="Export nix-email's EventCatalog source tree."
    )
    ap.add_argument("-o", "--out", type=Path, help="output tree root")
    ap.add_argument(
        "--plain",
        action="store_true",
        help=(
            "lint-tree parity flag (hub lint block); this tree has no "
            "versioned outgoing refs, so the output is identical"
        ),
    )
    ap.add_argument(
        "--selftest",
        action="store_true",
        help="run the golden selftest (no -o needed) and exit",
    )
    args = ap.parse_args()

    if args.selftest:
        selftest()
        return
    if not args.out:
        ap.error("-o/--out is required unless --selftest is given")
    export_tree(args.out)
    print(f"exported {len(expected_paths())} files to {args.out}")


if __name__ == "__main__":
    main()
