# Alpha execution: gap-filler lanes landed (R2/H1/T3/O1.1/S1/T1/E16.1); CI red on the new dprint gate

**2026-11-02 00:25 CET.** Session start ~18:40 2026-11-01. Mandate: execute
the WHOLE Alpha plan (`docs/planning/2026-11-01_18-11_*`). Owner-gated tasks
(O1 answering, A1/A2, B1, C-lane, R1) were NOT executed — the plan's
kill-switch #7 forbids defaulting owner decisions; everything with zero owner
dependency inside nix-email plus the docs-health skill repo was executed.

## a) FULLY DONE (verified, with evidence)

1. **Baseline + concurrency map.** `git status` clean at start; 19 live
   crush PIDs mapped to cwds: **SystemNix and pbx-artmann are OWNED by live
   sessions** → D1/D2, E9.2, E12, E14, B1 lanes untouched (doctrine: foreign
   in-flight repos). BuildFlow + SKILLS/docs-health unowned → eligible.
2. **R2 — unified formatter (the dprint coverage gap).**
   `flake-modules/devshells.nix`: `formatter` is now a wrapper routing
   `.nix` → alejandra and everything else → dprint, so the ONE canonical
   `nix fmt` / `nix fmt -- . --check` line (CI step + pre-push) covers both
   toolchains. Negative-tested BOTH directions locally (bad md fails check
   EXIT 1; `nix fmt` repairs). ci.yml step renamed (YAML-quoted after an
   actionlint catch); pre-push hook comment, AGENTS.md trap text,
   CONTRIBUTING gate section updated; CHANGELOG Changed entry. Commit
   `02ea3db` (+ daemon rider `be55e56`); statix + actionlint green.
3. **H1.1 — TODO_LIST strike-fragment normalization.** Four `~~` fragments
   normalized to bold-verdict form (the fourth was hidden mid-Evidence-cell:
   the mailsuite "wait until ~11-05" MOOT fragment). `annotate.go check-rows
   TODO_LIST.md` → **"1 file(s) complete", EXIT 0**; pipe lint green.
4. **H1.2 — CONTRIBUTING self-test rule.** "Any repo tool that carries a
   `--self-test` gets that self-test re-run in the SAME session that mutates
   the tool" added under "The gate".
5. **T3 — TELEMETRY.md compression.** The 0.16.26 VERDICT (D8) now leads
   the provenance block; the four dated 0.15-era interim updates collapsed
   into one History paragraph; stale "pinned Stalwart is 0.15.5" checklist
   item corrected to 0.16.26; §9 open-item 2 (0.15 TOML paths) RESOLVED.
   AGENTS.md doc-map pointer updated. dprint + pipes green.
6. **O1.1 — sitting sheet Batch 8 (mechanical prep only).** The four new
   calls added (g/2 CI cache-throttle policy, g/3 e2e timeout
   sweep-vs-per-flake, Q10 a/b A4 residuals) with recommendations +
   transcripts; 2026-11-01 coverage re-proof comment (open-call inventory
   cross-checked; C43/C45 marked settle-at-O3.3, not re-asked); Appendix C
   unlock rows; time budget re-dated ~75 min. Owner ANSWERING not done by
   design.
7. **S1 — docs-health skill upstream batch (SKILLS repo, was unowned).**
   Three additions: metadata Field/Value tables take the RESOLVED-append
   form (new Pattern C in `references/resolving-items.md`), the
   verify-read-IN-FULL mandate (verdict maps built FROM `--verify` output,
   never remembered greps) in SKILL.md, and the check-rows continuation-row
   blind-spot note (bare empty-leading-cell rows under struck parents pass
   the gate; interim mitigation = explicit
   `→ (row N verdict covers this continuation)` + row-count audits — the
   parked E1.2 proposal substance, recovered from the 20-48 catch and the
   10-30 e/4 finding). `scripts/check-skills.sh` green (33 skills);
   committed `2527308` incl. a dprint table-padding drift rider on
   go-error-modernization (formatting-only, called out in the message).
