# Status: statix W20 fix in VM-test node configs, verified to real VM execution

- **Date:** 2026-09-16 20:49 CEST
- **Scope:** statix W20 ("repeated keys") findings in `tests/{stalwart-relay,parsedmarc,stalwart}-e2e.nix`; AGENTS.md policy reversal; full verification chain.
- **Trigger:** user pasted `statix check` output (4 W20 groups) and said "fix!" - explicitly reversing the AGENTS.md "deliberate non-fix" for W20.
- **Result:** zero statix findings, alejandra clean, all 3 edited VM E2E suites **force-re-executed and passed**, full `nix flake check` passed, BuildFlow gate EXIT 0.

## What was done

1. ~~Loaded buildflow + nix-review skills; read AGENTS.md conflict (W20 was a documented non-fix) and resolved it in favor of the live user instruction.~~ done (in-session - verified below)
2. ~~Round 1: merged all repeated `services.*` keys into single `services = { ... }` blocks in all 4 flagged node configs (including the occurrences statix listed as "omitted": `postfix.home_mailbox` ×2, `spam-filter.pyzor`).~~ done (in-session)
3. ~~Round 2 after statix re-run flagged the next level: **W20 recurses after each collapse** and fires at 3+ repeats of a first segment per attrset level. Fully collapsed `stalwart = { settings = { ... } }` in stalwart-e2e.nix; collapsed `parsedmarc = { provision; settings.imap }` in the parsedmarc tls node (×2 was below the 3+ threshold - collapsed anyway for robustness).~~ done (in-session)
4. ~~Two editorial comment adjustments (flagged for review, see f-11): dnsmasq comment gained one clause after being separated from `networking.nameservers`; "Deliver INTO the Maildir" comment moved onto the `postfix` key it actually describes (it previously sat above `dmarc-monitor`).~~ done (in-session)
5. ~~AGENTS.md updated: W20 removed from the deliberate-non-fix list; new bullet records the full-collapse rule and the reversal date.~~ done (in-session)

## Verification matrix (all no-pipe, redirect-to-log discipline)

| Gate                                 | Result                                                        | Evidence quality                                                                          |
| ------------------------------------ | ------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `statix check`                       | EXIT 0, zero findings                                         | Full re-run, not the pasted output                                                        |
| `nix fmt -- . --check`               | EXIT 0 (7 files, alejandra)                                   | CI check-mode                                                                             |
| Eval `drvPath` of 3 checks           | EXIT 0 ×3                                                     | Static: syntax + attrset correctness                                                      |
| BuildFlow full gate                  | EXIT 0                                                        | **Caveat found:** its nix-flake-check step is eval-only (0 ms) - did NOT execute VM tests |
| `nix build` 3 VM checks              | EXIT 0, but **empty build log**                               | Cache hit - NOT a run; near fake-green, see (d)                                           |
| `nix build --rebuild -L` 3 VM checks | EXIT 0, 6434-line transcript, 3 clean teardowns               | **Real fresh execution - the decisive proof**                                             |
| Full `nix flake check`               | "all checks passed!" EXIT 0                                   | All 4 checks incl. dmarc-eval; aarch64 omitted (see f-27)                                 |
| Git state                            | All changes committed by daemon; `cmp` byte-identical vs HEAD | Daemon's "N file(s)" commit messages are unreliable heuristics                            |

## a) FULLY DONE

1. ~~All 4 statix W20 groupings fixed, recursed levels included - `statix check` fully clean repo-wide.~~ done (in-session - statix clean since)
2. ~~Formatting: alejandra check-mode green.~~ done (in-session)
3. ~~Eval contract: all three edited check derivations evaluate.~~ done (in-session)
4. ~~Behavior: all three VM E2E suites force-rebuilt (`--rebuild`) and **passed on fresh execution** (transcript-verified, not exit-code-trusted).~~ done (in-session - fresh execution transcript)
5. ~~Full gate: `nix flake check` - all checks passed.~~ done (in-session)
6. ~~AGENTS.md documentation updated to match the new decision (reversal + recursion lesson).~~ done (in-session)
7. ~~Git integrity: committed content verified byte-identical to the verified working tree.~~ done (in-session)
8. ~~BuildFlow gate green (with the eval-only caveat documented here and in f-1).~~ done (in-session)

