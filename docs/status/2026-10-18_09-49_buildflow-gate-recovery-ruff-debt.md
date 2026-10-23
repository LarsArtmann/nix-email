# Status: Buildflow Gate Recovery + Python Lint Debt

**Date:** 2026-10-18 09:49 CEST
**Session window:** 08:20-09:03 (gate runs), report written 09:49
**Trigger:** `buildflow --fix --build-mode=full ... all` exited 69 with the failure-loop
detector firing: ruff-check-fix had failed 3 consecutive runs with identical errors.
**Scope:** this report covers ONLY this session's work and what it noticed. No new
research was done; TODO_LIST rows below are the ones this session actually read.

## Summary

The gate was red on error-severity ruff findings in two Python files
(`modules/stalwart-module/migrate_v016.py`, `scripts/host-parse-fixture.py`).
All 8 findings were fixed at source, plus 9 more latent dead-code findings
surfaced once the pipeline unblocked (vulture had been skipped behind the
failure). The full gate now passes: exit 0, 33 of 42 steps, no error-severity
findings, failure-loop cleared. Remaining findings are warning/info severity
and documented as deliberate non-fixes. Everything is committed (daemon
commits `7ef98a4`, `da96af0`, `c9bbcb0`).

## a) FULLY DONE

| Done                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Evidence                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| All 8 ruff errors fixed at source (the gate failure): EXE001 x2 (chmod +x both scripts), PERF102 (migrate_v016.py:921 `.items()` to `.values()`), FURB192 x2 (migrate_v016.py:976,980 `sorted(...)[0]` to `min(...)`, semantic equivalence proven with a runtime check), BLE001 (migrate_v016.py:1868 `except Exception` narrowed to `except ValueError`; `binascii.Error` subclasses it), PLW1510 x2 (host-parse-fixture.py:29,86 explicit `check=False`; both sites already self-check returncode) | `ruff check` on both files: "All checks passed"; `py_compile` ok; `buildflow -s ruff-check-fix --fix` exit 0             |
| Vulture's 8 dead-code findings fixed: `for_blob` / `for_search` keyword params were accepted by `_build_foundationdb`, `_build_postgresql`, `_build_mysql` but never read by any body; removed from all 3 signatures + 6 call sites (the enclosing `_build_blob_store` / `_build_search_store` already carries the purpose, and 0.16 store objects take no purpose field)                                                                                                                            | `grep for_blob,for_search` count 0; py_compile ok; ruff clean; vulture count dropped 8 to 2                              |
| Dead stub `group_settings_by_prefix` removed (signature + `raise NotImplementedError`, zero callers repo-wide)                                                                                                                                                                                                                                                                                                                                                                                       | repo-wide grep: only the definition existed; vulture 2 to 0 in the final gate                                            |
| AGENTS.md known-noise bullet extended: bandit B404 / B603 / B108 on host-parse-fixture.py accepted (local developer forensic tool; subprocess runs developer-controlled nix commands without shell; the /tmp default is the documented `--out` UX), vulture `session.auth` false positive documented (requests library reads the attribute; assignment IS the usage)                                                                                                                                 | commit `c9bbcb0`; final gate lists bandit only as warning-severity                                                       |
| TODO_LIST.md updated: new Low row for the AGENTS.md-size preflight advisory (451 vs max 220), BuildFlow-upstream row extended with the bandit 54-vs-4 count gap + the ruff findings-identity parsing bug, new convert-smoke row for migrate_v016.py                                                                                                                                                                                                                                                  | dprint-formatted; `scripts/check-md-table-pipes.sh` pass; working-tree diff +3 rows                                      |
| Full gate green: exit 0, "BuildFlow passed with warnings 33 of 42", 1m23s final run, failure-loop detector silent                                                                                                                                                                                                                                                                                                                                                                                    | `/tmp/bf-full3.log`; three full-gate runs this session (full1 08:57, full2 09:00, full3 09:03), all exit 0 after the fix |

