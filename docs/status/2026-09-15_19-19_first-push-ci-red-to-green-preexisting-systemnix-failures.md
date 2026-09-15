# First push executed: CI red→green in three runs, SystemNix failures pre-existing, license reopened

**Date:** 2026-09-15, 18:20 → 19:19 CEST (report written 19:19)
**Directive:** the 18:17 report's §g answers arrived ("push both, plain";
"MIT: no"; Junk filing: "nix-email or not?" - question back to me) and were
executed; this report covers that execution window.
**Scope:** THIS window only. Prior windows: 17:05 and 17:59/18:17 reports.

## Headline

Both repos are pushed and **nix-email CI is GREEN on GitHub for the first
time ever** (run 34999737899: format gate, expected-checks guard, aarch64
shape guard, full VM-test flake check). Getting there took three CI runs:
the first exposed that all three pinned action SHAs in `ci.yml` never
existed (a prior session's from-memory identifiers, unvalidatable until the
repo was pushed), the second exposed that my aarch64 step was
emulation-dependent despite being labeled "arch-independent". SystemNix's CI
also fails - verified PRE-EXISTING (a `git+file:///home/...` input can never
resolve on CI). MIT was rejected by the user; the LICENSE choice is open
again while the public repo currently advertises MIT.

---

## a) FULLY DONE

1. **Pushes executed per authorization.** nix-email
   `1f8bb52..b80137f` (then the daemon carried the 18:17 report addendum to
   `4492f52`; a queued docs-only run 35000478603 rides it). SystemNix
   `ad6edcbb..ee85f1ff`. Both trees synced at push time.