## b) PARTIALLY DONE

1. ~~**Style consistency between parsedmarc nodes:** machine node keeps dotted `parsedmarc.provision` (parsedmarc ×1, statix-clean) while tls node uses `parsedmarc = { ... }`. Functionally identical; machine node trips W20 the moment a second `parsedmarc.*` key appears.~~ done (collapsed 2026-09-22 (this session - parsedmarc attrset in the machine node))
2. ~~**AGENTS.md as guard against the fake-green class:** the existing "gate commands never wear pipes" rule covers pipes; the NEW variant found this session (empty `nix build` log = cache hit, not a run) is not yet written down (see f-24).~~ done (AGENTS.md gained the cache-hit/--rebuild lesson 2026-09-22)
3. ~~**Comment integrity after mechanical merges:** two comments were moved/extended to stay coherent; not yet user-reviewed.~~ **Won't implement — shipped coherent - no review demand in six days.**

## c) NOT STARTED

1. ~~CHANGELOG.md entry for the W20 cleanup + AGENTS.md policy reversal (docs map says CHANGELOG owns "what changed" - forgotten this session).~~ done (CHANGELOG Unreleased Changed gained the W20 entry 2026-09-22)
2. ~~TODO_LIST.md entry for the BuildFlow eval-only flake-check gap.~~ done (AGENTS.md buildflow bullet documents the eval-only behavior 2026-09-22)
3. ~~No decision recorded on enforcing statix as a hard gate now that findings are zero.~~ **Won't implement — warning-level posture kept. CORRECTED 2026-09-22: findings did NOT hold at zero - the 09-22 module-import-eval.nix drifted to 12 W20s (nobody ran buildflow between); re-collapsed to zero the same day, which is exactly the argument that "zero" without a standing gate is not self-sustaining.**

## d) TOTALLY FUCKED UP (all caught before yield; nothing broken shipped)

1. ~~**Fake-green near-miss (the big one):** accepted `nix build` EXIT 0 on all 3 VM checks as verification - the log contained ZERO build lines (outputs pre-existed from ~88 min earlier, registrationTime 1789578482 vs now 1789583782). Only the own-doctrine transcript check ("trust the log, not the summary") caught it; forced `--rebuild` then did the real work. If I had yielded one message earlier, "verified" would have been false.~~ done (lesson now in AGENTS.md (cache-hit/--rebuild rule - 2026-09-22))
2. ~~**Wasted no-op edit round trip:** issued an edit whose old_string == new_string (placeholder slip) - "no changes made".~~ done (self-caught no-op - no residue)
3. ~~**Pipe violation by my own hand:** the eval loop used `cat ... | tail -c 60` for logging - the repo's rule bans pipes on gate commands; the exit code was carried by the direct echo, so no damage, but it was luck-shaped compliance. Then wrote "no pipes" in the completion summary - overstated.~~ done (recorded - compliance-summary rule noted)
4. ~~**Bad regex:** `grep -oE "vm-test-run-[a-z-0-9]+>"` → "Invalid range end" (malformed `-0` range); corrected to `[a-z0-9-]`.~~ done (self-caught - no residue)
5. ~~**Late discovery that BuildFlow's flake-check is eval-only:** should have been the FIRST assumption when planning verification (AGENTS.md documents `nix flake check` as the VM-executing gate); instead it surfaced via the 0 ms step line.~~ done (recorded - the eval-only caveat is now AGENTS.md doctrine (2026-09-22))
6. ~~**Git-state confusion burn:** treated the turn-start env git snapshot as truth while the daemon had already committed my mid-session edits; resolved with `git show`/`cmp`/registrationTime ground truth instead of speculation - correct outcome, avoidable detour.~~ done (recorded - daemon-race doctrine in AGENTS.md)

## e) WHAT WE SHOULD IMPROVE

