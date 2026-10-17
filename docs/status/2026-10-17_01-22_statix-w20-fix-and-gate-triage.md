# Status Report: statix W20 collapse fix + full-gate triage

- **When:** 2026-10-17, 01:22 CEST (session ran ~01:00-01:30)
- **Scope:** single session - fix the 4 statix W20 findings, verify them, triage the full-gate red that surfaced underneath
- **Branch state at writing:** `master`, clean tree, **5 commits ahead of origin/master, unpushed**
- **Master CI:** RED since 2026-10-16 22:56:10Z (4 consecutive red runs); no CI run has seen this session's fixes

## Executive summary

The 4 statix W20 warnings (repeated attrpath prefixes) were collapsed into
nested attrsets across 3 files - semantically identical rewrites, proven so
three independent ways (pinned-statix exit 0, byte-identical eval captures,
content-addressed VM output identity). The fix is committed locally
(8f8ced8) but **not pushed**, so master is still red from CI's perspective.

The full gate then failed on a SECOND, distinct problem: stalwart-e2e's
runtime catch-all apply. That failure predates this session. A parallel
session iterated on it while this one ran (3 daemon commits to the test
gained: log-dump-on-failure, explicit assert, and a corrected ordering
comment). My re-verification against the latest committed state is still
RED - but the log dump now captures the REAL root cause:
`Domain: match property \`name\` is missing from the object body`. The
earlier plan-ordering theory (Account-before-Domain) was a red herring:
Account-first fails with invalidResultReference, Domain-first is required,
and the true bug is the missing match property in the Domain upsert body.

## a) FULLY DONE

1. **All 4 statix W20 findings fixed.**
   - Evidence: `statix check .` exit 0 AND the CI-pinned variant
     (`nix run github:NixOS/nixpkgs/6774f7bc...#statix -- check .`) exit 0.
   - Files: `modules/stalwart-module/default.nix` (db + fs in both storage
     branches, storage with 5 keys, directory.internal, resolver),
     `tests/stalwart-relay-e2e.nix` (one environment block),
     `flake-modules/demo-vm.nix` (one environment block; banner indented
     string re-indented uniformly +2).
   - Commit: 8f8ced8 (daemon).
2. **Semantic identity of the rewrite proven mechanically.**
   - Demo banner string: byte-identical before/after (nix eval diff of the
     899-byte text).
   - Demo settings JSON: identical (demo takes the since0_16 branch).
   - `stalwart-relay-e2e`: green, and its VM output hashes to the SAME store
     path that was registered at 2026-10-16 22:44:53Z - BEFORE this
     session's edits existed. Content-addressing proves the collapse
     changed nothing observable.
3. **alejandra formatting compliance.** `nix fmt -- . --check` exit 0 after
   every edit (repo rule: daemon pushes mid-session).
4. **Eval contract checks green on the fixed tree.** dmarc-eval,
   module-import-eval, demo-eval all built exit 0.
5. **Root cause of master's 4 red CI runs identified.** All four died in the
   fail-closed "Statix lint Nix files" step on exactly the findings the user
   pasted; last green was 2026-10-16 05:25:23Z. This session's fix is the
   cure (pending push).
6. **Root-cause hunting for the stalwart-e2e catch-all failure advanced from
   silent red to a precise API error.** Started from the foreign diff's
   ordering theory; my recheck against the committed fix refuted it and the
   new log dump captured the real error: `Domain: match property \`name\`
   is missing from the object body` (apply-log transcript, this session's
   e2e-recheck log). Ordering was re-established as correct (Domain-first;
   Account-first fails invalidResultReference).
7. **AGENTS.md updated with the session lesson** (cf78a1f): attribute gate
   reds via git-status baseline + registrationTime dating before blaming
   your own diff; never edit a foreign in-flight file.

## b) PARTIALLY DONE

~~1. **"Full gate green on this tree" - not achieved.**~~ superseded - the catch-all root cause was fixed in-tree (Domain body carries `name`; credentials indexed-map, a38c137); the quota subtest is the remaining red (TODO_LIST)

- Works: every OTHER check verified individually (relay-e2e, dmarc-eval,
  module-import-eval, demo-eval) - all green.
- Open: stalwart-e2e re-verified during this report - STILL RED, now with
  the true root cause captured (see d2). Next fix is one line-class:
  add the match property `name` to the Domain upsert body.
- Effort to finish: S (edit + one e2e run).
  ~~2. **Master CI green - blocked on push.**~~ routed - TODO_LIST push row (ahead 9 as of 2026-10-17; C38 posture)
- Works: all 5 local commits (statix fix + e2e fix + AGENTS.md) are
  committed, tree clean.