8. **T1 — VM/debug tooling batch, transcript-verified against a LIVE
   demo VM** (`docs/probes/2026-11-01_demo-smoke-tooling/README.md`):
   - `scripts/demo-console.sh`: boot to login prompt, `sleep infinity`
     holder, 900 s hard timeout killed the whole process group, NO orphan
     QEMU left holding the demo-disk write lock. (First run caught its own
     bug: `.#vm` is an app, not a package — the closure is
     `nixosConfigurations.demo.config.system.build.vm`; fixed in-script.)
   - `scripts/vm-debug.sh --script-only --check`: EXIT 0 end-to-end —
     check eval, GC root (cached), driver extraction, starter generated
     under `~/.cache/nix-email/vm-debug/` (moved off `/tmp`), py_compile +
     rule-(b)/(f)/host-socket lint clean, driver command line printed
     without executing. User scripts from `/tmp` are copied to the cache
     dir before the driver runs (the 2026-10-31 sweeper class).
   - `scripts/demo-smoke.py`: **5/5 legs GREEN live** — anon JMAP session
     (200, apiUrl), AUTH submission 2587 STARTTLS+LOGIN, IMAPS 2593
     round-trip (needle `smoke-fb9d1a8f095351a1` delivered), catch-all
     accept on 2525, strict `x@demo.test` → 550. Ruff floor + py_compile
     clean. CONTRIBUTING pointers updated (console + smoke + modes).
9. **E16.1 — CI ruff step timing measured.** Run 41265954894 step
   "Lint Python files": 02:37:49Z → 02:37:59Z = **10 s** on a fresh runner
   (ROADMAP claimed ~13 s; same class — cold GitHub-ref eval walk, not nix
   being slow).

## b) PARTIALLY DONE

1. **E16.2 — ruff-floor lane.** Decision made: `.#ruff-floor` app
   (lock-resolved, no `github:NixOS/nixpkgs/$rev` eval walk); the ROADMAP's
   alternative premise ("devShell CI already builds for the fmt step") DIED
   with R2 — the formatter is now a store-path wrapper, not a devShell.
   NOT yet implemented (flake attr + ci.yml rewiring + eval guards).
2. **E16.3 refinement.** ROADMAP wants `--script-only` to skip the
   GC-root build (no VM run); my shipped version still builds it. The edit
   was prepared but blocked TWICE by the modified-since-read guard (daemon
   commits racing my edits) — re-apply pending.
3. **H1.3.** The f12ed24 session's report is STILL absent from the
   corridor (checked at start and again ~00:20); row stays open (external).
4. **CI watch.** The queued docs-only run 41330548537 went RED, and both
   successor runs too — triaged (see d), fix pending instructions.
5. **Bookkeeping batch (deferred by design to one surgery pass).** TODO row
   deletions (R2/T1/T3/S1 rows now landed), FEATURES rows, ROADMAP theme-6
   (a)/(b) flips, CHANGELOG entries for T1/T3, final gates.

## c) NOT STARTED

T2.1-T2.10 (deliverability probe backlog — the biggest repo lane), E5.1/E5.2
(parsedmarc ARF event assert + aggregate subtest control), E11.1/E11.2
(queue surface + dashboard row), E8.1 (vulnix replacement evaluation),
D3.1-D3.3/D4.1-D4.2 (BuildFlow batch, unowned), A5.1-A5.3 (hub workstream
check + publish chain), the full-gate verification pass (`nix flake check`
with builds), end-of-session TODO/FEATURES/CHANGELOG truth-up.

## d) TOTALLY FUCKED UP

1. **THREE consecutive RED CI masters: 41330548537 (4b7c2e8),
   41352524281 (d0ae969), 41358445174 (1aaec31).** Root cause (read from
   `--log-failed`, step "Enforce formatting: alejandra + dprint"):
   **my own R2 wrapper works exactly as designed and CI now enforces dprint
   — but the daemon pushed my unformatted docs before I formatted them.**
   At d0ae969/1aaec31: 2 files (the new probe transcript README +
   CONTRIBUTING pointer edits). Locally at 00:20: exactly
   `docs/probes/2026-11-01_demo-smoke-tooling/README.md` remains. The gate
   is correct; the author (me) shipped to it unformatted. Fix = one
   `nix fmt` + commit; the next push re-runs CI.
