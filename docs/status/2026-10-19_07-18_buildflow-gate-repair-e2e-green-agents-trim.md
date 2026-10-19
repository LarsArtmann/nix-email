# Status Report 2026-10-19 07:18 - BuildFlow Gate Repair, E2E Green, AGENTS.md Trim

Session scope: repair the failing `buildflow --fix --build-mode=full` run
(exit 69, 2 steps red), verify everything end-to-end, clear the recurring
preflight warnings. One session, ~70 min. Everything below is from THIS
session's own runs and observations - no unrelated research.

Gate verdict at report time: `nix flake check` EXIT:0 (all 10 x86_64
checks); buildflow rerun (30m budget): nix-build GREEN, ALL steps green
except ruff-check-fix, which is red on 4 findings in 2 files owned by a
DIFFERENT live session (handed off, not touched).

## a) FULLY DONE

| Item                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Evidence                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| ruff EXE001 x3 fixed: `chmod +x` on `es_probe.py`, `jmap_move.py` (docs/probes/2026-10-18-demo-smoke-backup/) and `modules/stalwart-module/rewrite-datastore-path.py`; scripts are invoked via `pythonEnv script.py` so the bit is cosmetic conformance                                                                                                                                                                                                                         | ruff check "All checks passed" on all 3; scoped verify at 07:18 shows zero EXE001                                                                                       |
| Both deadline-killed e2e checks rebuilt GREEN: `stalwart-migrate-e2e` and `stalwart-relay-e2e` built serialized in background (per the cross-repo OOM rule), not cache-hit                                                                                                                                                                                                                                                                                                      | `/tmp/migrate-e2e.log` MIGRATE-EXIT:0, `/tmp/relay-e2e.log` RELAY-EXIT:0 (real execution: VM boot + provision transcripts in log)                                       |
| Full gate green: `nix flake check > /tmp/gate.log` redirect-style                                                                                                                                                                                                                                                                                                                                                                                                               | gate.log final line `EXIT:0` (~07:11)                                                                                                                                   |
| buildflow rerun with adequate budget (`--max-time 30m --step-timeout nix-build=25m`): the previous 2 failed steps now green; nix-build passed                                                                                                                                                                                                                                                                                                                                   | `/tmp/buildflow-rerun.log`: only ruff-check-fix red (foreign files), everything else green; "26/42" with 1 failed                                                       |
| Root cause recorded: 5m `--max-time` cannot cover VM-e2e nix-build steps (per-step deadline fired at 2m46s); lesson added to AGENTS.md buildflow bullet ("Budget `--max-time` >= 30m")                                                                                                                                                                                                                                                                                          | AGENTS.md Commands section (daemon-committed)                                                                                                                           |
| devShell pins dprint + lychee + ruff (buildflow's "not in project devShell" warnings were a real reproducibility bug: `nix run nixpkgs#<tool>` picks registry-latest, so lint/format results drift run to run)                                                                                                                                                                                                                                                                  | flake-modules/devshells.nix; rerun log has ZERO "not in project devShell" warnings (was 7+); alejandra `nix fmt -- . --check` EXIT:0                                    |
| Cache DB VACUUM: buildflow cache.db 765 MB -> 99 MB (waited until the concurrent buildflow instance in cqrs-htmx exited - VACUUM under lock contention was the SQLITE_BUSY source class)                                                                                                                                                                                                                                                                                        | rerun log has zero `[system/db-size]` warnings; ls after VACUUM                                                                                                         |
| AGENTS.md 253 -> 220 lines (BuildFlow cap 220, was excess 34): VM debug loops + 0.16-upgrade loop rules moved verbatim-in-substance to new CONTRIBUTING section "VM debug loops"; 0.16-doctrine "sharpest edges" pointer-ized to the README ledger AFTER grep-verifying every specific lives there (auth 535 / MAIL FROM 501, negative-cache TTL, match property, synthesized-address login, over-quota journal silence); narrative fat cut; session lesson added; dprint clean | `wc -l` = 220; `dprint check AGENTS.md CONTRIBUTING.md` EXIT:0; preflight measured 221 mid-edit (07:13), 220 after final pass; TODO_LIST diet row marked DONE, C41 moot |
| Caught + carried forward a foreign edit: another session changed "THREE guard sites" to "FOUR" (new CI-enforced README check list) DURING my rewrite - the modified-since-read guard refused my stale whole-file write, I diffed, and the final text carries their FOUR-site bullet verbatim                                                                                                                                                                                    | git diff at 07:07 (hunk preserved in final AGENTS.md); grep 'FOUR guard sites' = 1                                                                                      |
| Fixed 2 formatter-mangles I had introduced (dprint turned a line starting with `> log` into a blockquote and `- skipped` into a nested list - the exact prose-wrap class AGENTS.md warns about)                                                                                                                                                                                                                                                                                 | final artifact scan `grep '^  *[-+>] '` clean; dprint EXIT:0                                                                                                            |
| Eval guards green after the flake.nix-adjacent edit: check set intact (10 x86_64 / 4 aarch64 attrNames), ci.yml lockstep untouched                                                                                                                                                                                                                                                                                                                                              | `nix eval .#checks.x86_64-linux --apply builtins.attrNames` = 10 names; aarch64 = 4 names                                                                               |
| Verified buildflow's earlier auto-fixes before trusting them: deadnix removed `hardeningOk` from tests/dmarc-eval.nix (grep confirms zero remaining refs), statix inherit rewrite in provision-plan-eval.nix (semantics-preserving) - both daemon-committed in 1da1c3c                                                                                                                                                                                                          | git show 1da1c3c; grep hardeningOk = no matches                                                                                                                         |
| dovecot2.protocols rename warning triaged: NO local setter exists (grep across *.nix) - the warning is emitted by nixpkgs' own parsedmarc module at the pinned rev; upstream, not actionable here                                                                                                                                                                                                                                                                               | grep 'protocols' in repo *.nix = no files                                                                                                                               |
| Handoff row in TODO_LIST for the 4 foreign ruff findings (owner: live CardDAV/archive session) + AGENTS-diet row advanced to DONE                                                                                                                                                                                                                                                                                                                                               | TODO_LIST.md "Ruff debt handoff..." row; tables dprint-normalized, check-md-table-pipes.sh EXIT:0                                                                       |

## b) PARTIALLY DONE

1. Full buildflow pipeline green.
   Works: every step except ruff-check-fix (rerun 07:13, 52.9s warm).
   Missing: ruff-check-fix red on 4 findings in 2 files another session was
   writing at 07:13:56 (same-second burst): `carddav_probe.py` F841 `token0`
   (:232) + RUF059 `headers2` (:245); archived `gen-repair-spec.py` SIM115 x2
   (:6, :51). I fixed the EXE001 half (chmod) and left content findings to the
   owner per the no-cross-edit rule. Blocker: ownership, not difficulty.
   Effort to finish: S (10 min) once the owning session is done.

2. AGENTS.md at the cap with zero headroom.
   Works: 220/220, preflight silent on the final text (measured mid-edit at
   221, fixed before yielding).
   Missing: the next hard-won lesson has nowhere to go without a cut. The C41
   "repo-local cap ~230" blessing is now moot, but the file will re-warn on
   the next addition. Effort: S per occurrence.

3. BuildFlow binary freshness (advisory warning, both runs).
   Works: triaged precisely - BuildFlow repo HEAD cf606f8 is 2 daemon commits
   past the binary build ef32fa0, AND BuildFlow's working tree has uncommitted
   `vendorHash.nix` (another session mid go-vendor/build cycle).
   Missing: rebuild + `nix run .#reinstall` is intentionally NOT done -
   installing a foreign WIP intermediate risks shipping a broken binary.
   Blocker: BuildFlow repo must land first. Effort: S after that.

4. CardDAV probe workstream (other session, observed not driven by me).
   Works: probe file exists (15 KB), EXE001 cleared by my chmod, archived
   specs dir populated.
   Missing: F841/RUF059/SIM115 x2 + whatever their T04 probe sequence still
   needs; their session was still writing 4 min before my last check.

## c) NOT STARTED

1. HARVEST of this report's section (f) into TODO_LIST.md/ROADMAP.md
   (docs-health HARVEST) - deliberately deferred: you instructed
   report-then-wait. The 2 rows THIS session already produced are in
   TODO_LIST; the (f) brainstorm below is not yet harvested.
2. `.buildflow.yml` durable step-timeout: bake `nix-build=25m` (or similar)
   into repo config so future full runs do not depend on remembering the
   flag. One-line config + rationale comment; not started (config change to
   the shared gate deserves owner eyes).
3. CHANGELOG entry for this session's user-visible bits (devShell tool pins,
   AGENTS.md restructure, CONTRIBUTING section). The daemon commits carry no
   narrative; nothing written yet.
