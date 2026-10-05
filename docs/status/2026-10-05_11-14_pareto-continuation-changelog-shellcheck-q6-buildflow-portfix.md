# Pareto continuation session — CHANGELOG debt paid, Q6 closed with source proof, T13 BuildFlow fix landed (2026-10-05)

- **Date:** 2026-10-05 11:14 CEST (`date` CLI)
- **Session scope:** continuation of the 10:29 execution session under a general
  "execute and verify until done" mandate: pay the recorded debts that were
  unblocked (CHANGELOG, red-run root-fix, Q6 residue, T13 upstream, doc sweep)
  plus the cross-repo CI checks the previous session left unwatched. No new
  research beyond what this session touched.
- **End state:** nix-email master == origin/master at `af5eb80`, tree clean,
  CI **green** (run 37287565055, full flake check). BuildFlow pushed through
  `15ea141d2` (their Build Gate red is PRE-EXISTING - identical failing job on
  the predecessor commit, 6 consecutive reds). SystemNix at `bf1c99c0` (their
  daemon carried my pipeline.md note; their CI reds are pre-existing and now
  fully diagnosed in their own TODO). InboxClean untouched (their CI red is
  setup-level, their cadence).

## a) FULLY DONE

1. **CHANGELOG `[Unreleased]` entries - the 10-29 session's biggest miss,
   paid.** Full coverage of the execution session: JMAP seam (e2e subtest +
   the pin facts: 307 redirect, `primaryAccounts`, EventSource push-verified
   with the `{closeafter}`/`{ping}` rejection), the contract doc + six probe
   transcripts, parsedmarc breadth fixtures, host-parse helper, CI hardening
   pair (pipe-lint + statix + pre-push inventory), the flake split, the
   runbook rewrite (PR #566282 ripple), docs freshness pass, archive repairs,
   the SystemNix hard-pin, and the CI red root-cause under Fixed. Commit
   `b1deb35`; pipe-lint green over all 59 tracked markdown files.
2. **Red-run blindness root-fixed (g/3 answered by doing both halves).**
   `actionlint` + `shellcheck` now live in the flake devShell (buildflow runs
   tools inside it, so its actionlint step is no longer blind), AND
   `.githooks/pre-push` gained an actionlint guard: devShell tools when
   present, else `nix shell nixpkgs#shellcheck nixpkgs#actionlint` fallback,
   fail-closed on findings, fail-open only on tool unavailability (CI stays
   the hard gate). Verified: devShell builds, `actionlint` EXIT 0 inside it,
   the hook itself is shellcheck-clean, the fallback invocation EXIT 0, and
   the new guard ran live on this session's own pushes. Commit `4e027d2`.
   AGENTS' gate-parity lesson rewritten to describe the fix + the remaining
   bare-`nix run` blindness.
3. **Q6 residue RESOLVED with source evidence.** The "auto-move-to-Junk" has
   NO 0.15.5 setting name because none exists: it is HARD-CODED in
   `crates/email/src/message/ingest.rs:344` (`if is_spam &&
   params.mailbox_ids == [INBOX_ID]` -> `JUNK_ID` + `$Junk` keyword), inside
   the `spam.enabled` block of the Smtp ingest arm; classification itself
   only runs for UNAUTHENTICATED sessions (`inbound/spam.rs`). Upstream
   CHANGELOG 0.5.0 confirms the feature shipped unconditionally - which is
   why the 2026-09-23 binary-strings sweep found no key. Consequence
   recorded in the README ledger + decision-batch: a wrapper `junkFiling`
   option is NOT implementable as a Stalwart setting; the (c) tag-only
   posture stands. Commit `099ba9d`. Method: `gh api` contents at ref
   `v0.15.5` + upstream CHANGELOG grep (line 1859).
4. **T13 (port-collision half) - implemented, tested, pushed upstream.**
   BuildFlow commit `15ea141d2`: (i) `maskStringsAndComments` blanks
   double-quoted strings, indented strings, line and block comments before
   the port regex runs - documentation examples and quoted fragments can no
   longer collide with runtime ports (in-source documented limitations:
   `${...}` interpolation content is masked with its string; single-quoted
   strings are NOT masked because `'` is a legal Nix identifier character);
   (ii) privileged-port (<1024) collisions downgraded to `SeverityWarning`
   with an explanatory message suffix - VM guests, containers, netns
   routinely re-declare privileged ports per isolated runtime - while
   unprivileged double assignments stay `SeverityError`. Tests:
   `TestCheck_PortCollisionDetection` updated (port 80 -> warning),
   `TestCheck_PortCollisionUnprivilegedStaysError` (3000 -> error) and
   `TestCheck_PortCollisionIgnoresStringsAndComments` (3 subtests including
   the literalExpression-docs FP shape) added. Full `go test ./...` EXIT 0,
   gofmt clean, `go build ./cmd/buildflow` green locally, BuildFlow
   CHANGELOG entry written.
5. **T13 verified against THIS repo with the locally built binary.**
   `buildflow -s nix-checker` EXIT:0 (was EXIT:69): zero error-severity
   findings remain, the demo-VM/relay 587 pair survives as an annotated
   warning (correct - it is a real attr pair in privileged context), and the
   dmarc docs-prose 993 FP is gone (masked). AGENTS known-noise note
   rewritten with the home-manager profile-flip caveat, TODO_LIST T13 row
   closed with the verdict, CHANGELOG gained the cross-repo Fixed entry.
   Commit `af5eb80`. Scope caveat: this verification ran the nix-checker
   STEP, not a full gate run - see d/6.
6. **Doc sweep.** The 08-01 burn plan marked SUPERSEDED as a status source
   (banner pointing at TODO_LIST verdicts + the 10-29 report; do-not-
   re-execute rule), the mailsuite draft re-headed "FILED as
   seanthegeek/mailsuite#65", AGENTS Documentation map now names
   `docs/INBOXCLEAN.md` and `docs/probes/`. Commit `537b832`; pipe-lint
   green after.
7. **Cross-repo CI checks (read-only) + recordings.** SystemNix master is
   red on every push since at least 2026-10-04 22:00Z with TWO pre-existing
   causes, both now diagnosed and filed in their `docs/todo/pipeline.md`:
   (i) the `branching-flow` input pins
   `git+ssh://git@github.com/LarsArtmann/branching-flow` (flake.nix:620-629)
   which Actions runners cannot fetch - the repo is PRIVATE so a plain
   https swap does NOT fix it (art-dupl, which fetched fine over https, is
   PUBLIC) - filed as `[blocked:user]` needing a deploy key/PAT secret;
   (ii) the secret-history scan hits - the full hit inventory from run
   37284891036 appended to their TODO 509 row: beyond the known canaries it
   adds `syn_cb0b` (~20 status-doc blobs), `re_bzp5m` (2 blobs in a
   June-2026 archive, provenance UNVERIFIED - flagged judge-before-
   allowlisting), and 3 private-key PEM blobs inside historical
   `nixos.qcow2` disk images. My explicit commit there was blocked by their
   pre-commit hook on a pre-existing unrelated broken anchor; their daemon
   carried the change as `bf1c99c0` (the expected norm). Also verified:
   nix-email CI green (run 37287565055) and the 07:25Z SCHEDULED SystemNix
   run went green while pushes stayed red - divergence noted, unexplained.
8. **InboxClean CI narrowed:** both failing jobs (Secret Scanning, Nix Flake
   Check) fail with ZERO steps and unarchivable logs - setup-level failure,
   root cause not determinable from here. Their repo, their debt.
9. **Hygiene + pushes.** Session /tmp artifacts (aggregate.zip,
   forensic.eml, t23-strike.py) trashed. nix-email pushed
   `48da45a..af5eb80` (the pre-push hook exercised the new actionlint guard
   in real use), BuildFlow pushed `2dfe6fba1..15ea141d2` after confirming
   their Build Gate red predates the push (identical failing job - `go build
   ./cmd/buildflow`, no failing STEP inside, logs unarchivable - on the
   predecessor commit `2dfe6fba` too).

## b) PARTIALLY DONE

1. **T13 overall** - the port-collision half is DONE upstream and verified
   (a/4-a/5). The OTHER half (T13b: dprint's markdown pipe-cell handling,
   the eaten-rows class at the source) is NOT STARTED: the bug lives in
   dprint's markdown plugin (external project), and nix-email's own
   `check-md-table-pipes.sh` remains the working mitigation. Remaining
   effort: L (verify-before-filing gate + upstream investigation).
2. **exit-69 retirement** - the fix is landed and step-verified, but the
   INSTALLED gate binary is home-manager-managed (store rev `3bb229e`,
   root-owned symlink; I deliberately did not touch the user profile). Full
   buildflow runs here still exit 69 with the same 4 known findings until
   the profile flips to >= `15ea141d2`. Effort to finish: one HM rebuild
   (owner-side), then shorten the AGENTS caveat.
3. **SystemNix canary allowlist (their TODO 509)** - now FULLY specced
   (complete hit inventory, digest-based approach, the re_bzp5m
   judge-first flag) but NOT implemented: it is a SystemNix-internal policy
   call, re-confirmed as such. Blocked on g/3 below.
4. **SystemNix branching-flow CI fix** - diagnosed to the exact fix shape
   (Actions credential for a private input) but needs the owner's secrets
   console; `[blocked:user]` row filed, nothing codeable from here.
5. **InboxClean CI** - triaged to "jobs fail with zero steps, logs
   unarchivable"; root cause unknown, not fixable from this side.
6. **The 10-29 report's f/20-f/50 backlog** - untouched this session
   (deliberate: this session executed the unblocked high-leverage set).
   The still-relevant items are carried forward into f/ below so the
   harvest does not lose them.

## c) NOT STARTED

1. **v0.5.0 release cut** - the CHANGELOG `[Unreleased]` is now complete and
   release-ready; gated on the release-timing call (g/1). Payload: JMAP
   subtest + contract doc + CI hardening + flake split + fixture breadth.
2. **T17** Resend live `:587` SASL smoke - needs the real API key.
3. **T19** qcow2 history purge - needs explicit force-push approval (or the
   accept-weight verdict).
4. **T20** D1-gated enablement slice (secrets rotation, live dmarc
   validation, migration compare, M22) - needs D1/D2 + real infrastructure.
5. **T21** monitoring encoding (Gatus checks, queue poll, failed-auth burst,
   dead-man) - needs C24/C29.
6. **T13b** dprint pipe-cell upstream work (see b/1).
7. **SystemNix**: the 2 remaining pin flips; CI-green confirmation after
   their branching-flow fix lands.
8. **InboxClean**: wiring the T4 push-quirk into their adapter as a
   documented client rule.
9. **Owner policy batch** (unchanged): D1, D2, C18, C19, C22, C34, Q4, Q5,
   C36, C37, demo g1/g2, qcow2 verdict.
10. **Post-flip cleanup** (after the HM buildflow flip): one full gate run
    here expecting EXIT:0, then reduce the AGENTS caveat to a history line.

## d) TOTALLY FUCKED UP (honest failure log)

1. **Repeated a documented cross-repo mistake.** I attempted an explicit
   commit in SystemNix although the 10-29 report's e/8 already recorded
   that their pre-commit hook blocks explicit commits on unrelated
   findings. Predictable block (their living-docs link check tripped on a
   PRE-EXISTING broken anchor in `docs/todo/upstream.md` - not my change).
   Outcome fine (daemon carried `bf1c99c0`), one cycle wasted. Severity:
   none (no damage), but it is the second session running that the written
   lesson was available and not re-read before acting.
2. **Bash-head instead of View-read before editing** -> one edit-tool
   bounce on the burn plan ("modified since last read") and one on the
   mailsuite draft ("must read the file first"). This is the EXACT d/6
   failure mode of the 10-29 report - third session in a row with this
   class.
3. **`check-md-table-pipes.sh` invoked without arguments** -> EXIT:2 usage
   error that briefly looked like a lint failure; had to read the script
   and re-run it CI-style (`git ls-files '*.md' | xargs`). One wasted
   cycle; motivated f/23 (argless mode).
4. **Wrong instrument twice on InboxClean logs**: `gh run view --log-failed`
   failed twice with "log not found" before I switched to the jobs API
   endpoint - which immediately revealed steps=0 (infra-level) and made the
   log question moot. The jobs endpoint should have been call one.
5. **Three wasted upstream-source calls before the direct one**: two
   sourcegraph queries and one GitHub code search returned nothing (query
   shapes wrong for the target) before `gh api contents` at ref v0.15.5
   landed the answer in one call. Q6 still resolved in ~6 calls total, but
   a third of them were spent on the wrong tools.
6. **Claim-scope slippage on the T13 verification**: the "gate exits 0
   again" evidence is from `-s nix-checker` ONLY - a full buildflow run
   with the new binary was not executed (other steps unchanged, so the risk
   is low, and the full gate here still runs the OLD installed binary
   anyway). The honest statement is: nix-checker step EXIT:0, full-gate
   parity pending the profile flip.
7. **Unreconciled finding-count gap**: the new binary's step summary
   reported "12 findings" while `--format finding` printed 2. I shipped the
   defensible part ("zero error-severity anywhere") but did not explain the
   12-vs-2 difference (suspect: the summary counts detect-only/cache-layer
   findings that the format view filters or baselines). Flagged as f/7,
   unresolved.
8. **Todo-list wobble at session start**: my rebuilt todo included
   "execute the SystemNix canary allowlist if unblocked", which I then
   walked back to record-only mid-session - the correct end state (the
   prior session had explicitly parked it as a policy call), but the
   initial plan contradicted a verdict I had already read an hour earlier.

## e) WHAT WE SHOULD IMPROVE

1. **Cross-repo pre-flight**: before the first commit attempt in a sibling
   repo, re-read the prior session's d/e sections for that repo (SystemNix
   hook norm was written down - reading it would have saved the cycle).
   Concretely: grep the last cross-repo status report for the repo name
   before writing to it.
