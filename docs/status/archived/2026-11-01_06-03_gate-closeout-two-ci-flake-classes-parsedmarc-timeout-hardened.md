# Gate closeout: both gates green, two new CI failure classes, parsedmarc-e2e timeout hardened

**2026-11-01 06:03 CET; continuation session ran ~02:30 -> 06:03 CET.**
Scope: the four b)-residuals of the Ω-execution pass (parent report:
`docs/status/2026-11-01_02-29_omega-execution-13-tasks-landed-a4-scope-split-pending-full-gate.md`,
items f/1-4) - the full gate pair, the CHANGELOG entry, the final
commit + push, and the CI watch. This file reports THIS session only;
the parent report owns the Ω-do-now landing itself.

## a) FULLY DONE

- **Baseline verified** - working tree matched the parent report
  exactly (2 deleted `.a4-*` probe scripts, 5 modified files, the
  untracked probe dir + report); the odd `[ahead 1]` resolved as a
  stale tracking ref (push showed the true range). Four live
  `crush -y` PIDs seen; the one working-tree surprise
  (`scripts/annotate-corridor.py` modified between status checks)
  was investigated BEFORE touching anything and turned out to be
  BuildFlow's own ruff autofix (see d), not a competing session.
- **Full `nix flake check` EXIT 0** (redirect-never-pipe, ~4 min).
  The log's `running 3 flake checks` count line was treated as the
  known noise it is: the live set was verified by
  `nix eval .#checks.x86_64-linux --apply builtins.attrNames` against
  `tests/check-expected.json` - all 12 x86_64 checks present, lockstep
  intact. Run AGAIN EXIT 0 after the parsedmarc-e2e hardening.
- **BuildFlow `--max-time 40m`** - first run EXIT 69 on the
  `dprint-format` step; root-caused (see d) and fixed with a real
  `nix develop -c dprint fmt` pass (9 files), then re-run EXIT 0 with
  **jscpd step GREEN: 0 exact clones across 18 files** - the D5 gate
  evidence the parent session owed. The `d2`/`agents-md` "regression"
  lines are ms-scale timing noise, not failures.
- **BuildFlow's ruff autofix accepted** - mid-gate it converted the
  annotate driver's `%`-formatting to `.format()` (UP031-class, 5
  sites). Judged on merits: complete conversion, semantically inert,
  `--self-test` re-verified green (4 keys, prose refusal,
  verify->apply->check-rows) - kept, not reverted, and now committed.
- **Formatter coverage gap closed for this landing** - the parent
  session's `nix fmt -- . --check` EXIT 0 was alejandra-only (the
  repo's `nix fmt` formats .nix; dprint covers md and runs via
  BuildFlow/the devShell), so the fresh status report and TODO_LIST
  edits had never been dprint-checked. `dprint fmt` reflowed 9 files;
  post-pass damage checks per doctrine: no stray mid-sentence `-`/`+`
  line leads, md pipe lint EXIT 0, and **`annotate check-rows` on both
  formatter-touched live corridors (10-23 full-corridor, 10-30 pass-12)
  = complete** (the strike-form fragility rule held).
- **CHANGELOG `[Unreleased]` Added entry** committed same-call
  (0fa32c4): the whole Ω-execution pass with gates, jscpd evidence,
  new files, exporter hardening, C45 flip, and every truth-up with its
  probe transcript.
- **Final landing commit e09376f** - 15 files: the `.a4-dnsmasq-probe2.py`/
  `.a4-probe3.py` deletions (which had already made origin RED - see
  next bullet), probe transcripts, the status report, all format-pass
  fallout. Pushed `9dc9477..e09376f`.