## b) PARTIALLY DONE

| Item                                | What works                                                                                                                                                                                                                                                                                                               | What remains                                                                                                                                                                           | Effort         |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- |
| Bandit findings triage **→ TODO_LIST BuildFlow row (54-vs-4 gap open there)** | All 4 unique findings (direct repo-wide run) judged and documented as accepted noise; none is a real security issue | The gate reports 54 findings vs the tool's 4; the aggregation or flag divergence is UNEXPLAINED and rides the extended TODO row (same class as the documented nix-checker 12-vs-2 gap) | S |
| ~~migrate_v016.py verification~~ done — migrate-convert-eval check shipped (W10, 2026-10-19) | ~~py_compile, ruff, vulture, and a `--help` smoke all pass; the removals are provably behavior-preserving (the params were never read)~~ | ~~NO functional test: the `convert` subcommand was never run against a stored 0.15 dump; ticketed as a TODO row~~ | ~~M~~ |
| ~~nix-flake-check warnings triage~~ done — triage stood; dovecot rename rides the upstream parsedmarc module | ~~All 3 warnings attributed: the `stalwart` 0.15.5 pin alias warning, the httpBind non-loopback warning (deliberate: a mail server must bind a real interface), and the `dovecot2.protocols` rename (root-caused 2026-09-16 as nixpkgs-internal via parsedmarc.nix; verdict ridden-by-design, README runbook documents it)~~ | ~~Zero code change by design; the warnings persist every run by choice~~ | ~~done as triage~~ |
| BuildFlow binary freshness advisory **→ TODO_LIST BuildFlow row (rebuild + delta review)** | Correctly NOT rebuilt: a concurrent session owns the BuildFlow repo (binary ef32fa0, HEAD 4eef532); rebuilding a moving checkout risks mid-flight changes | The delta commits (ef32fa0..4eef532) were never inspected; rebuild + delta review deferred until that repo settles | S |
| ~~vulture `auth` finding~~ done — documented accepted noise (AGENTS known-lint-noise) | ~~Documented as false positive; the gate already ignores it (warning-severity, below the error threshold)~~ | ~~Not suppressed in config (vulture has no per-line noqa; a whitelist file would be the mechanism)~~ | ~~S~~ |

## c) NOT STARTED

| Item                                                                              | Why not started                                                                                                                                                        | Still wanted?                           |
| --------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------- |
| ~~AGENTS.md trim below the BuildFlow preflight cap (451 lines, max 220, excess 231)~~ done — 220/220 reached (07-18 pass); C41 moot | ~~Ticketed this session; an editorial pass, NOT a mechanical delete; the file is deliberately knowledge-dense and trimming wrong lines destroys session-critical context~~ | ~~Yes, but shape depends on question (g3)~~ |
| ~~ruff / vulture / bandit into `devShells.default`~~ done — pinned in the devShell (2026-10-19, devshells.nix) | ~~Pre-existing TODO row ("ruff/lychee devShell accept-or-add"); the run re-warned on all three ("running via nix run nixpkgs WITHOUT project deps")~~ | ~~Yes~~ |
| ~~CI fail-closed ruff gate for tracked .py files~~ done — shipped bc24227 (V3, 2026-10-18; CI green with the step) | ~~Unstarted; needs a policy decision first (see g2) and a ci.yml read this session never did~~ | ~~Yes; it is the systemic fix for (d1)~~ |
| ~~Convert-smoke fixture for migrate_v016.py~~ done — migrate-convert-eval check (W10, 2026-10-19) | ~~Ticketed this session; no stored 0.15 dump was at hand mid-session~~ | ~~Yes~~ |
| BuildFlow binary rebuild + ef32fa0..4eef532 delta review **→ TODO_LIST BuildFlow row** | Blocked on the concurrent BuildFlow session landing | Yes, cheap once unblocked |

## d) TOTALLY FUCKED UP