2. **View-before-edit discipline**: two bounces this session, three sessions
   running. The rule exists; momentum beats it. Candidate: a Crush hook
   that warns when `edit` targets a file not previously View-read in this
   session.
3. **CI triage instrument**: default to `gh api .../actions/runs/<id>/jobs`
   (steps array + conclusions). It works when logs are unarchivable and
   instantly separates "no step ran" (infra) from "step X failed" (code).
4. **Verify-scope honesty**: when a fix targets one gate step, either run
   the full gate with the new binary or label the claim step-scoped in the
   same breath. Minutes vs. permanent record accuracy - cheap trade.
5. **Semantic changes deserve decision records**: the 1024 threshold and the
   warning-downgrade are POLICY, not just code. They should be findable in
   BuildFlow's docs/decision trail without reading git log (f/38-f/39).
6. **Count reconciliation**: when a tool's summary and detail views
   disagree, reconcile or disclose before claiming. One extra grep.
7. **Daemon-race discipline held**: every release-critical edit (CHANGELOG)
   went edit+commit in ONE tool call; zero races this session. Keep the
   pattern.
8. **Pipe-lint ergonomics**: an argless mode (default to
   `git ls-files '*.md'`) would have prevented d/3 - small fix in this
   repo (f/23).

## f) Up to 50 things we should get done next