- **Prior-origin red triaged by STEP name before assuming** - run
  41260720039 (the daemon's 01:21 auto-commit) failed
  `Lint Python files (ruff, fail-closed)`: F821 on the daemon-committed
  `.a4-dnsmasq-probe2.py` sweep artifact. The landing commit deletes
  both files, so the cause was already removed by e09376f.
- **NEW CI failure class #1 diagnosed and recorded** - CI run 1 on
  e09376f died mid store-path copy with GitHub cache-API
  `ResourceExhausted: rate limit exceeded` -> `substituter ... is
  disabled`, every lint/eval step green. `gh run rerun --failed` went
  green (41262497225, 10m). The class is now a one-line AGENTS.md rule
  (infra flake, remedy = rerun).
- **NEW CI failure class #2 root-caused and FIXED** - the dbb4c75
  (docs-only) run failed three times: twice the throttle again, then
  the real signal underneath: **`parsedmarc-e2e` "TLS variant: report
  collected over IMAPS 993" blew its 120 s wait cap** on the
  un-cached, build-saturated runner (the throttle makes the run build
  its closures itself). Same loaded-runner class as the v0.5.0
  `stalwart-bind-e2e` TimeoutStartSec lesson. Fix: all FIVE
  report-arrival `wait_until_succeeds` timeouts 120 s -> 300 s, stale
  in-test rationale replaced, incident recorded at the first site and
  in the CHANGELOG Fixed section. Verified locally BEFORE landing:
  `nix build .#checks.x86_64-linux.parsedmarc-e2e -L` EXIT 0, then the
  full `nix flake check` EXIT 0.
- **Master left verifiably green** - hardened HEAD pushed (2bdc395,
  with the daemon having raced the test file into 9a8dbd5 - both in
  the pushed range), CI run 41265954894 **success** (9m12s, full VM
  E2E). Working tree clean, in sync with origin.
- **Corridor record closed honestly** - the 02-29 report's b)-section
  staleness resolved via a dated completion addendum (h)) including
  the incidents, and now this follow-up report.

## b) PARTIALLY DONE

~~- **Loaded-runner timeout hardening covers parsedmarc-e2e only** - the~~ **→ routed - TODO 'Loaded-runner timeout audit' row (owner question g/3; row added 2026-11-01)**
other e2e tests (relay, deliverability, bind, stalwart-e2e, migrate)
carry their own wait/timeout budgets sized on healthy runners and
were never audited for this class. Evidence-driven fixing is
defensible (two greens today on the same code); a sweep is the
alternative (owner question, g/3).
~~- **TODO_LIST hand-off row not added** - the timeout-audit residual~~ **→ done 2026-11-01 - the TODO hand-off row was added by the docs-health pass**
lives only in this report's f-list; the doctrine says bounded work
gets a TODO_LIST row. One-liner, next docs touch.
~~- **The 02-29 report's h) addendum says the CI verdict "rides its~~ **→ done 2026-11-01 - run id 41265954894 stamped into the 02-29 h) addendum**
push"** - the final green run id (41265954894) is recorded HERE, not
stamped back into that file. Trivial; next docs touch.

## c) NOT STARTED (unchanged from the parent report's c-list)

