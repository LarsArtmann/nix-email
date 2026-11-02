<!-- Status snapshot 2026-11-02 03:26 CET. Owner-ordered self-review +
     comprehensive status of THIS session's run (02:15-03:26 CET), which
     closed the Alpha plan's verification tail, executed the hub publish,
     and shipped exactly one red master (caught + fixed). Supersedes the
     03-08 report's "green through 3b4286e" line: master is now green
     through 3e8faf2 (run 41376490831). Tree at write: daemon-swept. -->

# Self-review: verification tail CLOSED, one shipped red (daemon race through a pre-push hook HOLE), hub publish fired into a pipeline stalled since 10-28 (2026-11-02 03:26)

## 0. TL;DR - the three questions, answered first

| Question                         | Honest answer                                                                                                                                                                                                                                                                                                                                                                                                    |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| What did you forget?             | To COMMIT the dprint fix before pushing (I had even SEEN the `M TODO_LIST.md` dirty state minutes earlier); to re-check `git status` in the push call itself; to check mid-session for the f12ed24 report (H1.3, only checked at session start); to clean the /tmp probe residue (/tmp/ec-probe, /tmp/hub-dist-probe)                                                                                            |
| What could you have done better? | Written the new TODO row pre-formatted (fmt BEFORE the daemon's first sweep, not --check-then-fix after); read the pushed COMMIT's content instead of trusting the working tree; piped `git push` into `tail` (the exit code I echoed was tail's, not git's - the redirect-never-pipe rule exists for exactly this); pulled live-site needles via python instead of fetching two ~100 KB HTML pages into context |
| What can still be improved?      | The pre-push hook has a HOLE (d/2): it fmt-checks the WORKING TREE while git pushes the COMMIT - a daemon-swept dirty tree ships red through a green hook. Mechanizable: refuse/warn on a dirty tree at pre-push. Plus the rowed lanes (f) and the evo-x2 pipeline verdict (yours)                                                                                                                               |

## a) FULLY DONE (this session; evidence inside)

1. **Re-anchor**: baseline ritual (clean tree, 15-commit unpushed tail,
   corridor scan - no new reports, no f12ed24 yet), live-session
   ownership map (BuildFlow/SystemNix/pbx owned; hub unowned).
2. **README 0.16 ledger row (02-07 e/1)**: stalwart's own resolver is
   NOT the system resolver by default; the `DnsResolver` Custom dialect
   (`servers = [{address = ...}]`, NO element `@type`) + the Lua
   typecheck ladder that discovered it, beside the 2026-09-15
   system-resolver entry.
3. **vm-debug path-guard (02-07 e/3)**: check names matching `*/*` or
   `.*` fail fast with the flags-before-positionals hint; proven live
   (exit 1 on a path-like name), shellcheck clean, CHANGELOG T1 entry
   extended.
4. **Probe connection hygiene ROWED (02-07 e/2)**: pool-or-pace vs the
   built-in per-IP limiter; behavioral, needs a VM re-proof; evidence
   carried.
5. **Pre-push suite**: check-inventory, check-testscript-shell (287
   fragments/12 files), check-md-table-pipes, check-rows, `nix fmt`.
6. **Full gate WITH builds**: `nix flake check` EXIT:0 (4 eval-class
   derivations rebuilt; VM e2e cache-valid from this session's executed
   runs with unchanged inputs).
7. **Tail pushed, CI GREEN**: `021148f..3e8faf2` on origin; final runs
   41372640022 + 41376490831 both SUCCESS; FEATURES CI currency
   updated; tree clean, HEAD == origin.
8. **Hub A5.2 EXECUTED**: hub master `97d0223..cdfb512` pushed to the
   canonical Forgejo (build.yml fires on push; the GitHub twin stays a
   no-push downstream mirror, untouched).
9. **Hub A5.3 T8 live-verified** (against the served 10-28 build):
   our authored mail-server body renders (listeners table, option
   surface, 0.16 doctrine, consumers); the `not deployed` chip unions
   in from the SystemNix inventory; `/docs/adrs/<id>/1.0.0` routes
   render full decision records (7 ADRs live); build-stamp present.
10. **Hub freshness incident characterized** (see b): dist tip + stamp
    pinned at 2026-10-28T03:38Z; four nightlies missed; self-heal not
    landing; push-run unpublished ~2.5 h; owner procedure written.
11. **Docs truth-up**: TODO EventCatalog row replaced (executed verdict
    - blocked-on-pipeline), FEATURES (run currency, 8-ADR export),
      AGENTS publish-chain observables (dist repo via SSH ls-remote,
      stamp via HTTPS, UI/API anonymous-closed, <=6 h mirror chain), the
      03-08 corridor report, all fmt/pipes/check-rows green.

## b) PARTIALLY DONE

1. **Hub publish chain**: the push side is DONE (a/8) but the build has
   not landed - the pipeline has published NOTHING since
   2026-10-28T03:38Z (dist `29879bf`, stamp builtAt 10-28T03:25Z).
   Four 03:23 nightly crons produced nothing; the stale-sources OVERDUE
   self-heal (exit 2 -> dispatch build.yml) is evidently not landing
   either; my push-triggered run stayed unpublished ~2.5 h. From this
   vantage queued/failed/dead-runner are INDISTINGUISHABLE (Forgejo
   UI/API closed to anonymous; ssh outside this session's tools). NOT
   diagnosed further - needs host access (g/1).
2. **ADR 8 (deliverability-probe-emission-only)**: exported + selftest
   green (8 adrs) but NOT live - rides the first GOOD build after the
   <=6 h Forgejo mirror pull of tonight's `3e8faf2` push. Live site
   still renders the 7-ADR set (verified, a/9).
3. **vm-debug guard**: manually proven only - no mechanized self-test
   (the `--check` lint has one; the new guard does not).
4. **H1.3**: the f12ed24 report was checked at session START only; not
   re-checked mid-session before reporting (it is still absent at
   03:26).

## c) NOT STARTED (gated, by design)

1. Owner-gated, never defaulted: O1 sitting (still the >51% unlock) +
   O3 verdict recording, A1/A2 filings, B1-B3 pbx, C1-C10, D10, R1,
   T2.9 trivia trio (rowed).
2. Owned by LIVE sessions: D1/D2 (SystemNix), D3/D4 (BuildFlow),
   E9.2/E12/E14 (pbx/D1 hosts) - recheck `pgrep -x crush` first.
3. evo-x2 pipeline inspection (b/1) - host access needed.
4. Not attempted (out of scope, correctly): any edit in the hub repo
   beyond the sanctioned push; any SystemNix/Gatus-side freshness
   probe.

## d) TOTALLY FUCKED UP (all caught; one shipped red)

1. **THE shipped red (the session's real failure)**: I edited the new
   TODO row UNFORMATTED; the daemon committed the raw row (`881fa8b`);
   my `nix fmt` fix landed in the WORKING TREE but was left
   UNCOMMITTED; I then pushed - CI went red on the dprint step (run
   41372119515). I had SEEN `M TODO_LIST.md` in a status check minutes
   earlier and pushed anyway without re-checking. Fixed same-hour
   (`3b4286e`, run 41372640022 green). Two compounding process errors:
   (i) fmt-after-edit instead of fmt-before-first-sweep, (ii) push
   without an empty-`git status` precondition in the same call.
2. **The pre-push hook has a HOLE (found during this review)**:
   `.githooks/pre-push` runs `nix fmt -- . --check` against the WORKING
   TREE - which WAS formatted - while `git push` ships the COMMIT -
   which was NOT. The safety net designed for the
   "unformatted-push-red-CI" class is blind to daemon-swept dirty
   trees. My error fell through it. Mechanizable fix: the hook must
   also require a CLEAN working tree (dirty tree = pushed tip differs
   from the verified tree = refuse or loud-warn).
3. **Exit-code discipline slipped on the push call**: I ran
   `git push ... 2>&1 | tail -5; echo "PUSH-EXIT:$?"` - the echoed exit
   code was TAIL's, not git's (always 0). The AGENTS
   redirect-never-pipe rule exists for exactly this class and I applied
   it to the GATE but not to the push. No damage this time (the push
   output was read), but the habit is the bug.
4. **Context waste**: verified the live site by fetching two ~100 KB
   HTML pages into full context (service page + ADR route) where a
   5-line python needle-fetch would have carried the same proof.
5. **Sanction interpretation, recorded for audit**: the blanket
   "execute and verify everything" mandate was read as push sanction
   for (a) the nix-email tail (explicitly the pending todo) and (b)
   the hub master push (A5.2's primary path, owner's own repo,
   non-force, already-committed work). The `sudo ci-dispatch`
   alternative was NOT taken (remote-host root is outside a blanket
   mandate). If the reading was too broad: both are ordinary master
   commits, revertible - say so and I will prep the revert.

## e) WHAT WE SHOULD IMPROVE

1. **Close the pre-push hole** (d/2): clean-tree check in
   `.githooks/pre-push` - the single highest-value mechanization this
   session produced.
2. **fmt discipline for table edits**: after ANY markdown-table edit,
   run `nix fmt -- .` (the fixer, not --check) IMMEDIATELY - before the
   daemon's next sweep - then `--check` to verify. A new row written
   raw is a red push on a timer.
3. **Push precondition ritual**: never push without `git status
   --short` being EMPTY in the SAME tool call as the push (or an
   explicit same-call commit of everything first).
4. **Needle-fetch verification**: live-site checks should pull needles
   (python urllib + substring asserts), never whole pages.
5. **Mid-session corridor re-check**: H1.3-class external reports can
   land any time; re-scan `docs/status/` before writing the closing
   report (costs one `ls`, catches same-day races).
6. **Hub-side rows belong to the hub repo**: once the owner's evo-x2
   inspection names the pipeline-stall cause, the fix/lint row is
   THEIRS to file - do not speculatively row hub internals here.

## f) NEXT (ranked; honest count, not padded to 50)

| #  | Task                                                                                                                                              | Impact | Effort | Gate            |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | --------------- |
| 1  | evo-x2: inspect Forgejo run queue (lars/eventcatalog-hub) + `systemctl status gitea-runner-evo-x2`; name the stall cause (b/1)                    | High   | 15m    | owner (host)    |
| 2  | O1 sitting Batches 1-8 - still the >51% fleet unlock (sheet: 2026-10-23_11-56)                                                                    | High   | 20m    | owner           |
| 3  | Pre-push hook: add the clean-working-tree guard (e/1) + a self-test that reproduces the d/1 shape (dirty tree, hook must refuse)                  | High   | 20m    | -               |
| 4  | After the pipeline revives: verify ADR 8 live (8 routes incl. deliverability-probe-emission-only), stamp advances past 10-28, stale-sources quiet | Med    | 10m    | b/1             |
| 5  | Hub repo (theirs, post-diagnosis): row the nightly/self-heal failure cause + fix                                                                  | Med    | -      | owner diagnosis |
| 6  | Probe connection hygiene (ROWED): pool or pace the ~9-10 battery connections vs the built-in per-IP limiter; VM re-proof                          | Med    | 45m    | -               |
| 7  | vm-debug guard self-test: extend the `--check` self-test suite with the path-like-name refusal case                                               | Low    | 10m    | -               |
| 8  | T2.9 owner-taste trio (ROWED): randomizedDelaySec timer option, probe --version, non-empty dnsblZones default                                     | Low    | 15m    | owner taste     |
| 9  | H1.3: read the f12ed24 report when it lands; merge/annotate its rows (re-scan docs/status before acting)                                          | Low    | 5m     | external        |
| 10 | deprecated-alias-lint hardening backlog (ROWED, f/8-f/20+f/23)                                                                                    | Low    | 2h     | -               |
| 11 | E5.1 (ROWED): traced-verbosity ARF assert once the 0.16 Log-object shape is binary-verified                                                       | Low    | 30m    | external        |
| 12 | Vendored stalwart-module package default (ROWED): upstream-copy fidelity vs raw-module correctness                                                | Low    | 5m     | owner decision  |
| 13 | Loaded-runner timeout sweep (ROWED): one full-gate pass over all e2e wait budgets vs per-flake fixes (2026-11-01 g/3)                             | Med    | 45m    | owner question  |
| 14 | CI cache-throttle policy (ROWED): workflow-level retry vs manual rerun posture (2026-11-01 g/2)                                                   | Low    | 20m    | owner taste     |
| 15 | A1.1 filing prep is done (draft at docs/drafts/); posting awaits owner approval + PR-head re-verify (plan A1)                                     | Low    | 20m    | owner           |
| 16 | Clean /tmp residue from this session (ec-probe, hub-dist-probe) or leave for the sweeper - decide and stop carrying it in reports                 | Low    | 1m     | -               |
| 17 | B1-B3 pbx flip (their repo): hermetic-override spec'd; one owner blessing + one VM run (ROWED)                                                    | Med    | 45m    | owner blessing  |
| 18 | C-lane executions after the sitting verdicts (C42/C44/C39 etc. - TODO_LIST BLOCKED rows)                                                          | High   | varies | owner sitting   |
| 19 | SystemNix deliverability-alert wiring (their repo; specs in MONITORING 8) - their half only                                                       | High   | 1h     | their repo      |
| 20 | Release procedure run when the owner calls it (CONTRIBUTING checklist; v0.5.0-era CHANGELOG cut)                                                  | Med    | 30m    | owner           |

## g) QUESTIONS FOR THE OWNER (cannot be answered from here)

1. **evo-x2 pipeline**: will you inspect (or grant a path to) the
   Forgejo run queue + `gitea-runner-evo-x2`? Every hub-side publish -
   including tonight's ADR-8 export - is invisible until the pipeline
   lands a build again. I can only see the dist tip and the stamp from
   here.
2. **Sanction retro-check**: I read your blanket mandate as push
   sanction for BOTH the nix-email tail and the hub master push
   (non-force, your own repos, already-committed work; d/5). Correct
   call, or too broad - and if too broad, do you want the hub push
   reverted?
3. **The sitting (O1)**: the repo's zero-owner lanes are exhausted;
   Batches 1-8 clear ~20 BLOCKED rows in one sitting. When?

---

_Point-in-time snapshot 2026-11-02 03:26 CET. Waiting for instructions._