Sorted by leverage; the first ten are the real queue. This section is the
HARVEST input for TODO_LIST/ROADMAP (most gated items already live there;
items 4-7, 17-18, 37-47 are new from this session).

1. Ratify or override the four executed `[rec]` adoptions (C35, C17/C17a,
   C20, C38) and answer g/1-g/3 below - unblocks the release, the
   allowlist, and the pin verdicts. High/S/Decision
2. Cut **v0.5.0**: annotated tag -> tag-CI -> gh release. The CHANGELOG is
   ready; payload documented. High/S/Release
3. Flip the home-manager buildflow profile to >= `15ea141d2`, run ONE full
   gate here (expect EXIT:0), then shorten the AGENTS caveat to a history
   line. High/S/Tooling
4. SystemNix: add an Actions credential for the private branching-flow
   input (deploy key or PAT), flip the input URL, confirm their CI green.
   High/S/Infra (owner console)
5. SystemNix: implement the digest-based canary allowlist (TODO 509, now
   fully specced) - blocked on g/3. High/M/Security
6. Triage BuildFlow's Build Gate red (`go build ./cmd/buildflow`, 6+
   consecutive failures, no failing step, logs unarchivable) - and the
   Lint Gate red. High/M/Bug (upstream infra)
7. Reconcile the nix-checker summary-vs-detail finding-count gap (12 vs 2)
   in the new binary. Medium/S/Quality
