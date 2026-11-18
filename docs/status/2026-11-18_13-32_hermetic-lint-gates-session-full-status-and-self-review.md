# 2026-11-18 13:32 CET - Full session status + brutal self-review: hermetic lint gates

Scope line - what this report covers: the 2026-11-18 "more nix
native?" session (statix-lint / text-gates / vm-test-lint, two master
CI reds fixed) plus its own failures, verified from the session's own
transcripts: `date` 2026-11-18 13:32 CET; `git status -sb` =
`master...origin/master [ahead 6]`; newest CI run 44294708990
(2026-11-18 11:26, on the PRE-fix tree) still failure; `git log -S`
proves the transient fixture corruption below was never committed;
the mechanization queue (docs/planning/2026-11-02_06-55_*) carries no
overlapping items (grepped awk/hermetic/text-gate/pipe/statix - zero
hits).

## a) FULLY DONE (each built with -L, lockstep-registered, gate-green)

1. `statix-lint` flake check: statix from the repo pin over the flake
   source; measured contract (errors exit 1, warnings exit 0) made
   explicit; plants a syntax error to prove it fires. Replaces the
   per-run registry eval walk CI step.
2. `text-gates` flake check: the four markdown/count-drift lints
   hermetic (pinned bash/gawk/python3, flake source, FULL selftest
   matrix first). Four ambient CI steps consolidated into one
   fail-fast `nix build`. The `${../.}` lone-file-store-copy gotcha
   (first build failed with repo=/nix) is documented in-file.
3. `vm-test-lint` flake check + `scripts/check-vm-pipe-assertions.sh`:
   the pipe-assertion ban moved out of ci.yml (raw inline awk was
   untestable in place), `--self-test` mechanizes the 2026-09-16
   one-off negative test, per-line `# vm-pipe-ok: <reason>` exemption
   added; runs together with the testscript-shell lint, pinned.
4. Master CI red #1 FIXED (root cause): anchors selftest fixtures used
   bash-only `printf \xHH`; the runner's /bin/sh did not decode them
   (CI red since 2026-11-13 on fixture text, not tree). Now POSIX
   octal, portable across every POSIX printf.
5. Master CI red #2 FIXED (latent): two migrate-1x plumbing lines had
   the ambient pipe lint red since 2026-11-06, hidden behind red #1;
   now explicitly marked with reasons.
6. Corridor truth: README prose rows for all three checks, AGENTS
   text-gates bullet rewritten, CONTRIBUTING failure-class table
   (eighth script) + stale "--only selector" sentence fixed,
   drift-lint pointer text now names tests/check-expected.json.
7. Full local gate: `nix flake check` EXIT:0 (13 derivations built,
   incl. the changed migration VM rerun), `nix fmt -- . --check`,
   actionlint+shellcheck, every text lint, `check-inventory.sh`.
8. Session status report filed (renamed to its TRUE mtime, see d).

## b) PARTIALLY DONE

1. "More nix native" as a goal: seven ambient lint invocations are now
   hermetic, but the remaining ambient CI surface (ruff-floor step,
   registry-floating actionlint, jq/grep in the lockstep steps, the
   redundant parse step) was deliberately deferred - documented in the
   status report, NOT routed to TODO_LIST.
2. CI-green verification: local gate is green, but all six session
   commits are UNPUSHED; the 11:26 CI failure ran the pre-fix tree.
   "CI should go green" is a prediction, not an observation.
3. Corridor docs: three files updated; TODO_LIST rows and CHANGELOG
   entries not written.

## c) NOT STARTED

1. `buildflow` - never invoked this session (only nix flake check,
   fmt, actionlint, text lints).
2. aarch64 deep-eval of the new checks under emulation (attrNames
   shape verified; the derivation builds unproven on that arch -
   same posture as the pre-existing pure checks).
3. TODO_LIST routing of the deferred conversions.
4. CHANGELOG entries (may be owned by the release procedure).
5. Audit of the four interleaved daemon auto-commits for foreign
   hunks (four other crush sessions were alive at session start).
6. Hermetic conversion of "Assert README names every flake check"
   (considered, skipped).
7. `ruff-floor` step -> `ruff-lint` check (considered, skipped as
   fresh measured decision).
8. `apps.*` pinned local entry points (decided against, unratified).
9. Bulwark 1.21.x gap: noticed in the same-day report at session
   start; NOT this lane, untouched.

## d) TOTALLY FUCKED UP (owned, all but one self-caught pre-commit)

1. The first status report was named and headlined "15:40 CET" - a
   time invented without running `date` first. True mtime 12:43. A
   future-dated artifact sat in the corridor until this report's
   prep caught it (git mv + header fix applied).
2. Transients, self-caught by the verify loop, NEVER committed
   (proven via `git log -S`): corrupted anchors fixtures mid-edit
   (wrote slug garbage into headings, fixed within two tool calls); a
   `good.nice` garbage line in the new script; one ci.yml edit
   transcription mismatch. The first text-gates build legitimately
   failed (repo=/nix) - iteration, not a fuckup.