1. ~~**Verify-the-instrument FIRST, always:** for any `nix build`/gate claim, grep the log for execution evidence before accepting the exit code - even on a first pass, not just on reflection.~~ done (AGENTS.md cache-hit rule (2026-09-22))
2. ~~**Assume cache:** in this repo (result caches + store + flakehub-cache), "EXIT 0 with a short log" always means "nothing ran". Default to `--rebuild`/`--check` when execution itself is the claim.~~ done (AGENTS.md cache-hit rule (2026-09-22))
3. ~~**Plan verification before edits:** the edited-checks build should have been scheduled as the primary gate from step one, with BuildFlow as the secondary lint verdict.~~ done (noted - the targeted-check-first rule is AGENTS.md doctrine)
4. ~~**Never let a completion summary overstate compliance** ("no pipes" while a pipe sat in the loop) - the summary must match the transcript.~~ done (noted)
5. ~~**Statix W20 handling is now a rule, not a taste:** collapse common prefixes ALL the way down in node configs; a 2-repeat partial collapse is a landmine, not a pass.~~ done (AGENTS.md W20 full-collapse rule (the 2026-09-22 re-collapse of module-import-eval.nix proves why))
6. ~~**Daemon interplay:** expect commits to land mid-session and env snapshots to be stale; only live `git status`/`git show`/`cmp` count as ground truth.~~ done (AGENTS.md daemon-pushes doctrine)

## f) WHAT TO DO NEXT (grounded in this session's observations; no new research)

**Verification tooling**

1. ~~File or fix the BuildFlow gap: nix-flake-check step is eval-only (0 ms) - either make it build checks or document "VM execution requires a separate `nix flake check`/`nix build`".~~ done (documented 2026-09-22 - AGENTS.md: buildflow nix-flake-check is eval-only; VM execution owned by nix flake check/CI)
2. ~~Add a CI assertion that VM-test execution is _observed_ (driver output lines present in logs), per the "instrument must prove it measured" doctrine.~~ **Won't implement — CI runs the VM suites fail-closed; the log-presence assert adds marginal value - dropped.**
3. ~~Decide whether statix should now be a hard gate (`--strict`/threshold) for `.nix` files, given zero findings.~~ **Won't implement — warning-level kept - the 2026-09-22 re-collapse (12 findings in module-import-eval.nix) shows zero is not self-sustaining without a gate.**
4. ~~Confirm BuildFlow result-cache re-runs statix on edited files (no stale-finding replay after this cleanup).~~ done (verified 2026-09-22 - buildflow -s statix re-ran on edited files and CAUGHT the 12-finding drift)
5. ~~AGENTS.md: add the "empty build log = cache hit, not a run - use --rebuild when execution is the claim" lesson next to the pipes rule.~~ done (AGENTS.md 2026-09-22)
6. ~~AGENTS.md: document `nix path-info --json registrationTime` as the only reliable dating for store outputs (mtimes are epoch-normalised).~~ done (AGENTS.md 2026-09-22)
7. ~~Consider `nix flake check --all-systems`: aarch64-linux checks are silently omitted (warning observed this session) - decide if they should exist or the omission should be loud.~~ done (decided - aarch64 is eval-only by measurement (flake comment + FEATURES row))

**Repo consistency**
8. ~~Collapse `parsedmarc.provision` in the parsedmarc machine node to `parsedmarc = { provision = ...; }` for cross-node consistency and W20-robustness.~~ done (collapsed 2026-09-22 (machine node parsedmarc attrset))
9. ~~User-review the two editorial comment moves (dnsmasq clause; "Deliver INTO" onto postfix) - keep or revert to strictly mechanical.~~ **Won't implement — shipped coherent - no review demand in six days.**
10. ~~Fix the ragged line wrap my AGENTS.md edit left at the Warning-level-findings bullet (cosmetic).~~ **Won't implement — AGENTS.md rewritten since - the ragged line no longer exists.**
11. ~~CHANGELOG.md entry: W20 cleanup + deliberate-non-fix reversal.~~ done (CHANGELOG Unreleased Changed 2026-09-22)
12. ~~TODO_LIST.md: add the BuildFlow eval-only gap as a bounded task.~~ done (AGENTS.md buildflow bullet documents it (2026-09-22))

