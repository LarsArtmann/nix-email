# 2026-09-16 08:03 - Status: BuildFlow Gate Recovery (flake `self`-removal root cause, devShell unblock, policy skips)

**Point-in-time snapshot.** Scope: the 2026-09-16 ~07:00-07:30 session that
recovered the repo from a fully-red BuildFlow gate (user-pasted failure
report). Observations are from that session's tool output only - nothing
else re-researched. Historical reports are annotated, not rewritten.

Headline: **BuildFlow 25 success / 0 failed, exit 0** ("passed with
warnings", 17.4 s, cache-replayed); independent `nix flake check` exit 0.
Remaining warnings are exactly two documented deliberate non-fixes.

---

## Root cause chain (what the pasted failure actually was)

1. Commit `a4fc343` (2026-09-16 07:07, previous session) removed the
   "unused" `self` from the flake outputs lambda as a lint nit.
2. Nix ALWAYS passes `self` to `outputs`; the closed pattern
   `{ nixpkgs }` rejected it: "function 'outputs' called with unexpected
   argument 'self'" -> the flake could not evaluate AT ALL.
3. Every red in the pasted report cascaded from that: nix-build, vulnix,
   nix-flake-check, nix-build-verify, nix-hash-fix (eval error), and - via
   the missing devShell - dprint/pyupgrade/ruff/mypy/pytest/bandit/vulture
   ("does not provide attribute 'devShells...default'").
4. The nix-checker findings (tests/parsedmarc-e2e.nix:39 sha256) and the
   "9 tools unavailable" (JS/TS + interrogate binaries) were noise both
   before and after; they are not gate-relevant (warning severity).

---

## a) FULLY DONE

| # | Item | Verification (this session, fresh tool output) |
|---|------|------------------------------------------------|
| 1 | Root-cause diagnosis of the failed gate | `git show a4fc343` diff: `- self,` in outputs lambda |
| 2 | flake.nix outputs signature fixed, deadnix-proof: `outputs = { nixpkgs, ... }:` | ellipsis accepts always-passed `self`; deadnix has nothing to strip |
| 3 | `devShells.<system>.default` added (`mkShellNoCC`: alejandra + python3) | `nix develop --command echo` -> `DEVSHELL_OK`, exit 0 |
| 4 | devShells shape corrected after first attempt was wrong (`.default` missing) | `nix flake show`: 0 "is not a derivation" warnings (was ~45) |
| 5 | Formatting green | `nix fmt -- . --check` exit 0 (CI check-mode) |
| 6 | Eval-contract check builds | `nix build .#checks.x86_64-linux.dmarc-eval -L` exit 0 |
| 7 | Full BuildFlow gate green | `buildflow` -> "BuildFlow passed with warnings 24/32", 25 success / 0 failed, EXIT:0; `nix-flake-check ✔ 8.8s`, `nix-build ✔ 17.3s` |
| 8 | Independent gate cross-check | `nix flake check` -> `FLAKE_CHECK_EXIT:0` |
| 9 | `.buildflow.yml` created: skip_steps vulnix / pytest-test / mypy-check, rationale inline | `buildflow verify-config`: "Configuration is valid. 13 steps would run in 'full' mode"; final run shows "6 skipped via config" |
| 10 | vulnix crash decoded: NVD retired legacy JSON feeds (HTTP 404 on `nvdcve-2.0-modified.json.gz`, vulnix 1.12.5 unmaintained) - BuildFlow's "unscannable store path ./result" hint is a MISDIAGNOSIS | full traceback captured in /tmp/gate.log lines 320-349 |
| 11 | ruff F821 false positive silenced at the source: `# ruff: noqa: F821` in tests/fixtures/debug-template.py (start_all/machine are nixos-test-driver-injected) | `buildflow -s ruff-check` exit 0 (was 74 findings) |
| 12 | statix W20 triaged with exact tool wording: it wants `services = { dovecot2 = ...; }` grouping over idiomatic `services.<name> = {...}` node-config blocks - style opinion, not correctness (literal duplicate keys cannot even evaluate) | `nix run nixpkgs#statix -- check tests/parsedmarc-e2e.nix` output captured |
| 13 | "9 tools unavailable" identified: 8 JS/TS (jest, knip, madge, publint, svelte-check, vitest, vue-tsc, c8) + interrogate - expected noise for a Nix-only repo, exit-code-irrelevant | `buildflow --dry-run --verbose` list captured |
| 14 | AGENTS.md updated: buildflow gate + devShell contract in Commands; outputs-signature trap, deliberate non-fixes, vulnix story in Working rules | committed by daemon (08:0x) |
| 15 | deadnix behavior empirically bounded: report-only by default; `-e/--edit` to modify; `-L/--no-lambda-pattern-names` exists upstream "don't break nixpkgs callPackage" - i.e. this breakage class is known upstream | `/tmp/deadnix-self-test`: unused `self` flagged, exit 0, no edit; `--help` captured |

## b) PARTIALLY DONE

1. ~~**CHANGELOG.md** - my session's changes (flake eval fix, devShells
   output, `.buildflow.yml`, AGENTS.md rules) are NOT in `[Unreleased]`;
   it only carries the parallel session's CI pipe-lint item.~~ done (`e18758f`, `2b7257e`: session-6/7/8 entries landed)