1. **Error-class lint shipped to a red gate and SAT there.** The ruff errors
   were introduced by `f9ab833` (feat: stalwart 0.15 to 0.16 store migration,
   which added migrate_v016.py) and the gate failed 3+ consecutive runs before
   this session touched it. The daemon's pushes bypass the pre-push hook, so
   nothing local stopped the red from landing; whether CI would have caught it
   is UNKNOWN (ruff's presence in ci.yml was never verified this session).
   Severity: master red risk on every dependent consumer pin. Mitigation: fixed
   this session; systemic fix is the CI gate (c3).
2. **BuildFlow mangles ruff findings into garbage.** `buildflow -s
   ruff-check-fix --format finding` emitted 55 positionless pseudo-findings
   (report builder: "missing_file=55"): ruff's pretty-printed output lines are
   split into per-line "findings" with no file identity. Drill-down for ruff is
   unusable; the working triage was a direct `ruff --output-format concise`
   run. Upstream candidate, ticketed. Severity: workflow friction, not
   correctness.
3. **bandit count gap 54 vs 4.** The gate reports 54 bandit findings; direct
   `bandit -r scripts modules tests` reports 4, all on one file. 13.5x
   inflation, unexplained (aggregation per message-line? different flags?).
   Same failure class as the documented nix-checker 12-vs-2 gap. Ticketed.
   Severity: every future session wastes time re-litigating the number.
4. **Two executable-intent scripts shipped non-executable.** Both shebang
   scripts landed without the exec bit (host-parse-fixture.py since `d0c991e`,
   migrate_v016.py since `f9ab833`). The gate caught it, but only after 3
   ignored reds; WHO or WHAT strips the mode bit was never investigated (e6).

## e) WHAT WE SHOULD IMPROVE

1. **Ruff findings UX through BuildFlow:** parse ruff's JSON output instead of
   the pretty-printed text so findings carry file/line identity; until then,
   document the direct-run triage pattern (one `nix run nixpkgs#ruff --
   check ... --output-format concise` beat the entire findings drill-down).
2. **Blocked steps hide sibling detections:** bandit and vulture only appeared
   AFTER ruff went green; during the red window the repo's full Python lint
   surface was invisible. BuildFlow could run detect-only steps even when a
   sibling repair step fails. (Upstream idea; batch with row 66.)
3. **Python tooling lives outside the devShell:** every run warns "running via
   nix run WITHOUT project deps" for ruff, vulture, and bandit. Decide
   add-or-accept once in `.buildflow.yml` / devShell instead of per-run noise.
4. **Dead code shipped in a feature commit:** `f9ab833` carried unread params,
   a NotImplementedError stub, and a blind except. The script was written
   without a lint pass. Cheap policy: run the gate before committing Python
   (or rely on the CI gate from c3).
5. **EXE001 root cause unexplored:** two scripts lost (or never got) their exec
   bit; one `git log -p` look at mode-line history would say whether an
   editor, a copy step, or the daemon strips it. Not done.
6. **AGENTS.md size policy mismatch:** the fleet cap is 220 lines; this repo
   runs 451 deliberate ones. Either configure a repo-local cap (if
   `.buildflow.yml` supports it) or do the trim; otherwise the preflight warn
   fires every run forever.

## f) Up to 50 next tasks

New this session first (1-10), then carried rows this session actually read
(11-45). Bounded honestly: TODO_LIST rows before line 50 were not read this
session and are not restated here. Impact: Critical / High / Med / Low.
Effort: S under 30min, M 30min-2h, L over 2h.

| N  | Task                                                                                                                                                                                                              | Impact | Effort | Category      |
| -- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ------------- |
| ~~1~~ done — bc24227 fail-closed floor (V3, 2026-10-18) | ~~Verify whether CI lints Python at all (read ci.yml), then add a fail-closed ruff step for tracked .py files so daemon pushes cannot ship lint reds again~~ | ~~High~~ | ~~M~~ | ~~Quality~~ |
| ~~2~~ done — migrate-convert-eval (W10, 2026-10-19) | ~~Convert-smoke migrate_v016.py: run `convert` against a stored 0.15 dump or minimal fixture (ticketed)~~ | ~~Med~~ | ~~M~~ | ~~Quality~~ |
| ~~3~~ done — 220/220 (07-18 pass, 2026-10-19) | ~~AGENTS.md trim below 220 lines or configure a repo-local cap; shape awaits g3~~ | ~~Med~~ | ~~L~~ | ~~Documentation~~ |
| 4 **→ TODO_LIST BuildFlow row** | Reconcile bandit 54-vs-4 gate-count gap (BuildFlow upstream; rides row 66) | Low | S | Bug |
| 5 **→ TODO_LIST BuildFlow row** | Fix BuildFlow ruff findings-identity parsing, missing_file=55 (upstream; rides row 66) | Low | S | Bug |
| 6 **→ TODO_LIST BuildFlow row** | BuildFlow upstream: run detect-only steps even when a sibling repair step fails (rides row 66) | Low | S | Feature |
| ~~7~~ done — pinned 2026-10-19 (devshells.nix) | ~~Add ruff, vulture, bandit to devShells.default or accept the noise in .buildflow.yml~~ | ~~Low~~ | ~~S~~ | ~~Cleanup~~ |
| ~~8~~ done — creator-mode gap proven (V3.6, 2026-10-19) | ~~EXE001 root cause: `git log -p` the mode lines of both scripts; find what strips exec bits~~ | ~~Low~~ | ~~S~~ | ~~Investigation~~ |
| 9 **→ TODO_LIST BuildFlow row** | BuildFlow binary rebuild + ef32fa0..4eef532 delta review once the concurrent session lands | Low | S | Cleanup |
| 10 **→ TODO_LIST BuildFlow row** | Verify and document the vulture confidence policy (gate shows 0 findings while the CLI shows a 60%-confidence `auth`) | Low | S | Documentation |
| ~~11~~ done — lives in the TODO_LIST upstream-watch row (current) | ~~Upstream watch row: nixpkgs PRs #563651 / #563652 / #563777, mailsuite#65, PR #566282 merged (provision.opensearch port procedure MANDATORY at next pin advance), PR #552103 vendored-module retirement checklist~~ | ~~Med~~ | ~~S~~ | ~~Maintenance~~ |
| ~~12~~ done — W7 landed 2026-10-19 (37-series + NO-GAUGE verdict + spot-check) | ~~MONITORING.md 0.16 work: journal-grep quota guidance to a queue-depth metric alert + stalwart-provision failure alert + TELEMETRY.md key spot-check~~ | ~~Med~~ | ~~M~~ | ~~Documentation~~ |
| ~~13~~ done — V19 sweep 2026-10-18 (one stale hit, fixed) | ~~Sweep remaining docs for 0.15-only API references beyond the 2026-10-17 updates~~ | ~~Low~~ | ~~S~~ | ~~Documentation~~ |
| ~~14~~ done — V18 probes + W6 e2e push subtest (ping residue in TODO row) | ~~JMAP anti-rot re-based on 0.16: EventSource push probe + per-account Junk-filing e2e + StateChange assertion hardening~~ | ~~Low~~ | ~~L~~ | ~~Feature~~ |
| ~~15~~ done — X14 landed 2026-10-19 (CHANGELOG entry) | ~~buildflow local-noise batch: nix-hash-fix WARN, lychee private-repo policy, interrogate/jest skip configs, timings cleanup~~ | ~~Low~~ | ~~M~~ | ~~Cleanup~~ |
| 16 **→ TODO_LIST upstream-filings row** | T13b: dprint markdown pipe-cell handling upstream (verify-before-filing first) | Low | L | Bug |
| ~~17~~ done — W11 (argless + indented fences, 2026-10-19) | ~~scripts/check-md-table-pipes.sh: argless mode + indented-fence coverage~~ | ~~Low~~ | ~~S~~ | ~~Quality~~ |
| ~~18~~ done — apps.host-parse-fixture + dry-run (W10, 2026-10-19) | ~~host-parse-fixture.py as a flake app + closure re-check after the upgrade~~ | ~~Low~~ | ~~S~~ | ~~Feature~~ |
| 19 **→ TODO_LIST row (open)** | TLS-node coverage for the Netease + LinkedIn parsedmarc fixtures | Low | M | Quality |
| ~~20~~ done — scripts/vm-debug.sh (X16, 2026-10-19) | ~~Pin the VM debug-driver recipe as a script (GC root + test-script dance)~~ | ~~Low~~ | ~~M~~ | ~~Quality~~ |
| ~~21~~ done — resolved-as-redundant (W10, 2026-10-19) | ~~apps.vm store-closure eval guard (demo rot guard)~~ | ~~Low~~ | ~~S~~ | ~~Quality~~ |
| ~~22~~ done — W9 build-time greps (2026-10-19) | ~~dmarc-eval IFD cleanup (build-time grep instead of builtins.readFile)~~ | ~~Low~~ | ~~S~~ | ~~Quality~~ |
| ~~23~~ done — decided AGAINST for fetchurl pins (W10, 2026-10-19) | ~~Fixture dedup decision: shared tests/fixtures.nix; decide, don't default~~ | ~~Low~~ | ~~S~~ | ~~Cleanup~~ |
| ~~24~~ done — V26 2026-10-18 + W10.5 demo-disk trashing | ~~Repo hygiene: stale result* symlinks, /tmp GC roots and debug scripts, demo disk CWD-relative footgun~~ | ~~Low~~ | ~~S~~ | ~~Cleanup~~ |
| ~~25~~ done — check-set-lockstep (X9, 2026-10-19) | ~~Local lockstep guard: flake eval check asserting checks attrNames == ci.yml expected list~~ | ~~Low~~ | ~~S~~ | ~~Quality~~ |
| 26 **→ TODO_LIST flood watch row** | Flood-limiter robustness: 3-banner/7-hangup timing sensitivity on slow runners | Low | S | Quality |
| 27 **→ TODO_LIST row** | Relay bounce-path test on 0.16 via Mailpit/queue state, never the journal | Low | M | Quality |
| 28 **→ trim open (TODO row); restart-persistence shipped (W6)** | E2E polish: runtime trim investigation + restart-persistence extension | Low | M | Quality |
| ~~29~~ done — attributed buildflow-emitted 2026-10-19 (nix prints no aggregate count); BuildFlow-side residue in the TODO row | ~~Reconcile the "running 4 flake checks" log line vs the 7 defined checks~~ | ~~Low~~ | ~~S~~ | ~~Bug~~ |
| ~~30~~ done — X17.1 fault-injection proof (2026-10-20, 60e7916) | ~~Prove the apply-log dump fires on failure (fault injection) + dump-on-failure audit~~ | ~~Low~~ | ~~M~~ | ~~Quality~~ |
| ~~31~~ done — W11 pre-push parity incl. pinned statix | ~~pinned-statix into the pre-push hook (mirror CI; four shipped reds precedent)~~ | ~~Low~~ | ~~M~~ | ~~Quality~~ |
| ~~32~~ done — untracked + gitignored (V21, 2026-10-19) | ~~Decide .config/metadata.yaml fate: keep or gitignore~~ | ~~Low~~ | ~~S~~ | ~~Cleanup~~ |
| ~~33~~ done — scripts/check-refactor-identity.sh (W18.2, 2026-10-19) | ~~Script the refactor-identity proof (outPath + registrationTime dating)~~ | ~~Low~~ | ~~S~~ | ~~Quality~~ |
| ~~34~~ done — shipped (V9, 2026-10-18; Exec lint + port pin included) | ~~provision-plan-eval fast eval check + eval-time systemd Exec lint + fallback port pin (needs all THREE guard sites in one commit)~~ | ~~Med~~ | ~~M~~ | ~~Feature~~ |
| ~~35~~ done — W9 drop-detectors + negative self-test (2026-10-19) | ~~dmarc-eval: eval-time assertion pinning the upstream parsedmarc unit-hardening shape~~ | ~~Med~~ | ~~M~~ | ~~Quality~~ |
| 36 **→ ROADMAP open questions** | User decision D1 / D2 (ROADMAP open decisions gating roadmap items) | Med | S | Decision |
| 37 **→ ROADMAP Q6 residue (ratification in decision-batch)** | User decision: spam-to-Junk filing semantics (ROADMAP) | Med | S | Decision |
| 38 **→ decision-batch C45 (delta table written)** | Decision C45: the 0.16.26 overlay question (TODO_LIST) | Low | S | Decision |
| ~~39~~ done — V11 2026-10-18 + W10.5 2026-10-19 (0.16 smoke) | ~~Fresh host-side runtime smoke of the demo VM (AGENTS.md marks it pending)~~ | ~~Low~~ | ~~M~~ | ~~Quality~~ |
| ~~40~~ done — mypy rationale replaced 2026-10-19 (X14); pytest skip stands | ~~Consider retiring the mypy-check and pytest-test skip rationales in .buildflow.yml~~ | ~~Low~~ | ~~S~~ | ~~Cleanup~~ |

## g) Questions I cannot figure out myself

1. **What is the lifecycle of `migrate_v016.py`?** Does it retire together with **→ de-facto answered: ships + is tested with the vendored module (migrate-convert-eval); retirement rides #552103 (module header checklist)**
   `modules/stalwart-module/` when nixpkgs PR #552103 merges (the module header
   carries that retirement checklist), or does it stay as a standalone operator
   tool? I checked the module header, README ledger, and TODO rows; the
   script's fate is stated nowhere. This decides whether the convert-smoke
   fixture (task 2) is worth building at all.