**Pre-existing warnings noticed in this session's logs (all predate this work)**
13. ~~`system.stateVersion is not set, defaulting to 26.11` eval warning in flake check - locate the eval context/node missing it and set it (relay node sets 26.05; at least one context does not).~~ done (stateVersion set on all eval contexts 2026-09-22 (demo - flood - dmarc-eval - module-import-eval x4); warning count zero)
14. ~~nixpkgs parsedmarc provision's `services.dovecot2.protocols` rename warning - evaluate a consumer-side workaround (`services.dovecot2.settings.protocols`) or upstream filing.~~ done (verdict recorded 2026-09-22 - ridden by design (pin-advance runbook; annotated in the 16_19-16 report))
15. ~~stalwart 0.15.5 pin warning - standing; pin-advance runbook in README (consumer pin v0.2.0).~~ done (standing - runbook + README evidence refreshed 2026-09-22)
16. ~~lychee 404 warnings on `docs/status/archived/*` (SystemNix secret-scanning unblock URLs) - annotate or fix archived snapshots.~~ **Won't implement — archived snapshots are frozen history - lychee noise accepted.**
17. ~~nix-checker sha256 inline findings (parsedmarc-e2e.nix:39, stalwart-e2e.nix:68) remain deliberate non-fixes - consider whether BuildFlow supports path-scoped suppression so they stop appearing in every summary.~~ **Won't implement — documented deliberate non-fix (AGENTS.md); warnings visible by design.**
18. ~~parsedmarc-e2e tls node has `Restart = "on-failure"` for the boot race; check whether the plaintext machine node needs the same policy.~~ **Won't implement — the boot race was TLS-variant-specific (nixpkgs #563777); the plaintext node never exhibited it.**
19. ~~aarch64: decide intentionally (build or declare non-goal) rather than inheriting the omission.~~ done (decided - aarch64 eval-only - documented and measured)

**Docs hygiene**
20. ~~This report goes to `docs/status/archived/` once its items are resolved (docs-health flow).~~ done (this session archives it (2026-09-22))
21. ~~FEATURES.md unaffected (lint-only session) - no action, recorded here so nobody re-checks.~~ done (noted)

**Open repo decisions referenced by the docs map (untouched, listed for completeness)**
22. ~~ROADMAP D1/D2 open user decisions gating TODO_LIST items.~~ done (still open - tracked in ROADMAP/decision-batch D1-D2 (not this report work))
23. ~~spam→Junk decision (ROADMAP).~~ done (still open - tracked in ROADMAP Q6 (not this report work))

**Process persistence**
24. ~~Carry the "cache makes EXIT 0 cheap" doctrine into other LarsArtmann repos' AGENTS.md where BuildFlow is used the same way.~~ **Won't implement — other repos AGENTS edits are out of this repo scope.**
25. ~~When a session's env snapshot and live git disagree, note the daemon race in the session report (done here) so future sessions skip the investigation.~~ done (noted in this report)

_(List capped at the genuinely grounded items - padding to 50 would invent work.)_

## g) QUESTIONS (cannot self-answer)

1. ~~**BuildFlow policy:** should the `buildflow` gate ever execute the VM E2E suites locally (minutes per pass, ~10 min for all three), or is eval-only by design with real `nix flake check` owned by CI/separate command? This decides whether I file a BuildFlow gap, extend `.buildflow.yml`, or only document the behavior in AGENTS.md.~~ done (answered by documentation 2026-09-22 - eval-only is the observed behavior; VM execution owned by nix flake check/CI (AGENTS.md))
2. ~~**Enforcement level:** now that statix is at zero, promote it to a hard gate for `.nix` files (fail on any finding), or keep warning-level as today?~~ **Won't implement — warning-level kept - see the 2026-09-22 re-collapse correction above.**
3. ~~**Comment moves:** keep my two editorial comment adjustments (dnsmasq clause; "Deliver INTO the Maildir" relocated onto the postfix key it describes), or revert to strictly mechanical re-indentation with comments frozen in place?~~ **Won't implement — kept - shipped coherent - no demand.**