8. **T17**: Resend live `:587` SASL smoke (needs the real API key).
   High/S/Feature (gated)
9. **T19**: qcow2 history purge or record the accept-weight verdict
   (force-push approval needed). Low/M/Cleanup (gated)
10. **T20**: D1-gated enablement slice (rotate 3 secrets, live dmarc
    validation, migration compare, M22). High/M/Feature (gated)
11. **T21**: monitoring encoding (Gatus starttls/tls/cert, queue depth/age,
    failed-auth burst, dead-man). High/M/Feature (gated)
12. Answer **D1** (Workspace) / **D2** (VPS) - unblocks T20 + the
    production ROADMAP half. High/S/Decision
13. Answer the policy batch: C18, C19, C22, C34, Q4, Q5, C36, C37, demo
    g1/g2, qcow2 verdict. Medium/S/Decision
14. **T13b**: investigate dprint's markdown pipe-cell behavior upstream
    (verify-before-filing gate first). Medium/L/Bug (external)
15. Watch nixpkgs PR #566282 (imapclient 4.1.0 + `provision.opensearch`
    rename); when merged, run README runbook step 2's port procedure
    BEFORE the next pin bump. High/S/Watch
16. Re-check mailsuite#65 + nixpkgs#563651/#563777 on the next watch
    cadence; track #566282's mailsuite 4.6.5 bump for fixture drift.
    Medium/S/Watch