2. ~~**TODO_LIST.md routing** - TODO_LIST was freshly swept this morning
   (full docs-health AUDIT) but contains none of this session's findings;
   section (f) below is the HARVEST input. Not routed (user ordered WAIT).~~ done (`e18758f` sweep + the 2026-09-16 evening AUDIT pass)
3. ~~**README.md** - the new devShell + `nix develop` tool-environment
   contract is not reflected in the runbook/README.~~ done (2026-09-16 evening AUDIT: README "Development" section added - devShell, gate hierarchy, no-pipes rule)
4. ~~**Fresh (uncached) VM E2E confirmation** - all greens today were
   store/cache replays (nix-build 17.3 s, flake-check 8.8 s). Sound,
   because my changes touch no test derivation, but no fresh pass was
   OBSERVED this session for stalwart-e2e / stalwart-relay-e2e /
   parsedmarc-e2e.~~ done (fresh runs observed later on 2026-09-16: 15-21 report §a/3-4 full flake check EXIT:0; 18-03 report §a/1 full VM run 362.78 s EXIT:0)
5. ~~**deadnix claim precision** - verified deadnix FLAGS unused `self`;
   did not verify BuildFlow's exact deadnix invocation flags. AGENTS.md
   wording "deadnix --fix re-removes it every run" cites a flag that does
   not exist (mechanism holds only via BuildFlow's edit-mode auto-fix).~~ done (2026-09-16 evening AUDIT: AGENTS.md reworded - report-only default, BuildFlow deadnix auto-fix is the removal path)
6. ~~**BuildFlow binary freshness** - doctor warns the binary predates HEAD
   by ~60 h (advisory, all steps executed fine); upgrade deferred.~~ **Won't implement — machine-local tooling state, not repo content; advisory warning only.**

## c) NOT STARTED

1. ~~`buildflow upgrade` (stale binary).~~ **Won't implement — machine-local; not repo work.**
2. ~~BuildFlow results DB vacuum (doctor: 2.71 GB;
   `sqlite3 ~/.cache/buildflow/buildflow.db VACUUM`).~~ **Won't implement — machine-local.**
3. ~~One fresh uncached full `nix flake check` on the current tree.~~ done (15-21 report §a/4: full gate EXIT:0 on fresh store builds)
4. ~~HARVEST of section (f) into TODO_LIST.md / ROADMAP.md.~~ done (`e18758f` + `43cd0b4` + the 2026-09-16 evening AUDIT pass)
5. ~~CI status check: whether CI ran green on today's commits (the parallel
   session added a CI pipe-lint step; my flake fix landed after).~~ done (master green through `0de8b3d`, incl. runs 35117320385/35118323763 and the PR #1 merge window)
6. ~~BuildFlow pre-commit hook: none installed - the auto-commit daemon is
   the only automated gate.~~ **Won't implement — superseded by the git pre-push fmt hook (TODO_LIST row); a full-gate precommit is too slow for daemon commits.**
7. ~~Upstream filings (all fleet-value BuildFlow tasks, none filed):
   vulnix NVD-404 + misdiagnosis message; nix-checker FP on pinned
   fixtures; statix W20 FP; summary line-count vs finding-count
   discrepancy (statix "60" in summary vs 4 actual findings).~~ _(routed: BuildFlow repo - fleet scope, deliberately out of this repo's TODO_LIST)_
8. ~~The nixpkgs eval warning observed in gate1:
   "The option `services.dovecot2.protocols' ... renamed to
   `services.dovecot2.settings.protocols'" emitted from nixpkgs'
   parsedmarc.nix during OUR check evaluation - not investigated whether
   we trigger it or nixpkgs-internal noise.~~ _(routed: TODO_LIST Low row)_
9. ~~Renovate + Dependabot split-brain check: `renovate.json` exists AND
   `.github/dependabot.yml` was added this morning (github-actions
   ecosystem) - uncoordinated dependency automation.~~ _(routed: TODO_LIST Renovate install-or-drop row; renovate.json still enables github-actions per the 2026-09-16 evening re-read)_
10. ~~Which tool rewrote `{ ... }` to `{...}` in tests/stalwart-relay-e2e.nix
    (dprint is documented as json/yaml/markdown-only; the foreign edit
    suggests something else owns .nix style) - unexplained formatter
    overlap.~~ _(routed: TODO_LIST Low row)_
11. ~~docs-health ANNOTATE pass over this report once its items resolve.~~ done (this pass, 2026-09-16 evening)

## d) TOTALLY FUCKED UP

1. **(Inherited, root cause) `a4fc343` shipped a dead flake with a commit
   message claiming it produced "a clean, warning-free tree" and
   asserting verification.** A lint-nit cleanup was committed WITHOUT
   running the gate it claims to prepare. Today's entire incident is
   downstream. The lesson is now in AGENTS.md, but the process gap that
   let a false "Verification:" line into history is unfixed.
2. **(Mine) First devShells attempt had the wrong shape** - derivation
   directly at `devShells.<system>`, missing `.default`, even though the
   required contract is literally in the error message I was fixing.
   Caught by my own `nix flake show` verification within one cycle;
   cost: one blocked edit + one verification round.
3. **(Mine, small) AGENTS.md over-claim from memory** - wrote "deadnix
   --fix re-removes it every run"; no such flag exists; verified the
   direction only after writing (see b5). Should have tested first.
4. **(Process) Two agent sessions + the auto-commit daemon raced in one
   repo all session**: my shape-fix was blocked by an on-disk change
   (mod-time guard fired); foreign commits landed mid-session
   (ba7645c CI fix, 8dd8894 45-file audit commit); one foreign edit
   (tests/stalwart-relay-e2e.nix whitespace) sat uncommitted for hours.
   No coordination protocol. Survived via edit-tool guards and
   re-reading, not by process.
5. **(Inherited noise) BuildFlow summary overcounts** - "statix 60
   findings" in the summary vs 4 real findings in finding-format
   (summary counts diagnostic lines). Misleading during triage.

## e) WHAT WE SHOULD IMPROVE

1. **Gate-before-commit for nit cleanups**: any commit touching
   flake.nix must run `nix eval` / `nix flake check` first, and the
   message's "Verification:" line must cite a command + exit code that
   actually ran. (Would have prevented the entire incident.)
2. **Never document tool behavior from memory** - 30-second empirical
   tests (the deadnix case) before AGENTS.md claims.
3. **Verify output shapes against their consumer contract before
   writing them** (devShells `.default`), not after.
4. **Doctor-first ordering**: `buildflow doctor` before the first full
   gate surfaces stale-binary/db warnings upfront.
5. **Machine-readable diagnostics**: `nix flake show --json` + jq instead
   of a 300-line eval wall (pipes are fine for diagnostics; the
   no-pipes rule is for gates).
6. **Single-writer discipline** or explicit scope partition while
   multiple sessions + daemon are live in one repo.
7. **Deliberate-non-fix documentation stays in sync** in exactly two
   places (.buildflow.yml comments + AGENTS.md) - keep them mirrored.
8. **Route session outputs immediately** (CHANGELOG, TODO_LIST) instead
   of deferring to "later".

## Self-review (the three questions, blunt)

- **What did I forget?** CHANGELOG entry; README runbook note for the
  devShell contract; TODO routing; a fresh uncached E2E observation;
  doctor-before-gate ordering; and I noticed the parallel session too
  late (only when my edit was blocked by an on-disk change).
- **What could I have done better?** Get the devShells shape right the
  first time (the contract was in the error text I was fixing);
  verify-then-write instead of write-then-verify for the deadnix claim;
  check `git log` for fresh foreign commits at session start and before
  each write; use JSON diagnostics from the start.
- **What could I still improve?** Section (e), plus: build a habit of
  closing the documentation loop (CHANGELOG/HARVEST) in the same
  session, and of distinguishing "verified" from "replayed from cache"
  when reporting green.

---

## f) Up to 50 things we should get done next

> BRAINSTORM, not a commitment list (per status-report skill: larger N is
> HARVEST fuel). Sorted roughly by impact within groups. Items marked
> [dec] need a user decision; [fleet] belong upstream in BuildFlow;
> [ctx] sourced from repo context rather than this session.

**Gate correctness & verification**
1. ~~One fresh uncached `nix flake check` (+ all three VM E2E checks) on
   the current tree - replace cache-replayed green with an observed one.~~ done (15-21 §a/3-4 + 18-03 §a/1: fresh full gate + fresh VM run, both EXIT:0)
2. ~~Align AGENTS.md deadnix wording with reality (report-only default;
   BuildFlow edit-mode is the removal path) - 2-line fix.~~ done (2026-09-16 evening AUDIT)
3. ~~Check CI run status for today's commits (parallel session's CI change
   + this flake fix).~~ done (green through `0de8b3d`, incl. the PR #1 merge run)
4. ~~Investigate the nixpkgs `dovecot2.protocols` rename warning emitted
   during our check evals - ours to fix or documented noise?~~ _(routed: TODO_LIST Low row)_
5. ~~Investigate which formatter rewrote `{ ... }` -> `{...}` in
   tests/stalwart-relay-e2e.nix (documented dprint scope says it should
   not own .nix).~~ _(routed: TODO_LIST Low row)_
6. ~~Resolve the renovate.json + dependabot.yml overlap (split brain).~~ _(routed: TODO_LIST Renovate install-or-drop row)_
7. ~~Add a repo rule: "Verification:" commit-message lines must cite a
   command + exit that actually ran (guards against a4fc343 recurrence).~~ **Won't implement — no enforcement mechanism without precommit hooks (rejected above); the discipline lives in AGENTS's gate-before-commit rules.**
8. ~~Decide [dec] `--fail-on` policy: keep default (error) or move to
   `--strict` (warning) once the two documented FPs are handled upstream.~~ **Won't implement — error-threshold default is the working policy; revisit only if the FPs get fixed upstream.**
9. ~~Verify `.buildflow.yml` passes `buildflow verify-config` in CI, not
   just locally.~~ **Won't implement — CI runs `nix flake check`, not buildflow; the config is validated locally (verify-config EXIT:0).**
10. ~~Keep the root `result` symlink out of scanner paths (cosmetic;
    documented that gates are unaffected).~~ **Won't implement — cosmetic; documented.**

**BuildFlow environment**
11. ~~`buildflow upgrade` (binary predates HEAD ~60 h).~~ **Won't implement — machine-local.**
12. ~~Vacuum the 2.71 GB BuildFlow results DB.~~ **Won't implement — machine-local.**
13. ~~Inspect BuildFlow's deadnix invocation (does it pass `-e`? `-L`?)
    and record it in AGENTS.md.~~ **Won't implement — AGENTS now states the verified part (report-only default, BuildFlow auto-fix removal); exact flag archaeology adds nothing.**
14. ~~Test whether a statix config can scope-disable W20 for tests/ -
    prefer config over prose documentation if it works.~~ **Won't implement — W20 stays a documented deliberate non-fix; config-scoping it adds maintenance for a style opinion.**
15. ~~`buildflow precommit install`? [dec] - hook-gated commits vs
    daemon-only auto-gate.~~ **Won't implement — superseded by the pre-push fmt hook (TODO_LIST).**
16. ~~Baseline uncached step timings (`buildflow timings`) after the fix,
    for future regression detection.~~ **Won't implement — YAGNI; VM-test wall cost is already measured per run in the e2e.**

**Upstream / fleet (BuildFlow repo)**
17. ~~[fleet] File: vulnix NVD-legacy-feed 404 crash + BuildFlow's
    misdiagnosis message ("unscannable store path").~~ _(routed: BuildFlow repo - fleet scope)_
18. ~~[fleet] File: nix-checker hardcoded-hash / inline-hash FPs on
    pinned test fixtures (fetchurl pins are intentional).~~ _(routed: BuildFlow repo - fleet scope)_
19. ~~[fleet] File: statix W20 FP on idiomatic NixOS `services.<name>`
    node-config blocks.~~ _(routed: BuildFlow repo - fleet scope)_
20. ~~[fleet] File: summary counts diagnostic lines, not findings
    (statix 60 vs 4).~~ _(routed: BuildFlow repo - fleet scope)_
21. ~~[fleet] Evaluate a maintained CVE-scanner replacement for vulnix
    (NVD retired the legacy feeds; vulnix unmaintained).~~ _(routed: BuildFlow repo - fleet scope)_
22. ~~[fleet] Consider exposing `buildflow config validate` as a cheap CI
    step for fleet repos.~~ _(routed: BuildFlow repo - fleet scope)_

**Flake / product**
23. ~~CHANGELOG entry for this session (flake eval fix, devShells,
    .buildflow.yml, AGENTS rules).~~ done (`2b7257e` + session-6 entries)
24. ~~README: document `nix develop` devShell + the buildflow gate next to
    the existing runbook.~~ done (2026-09-16 evening AUDIT: README "Development" section)
25. ~~Release decision [dec]: cut v0.2.1 (consumer-relevant for NEW
    consumers; SystemNix's existing pin is unaffected) or batch.~~ done (superseded: batched into the 0.3.0 TODO row - unblocked when PR #1 merged)
26. ~~ROADMAP [dec]: treefmt-nix standard stack vs minimal-alejandra
    (nix-review checklist prefers the stack; compat doctrine prefers
    minimal - genuine tradeoff, user decision).~~ _(routed: ROADMAP §5 raw idea)_
27. ~~Confirm SystemNix's pin still evaluates against this flake (compat
    doctrine spot-check; no bump expected).~~ _(routed: rides the SystemNix push TODO row; pin is tag v0.2.0, all changes since are additive)_
28. ~~Ask SystemNix whether it wants upstream devShells or defines its own
    (contract note in README).~~ _(routed: SystemNix coordination, TODO_LIST row)_
29. ~~Audit that every flake output introduced since v0.2.0 is documented
    (devShells is the only addition so far).~~ done (FEATURES carries the devShell row; no other outputs added)
30. ~~Consider `nix flake update` cadence policy (compat doctrine: only
    together with SystemNix) - write it down [ctx].~~ done (documented: Pin-advance runbook + AGENTS conventions)

**Docs**
31. ~~HARVEST section (f) into TODO_LIST.md / ROADMAP.md (docs-health).~~ done (`e18758f` + evening AUDIT)
32. ~~ANNOTATE this report as its items resolve.~~ done (this pass)
33. ~~Mirror the "known lint noise" list into README only if consumers
    inherit BuildFlow (probably not - confirm, then likely skip) [dec].~~ **Won't implement — consumers don't inherit BuildFlow (flake outputs carry none of it).**
34. ~~Keep `.buildflow.yml` rationale comments and AGENTS.md non-fix list
    in sync on every future skip-set change.~~ done (standing rule, AGENTS Commands)
35. ~~Review docs/TELEMETRY.md staleness caveat (version-skew vs pinned
    0.15.5) [ctx, pre-existing].~~ done (2026-09-16 evening AUDIT: provenance block self-caveats correctly; key-verification doctrine intact)

**Tests**
36. ~~Fresh observed passes for stalwart-e2e, stalwart-relay-e2e,
    parsedmarc-e2e (dup of #1 at check granularity; keep one).~~ done (15-21 + 18-03 fresh runs)
37. ~~Consider extending dmarc-eval (or a tiny eval check) to assert the
    devShells output exists - contract completeness vs YAGNI [dec].~~ **Won't implement — YAGNI; `nix flake show` catches shape breaks (it did during the incident).**
38. ~~Mypy skip revisit trigger: first real Python module lands
    (documented in .buildflow.yml - just honor it).~~ done (trigger documented in `.buildflow.yml`)
39. ~~If more Python fixtures appear, move from in-file noqa to
    ruff.toml per-file-ignores (threshold: 2+ files).~~ done (threshold documented; single fixture keeps the in-file noqa)

**Process / hygiene**
40. Single-writer or scoped-partition agreement for multi-session work
    in this repo [dec].
41. ~~Re-read `git log`/`git status` immediately before every write burst
    while the daemon + parallel sessions are live (cheap, prevents
    blocked edits).~~ done (standing practice; applied every session since)
42. ~~Prefer `--format json` for future triage (grep-able, no ANSI).~~ **Won't implement — advisory preference; nothing to change in the repo.**
43. ~~Decide the fate of `interrogate` (never install; permanently N/A
    unless Python grows).~~ done (documented as expected noise in AGENTS Commands)
44. ~~Commit the still-uncommitted foreign whitespace edit in
    tests/stalwart-relay-e2e.nix (or hand it back to its author) - it
    has been dangling since morning.~~ done (tree clean; the edit landed in the day's commit stream)
45. ~~Post-fix full buildflow re-run on a cold result cache to prove the
    17.4 s green is reproducible, not an artifact of warm caches.~~ **Won't implement — superseded by the fresh uncached `nix flake check` + VM runs from sessions 6-8.**
46. ~~Document the gate hierarchy in AGENTS.md Commands explicitly:
    buildflow (wrapper) vs nix flake check (project gate) - which is
    authoritative when they disagree [dec].~~ done (AGENTS Commands states both; README "Development" now carries the hierarchy too)
47. ~~Spot-check that `nix fmt -- . --check` covers the new
    tests/fixtures file set (it did this session; keep it in the loop).~~ done (observed again in every later gate run)
48. ~~Consider adding `nom` (nix-output-monitor) or `nix flake show --json`
    recipe to README debug section (small QoL) [ctx].~~ **Won't implement — QoL nicety, not worth the README surface.**
49. Schedule the periodic `git town` / repo-hygiene sweep this repo's
    git-town.toml implies [ctx].
50. ~~Close the loop on this session: after HARVEST, delete resolved items
    from TODO_LIST per its living-document rule (completed items are
    DELETED, not ticked).~~ done (e18758f + evening AUDIT sweeps)

---

## g) Questions I cannot figure out myself

1. ~~**Is the parallel session still active, and who owns the tree?**
   Mid-session I observed foreign commits (ba7645c CI fix, a 45-file
   docs-health audit) and a dangling uncommitted edit to
   tests/stalwart-relay-e2e.nix that is not mine. I cannot know whether
   another agent is running right now. Should I take exclusive ownership
   (and commit/dispose of the dangling edit), or coordinate around it?~~ done (moot by evening: tree clean, everything pushed, the dangling edit long since landed)
2. ~~**Commit gating policy:** should I install the BuildFlow pre-commit
   hook (`buildflow precommit install`) so "lint nit" commits physically
   cannot skip the gate, or do you deliberately keep the auto-commit
   daemon as the only automated gate?~~ _(routed: TODO_LIST branch-protection policy row - same bypass-vs-strict decision)_
3. ~~**Release cadence:** the flake-eval fix + devShells output are
   consumer-visible for new consumers (SystemNix's existing v0.2.0 pin
   is unaffected). Cut v0.2.1 now, or batch with the next
   consumer-visible change?~~ done (superseded: batched - the 0.3.0 TODO row now covers it, unblocked when PR #1 merged)

---

## Verification appendix (commands as run, exit codes)

- `nix flake show` -> SHOW_EXIT:0 (second run: 0 shape warnings)
- `nix fmt -- . --check` -> FMT_EXIT:0
- `nix develop --command echo` -> DEVSHELL_OK, EXIT:0
- `nix build .#checks.x86_64-linux.dmarc-eval -L` -> EXIT:0
- `buildflow` (full) -> 25 success / 0 failed, EXIT:0 (gate1: 26/32, 1
  failed = vulnix, EXIT:69; pre-fix pasted run: 7 failed, EXIT:1)
- `nix flake check` (independent) -> FLAKE_CHECK_EXIT:0
- `buildflow verify-config` -> valid, EXIT:0
- `buildflow -s ruff-check` -> EXIT:0
- `nix run nixpkgs#deadnix` self-test -> flags unused self, exit 0, no
  edit (report-only default confirmed via `--help`)

_Time: 2026-09-16 08:03 CEST. This file is a historical snapshot; living
facts live in README.md's verified-facts ledger and AGENTS.md._

---

## Resolution addendum (2026-09-16, docs-health pass)

All sections resolved inline. a/§f items 40 (single-writer agreement) and
49 (git-town sweep cadence) stay open as user process decisions. Fleet
items (f/17-22) live in the BuildFlow repo, not here. HARVEST landed:
f/4, f/5 → TODO_LIST Low rows; f/6 → the Renovate install-or-drop row;
f/15 → superseded by the pre-push fmt hook row; f/26 → ROADMAP §5;
f/25/f/28/f/27 → the 0.3.0 release row / SystemNix coordination row.
Archived.
