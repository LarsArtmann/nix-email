# W-generation execution: migration fixed, first full gate green, tooling mechanized — 2026-10-19 04:43

> Session over the W-plan (`docs/planning/2026-10-19_02-34_SUPERB-pareto-w-generation-migration-fix-release-unlock.md`).
> Executed W1, W2, W6 (partial), W7, W9, W10 (partial), W11, W12.2, W14, W15, W18.2, W19.
> W3/W8 remain owner-gated (questions at the bottom). W4/W5 blocked on W3; W16/W17 blocked on their gates.

| Field | Value                                                                                                                                                        |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| HEAD  | master == origin (daemon pushes; final CI green on `6dd4782`, 6m6s)                                                                                          |
| Gate  | FULL `nix flake check` GREEN for the FIRST time (10-check set, 2026-10-19 03:5x; count line says "running 7" - known CLI noise)                              |
| CI    | green (39190484173). Two intermediate daemon pushes ran red on the NEW README-completeness lint mid-batch - the lint working as designed, fixed same session |

## a) The critical bug is closed (W1, three stacked root causes, runs 6-10)

`stalwart-migrate-e2e` is GREEN end-to-end (9/9 subtests, run 10). The
post-migration exit-101 panic was THREE bugs stacked, each
transcript-pinned before the fix:

1. **Copy-path DataStore** (runs 6-7): the 0.15 management API serves
   the probe's EFFECTIVE settings, so probe.toml's
   `store.db.path = <dump copy>` leaked into convert's config.json and
   recovery mode migrated the COPY while the live store stayed
   pre-0.16. Fix: `--patch-paths dump=live` + a forced
   DataStore-at-live-store pass (`rewrite-datastore-path.py`).
2. **Root-owned RocksDB files** (run 8): recovery/probe now run as the
   SERVICE user (setpriv) with ownership normalization before the
   boot; root-littered MANIFEST/WAL blocked mid-apply writes (jmap 503
   serverUnavailable).
3. **Poisoned store skips the wipe** (run 9): recovery mode's one-shot
   wipe only triggers on a CLEAN pre-0.16 store; poisoned settings skip
   it, built-in Role objects are never re-seeded, and the apply dies on
   `x:Account/set` "Role not found". Fix: the script restores the clean
   dump copy into the live store path before recovery (upstream
   doctrine; freshest poisoned-live mail survives in
   `.v015-premigrate`).

The script now VERIFIES its end state before claiming it (stable unit
boot + provision apply; failed verification removes the marker). The
upstream UPGRADING/v0_16.md was fetched as ground truth. README,
CHANGELOG, and the module header carry the full dialect.

## b) Everything else that landed

- **W2**: first-ever full gate green; statix CI red root-caused (5
  findings in the new provision-plan-eval, fixed with CI's exact pin);
  push + CI green; metrics + count-line harvested.
- **W6**: dkim-survival subtest proven green in the gate; NEW JMAP push
  subtest (EventSource StateChange on delivery - the session
  eventSourceUrl is a TEMPLATE, raw GET = 400; probe-proven
  types=Email/closeafter=no params); provision-not-rerun pinned across
  restart; 19/19 subtests green. Residues routed to TODO (bounce-path,
  runtime trim, ping probe).
- **W7**: MONITORING/TELEMETRY 0.16 truth - the 37-series Prometheus
  inventory transcribed from the gate transcript (§5.5); the honest
  NO-GAUGE queue verdict (only the cumulative
  `queue_authenticated_message_queued` counter; 0.15 REST poll dead on
  0.16; counter-divergence proxy specified); provision-failure alert
  row; verify-budget note; TELEMETRY 0.16.22 spot-check banner.
- **W9**: dmarc-eval hardening pins (drop-detector semantics + negative
  self-test) + IFD cleanup (build-time greps).
- **W10**: convert-smoke shipped as the NEW `migrate-convert-eval`
  check (the migration script's first functional test; check set 9→10,
  all four guard sites updated); host-parse app dry-ran end-to-end
  (note the `--` separator); demo VM re-smoked post-relocation (stale
  repo-root demo.qcow2 trashed); fixture-dedup decided AGAINST;
  apps.vm eval guard resolved-as-redundant.
- **W11**: guard tooling - list-marker lint (empirically scoped against
  real dprint behavior: T1 normalizes, T2/T3/T4 stable), check-set
  drift alarm, README-completeness CI step (caught TWO real drifts on
  its first day), pipes lint argless + indented fences, `nix-health`
  devShell bisect, pre-push parity incl. pinned statix. Every step
  self-tests on planted fixtures.
- **W12.2**: evidence comment filed on nixpkgs PR #552103
  (voice-checked; verify gates passed; link in CHANGELOG). W12.3/W12.4
  routed to TODO.
- **W14**: DNS-race verdict DECIDED as documented doctrine (ordering
  cannot fix it - network-online.target is a no-op under dhcpcd; the
  DnsResolver singleton is the required pattern for late-DNS hosts;
  wrapper deliberately does not default it).
- **W15**: V-plan + P-plan annotated superseded (per-task
  dispositions); snapshot-vs-wrapper matchOn ledger line; probe-manifest
  audit clean; TODO truth-up (8+ rows closed, residue rows added).
- **W18.2**: refactor-identity script shipped. **W19**: upstream watch
  re-checked (no retirement triggers; #552103 still open).

## c) Owner questions still gating (W3/W8 — cannot be self-answered)

1. **C43**: cut v0.5.0 with the vendored module now? (W4/W5 chain) **→ decision-batch C43**
2. **C45**: 0.16.22 vs the 0.16.26 overlay (README delta table is the input). **→ decision-batch C45 (delta table written)**
3. **C44**: account-secrets doctrine (sops-rendered apply vs admin-created). **→ decision-batch C44**
4. **C39/C41/C46** + the `[rec]` ratifications (sitting #1). **→ decision-batch sittings (open)**
5. W8 batch: C18/C19/C22/C24/C29/C34, Q4, bandit/vulture CI scope, demo **→ decision-batch + TODO blocked-on-user rows**
   g1/g2, qcow2 history verdict, D1/D2 timeline, Resend key.

## d) Known state

- The gate count line ("running 7" vs 10) is documented noise; attrNames is truth.
- Concurrent session active (upstream-watch docs); no file conflicts hit.
- BuildFlow binary rebuild still blocked (their session owns the checkout).