4. Origin CI verification of today's daemon-pushed commits (last known green
   run 39191414206 predates all of today's commits).
5. Probe-script executable-bit doctrine (chmod vs drop-shebang vs
   per-file-ignore for EXE001) - ruff will fire on every future probe with a
   shebang; needs a one-line convention decision. Not started (owner call).
6. nix-checker "sha256 in tests/common.nix - extract to sha256.nix" info
   finding: accept-or-fix decision not started (info-level, non-blocking).

## d) TOTALLY FUCKED UP

Nothing I touched landed broken - but two near-misses and one honest
limitation, because this section loses its value if I am gentle:

1. NEAR-MISS, would have destroyed foreign work: my first AGENTS.md trim was
   drafted from a stale read. Between my read (07:03) and write (07:06),
   another session corrected THREE to FOUR guard sites in that same file. I
   attempted the whole-file write anyway; the modified-since-read guard
   refused it. Only THAT tooling guard prevented me from reverting a fresh,
   correct, CI-relevant edit by another session. Root cause: I had earlier
   observed `docs/status/archived/README.md` modified in the working tree -
   evidence of live foreign doc work - and did not connect it to "re-check
   AGENTS.md immediately before a whole-file rewrite". Mitigation now: the
   final text carries their edit; the write tool guard is the only thing that
   saved the first attempt. This was a process failure, not bad luck.