2. **Bracketed-paste artifact (`[?2004h`) landed inside a vm-debug.sh
   string via multiedit** — caught by immediate read-back, repaired with
   sed byte surgery (edit tools can't match invisible bytes).
3. **My 18:44 "whole tree dprint-clean" verification went stale
   mid-session**: I kept editing docs after it and formatted per-file,
   missing one entirely. Same class as the 11-01 closeout lesson the R2
   task itself was fixing — the fix created a fresh instance of the
   original sin.
4. Two mod-time guard rejections on the same vm-debug edit (edited across
   daemon commits without re-viewing first).

## e) WHAT TO IMPROVE

- **Run `nix fmt -- . --check` after EVERY docs write**, or at every
  natural pause — daemon push windows make per-file formatting and
  "I'll format at the end" both unsafe. The tree-level gate is the only
  check that matches the push model.
- **Byte-level read-back after every multiedit** on files with quotes and
  escapes (one invisible-artifact catch this session).
- Re-view immediately before re-applying a guard-blocked edit — the file
  changed under you; your old_string is from a stale world.
- The SKILLS dprint-drift rider was committed with a callout line — keep
  that habit for foreign riders.
- Consider asking the owner for a daemon-pause env var for mid-flight docs
  sessions (the R2 red chain is the second daemon-push red class after
  statix 4x).

## f) NEXT (ordered, top = unblock)

1. `nix fmt` the tree + commit → green CI chain (fixes the 3 reds).
2. Re-apply vm-debug.sh `--script-only` skip-build (re-view first).
3. E16.2: add `.#ruff-floor` app (pinned `pkgs.ruff`) + rewire the ci.yml
   ruff step (KEEP the never-firing self-test) + run both eval guards
   (check attrNames unchanged + aarch64 shape) + read the next CI step
   timing.
4. ROADMAP theme-6: flip (a) with the measured 10 s + chosen lane; flip
   (b) vm-debug modes DONE.
5. CHANGELOG: T1 (console + smoke + modes) and T3 (TELEMETRY compression)
   entries, same-call commits.
6. TODO_LIST surgery: DELETE the dprint-coverage, VM/debug-tooling,
   TELEMETRY-compression, docs-health-skill rows; trim the hygiene row to
   the H1.3 residue; check-rows + pipes after.
7. FEATURES.md rows: unified formatter gate, demo-console.sh,
   demo-smoke.py, vm-debug modes (+ ruff-floor when landed).
   8-18. **T2 lane**: enable=false eval pin; inbound-MX canary (1 h
   negative-cache trap); junk-folder verdict; IPv6/DNSBL/PTR; cert expiry
   25/587; per-check timeouts + metricsUrl; dmarc-freshness +
   parsedmarc-sink INFO; emission-only ADR 8 + quickstart note; trivia tail
   (owner-taste flags marked); CONTRIBUTING force-assert pattern;
   deliverability-e2e + eval rebuilds; full gate.
   19-20. **E5**: traced-verbosity ARF event assert (transcript-first: run,
   capture journal, then assert); aggregate-subtest control + combined
   runtime budget.
   21-22. **E11**: queue-surface re-verify + MONITORING row refresh; first
   `queue_rescheduled` dashboard/alert row (consumer-side spec).
8. **E8.1**: BuildFlow scanner roadmap check; go-vulncheck/osv-scanner
   evaluation; record the verdict.
   24-28. **D3/D4 (BuildFlow, unowned)**: count-gap reproduction; ruff
   identity parsing fix (both modes); detect-only/vulture/masking/threshold

- jscpd skill note; binary rebuild + delta review + reinstall;
  `buildflow -d` + state-DB purge + rev-stamp cadence.
  29-30. **A5**: hub workstream read; publish chain only if the demo-flagging
  workstream landed.

31. Full `nix flake check` (WITH builds) redirected, EXIT read.
32. Pre-push suite green locally (fmt check, inventory, actionlint, md
    lints, statix, testscript shell).
33. Watch CI to green BY STEP NAME.
34. H1.3: re-check the corridor for the f12ed24 report; merge or keep.
35. Next docs-health pass inputs: this report + the 17-43/18-00 pair as
    ONE session; Ω-plan banner + archive; B3's three stay frozen until the
    pbx blessing.
36. AGENTS.md: consider one line "run `nix fmt` before ANY yield — the
    daemon pushes mid-session" (the R2 incident as the citation).
37. (owner) THE SITTING: sheet Batches 1-8, ~75 min — unlocks >51%.
38. (post-sitting) O3 verdict recording; A1/A2 filings; B1-B3; C1-C10; R1.
39. (gated) E4 (A5), E9/E12/E14 (D1 host), E10 (C2), E13 (D10), E17
    (next bump ride).

## g) QUESTIONS (cannot figure out myself)

1. Master is red from my dprint-gate extension catching my own unformatted
   docs — fix is one `nix fmt` + commit. You said WAIT: apply that single
   fix now, or does EVERYTHING wait for your go?
2. BuildFlow (D3/D4) is unowned right now; the plan parks it as
   "their repo, their cadence". Execute it in this session — including the
   binary reinstall and state-DB purge on this machine — or reserve it for
   a dedicated BuildFlow session?
3. The sitting sheet is Batch-8-extended and coverage-re-proofed; one
   ~75-min sitting unlocks >51% of the plan. Run it now, or should I keep
   burning the non-owner lanes (T2/E5/E11/E8) first?