2. **Answer-driven doc updates landed BEFORE the push:** TODO_LIST rows
   flipped (pin advance and v0.1.0 → unblocked; LICENSE → "user rejected
   MIT, which license?"), ROADMAP Q3 reopened, Q6 annotated with the user's
   narrowing question and my recommendation.
3. **CI green, run 3** (`34999737899`, commit `b80137f`): all four
   gate-relevant steps success - `Enforce alejandra formatting (fail-closed)`,
   `Assert the expected checks exist`, `Assert the aarch64 check set exists
   (shape guard)`, `Run nix flake check (eval contract + VM tests)`. The
   GitHub-hosted VM tests passing also independently re-validates the
   session's test changes on a clean runner.
4. **Bogus action SHAs fixed** (commit `c6aa0fa`): checkout/nix-installer/
   flakehub-cache repinned from the REAL tag refs (`gh api git/ref/tags/*`),
   YAML-validated. The one-digit checkout corruption (`11bd19…` vs real
   `11bd71…` for v4.2.2) is now ledgered in the CHANGELOG bullet.
5. **aarch64 CI step made honest** (commit `b80137f`): shape-only
   (`attrNames`), because forcing the outPath builds the aarch64 strip
   script → "platform mismatch" without emulation. Deep build remains a
   locally-verified fact (TODO_LIST evidence).
6. **SystemNix CI triaged to root cause:** `flake.nix:448` pins
   `git+file:///home/lars/projects/branching-flow` - cannot resolve on any
   runner. Verified pre-existing via run history (15:53/16:19 failures
   predate today's pushes). NOT this session's change; fix not started
   (SystemNix territory, prepared-source pattern).
7. **Daemon blind spot handled per the buildflow skill:** two narrow,
   explicit commits (CI fixes only) when the daemon stalled ~10 min;
   everything else left to the daemon, which also pushed the report
   addendum on its own.

## b) PARTIALLY DONE

1. **SystemNix CI triage:** root cause identified for "Nix flake check",
   but the "Secret history scan" and "Go deps audit" failures were seen in
   the list and NOT opened - two of four workflows unexamined.
2. **SystemNix tree has new foreign commits** (`63fd5a83`, `84c47e67`, 8
   files - not mine, likely a parallel session/user): local master is 2
   ahead of origin. Left untouched deliberately (not my change to push or
   revert).
3. **The queued docs-only nix-email run** (35000478603) was not waited out
   (docs-only diff on a green workflow; expectation, not verdict).

## c) NOT STARTED

1. **SystemNix pin advance** - the session's top-unblocked TODO row
   (upstream `relay` option is now on origin/master): bump input rev,
   restore relay-credential assertions, delete the wrapper guard, gate both
   repos. ~30 min, fully specified.
2. **v0.1.0 tag + GitHub release** (unblocked by the push).
3. **Junk-filing implementation** (recommendation delivered: wrapper-owned
   in nix-email; awaiting the user's confirm).
4. **LICENSE flip** (MIT rejected; target license unknown - the pushed repo
   currently advertises MIT).
5. **Upstream nixpkgs filings** (authorization still pending; diagnoses
   current vs master).
6. All D1-gated work (unchanged).

## d) TOTALLY FUCKED UP

1. **I pushed a workflow I had only YAML-validated, not action-validated.**
   The bogus SHAs were checkable BEFORE the push with the same one-line
   `gh api git/ref/tags/...` I used AFTER the failure. YAML parses fine with
   nonexistent SHAs; resolution is the actual contract. First-ever CI run
   burned on it.
2. **"Arch-independent" was an environment-dependent claim.** My aarch64
   step worked locally BECAUSE THIS HOST HAS EMULATION - my own earlier
   aarch64 build log literally showed cross-stdenv downloads, and I still
   labeled the step "arch-independent" without testing on a clean x86_64
   box. Same genus as the transcript lesson: the claim outran the
   observation.
3. **Three CI runs to green** where one was achievable: SHA validation +
   a semantics-think about what `nix eval --json` forces would have caught
   both failures at push time. The push authorization said "plain" - it did
   not say "unverified".
4. **License state now publicly inconsistent:** the user rejected MIT, but
   origin carries an MIT LICENSE (GitHub shows the MIT badge). I noticed
   this only while writing this report - it should have been flagged the
   moment the answer "no" arrived, since a push was already authorized.

## e) WHAT WE SHOULD IMPROVE

1. **Validate CI workflows like outbound claims** (verify-before-filing
   spirit): resolve every pinned action SHA (`gh api git/ref/tags/…`) and
   sanity-check each step's environment assumptions BEFORE the first push -
   a workflow that has never run is an unverified document, not a gate.
2. **Name the environment in every verification claim** ("works on the dev
   host WITH emulation" ≠ "arch-independent"). CI runner ≠ dev host.
3. **The moment a user answer changes public state (license!), surface the
   inconsistency immediately** - the MIT badge is live on GitHub right now.
4. **actionlint in CI** (from the 18:17 §f-11) would have caught neither
   bogus-SHA failure, but the SHA-resolution check can be scripted into CI
   or a pre-push hook - worth a TODO.
5. **Positive pattern to keep:** root-causing SystemNix against run HISTORY
   (15:53/16:19 failures) before blaming today's diff - five minutes that
   prevented a wrong "my test broke CI" conclusion.

## f) Up to 50 things we should get done next

Routed in TODO_LIST/ROADMAP unless noted; the live short list:

1. **SystemNix pin advance** (top row, now unblocked; procedure in the row).
2. **v0.1.0 tag + GitHub release** (CHANGELOG is ready; go-release
   discipline).
3. **LICENSE decision + flip** (§g-1; public MIT badge makes it urgent).
4. **Junk filing: confirm wrapper-owned** (§g-2) → sieve + GTUBE subtest
   upgrade.
5. **SystemNix `branching-flow` local-input fix** (§g-3; prepared-source
   pattern) + triage its "Secret history scan"/"Go deps audit" failures.
6. Check whether Renovate activates now that the repo is pushed
   (renovate.json predates the first push; approval-gated by config).
7. Upstream nixpkgs filings (both diagnoses current vs master).
8. CI: script the pinned-action SHA resolution check (pre-push or in-CI).
9. aarch64 `stalwart-e2e` emulated run; parsedmarc-e2e TLS variant; CSV
   row-count; two-reschedule quota assertion; pin-advance runbook; CI
   lockstep audit test (all TODO_LIST).
10. Confirm the queued docs-only CI run (35000478603) went green.
11. docs-health ANNOTATE pass over the three 2026-09-15 status reports
    (their numbered items are now partially resolved - inline markers due).
12. Nothing else new; everything else already lives in TODO_LIST (16 rows) /
    ROADMAP.

## g) Questions I cannot figure out myself

1. **Which license?** You rejected MIT, but `LICENSE` on origin currently
   says MIT (GitHub renders the badge). Name the target (Apache-2.0?
   BSD-2/3-Clause? unlicensed-for-now?) and I flip the file and re-push.
2. **Junk filing - confirm wrapper-owned in nix-email?** My recommendation
   is yes (E2E-testable here, consistent for every consumer); alternatives
   are SystemNix-owned sieve or documented tag-only.
3. **SystemNix CI:** the `branching-flow` `git+file:///home/...` pin can
   never work on CI. Fix it in a SystemNix session now (prepared-source
   pattern per the nix-private-go-repos skill), or leave it for a dedicated
   SystemNix session while its CI stays red?

---

**Report format note:** `.md` per your instruction - overrides the
status-report/brutal-self-review HTML canonical outputs; intentional, not
propagated into the skills.

**Then per the skill: WAITING FOR INSTRUCTIONS.**