17. Explain the SystemNix scheduled-vs-push CI divergence (a 07:25Z
    schedule run went green while pushes stayed red - different job set?).
    Medium/S/Infra
18. InboxClean: triage their setup-level CI failure (jobs with zero steps).
    Medium/S/Bug (their repo)
19. InboxClean: wire the T4 push-quirk (`{closeafter}`/`{ping}` rejected on
    0.15.5) into their adapter as a documented client rule. Medium/S/Feature
20. Add a JMAP push e2e assertion (EventSource 200 on `?types=Email`) to
    stalwart-e2e - cheap anti-rot. Medium/S/Quality
21. Verify the per-account Junk-filing JMAP automation path end-to-end
    (push + Mailbox/set fileinto): with Q6's hard-coded-move finding, the
    automation path is THE declarative path this stack will ever have.
    Medium/M/Feature
22. Make `scripts/host-parse-fixture.py` a flake app
    (`nix run .#host-parse -- <fixture>`). Low/S/Cleanup
23. Extend `check-md-table-pipes.sh`: argless mode defaulting to
    `git ls-files` + indented-fence coverage. Low/S/Quality
24. Add the `arrival_date_utc` timezone-normalization assertion class to
    the AGENTS fixture-traps list. Low/S/Docs
25. Consider TLS-node coverage for the two new parsedmarc fixtures (they
    ride the plaintext node only). Low/M/Quality
26. Re-read the ci.yml lockstep/shape guard lists once post-session (they
    should exclude `scripts/` - verify, do not assume). Low/S/Quality
