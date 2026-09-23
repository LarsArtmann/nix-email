# Session status: T12 green, v0.4.0 shipped, plus what I got wrong

_Report written 2026-09-23 05:55 CEST, covering THIS session only (resume
~04:00 → 05:55): T12 diagnosis/fix, T15 buildflow pass, final gate, CI
guard repair, T02 v0.4.0 release, close-out, cleanup. Basis: session
transcripts (`/tmp/t12-*`, `/tmp/t15-*`, `/tmp/t02-*`, `/tmp/gate-final.log`),
`gh run` outputs, and `git status` at write time (ahead 3, docs-only)._

## a) FULLY DONE

1. **T12 forensic/failure e2e — RED to GREEN, root-caused properly.** The
   host-side dry-run of the pinned parsedmarc 11.0.1 package (PYTHONPATH
   assembled from the drv closure, its own python3.13) reproduced the VM
   failure in ~30 s: upstream's ORIGINAL sample
   (`samples/forensic/subject.eml` @ f45ab94e) is malformed — its blank
   separator lines contain a single space, so the stdlib email parser
   folds them into the previous header and `parse_report_email`'s
   payload walk never sees `Feedback-Type` → `InvalidDMARCReport "is not
   a valid report"`. Upstream itself repaired those bytes when renaming
   forensic→failure (commit `ae1e5adb`, PR #659). The fixture now pins
   the repaired artifact verbatim (sha256-verified against the blob, URL
   re-downloaded byte-identical); every jq assertion was validated
   host-side BEFORE the VM run; targeted VM check GREEN (all subtests);
   a journal-dump diagnosability branch was added to the subtest's
   timeout path.
2. **T12 documentation from the green transcript only**: FEATURES
   parsedmarc-e2e row extended, TODO row deleted, CHANGELOG entry with
   the malformed-sample story, AGENTS.md host-dry-run lesson.
3. **T15 buildflow full pass** (run twice, steady state): dprint
   md-table alignment landed over 11 files. The diff review (mandated by
   the handoff) caught dprint EATING two table rows whose cells carried
   literal `|` characters — both restored from git with GFM `\|`
   escaping; escaping rule added to AGENTS.md; CHANGELOG entry written.
4. **nix-checker port-collision verdict**: 4 error-severity findings
   verified as cross-context false positives (demo-VM hostfwd GUEST
   ports vs a different VM test's relay CLIENT port vs a module
   `example` block — no shared runtime). Documented in AGENTS.md
   known-noise; deliberately did NOT skip the tool (it owns real
   stale-hash checks); root fix routed to BuildFlow upstream as a
   TODO_LIST row (the gate will keep exiting 69 on these until that
   lands — honest amber over blind green).
5. **CI guard repair (NEW finding, not in any plan)**: master CI had
   been red since 2026-09-22 — BOTH ci.yml check-inventory guards
   (x86_64 lockstep list AND the aarch64 shape guard) never registered
   `module-import-eval`. Both fixed, verified locally with the exact CI
   assertion commands, AGENTS.md rule added ("update both lists in the
   same change; the local full gate does not run these CI-side guards").
6. **Final full gate**: `nix flake check` EXIT:0 (fresh run on the fixed
   tree).
7. **T02 v0.4.0 RELEASED** (explicitly approved + push-authorized via
   the structured question prompt): CHANGELOG cut committed immediately
   (febb1e4) per the runbook's daemon-race rule; claim surface verified
   against the real diff (`modules/`: 15 new option/default lines, ZERO
   removed — additive-only); buildflow + full gate green; annotated tag
   `v0.4.0`; master + tag pushed; TAG CI green (8m32s) and MASTER CI
   green (8m44s); GitHub release published, Latest, with pin-evidence
   footer stating honestly that the nixpkgs pin ADVANCED
   (`eaad0894` → `6774f7bc`) rather than claiming "unchanged".
8. **Close-out**: TODO_LIST — Dependabot row (PR #2 verified MERGED, was
   stale), T15 buildflow row, 21-10 annotate row all deleted; archive-
   sweep row rewritten to current truth (all five candidates annotated,
   16_20-49 archived; archives gated on live items); BuildFlow upstream
   row added; v0.4.0 release row deleted post-release. CHANGELOG gained
   4 entries (forensic e2e, Dependabot, dprint repair, CI guards).
   decision-batch C17 updated (stable ref now EXISTS) and the release
   decision marked RESOLVED. The 03-21 report's three open questions
   annotated ANSWERED/ANSWERED/MOOT.
9. **Cleanup**: the four GC-root symlinks in /tmp/demo-t03 dropped
   (driver + three VM closures); t12/t15/t02 logs left in /tmp as
   ephemeral evidence.

## b) PARTIALLY DONE

1. **3 docs-only commits unpushed** (TODO row deletions, decision-batch
   and 03-21 annotations, this report will join them). Polled ~10 min;
   the daemon had committed but not pushed. No user-facing risk
   (markdown only; master CI already green on the release head febb1e4),
   but "push verification" for the absolute final head is pending the
   daemon's next cycle.
2. **Buildflow gate amber by design** (exit 69) on the 4 documented
   port-collision FPs — resolved only when the upstream BuildFlow fix
   lands (row exists; not started, see c).
3. **dprint pipe-truncation guard**: the escaping rule is documented,
   but nothing MECHANICAL stops the next unescaped-pipe row from being
   eaten (see e/3, f/5).

## c) NOT STARTED (user-gated or routed; deliberately untouched)

1. T16–T18 SystemNix work: C17a pin choice (now unblocked — `?ref=v0.4.0`
   exists), the ~47-commit push + CI debt, Resend API key.
2. T19 qcow2 blob purge verdict (history rewrite).
3. T21–T23 / D1–D2 live enablement chain; DNSBL runtime evidence waits
   on D1.
4. Upstream verdict filings still pending (nixpkgs #563651/#563777;
   imapclient 4.1.0 bump via #563652).
5. Standing user decisions in TODO_LIST: Renovate install-or-drop,
   Discussions enable-or-not, mailsuite STARTTLS draft file-or-skip,
   ROADMAP Q6, demo g1/g2.
6. BuildFlow upstream fixes (port-collision context-awareness or
   suppression; dprint-style table normalization that escapes/refuses
   pipes).

## d) TOTALLY FUCKED UP (honest: errors, misfires, near-misses)

1. **The T12 red was preventable and the prevention was already
   written down.** The previous session's own strategy section said
   "dry-run pinned parsers on the HOST before burning VM cycles" — but
   only as a post-hoc lesson candidate; the fixture went to a VM
   unvalidated and cost a ~5 min red build plus a session interruption.
   The dry-run this session took 30 seconds. Lesson now enforced in
   AGENTS.md, but it should never have needed a red run to be learned.
2. **I nearly mis-attributed the red CI run.** First look at `gh run
   list` said "failure on the pre-fix tree" and the plausible cause was
   the known T12 red — only drilling into `--log-failed` exposed the
   lockstep-guard failure, a SECOND distinct cause that had already
   shipped three red master runs unnoticed. Plausible-cause acceptance
   would have left master red after the T12 fix. (Counterpart rule
   added to e/2.)
3. **One stale TODO row left in the living tracker.** The
   `rateLimits`/DNSBL ergonomics row survived my close-out pass even
   though its deliverable ("sizing note") demonstrably landed in README
   (T11/a16) — I read the row this session and did not reconcile it.
   Caught while writing this report (README grep). Not yet fixed:
   intentionally, because this report session was told to report, not
   act — first action candidate on resume.
4. **A false "my edit was lost" alarm.** After dprint settled, I grep'd
   for `v0.4.0 is cut` (no backticks) and briefly suspected the
   decision-batch edit had been destroyed. The text was there; my grep
   pattern was wrong. Sentinel checks must anchor on text that cannot
   be re-wrapped or re-marked.
5. **dprint ate evidence rows and I almost shipped it.** The handoff's
   "review diff before accepting" instruction is the only reason two
   status-report rows were not silently truncated into phantom columns.
   Without that mandate, a "formatting-only" pass would have destroyed
   transcript evidence in archived-adjacent docs.
6. Small mechanical misfires (recovered in-line, cost only seconds):
   first TODO_LIST edit failed on trailing-whitespace exact-match (fixed
   via python line surgery); a python JSON parse of nix-checker output
   crashed on non-JSON wrapper lines (recovered with grep); ran
   `buildflow -s dprint-format` without `--fix` once (rejected as
   repair-only, rerun correctly).

## e) WHAT WE SHOULD IMPROVE

1. **Make the host-side dry-run a first-class tool, not a trick.** The
   PYTHONPATH-from-drv-closure technique lives only in AGENTS.md prose.
   A `scripts/host-parse-fixture.py` (or a flake app) would make
   "validate every VM fixture host-side first" a one-liner.
2. **Cause-attribution discipline for red CI.** Rule candidate: NEVER
   close a red run as "the known one" without reading the failing STEP
   name from `gh run view --log-failed`. Two distinct causes can stack;
   they did.
3. **Mechanical guard for the dprint pipe trap.** The awk pipe-lint
   class in CI could gain a sibling check: unescaped `|` inside a
   markdown table cell (heuristic: odd pipe-count per row vs header).
   Cheap, fail-closed, saves the next eaten row.
4. **The lockstep "same commit" rule is unenforceable under the
   auto-commit daemon** — the guard fired exactly as designed, but only
   AFTER three red pushes. Move (or mirror) the attrNames-vs-list check
   into the local pre-push hook so it fails before origin ever sees it.
5. **BuildFlow upstream owes us two fixes** (routed, TODO rows exist):
   port-collision context-blindness (no suppression mechanism exists at
   all today — verified in the BuildFlow source) and a markdown table
   normalizer that escapes or refuses pipes rather than truncating.
6. **Stale-row sweep needs a cheaper trigger.** This session found one
   stale TODO row by accident (d/3). A "row deliverable grep" pass
   during close-out (one grep per evidence column) would mechanize it.
7. **Daemon push cadence is opaque.** Three docs commits sat >10 min;
   nothing broke, but the session's "push verification" step cannot
   fully close. Accept as a known daemon property (documented here),
   or decide a session-end flush policy (g/3).

## f) Up to 50 things we should get done next (ranked; not a commitment list)

1. Delete/rewrite the stale `rateLimits`/DNSBL ergonomics TODO row
   (deliverable landed; evidence grep done — 1 min).
2. Verify the daemon shipped the 3–4 docs commits; confirm CI green on
   the true final head.
3. Decide C17a: pin SystemNix to `?ref=v0.4.0` or keep floating master
   (USER — now unblocked by the tag).
4. Execute the SystemNix push + CI-debt sweep once C17a is decided
   (USER-gated, T16–T18).
5. BuildFlow upstream: port-collision context-awareness (same-config
   scoping, example-block skip) or finding-level suppression; retire the
   AGENTS note + gate exit 69 when landed.
6. BuildFlow upstream: markdown-table normalizer must escape/refuse
   pipes, never truncate.
7. CI: add the unescaped-pipe-in-table-cell lint (e/3).
8. Pre-push hook: mirror the lockstep attrNames-vs-list check locally
   (e/4).
9. `scripts/host-parse-fixture.py` or flake app for fixture dry-runs
   (e/1).
10. parsedmarc e2e: add upstream's newer failure samples (Netease,
    LinkedIn `.crlf` variant) for parser breadth — each dry-run host-
    side first per the new rule.
11. parsedmarc e2e: assert `arrival_date_utc` (+0200 → UTC
    normalization) — free signal from the existing fixture.
12. Watch nixpkgs #563651/#563777; recheck #563652's imapclient 4.1.0
    bump status at the next pin advance.
13. Next pin bump: re-verify imapsync/mailpit/swaks presence list
    (existing TODO row).
14. Archive sweep: re-check 16_19-16 (15 routed items) and the other
    annotated reports for full resolution as backlog lands (existing
    row, rewritten this session).
15. Annotate+archive 17_15-11/17_21-07 once the g2-gated items resolve.
16. Demo g1/g2 decisions (dmarc-in-demo scope) — USER.
17. D1 live-enablement decision — USER; unlocks DNSBL runtime evidence,
    pyzor verdict, Gatus wiring on the consumer side.
18. D2 spam→Junk policy decision — USER.
19. qcow2 blob purge verdict (filter-repo + `--force-with-lease` window)
   — USER.
20. Renovate install-or-drop — USER.
21. GitHub Discussions enable-or-issues-only — USER.
22. mailsuite STARTTLS draft: file or skip — USER (draft ready).
23. ROADMAP Q6 (declarative Junk filing) verdict → possible Stalwart
    upstream feature request.
24. Release hygiene: confirm `[Unreleased]` stays a single
   Added/Changed/Fixed triple as the daemon appends in parallel.
25. Post-release sanity: `nix flake show` + `nix run .#vm` boot smoke on
   the v0.4.0 tag specifically (local gates ran on the tree, not the
   tag object).
26. CHANGELOG: the 0.4.0 "Fixed" section leads with the CI-guard repair
   — fine; consider folding future CI-infra notes into a Maintenance
   heading if they accumulate.
27. Consider documenting the daemon-race commit pattern (edit+commit in
   one tool call) for non-CHANGELOG release-critical files too — it is
   currently only spelled out for CHANGELOG.
28. AGENTS.md: the fixture-trap bullet now spans five sub-lessons;
   consider splitting lint-noise vs fixture-traps vs editing-traps into
   sub-bullets for scanability.

## g) Questions I can NOT figure out myself

1. **C17a — SystemNix pin choice, now actionable**: hard-pin
   `github:LarsArtmann/nix-email?ref=v0.4.0` (pin-discipline doctrine,
   reproducible consumer lock) or keep floating `?ref=master` (fleet
   posture, rides fixes immediately)? Both defensible; it is your
   doctrine call and it gates the SystemNix push (f/3, f/4).
2. **BuildFlow upstream fixes scheduling**: should the port-collision
   and dprint-pipe fixes (f/5, f/6) be a dedicated BuildFlow-repo
   session soon — I can author both — or stay routed-as-TODO until
   BuildFlow's own cycle? Your prioritization across repos.
3. **Daemon flush policy at session end**: when the tree is
   done-but-ahead on docs-only commits, do you want an explicit
   "wait-for-daemon-push" block (adds up to ~10 min per session), or is
   riding the daemon's next cycle acceptable as it did here? (e/7; a
   process preference only you can set.)