- Open: origin/master has none of it; `gh run list` shows no run newer
  than 22:56:10Z. The daemon owns pushes; I do not push unasked.
- Effort: S.
  ~~3. **stalwart-e2e catch-all bug fix - committed, verified RED, root cause~~ done - fixed in-tree (see b/1); the 00-03 report records the subtest passing
  now precise.**
- The parallel session's fix evolved across 3 daemon commits: kept
  Domain-first order (Account-first fails invalidResultReference - their
  apply-log transcript), added execute+log-dump+assert (this produced
  today's diagnostic transcript), but the Domain upsert body still lacks
  the required match property `name`.
- Open: the one-line-class body fix + re-run; ownership unclear (g1).
  ~~4. **Demo VM verification after the environment-block move.**~~ routed - TODO_LIST demo-smoke row
- Works: demo-eval green; banner string byte-identical.
- Open: no runtime smoke (`nix run .#vm`) this session - the demo
  toplevel has never been realized on this machine (path-info
  registrationTime is null), so there is no built-VM evidence.
- Effort: M.
  ~~5. **Full-gate log triage.**~~ partially closed 2026-10-17 - 6 checks defined = 6 in ci.yml lockstep (nix eval attrNames); the log count line remains unexplained (TODO_LIST row)
- Works: failing check identified with step-level evidence; cache-hit vs
  real-run resolved via registrationTime dating.
- Open: the gate log says "running 4 flake checks" while the repo
  defines 5; unexplained at report time.

## c) NOT STARTED

~~1. **CI validation of the statix fix** - waiting on push (see g2).~~ routed - TODO_LIST push row
~~2. **One clean full `nix flake check`** on the committed tree.~~ routed - TODO_LIST gate row
~~3. **Full buildflow gate pass** on the fixed tree (the nix-checker stale-hash~~ routed - TODO_LIST gate row
and input-drift signal has not run this session).
~~4. **README ledger entry** for the catchAllAddress-validation-ordering trap~~ done - the README 'Stalwart 0.16' ledger section carries the plan dialect incl. the Domain match-property trap (2026-10-17 pass)
(it is exactly the "obvious key is wrong" class the ledger exists for).
~~5. **Decision + work: topo-sort hardening for runtime plans** in~~ routed - TODO_LIST match-property audit row; the upstream topo-sort ask rides the #552103 merge watch
stalwart-provision (currently only the boot path orders correctly and
only the test works around it) - needs an owner decision, see g3.
~~6. **docs-health HARVEST** of this report's section (f) into TODO_LIST /~~ done - this pass
ROADMAP.
~~7. **"4 vs 5 flake checks" reconciliation** (`nix eval .#checks.x86_64-linux~~ partially closed - see b/5
   --apply builtins.attrNames` vs the gate log line).
~~8. **Proof that the new apply-log dump actually fires on failure**~~ routed - TODO_LIST fault-injection/dump-on-failure row
(deliberate fault-injection in a debug VM run).

## d) TOTALLY FUCKED UP

1. **Master CI: 4 consecutive red runs (2026-10-16, 14:29 through 22:56).**
   - Severity: blocks the release hygiene this repo's consumers depend on
     (SystemNix pins release tags; a red master muddies every pin advance).
   - Root cause: the auto-commit daemon pushed mid-session edits containing
     the W20 findings; CI's fail-closed statix step (correctly) rejected
     them. Local dev never ran statix before the push.
   - Mitigation: FIXED locally in 8f8ced8, verified with CI's exact pinned
     statix - but **still red upstream until pushed**.
2. **stalwart-e2e catch-all: runtime apply fails (exit 1) - true root cause
   now captured.**
   - Severity: blocks the full gate; the repo's primary behavioral E2E is
     red on every full run.
   - Root cause (CAPTURED THIS SESSION, replacing the earlier ordering
     theory): `upsert Domain: match property \`name\` is missing from the
     object body` - the 0.16 API requires the match property in an upsert
     body even when patching an existing object; the test's Domain body
     carries only catchAllAddress. Diagnosis evolution: ordering theory
     (from the first foreign diff) was REFUTED by the committed fix's own
     transcript comment plus my recheck.
   - Evidence-loss note: the FIRST failure's error is still lost (old code
     never dumped the log); every future failure now dumps. The dump
     mechanism is proven working (it produced today's transcript).
   - Mitigation: add the match property to the Domain upsert body, re-run;
     ownership with the parallel session (g1).
3. **Not fucked up - stated to keep (d) honest:** nothing in this session's
   own edits broke anything. Proof: pinned-statix exit 0, fmt exit 0,
   byte-identical eval captures, and a VM closure that hashes identical to
   its pre-edit build.

## e) WHAT WE SHOULD IMPROVE

1. **No session-start tree baseline.** I began editing without `git status`
   and without noticing same-day status docs (20:48, 21:08) that signaled an
   ACTIVE parallel session in the same files' neighborhood. Impact: real
   clobber risk on the foreign in-flight file; I got lucky. Fix: mechanical
   start ritual - `git status --short` + `ls docs/status` same-day scan +
   note foreign files before the first edit.
2. **Gate-first instead of check-first.** AGENTS.md prescribes building the
   ONE touched check before a full gate (~9 min lesson). I ran the full gate
   first; it aborted at the unrelated e2e red and I still had to verify each
   check individually. Fix: order verification targeted-first, gate last.
3. **Cache-hit acceptance.** I read relay-e2e's `EXIT:0` before noticing the
   1-line log (cache hit). The doctrine caught it, but the reflex should be:
   grep the log for execution lines BEFORE reading the exit code.
4. **Refactor-identity dating is still a hand-rolled recipe.** The
   registrationTime proof (output registered before the edits, same path
   after) is the cheapest strong evidence a pure refactor can produce, but
   it took 3 commands and one jq fumble. Fix: a tiny script or a documented
   recipe in AGENTS.md (partially done - the lesson is recorded; the recipe
   is prose, not tooling).
5. **Silent-failure pattern in VM tests.** A test step that redirects output
   into the VM and never dumps it on failure cost a full VM run's evidence
   (the e2e catch-all). One test now does it right; the pattern should be
   audited repo-wide.
6. **statix runs only in CI.** The W20 class ships to red CI via the daemon
   because no local step fails fast. Fix options: pinned-statix in the
   pre-push hook (actionlint already got this treatment) or a buildflow
   step ordering guarantee.

## f) Next tasks (ranked; brainstorm input for docs-health HARVEST, not a commitment list)

| #      | Task                                                                                                                                                                                                                  | Impact       | Effort | Category          |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------ | ----------------- |
| ~~1~~  | ~~Push the 5 local commits and watch CI to green on master~~ closed - the parallel session closed its own report at 02:06 (the 00-03 file); ownership question moot                                                   | ~~Critical~~ | ~~S~~  | ~~Quality~~       |
| ~~2~~  | ~~Add match property `name` to the Domain upsert body in the catch-all plan, re-run stalwart-e2e~~ routed - C38 posture + TODO_LIST push row                                                                          | ~~Critical~~ | ~~S~~  | ~~Bug~~           |
| ~~3~~  | ~~One clean full `nix flake check` on the committed tree~~ closed - fixed in-tree (see b/1)                                                                                                                           | ~~Critical~~ | ~~M~~  | ~~Quality~~       |
| ~~4~~  | ~~Harvest this report's (f) into TODO_LIST/ROADMAP (docs-health HARVEST)~~ done - this pass                                                                                                                           | ~~High~~     | ~~S~~  | ~~Documentation~~ |
| ~~5~~  | ~~Audit other 0.16 runtime plans (provision singletons et al) for the missing match-property class~~ routed - TODO_LIST match-property audit row                                                                      | ~~High~~     | ~~M~~  | ~~Bug~~           |
| ~~6~~  | ~~Reconcile "running 4 flake checks" gate-log line against the 5 defined checks~~ routed - TODO_LIST gate-log count row (6=6 verified; line unexplained)                                                              | ~~High~~     | ~~S~~  | ~~Bug~~           |
| ~~7~~  | ~~Adopt the session-start baseline ritual (git status + same-day status-doc scan)~~ done - AGENTS session-start baseline ritual added (2026-10-17 pass)                                                               | ~~High~~     | ~~S~~  | ~~Process~~       |
| ~~8~~  | ~~Full buildflow gate pass on the fixed tree (nix-checker drift signal)~~ routed - TODO_LIST gate row                                                                                                                 | ~~Medium~~   | ~~M~~  | ~~Quality~~       |
| ~~9~~  | ~~README ledger entry: catchAllAddress validation ordering trap~~ done - README ledger carries the trap (this pass)                                                                                                   | ~~Medium~~   | ~~S~~  | ~~Documentation~~ |
| ~~10~~ | ~~Demo VM runtime smoke after the environment-block move (nix run .#vm, ports + banner probe)~~ routed - TODO_LIST demo-smoke row                                                                                     | ~~Medium~~   | ~~M~~  | ~~Quality~~       |
| ~~11~~ | ~~Verify the apply-log dump fires on failure via deliberate fault-injection~~ routed - TODO_LIST fault-injection row                                                                                                  | ~~Medium~~   | ~~S~~  | ~~Quality~~       |
| ~~12~~ | ~~Audit all VM-test steps that redirect output to VM-local files: dump on failure, repo-wide rule~~ routed - TODO_LIST dump-on-failure audit row                                                                      | ~~Medium~~   | ~~M~~  | ~~Quality~~       |
| ~~13~~ | ~~Script the refactor-identity proof (drv/outPath + registrationTime dating)~~ routed - TODO_LIST refactor-identity script row                                                                                        | ~~Medium~~   | ~~S~~  | ~~Quality~~       |
| ~~14~~ | ~~Add pinned-statix to the pre-push hook (mirror CI, like actionlint+shellcheck)~~ routed - TODO_LIST pinned-statix pre-push row                                                                                      | ~~Medium~~   | ~~M~~  | ~~Quality~~       |
| ~~15~~ | ~~Session-start habit: statix check . before any .nix edit session~~ done - AGENTS ritual covers statix-class gate parity (pinned-statix hook = the TODO row)                                                         | ~~Medium~~   | ~~S~~  | ~~Process~~       |
| ~~16~~ | ~~Confirm no ci.yml lockstep/shape-guard change needed (no checks added/removed this session)~~ routed - TODO_LIST ci-lockstep row                                                                                    | ~~Low~~      | ~~S~~  | ~~Quality~~       |
| ~~17~~ | ~~Verify daemon-committed content matches intended edits (git diff 8f8ced8^..8f8ced8 read-back)~~ won't implement as a standing step - the edit tool's exact matching + the daemon's reformat behavior are the guards | ~~Low~~      | ~~S~~  | ~~Cleanup~~       |
| ~~18~~ | ~~Annotate the 21:08 going-green status doc: green predates the 23:04 catch-all red~~ done - the 21-08 doc got its inline correction in this pass's archive sweep                                                     | ~~Low~~      | ~~S~~  | ~~Documentation~~ |
| ~~19~~ | ~~Track the BuildFlow nix-checker summary-vs-detail 12-vs-2 count gap (BuildFlow-repo TODO)~~ routed - TODO_LIST BuildFlow-upstream row                                                                               | ~~Low~~      | ~~M~~  | ~~Quality~~       |
| ~~20~~ | ~~Clean session /tmp artifacts (gate.log, eval captures) after the verification window closes~~ routed - TODO_LIST repo-hygiene row                                                                                   | ~~Low~~      | ~~S~~  | ~~Cleanup~~       |

(20 items - grounded strictly in this session's observations; the "up to 50"
headroom stays empty rather than padded.)

## g) Questions I cannot answer myself

~~1. **Is the parallel 0.16-upgrade session still active, and do you want me to~~ closed - the parallel session closed its own report at 02:06 (the 00-03 file); ownership question moot
take ownership of the stalwart-e2e fix (verify, iterate, push) or stay
hands-off?** I tried to tell from commit timestamps (its file was edited
at 01:05, committed by the daemon in three pieces) and the same-day
status docs - neither says whether the session is done.
~~2. **Push policy: shall I push the 5 local commits now so CI validates the~~ routed - C38 posture + TODO_LIST push row
statix fix, or do you/daemon own pushes on your own schedule?** I
verified via `gh run list` (no run after 22:56:10Z) and `git status -sb`
(ahead 5). I will not push unasked; every hour of delay keeps master red.
~~3. **For the catch-all fix: should I apply the one-line-class repair (add~~ closed - fixed in-tree (see b/1)
`name` to the Domain upsert body) myself, or is the parallel session
mid-iteration and I must stay hands-off?** I tried: the committed code
plus my recheck transcript pin the fix precisely; what I cannot know is
whether the other session is seconds from landing exactly that. A wrong
guess either duplicates work or clobbers theirs.

## Verification chain appendix (evidence, reproducible)

- `statix check .` -> exit 0 (local statix)
- `nix run github:NixOS/nixpkgs/<lock-rev>#statix -- check .` -> exit 0
  (CI's exact command and tool version)
- `nix fmt -- . --check` -> exit 0
- `nix eval --raw .#nixosConfigurations.demo.config...banner.text` before vs
  after -> identical bytes (899 B)
- `nix eval --json ...services.stalwart.settings` before vs after ->
  identical JSON
- `nix build .#checks.x86_64-linux.stalwart-relay-e2e` -> exit 0; output
  path registered 2026-10-16 22:44:53Z (pre-edit) - content-identical
- dmarc-eval + module-import-eval + demo-eval -> exit 0
- Full `nix flake check` -> exit 1, failing check stalwart-e2e catch-all
  (pre-existing, root-caused, fix committed, re-verification launched)
- `nix build .#checks.x86_64-linux.stalwart-e2e` on the committed fix ->
  exit 1, BUT the new log dump captured the real error:
  `upsert Domain: match property \`name\` is missing from the object body`
  (the ordering red herring is retired; see d2)