2. The shared gate is red RIGHT NOW and I could not make it fully green:
   buildflow exit 69 persists (ruff-check-fix) because a concurrent session
   owns the failing files. Severity: blocks anyone's clean full-gate
   evidence until they land. Root cause: cross-session file ownership, by
   design of the parallel-sessions workflow. Mitigation: TODO_LIST handoff
   row; their own pre-commit gate forces the fix at their next commit.
3. I burned one full 5-minute buildflow cycle re-running the user's command
   with the SAME failing budget constraints before sizing the timeout
   properly. Predictable from the first run's own error text (deadline
   arithmetic is printed). Wasted ~5 min of gate time; the second run with
   30m was the informative one.
4. Residual risk I accepted and must name: my AGENTS.md rewrite was a
   whole-file `write` over a memory file. I concept-verified per bullet and
   the diff review is in the transcript, but a whole-file rewrite always
   risks silent drops in a way targeted edits do not. If any lesson feels
   missing on next read, the pre-trim text is in git history (pre-6af44f7).

## e) WHAT WE SHOULD IMPROVE

1. Whole-file rewrites of shared files need a re-read-plus-diff IMMEDIATELY
   before the write, not a read minutes earlier. The guard caught me once;
   guards are the backup, not the procedure. Concrete: add "fresh `git diff
   <file>` immediately before any whole-file write to a shared doc" to the
   session-start ritual bullet in AGENTS.md (costs 1 line; file has 0
   headroom - see the tension).
2. The AGENTS.md 220 cap has no buffer. Every future lesson forces an
   immediate cut (or the warning returns). Suggested: bless a 225 working
   cap with a hard 230 ceiling, or move one more block (candidate: the
   repo-tool traps bullet -> CONTRIBUTING) to regain ~6 lines.
3. dprint prose-mangle class keeps biting (this session: blockquote +
   nested-list artifacts from MY wrapping). The lint
   `scripts/check-md-table-pipes.sh` covers table pipes only; a 5-line awk
   twin for "continuation lines starting with `>`, `-`, `+` inside list
   items" would mechanize the `git diff` discipline. Candidate CI/BuildFlow
   step.
4. buildflow full-gate runs in this repo need budget sizing knowledge that
   currently lives only in heads + one AGENTS.md line: default per-step
   deadline kills VM-e2e. Durable fix: `.buildflow.yml` step-timeout (see
   c2) so the flag is not per-invocation tribal knowledge.
5. Ruff on probe scripts: F841/RUF059 are routine in probe code (bind
   results for later inspection); EXE001 fires on every new shebang script.
   Either a docs/probes per-file-ignores block or a written convention ends
   a recurring repair-vs-noise argument. Decision needed (V2.3 python-lint
   scope batch).
6. Cross-session SQLITE_BUSY: two buildflow instances share one state DB;
   resume checkpoints dropped for minutes under contention. Works, but
   timing analytics lost records ("1 lost to write failures"). BuildFlow-
   side improvement (their repo): per-session DB or retry backoff. Already
   adjacent to TODO row "BuildFlow upstream follow-ups".
7. Scoped-first verification: `buildflow -s ruff-check-fix` (9 s) would have
   surfaced the foreign-file findings before any full run. Habit candidate:
   scope-verify the previously failing step first, then run the full gate
   once.

## f) Up to 50 things to get done next

Brainstorm per the skill contract (larger N = routing rigor at HARVEST;
items already living in TODO_LIST are marked so they are not double-created).

| #  | Task                                                                                                                       | Impact | Effort | Category      | Source                         |
| -- | -------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ------------- | ------------------------------ |
| 1  | Fix `carddav_probe.py` F841 (`token0`, :232) - prefix underscore or wire into the T04 assertions                           | Medium | S      | Bug           | NEW (handoff row)              |
| 2  | Fix `carddav_probe.py` RUF059 (`headers2`, :245)                                                                           | Medium | S      | Bug           | NEW (handoff row)              |
| 3  | Fix `gen-repair-spec.py` SIM115 x2 with context managers (:6, :51)                                                         | Low    | S      | Quality       | NEW (handoff row)              |
| 4  | Re-run full buildflow (30m budget) for the first fully-green ruff-check-fix once 1-3 land                                  | High   | S      | Quality       | NEW                            |
| 5  | Bake `step-timeout nix-build` into `.buildflow.yml` with rationale comment                                                 | High   | S      | Quality       | NEW                            |
| 6  | Rebuild + reinstall BuildFlow binary after its repo lands `vendorHash.nix`; re-review ef32fa0..cf606f8+ delta first        | Medium | S      | Cleanup       | NEW                            |
| 7  | HARVEST this report into TODO_LIST/ROADMAP (docs-health)                                                                   | High   | S      | Documentation | NEW (skill-mandated)           |
| 8  | CHANGELOG entries: devShell tool pins, AGENTS restructure, CONTRIBUTING "VM debug loops"                                   | Low    | S      | Documentation | NEW                            |
| 9  | Verify origin CI green on today's daemon-pushed commits (post 39191414206)                                                 | High   | S      | Quality       | NEW                            |
| 10 | Probe-script lint doctrine: per-file-ignores for docs/probes (F841/RUF059/EXE001) vs written chmod convention              | Medium | S      | Quality       | NEW                            |
| 11 | AGENTS.md headroom policy: bless 225 working cap or cut one more block (repo-tool traps -> CONTRIBUTING candidate)         | Medium | S      | Documentation | NEW                            |
| 12 | Validate the "--max-time >= 30m" number against a COLD-cache full buildflow run (today was warm) and adjust if tight       | Medium | M      | Quality       | NEW                            |
| 13 | md prose-mangle lint: awk twin of check-md-table-pipes.sh for list-item continuation lines starting with `>`/`-`/`+`       | Medium | S      | Quality       | NEW                            |
| 14 | CardDAV session completion: land transcripts under docs/probes/ + README index, settle wire-claims per the transcript rule | High   | M      | Feature       | NEW (their plan)               |
| 15 | Verify the new FOURth guard site (README anti-drift CI step) end-to-end on a real check add/remove                         | Medium | S      | Quality       | NEW (their change)             |
| 16 | Confirm deadnix-removed `hardeningOk` is not referenced in FEATURES/README/status docs (contract variable vanished)        | Low    | S      | Documentation | NEW                            |
| 17 | nixpkgs parsedmarc-module dovecot rename warning: note for the next pin-advance (upstream fix or local mute)               | Low    | S      | Cleanup       | NEW                            |
| 18 | Decide nix-checker "extract sha256 to sha256.nix" (tests/common.nix): accept as info or do the 2-line extraction           | Low    | S      | Cleanup       | NEW                            |
| 19 | After next full executed gate, refresh the ledger/e2e-evidence pointers that cite cached greens (release evidence hygiene) | Medium | M      | Quality       | NEW                            |
| 20 | Relay bounce-path e2e subtest (W6.3): assert via Mailpit/queue, never journal                                              | Low    | M      | Feature       | TODO row (exists)              |
| 21 | E2E runtime trim investigation (W6.4 TTL windows)                                                                          | Low    | S      | Quality       | TODO row (exists)              |
| 22 | Flood-subtest refill flake: capture plan if it recurs                                                                      | Low    | S      | Bug           | TODO row (exists)              |
| 23 | EventSource `ping` parameter probe (last unprobed JMAP quirk)                                                              | Low    | S      | Feature       | TODO row (exists)              |
| 24 | Apply-log dump-on-failure fault-injection proof (W18.3)                                                                    | Low    | S      | Quality       | TODO row (exists)              |
| 25 | External-link re-verification sweep (T15)                                                                                  | Low    | S      | Documentation | TODO row (exists)              |
| 26 | Upstream filings remainder (dnsmasq note, dprint T13b)                                                                     | Low    | M      | Documentation | TODO row (exists)              |
| 27 | Upstream watch batch (#563651/#563652/#563777/mailsuite#65/#552103 retirement)                                             | Medium | S      | Cleanup       | TODO row (exists)              |
| 28 | BuildFlow upstream follow-ups (identity parsing, bandit count gap, masking docs)                                           | Low    | M      | Bug           | TODO row (exists)              |
| 29 | buildflow local-noise batch (nix-hash-fix WARN, lychee policy, interrogate skip)                                           | Low    | M      | Cleanup       | TODO row (exists)              |
| 30 | TLS-node coverage for Netease/LinkedIn parsedmarc fixtures                                                                 | Low    | M      | Feature       | TODO row (exists)              |
| 31 | Pin VM debug-driver recipe as a script (CONTRIBUTING section now documents it; scripting still open)                       | Low    | M      | Quality       | TODO row (exists)              |
| 32 | dmarc-eval IFD cleanup                                                                                                     | Low    | S      | Cleanup       | TODO row (exists)              |
| 33 | Local lockstep eval guard (attrNames == ci.yml expected, locally)                                                          | Medium | S      | Quality       | TODO row (exists)              |
| 34 | Flood-limiter robustness (relaxed-bound transcript check)                                                                  | Low    | S      | Quality       | TODO row (exists)              |
| 35 | "running N flake checks" log-line reconciliation                                                                           | Low    | S      | Bug           | TODO row (exists)              |
| 36 | nixpkgs `stalwart` rename watch past 0.16 (disabledModules collision)                                                      | Low    | S      | Cleanup       | TODO row (exists)              |
| 37 | check-inventory.sh CI twin (daemon pushes bypass pre-push)                                                                 | Low    | S      | Quality       | TODO row (exists)              |
| 38 | Cut v0.5.0 (C43 doctrine call + dry-run of release procedure)                                                              | High   | L      | Release       | TODO row (exists, C43-blocked) |
| 39 | SystemNix pin advance runbook (post v0.5.0)                                                                                | High   | L      | Release       | TODO row (exists, blocked)     |
| 40 | C42 dmarc-monitor retire-or-keep decision                                                                                  | Medium | S      | Decision      | TODO row (exists, blocked)     |
| 41 | C44 real-host account-secrets doctrine                                                                                     | Medium | M      | Decision      | TODO row (exists, blocked)     |
| 42 | C45 Stalwart 0.16.22-vs-0.16.26 overlay decision + delta table                                                             | Medium | M      | Decision      | TODO row (exists, blocked)     |
| 43 | dmarc-monitor live validation (D1 mailbox decision)                                                                        | High   | M      | Feature       | TODO row (exists, blocked)     |
| 44 | MemoryMax policy decision (C39)                                                                                            | Medium | S      | Decision      | TODO row (exists, blocked)     |
| 45 | Match-property audit remainder: dead wrapper-option ride + snapshot-vs-wrapper matchOn ledger line                         | Medium | M      | Quality       | TODO row (exists, in progress) |
| 46 | CI python-lint scope: deeper ruleset decision (PERF/FURB/BLE vs floor)                                                     | Low    | S      | Quality       | TODO row (exists, in progress) |
| 47 | pbx-artmann stalwart-host-wiring flip + f27 cell restore (their repo)                                                      | Medium | S      | Bug           | TODO row (exists, their repo)  |
| 48 | Consider recording "register reads with view before edit" as a mechanized pre-edit hook instead of a ritual line           | Low    | M      | Quality       | NEW                            |
| 49 | E2E polish batch: restart-persistence extension (provision unit must not re-run)                                           | Low    | M      | Quality       | TODO row (exists)              |
| 50 | JMAP anti-rot: `ping` probe (merge with #23 if harvested once)                                                             | Low    | S      | Feature       | TODO row (exists)              |

HARVEST note: items 1-19 are this session's new ground; 20-50 already live in
TODO_LIST (do not double-create - verify + link instead).

## g) Questions I cannot answer myself

1. The CardDAV/archive session owned the 2 red files at 07:13:56 and was
   still writing 4 minutes later. Is that session still active, and do you
   want me to KEEP HANDING OFF (my current posture) or TAKE OVER the 4
   findings now (breaking the no-cross-edit rule for a ~10 min green gate)?
2. Budget policy: should `.buildflow.yml` carry a durable
   `nix-build` step-timeout (+ documented 30m full-run budget), or do you
   prefer the flags per invocation so the operator always feels the cost?
3. Probe-script lint doctrine: for `docs/probes/**`, do you want
   per-file-ignores (accept F841/RUF059 as probe idioms), a written
   "always chmod +x new probes" convention, or shebangs dropped instead?
   (I fixed today's instances mechanically; the doctrine decides whether
   tomorrow's are noise or work.)

WAITING FOR INSTRUCTIONS.