27. README demo section: add the one-VM-per-qcow2 write-lock note (bit
    InboxClean's spike). Low/S/Docs
28. Pin the VM debug-driver recipe (GC root + `--test-script`) as a script.
    Low/S/Tooling
29. Extend the docs-health sweep rule to cover `docs/probes/` (the
    Documentation map names the dir; the sweep rule does not yet).
    Low/S/Docs
30. F22.3 verdict: accept ~21 KB as the AGENTS floor (recommended) or
    define an enforced budget. Low/S/Decision
31. Archive/supersede the 2026-09-22 master plans once their M/T-number
    references are harvested. Low/S/Docs
32. Evaluate removing the interrogate/jest "N tools unavailable" noise via
    proper skip configs. Low/S/Tooling
33. `buildflow timings --regressions` cleanup (govulncheck +758 percent
    noise). Low/S/Tooling
34. Invite SystemNix's inboxclean-paperless check to assert the v0.4.0 TAG
    (their contract check pins the input, not tag semantics).
    Low/S/Quality (their repo)
35. Audit that every fine task executed via daemon commits has its evidence
    landed (f/44 of the 10-29 report). Low/M/Docs
36. Explore upstream auto-move-to-Junk on NEWER stalwart (0.16+) during the
    stalwart-passing watch: Q6 proved NO key exists in 0.15.5; the 0.16+
    question is the only open form. Low/S/Watch
37. Record the AGAINST decision on seeding JMAP facts into the README
    ledger (the quickstart already carries them; duplication risk).
    Low/S/Docs (likely DROP)
38. BuildFlow: document the masking semantics + privileged threshold in
    user-facing docs. Low/S/Docs (upstream)
39. BuildFlow: consider exposing the 1024 threshold as config with the
    current value as default. Low/S/Feature (upstream)
40. Update SystemNix's nix-email-contract to also assert tag semantics
    when their profile/pin story settles. Low/S/Quality
41. Next docs-health pass at the next release boundary (audit cadence).
    Low/M/Docs
42. Sweep remaining /tmp session scratch (driver logs) if any survive.
    Low/S/Cleanup
43. Consider a `BUILDFLOW_TELEMETRY_DISABLED=true` note for CI-adjacent
    runs (observed 403 telemetry noise in step output). Low/S/Tooling
44. Verify `nix flake show`/FEATURES describes the devShell surface
    correctly now that actionlint+shellcheck are intentional members.
    Low/S/Docs
45. Fleet hygiene: once repos' buildflow flips, REMOVE their accepted
    port-collision baseline entries (accepted noise that no longer exists
    - the baseline-staleness machinery should catch this; verify it does).
      Low/S/Quality (upstream fleet)
46. Add mask-function edge cases (CRLF files, no-trailing-newline) to the
    checker's test table. Low/S/Quality (upstream)
47. Answer this report's g/1-g/3 - gates several items above.
    High/S/Decision

## g) QUESTIONS FOR YOU (not answerable from the repo)

1. **Release timing**: cut **v0.5.0 NOW** (CHANGELOG `[Unreleased]` is
   complete; tag -> tag-CI -> gh release), or do releases wait for a
   boundary you pick? I tagged nothing - an annotated public release is
   irreversible-ish and stays your call.
2. **Ratification**: confirm the four executed `[rec]` adoptions as
   RESOLVED - C35 (JMAP seam executed), C17/C17a (SystemNix pushed +
   hard-pinned `?ref=v0.4.0`), C20 (mailsuite#65 public), C38 (daemon-flush
   followed) - or name overrides and I will revert the pin / comment on the
   issue.
3. **SystemNix `re_bzp5m`**: the two June-2026 history blobs (session-131B
   archive) matching the Resend-key pattern - deliberate canary
   (digest-allowlist it) or a real since-rotated key (rotate now, then
   allowlist)? I refused to read or print the blob content, and nothing in
   their repo records its provenance. This gates their TODO 509.