~~- **O1 the owner sitting** (C42/C44/C39-C41/C46, pbx blessing, D1/D2,~~ **→ routed - sitting sheet + TODO blocked rows (Omega O1)**
Resend key, policy batch, REPORT-RENAME/CADENCE, AGENTS cap,
C36/C37/Q5) - still the 1% gating >51%.
~~- **O3 verdict recording** (O1-gated), **A1** (#552103 webui comment,~~ **→ routed - Omega-plan tasks O3/A1/A2/A5/B1-B3/C1-C10/D1-D4/D10/E4/E5/E8-E14/E17/E18 (owner-gated, their-repo, and backlog lanes)**
owner review), **A2** (#563651 follow-up, owner go), **A5.2-3**
(their push + CI watch + live verify), **B1-B3** (pbx lanes),
**C1-C10** (verdict executions), **D1-D4** (SystemNix/BuildFlow
repos), **D10**, **E4/E5/E8-E14** (backlog/external/standing),
**E17/E18** (rides).
~~- **A4 owner questions still open** (parent g/2-3): keep vs remove the~~ **→ routed - ROADMAP open question 10a/10b (added 2026-11-01)**
labelled dead-end `server = ["10.0.2.3"]` lines; local-only vs
upstream repro for the framework datum.

## d) TOTALLY FUCKED UP

- **Formatter-stack flailing** - three wrong turns before reading the
  actual config: bare `nix fmt` (the documented STDIN trap - wasted a
  cycle), then `nix fmt -- .` which is ALEJANDRA-ONLY (I wrongly
  expected it to apply dprint; devshells.nix says so in one comment
  line I hadn't read), then `dprint fmt CHANGELOG.md` with an explicit
  path (exit 14, plugin-include semantics). `nix develop -c dprint fmt`
  was the correct call all along. The lesson is embarrassing because
  AGENTS.md HAD the pieces; I pattern-matched instead of reading
  devshells.nix/dprint.json first.
- **Asserted anchor uniqueness in a file I'd read 60 lines of** - the
  CHANGELOG is ~1400 lines with many `### Changed` sections; my
  first insert crashed on "anchor not unique". Fix was trivial
  (first-occurrence + assert `[Unreleased]` in head), but the
  assumption was malpractice: grep-count the anchor or read the file.
- **Daemon race caught me despite the warning** - the session summary
  explicitly says the daemon races explicit commits. I applied
  same-call discipline to the CHANGELOG but NOT to the parsedmarc-e2e
  edit made ~10 minutes earlier: the daemon committed the test file
  (9a8dbd5) before my explicit commit, which then swept only 2 of the
  3 files I intended. Outcome fine (both commits pushed in one range),
  but the landing held by luck, not by a `git status` check
  immediately before committing.
- **One wasted CI cycle on the throttle** - after run 2's
  ResourceExhausted failure I reran blind at 7-minute spacing. Run 3
  then failed with a REAL timeout hiding under the same cache noise;
  only then did I grep the full failed log for non-infra errors. The
  doctrine's "read the failing STEP name" should have extended
  immediately to "grep the WHOLE failed log for non-cache errors
  before rerunning" - that discipline is now written into e).

## e) WHAT WE SHOULD IMPROVE

1. **Rerun-triage discipline**: before ANY `gh run rerun`, grep the
   full failed log for non-infra errors (cache/throttle signatures
   mask real test failures - run 3 proved a real one hides under
   them). Candidate for the AGENTS.md CI rule line.
2. **Timeout audit across all e2e tests** for the loaded-runner class
   (one sweep vs per-flake is owner question g/3); the parsedmarc
   incident is the existence proof.
3. **Close the dprint coverage gap**: local `nix fmt` gives false
   confidence for markdown (alejandra-only); either the fmt wrapper
   should run dprint too, or a dprint check belongs in the pre-commit
   path. Repo/BuildFlow lane.
4. **CI-side cache-throttle mitigation** - observed: 5-minute spacing
   worked once, 7-minute did not; the throttle window is not
   respectfully waitable. A workflow-level retry or cache-disable
   fallback would de-flake CI (owner question g/2 - it touches CI cost
   profile and possibly the BuildFlow/system-level doctrine).
5. **Same-call commit discipline applies to EVERYTHING the session
   touched**, not just the file in the current edit - `git status`
   immediately before any explicit commit is the cheap guard.
6. **Python-edit protocol**: grep-count anchors in big files before
   asserting uniqueness (the CHANGELOG lesson).
7. **`nix fmt` naming trap** is documented in AGENTS.md but the
   "alejandra-only, dprint is separate" half is NOT - one clause would
   have saved three wrong turns.
8. **Minor**: the 02-29 report's h) wants the final green run id
   stamped (b-item); the "ahead 1" tracking oddity self-resolved on
   push (stale tracking ref, no action).

## f) NEXT (consolidated: NEW items first, then the parent's still-open list)

~~1. **NEW - TODO_LIST row**: loaded-runner timeout audit across all e2e~~ done 2026-11-01 (TODO row added by the docs-health pass)
tests (b-item; the parsedmarc fix is the template).
~~2. **NEW - owner decision g/2**: CI cache-throttle policy (rerun-only~~ routed: TODO "CI cache-throttle policy" row (added 2026-11-01)
vs workflow mitigation).
~~3. **NEW - owner decision g/3**: timeout-hardening sweep now vs~~ routed: TODO "Loaded-runner timeout audit" row (added 2026-11-01)
evidence-driven per-flake.
~~4. **NEW**: stamp the final green run id (41265954894) into the 02-29~~ done 2026-11-01 (run id 41265954894 stamped into the 02-29 h) addendum; both AGENTS.md clauses added)
report's h) addendum; add the AGENTS.md rerun-triage clause (e/1,
e/7 one-liners).
~~5. **NEW**: dprint coverage gap fix (e/3; repo or BuildFlow lane).~~ routed: TODO "dprint coverage gap" row (added 2026-11-01)
~~6. Carry: **O1 the owner sitting** (~70 min, unblocks >51%).~~ routed: sitting sheet (Omega O1)
~~7. Carry: **O3** verdict recording (decision-batch lines, TODO re-rows,~~ routed: Omega O3 (O1-gated)
sheet ANSWERED prefixes, banner; same-call CHANGELOG).
~~8. Carry: **A1** #552103 webui comment -> owner review -> re-verify at~~ routed: TODO admin-bundle row (Omega A1; owner review)
PR head -> github-voice -> post.
~~9. Carry: **A2** #563651 follow-up (re-verify the host-less~~ routed: TODO upstream-watch row (Omega A2; ON HOLD per owner)
`[opensearch]` shape first).
~~10. Carry: **A3** verify mailsuite's new `starttls` opt-out at the~~ routed: TODO upstream-watch row residual (next mailsuite-advancing bump)
next mailsuite-advancing bump.
~~11. Carry: **A4 depth** (parent g/2): remove the dead-end~~ routed: ROADMAP open question 10a (added 2026-11-01)
`server = ["10.0.2.3"]` lines (config change + full e2e re-run) or
keep labelled (current).
~~12. Carry: **A4 venue** (parent g/3): local-only (current) vs minimal~~ routed: ROADMAP open question 10b (added 2026-11-01)
upstream repro.
~~13. Carry: **A5** when the hub workstream lands: their push -> first~~ routed: TODO EventCatalog row (Omega A5; external workstream)
full-9-source run -> live-verify catalog.home.lan (T8 checklist).
~~14. Carry: **B1** pbx `mkVMOverride` landing (post-blessing) + their~~ routed: TODO pbx row (Omega B1; owner blessing)
full gate.
~~15. Carry: **B2** nix-email CHANGELOG + TODO close + issue #4~~ routed: Omega B2 (B1-gated)
cross-link.
~~16. Carry: **B3** corridor tail closeout (three deferred reports ->~~ routed: Omega B3 (the pbx-deferred three)
archived).
~~ 17-26. Carry: **C1-C10** verdict executions (C42 dmarc-monitor,~~ **→ routed - TODO + sitting-sheet rows (Omega C1-C10, post-sitting verdict executions)**
C44 account-secrets, C39 MemoryMax, C41/C46 recording, policy
batch, REPORT-RENAME/CADENCE, AGENTS cap, qcow2 verdict, Resend
SASL verify, flood posture).
~~ 27-30. Carry: **D1-D4** (SystemNix deliverability wiring, SystemNix~~ **→ routed - TODO SystemNix + BuildFlow rows (Omega D1-D4, their repos)**
CI-debt, BuildFlow upstream batch, BuildFlow binary rebuild +
state-DB purge).
~~17. Carry: **E4** catalog content refresh + publish receipts~~ routed: Omega E4 (A5-gated)
(A5-gated).
~~18. Carry: **E5** report-ingestion test ideas.~~ routed: Omega E5
~~19. Carry: **E8** vulnix replacement once BuildFlow ships a scanner.~~ routed: Omega E8 (external)
~~20. Carry: **E9** OIDC/Pocket ID wiring on the D1 host.~~ routed: Omega E9 (D1-gated)
~~21. Carry: **E10** 0.16-born wrapper options (catch-all + typed~~ routed: Omega E10 (C2-gated)
credentials) incl. the D6 guarded reconcile-retire path.
~~22. Carry: **E11** queue-depth surface + first `queue_rescheduled`~~ routed: Omega E11 (lazy registration now noted in MONITORING row 2)
dashboard/alert row (LAZY registration noted).
~~23. Carry: **E12** parsedmarc against the real 0.16 deployment.~~ routed: Omega E12 (D1-gated)
~~24. Carry: **E13** vandelay-vs-imapsync compare (1.0.12 in-pin).~~ routed: Omega E13 (D1-gated)
~~25. Carry: **E14** rotate the three SystemNix placeholder secrets.~~ routed: Omega E14 (D1-gated)
~~26. Carry: **E16** build the `.#ruff-floor` app or devShell floor path~~ routed: ROADMAP theme 6 E16 parked ideas - instrument CI timing.
~~27. Carry: **E17** pin-advance RIDE at the next stalwart bump (now~~ routed: TODO contacts-probe + rename-watch rows (standing ride)
also watching `stalwart_1_0` on master).
~~28. Carry: **E18** next docs-health pass archives the 10-30 -> 11-01~~ done 2026-11-01: THIS docs-health pass archived the corridor (this report included)
corridor (this report included).
~~29. Carry: scripts/demo-console.sh mechanization (parent e/1).~~ routed: TODO VM/debug tooling batch row (2026-11-01)
~~30. Carry: CONTRIBUTING test-driver errexit rule + vm-debug /tmp guard~~ done 2026-11-01 (errexit rule landed in CONTRIBUTING) + routed: TODO VM/debug tooling batch (the /tmp guard half)
(parent e/2-3).
~~31. Carry: check in the demo smoke probe script (parent e/10).~~ routed: TODO VM/debug tooling batch row
~~32. Carry: MONITORING row-2 `queue_rescheduled` lazy-registration note~~ done 2026-11-01 (lazy-registration note added to MONITORING row 2)
(parent f/48).
~~33. Carry: TELEMETRY.md 0.15-era compression pass (parent f/49).~~ routed: TODO TELEMETRY-compression row (2026-11-01)
~~34. Carry: BuildFlow skill note "jscpd honors its native~~ routed: TODO BuildFlow row (skill-note clause appended 2026-11-01)
`.jscpd.json`" (parent f/50, their repo).
~~35. Carry: background-job self-timeout defaults (parent e/4).~~ routed: the mechanizable half rides the TODO VM/debug tooling row (hard timeouts in demo-console); the rest is session discipline
~~36. Carry: Ω-plan auto-absorb of fresh discoveries (parent e/6).~~ routed: standing practice - the Omega-plan coverage appendix + TODO watch rows absorbed the discoveries (stalwart_1_0 watch, lazy queue series)

## g) QUESTIONS FOR THE OWNER

~~1. **When will you hold the O1 sitting?** (unchanged - it still gates~~ routed: owner - the sitting sheet (standing)

> 51% of everything in c).)
> ~~2. **CI cache-throttle policy**: today's pattern was fail -> manual~~ routed: TODO "CI cache-throttle policy" row (added 2026-11-01)
> `gh run rerun --failed` -> green (3 of 5 runs today needed it, and
> the throttle's second-order effect caused the one REAL failure).
> Want a workflow-level mitigation (retry step, or cache-disable
> fallback that eats a slower cold build), or is manual rerun
> acceptable for a solo-maintainer repo?
> ~~3. **Timeout-hardening policy**: harden ALL e2e wait budgets to the~~ routed: TODO "Loaded-runner timeout audit" row (added 2026-11-01)
> parsedmarc 300 s template in one sweep (one full-gate cost, class
> closed), or fix per real flake as observed (evidence-driven, but
> each flake costs a CI cycle + triage)?