3. Process miss: lockstep-coupled files (checks.nix +
   tests/check-expected.json) were edited in SEPARATE tool calls
   while a commit daemon runs mid-session - a transient lockstep-red
   daemon commit was possible at any interleaving. Got lucky. The
   edit-and-commit-in-one-burst doctrine exists; I did not apply it.

## e) WHAT WE SHOULD IMPROVE (method)

1. Run `date` before timestamping ANY corridor artifact - filenames
   are load-bearing for the same-day scan.
2. Batch lockstep-coupled edits into one tool call burst; commit
   immediately after verification.
3. Route every "considered and skipped" into TODO_LIST at the moment
   of skipping (docs-health rule) - prose-only routing in a status
   report rots.
4. Terminal claims about CI must be phrased "unverified until pushed
   and observed" AND paired with an explicit follow-up row.
5. Before mechanizing a surface, grep the corridor for OTHER
   sessions' queued plans on the same surface FIRST (the
   mechanization queue went unread until this report; zero overlap,
   but that was luck, not diligence).
6. Keep doing: probe-derived gate contracts belong IN the check
   (statix exit probe, planted-defect selftests) with the probe
   transcript in the status report.

## f) Next (ranked, bounded; ~1-8 are this session's direct debt)

1. Watch the next CI run after the daemon pushes the 6 unpushed
   commits; if red, read the failing STEP name first, grep the whole
   log for non-infra errors before any rerun (repo rule).
2. Owner verdict on the `vm-pipe-ok` marker vs rewriting the two
   migrate-1x lines pipe-free.
3. TODO_LIST rows: ruff-lint conversion, readme-check-names
   conversion, jq pinning, parse-step dedup (all deferred).
4. Convert the ruff-floor CI step into a `ruff-lint` flake check
   (same pattern as the three shipped).
5. Convert "Assert README names every flake check" into a hermetic
   `readme-check-names` check (attrNames interpolated at eval time).
6. Drop or fold "Parse all Nix files" (alejandra --check already
   parses every .nix; the step is pure fail-fast duplication).
7. Enforce reason text in the exemption marker (awk currently
   exempts bare `# vm-pipe-ok`; require `vm-pipe-ok: <reason>`).
8. Run `buildflow` over the changed tree (30m budget; skipped this
   session).
9. aarch64 emulation deep-eval of the three new checks (precedent:
   2026-09-15).
10. Audit the four interleaved daemon commits for foreign hunks.
11. CHANGELOG entries for the two master-red fixes (or confirm the
    release procedure owns them).
12. Check `.buildflow.yml` skip rationale for references to the CI
    steps removed this session.
13. Verify the pre-push hook is alive and covers the new check names
    (`git config core.hooksPath && ls ...` - inventory passed
    manually; hook wiring unproven this session).
14. Consider `apps.text-gates` / `apps.vm-test-lint` for a pinned
    host-side loop (decided against for now - revisit).
15. A `-fires` companion for `check-set-lockstep` (plant drift in a
    json copy, expect the eval throw) - it is the one lockstep-family
    guard without a fires proof.
16. Document the `vm-pipe-ok` marker in AGENTS's pipe-lint working
    rule (currently only script header + README row carry it).
17. README Development section: add the one-command lint builds for
    contributors (`nix build .#checks.x86_64-linux.text-gates -L`).
18. Vocabulary: pick one of "docs gates" (script name) vs
    "text-gates" (check name) and align identifiers/greppability.
19. Grep scripts/ for any other bash-only printf `\x` usage; apply
    the POSIX-octal rule everywhere.
20. Decide whether statix warnings should ever be gated (contract
    note says hand-fixed only - make it an explicit owner posture if
    it is one).
21. Re-verify flake-source-vs-git-ls-files set equivalence claim with
    a one-off diff (find ${self} vs git ls-files) next session that
    touches text-gates.
22. Add the three new checks to the pre-push hook's coverage if the
    hook is meant to mirror CI (currently inventory-only).
23. Same-day context, different lane: the bulwark 1.21.x gap report
    lists three stale claims it did not fix under standing permission
    - route or execute in its own lane.
24. If CI goes green on push: record the restored-green date beside
    the red window in CHANGELOG (2026-11-13..18).

## g) Questions for the owner (cannot be self-answered)

1. Is the per-line `# vm-pipe-ok: <reason>` exemption the blessed
   mechanism for in-VM shell plumbing, or should the two migrate-1x
   lines be rewritten pipe-free instead (marker rolls back cleanly)?
2. Should the remaining ambient CI surface (ruff-floor step,
   registry-floating actionlint, jq/grep lockstep helpers, redundant
   parse step) be hermeticized/consolidated too, or is the documented
   float/floor posture there frozen?
3. The six commits are unpushed and I do not push: want me to watch
   and triage the CI run as soon as the daemon pushes them (or should
   you push first so the run is on the record)?

Verdict in one line: three hermetic gates shipped and locally proven,
two real master reds root-caused and fixed, one invented timestamp
embarrassed into a rename, and the CI-green claim stays a prediction
until the unpushed commits run.