~~2. **Should CI grow a fail-closed Python lint gate (ruff, maybe bandit/vulture)~~ done — shipped bc24227 (V3); scope doctrine residue = TODO row
   for tracked .py files?** I never read ci.yml this session, so I do not know
   whether Python is linted in CI today. If it is not, (d1) can recur on the
   next feature commit that touches Python; if you want it, the ci.yml
   inventory question needs an answer first.
~~3. **Trim AGENTS.md to the fleet cap, or configure a repo-local cap?** The 451~~ done — 220/220 reached (07-18 pass); C41 moot
   lines are deliberate operational density (ledger pointers, VM debug rules,
   poison-store class warnings). A mechanical trim risks evicting context that
   has no other home; a repo-local cap in .buildflow.yml silences the preflight
   warn honestly. Which doctrine wins for this repo?

## Session evidence index

- Failing run: 08:20:10, exit 69, failure loop (3 consecutive ruff-check-fix
  errors). Log: `/tmp` (not preserved), findings reproduced via
  `nix run nixpkgs#ruff -- check ... --output-format concise`.
- Single-step green: 08:55:09 (`buildflow -s ruff-check-fix --fix`, exit 0).
- Full gates: full1 08:57 (1m13s), full2 09:00 (1m58s), full3 09:03 (1m23s),
  all exit 0.
- Daemon commits carrying this session: `7ef98a4`, `da96af0`, `c9bbcb0`
  (09:03:27, AGENTS.md + migrate_v016.py).
- Bandit direct-run reconciliation: `bandit -r scripts modules tests` = 4
  findings, all `scripts/host-parse-fixture.py` (B404, B603 x2, B108).
- Gate tool counts at close: bandit-check 54 (warning), nix-flake-check 3
  (warning), nix-checker 12 (info). No error-severity findings remain.
