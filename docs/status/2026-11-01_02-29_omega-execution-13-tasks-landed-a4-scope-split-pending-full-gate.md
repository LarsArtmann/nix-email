# Ω-execution status: 13 do-now tasks landed, A4 scope split settled, gates partially run

**2026-11-01 02:29 CET, session ran 03:49 CET 10-31 -> 02:29 CET 11-01.**
Scope: the Ω-generation plan (`docs/planning/2026-10-31_00-38_*`) minus
owner-gated/their-repo lanes. Start state: clean `ca344ec`, origin CI
GREEN (run 41146208130). This file reports THAT session only.

## a) FULLY DONE

- **O2 verified already green** - baseline confirmed origin CI success on
  HEAD before any edit; no push was owed from this session (it happened
  in the prior one).
- **D9 upstream watch re-date** - all four nixpkgs items re-checked LIVE
  via `gh`: #552103 OPEN, head UNCHANGED at `9b15e1f` (the A1 draft's
  verified base holds), #563651/#563652/#563777 open/silent as recorded.
  **mailsuite#65 CLOSED COMPLETED 2026-10-27, fixed by their PR #67**
  (`feat/imap-starttls-opt-out`, releases 2.3.3/2.3.4) - the ~11-05
  nudge (plan A3) is MOOT; residual = verify their new `starttls`
  opt-out at the next mailsuite-advancing bump. Rename watch: master
  still ships single-file `stalwart.nix` (no collision) AND now also
  packages `stalwart_1_0` (future bump target, owner decision).
  TODO_LIST watch row re-dated; stale "blocked on gh auth" claims
  truthed in two rows.
- **D5 jscpd decision** - discovered jscpd HONORS its own native
  `.jscpd.json` even though BuildFlow's global `exclude:` is invisible
  to it: committed `.jscpd.json` (`ignore: ["**/docs/probes/**"]`),
  UN-SKIPPED the step in `.buildflow.yml`, verified live (11 clones ->
  0, all 11 were frozen probe evidence; maintained surface still
  scanned). Net quality gain, not a weakening.
- **D6 reconcile-destroy** - pattern + one-shot scoped remedy documented
  beside the `relay` option (mail-server.nix header + option
  description). Guarded automated path EVALUATED: mechanism sound when
  the reconciled set is scope-pinned (`scope.name = routeId`) + the
  stale strategy singleton gets a default-shape update; NOT implemented
  (public option surface + behavior change wanting its own VM proof) -
  rides E10. TODO row closed DONE.
- **D7 README line-by-line (F6)** - every section re-verified against
  code/pin. Fixed: parsedmarc version (11.0.2 in the dmarc-monitor
  docs), **vandelay IS in the pin (1.0.12, eval-verified - the old
  "not in nixpkgs" note was dead)**, C43 answered/v0.5.0 shipped
  sentence, C45 ADR status, junk-filing "pending" note retired (the
  e2e GTUBE subtest IS the re-verification - INBOX-select probe green
  on both 0.16 versions), 0.15-era SSE verdict replaced with the
  2026-10-26 probe facts, mailsuite bullet updated, gh-auth staleness.
  Dated D7 verdict banner added to the STATUS block. F6 CLOSED.
- **D8 TELEMETRY re-verify** - fresh `stalwart-e2e` rebuild
  (`--rebuild`, EXIT 0): 37-series HELP set on 0.16.26, set-identical
  to the 0.16.22 transcription (`queue_rescheduled` is LAZILY
  REGISTERED - appears only after a real deferral, consistent with the
  relay-e2e amendment). Binary `strings` over the pinned 0.16.26:
  whole telemetry object model present; webhook/alert fields moved to
  camelCase (`signatureKey`, `discardAfter`, ...; kebab tokens GONE).
  TELEMETRY.md standing caveat RETIRED, dated verdict banner written.
  Rode the same session: **fresh 0.16.26 demo-VM smoke** (anon JMAP
  session shape, AUTH submission -> IMAPS round-trip, catch-all
  SMTP-accept + strict 550 outside the domain) - transcript
  `docs/probes/2026-10-31-demo-smoke-01626/`; the README's "fresh 0.16
  smoke is a TODO_LIST row" caveat retired.
- **E6 DOMAIN_LANGUAGE.md** - first draft shipped (6 bounded contexts:
  wrapper/fleet, plan dialect, outbound, inbound, DMARC, store
  lifecycle), linked from README Development. ROADMAP bullet flipped.
- **E7 arch-diagram audit** - both `.d2` sources re-baselined to the
  0.16.26 surface (provision node, dual declarative DKIM,
  MtaRoute/MtaOutboundStrategy vocabulary in the target diagram, the
  deliverability probe, opt-in limiter, metrics singleton); SVGs
  re-rendered with the pinned `--layout=elk` command; README inline d2
  synced. v2 verdict: TEST-level concern, correctly absent from runtime
  diagrams. ROADMAP bullet flipped.
- **E1 annotate driver** - `scripts/annotate-corridor.py` shipped:
  line-number verdict map -> emit-keys -> spec.tsv -> `--verify` ->
  apply -> check-rows, with the stream-sync len assert BEFORE zip,
  prose-line refusal with the manual house-grammar recipe, `--self-test`
  green. Ruff floor clean. CONTRIBUTING pointer added. (The
  continuation-row strictness proposal upstream stays parked - needs a
  docs-health-repo session.)
- **E3 exporter hardening** - selftest now asserts absolute body-link
  URLs (kills the REPO_BASE class), `--plain` byte-parity, EXACT
  frontmatter line shapes, ADR cross-links in-tree; `--check` drift
  mode shipped and verified BOTH ways (clean pass + tamper detection
  exit 1). Also this pass: **C45's ADR flipped `proposed` -> `superseded`**
  (resolved by events 2026-10-28, not by an owner call) with an honest
  Decision section; selftest green after.
- **E15 non-goals pass** - all seven stands re-proven (listener
  contract 25/465/587/993 grep-verified), nothing overtaken; dated
  confirmation line added.
- **E16 parked ideas** - measured (warm `nix run` 0.14 s vs CI-cold
  ~13 s: fresh-runner eval + download, not nix being slow); ideas +
  cheapest-first order (flake app pin / devShell reuse / instrument
  first) and the vm-debug `--script-only`/`--check` designs recorded in
  ROADMAP theme 6.
- **A4 dnsmasq scope split** - the X12.2 question SETTLED by transcript
  (`docs/probes/2026-10-31-dnsmasq-forward/`, three vm-debug runs +
  the demo FIFO console): in the multi-node test-driver net the node
  has NO user-net NIC at all (no default route), so 10.0.2.3 is
  INSTANTLY unreachable (dig exit 9 in ~58 ms), dnsmasq REFUSES
  non-local, getent fails exit 2 - relay-e2e's green rides its LOCAL
  zone and is safe only because SpamPyzor is explicitly disabled; in
  the single-VM demo, 10.0.2.3 is LIVE (getent exit 0). Both test
  headers now say the truth (deliverability-e2e's own inline comment
  already knew the exit-9 lesson - its header contradicted it).
  Venue: LOCAL note only, no upstream filing (framework-by-design, no
  measured victim beyond our stale comments). AGENTS.md got the
  one-line durable rule.
- **A5 watch** - read-only: hub master ahead 14, unpushed, the
  demo-flag workstream is mid-flight in its own session; the push
  stays theirs. Watch verdict recorded in the plan row.
- **Ω-plan verdict annotations** - all eleven do-now L1 rows carry
  dated DONE verdicts in the plan file; coverage appendix unchanged.

## b) PARTIALLY DONE

- **Gates**: `nix fmt -- . --check` EXIT 0; md table-pipe lint EXIT 0;
  ruff floor clean on every working-tree script (the sweep's 2 errors
  are phantom index entries of the already-deleted probe scripts - they
  vanish with the final commit); exporter selftest + annotate
  self-test green. **NOT yet run: the FULL `nix flake check` (mandatory
  - the two test-file comment changes alter the test derivations) and
    `buildflow` (mandatory - the jscpd un-skip needs its gate evidence).**
- **CHANGELOG [Unreleased] entry** - not yet written (same-call commit
  discipline pending); final commit + push + CI watch pending.
- **A3 residual** - upstream fixed the issue; verifying their new
  `starttls` opt-out satisfies parsedmarc is parked to the next
  mailsuite-advancing bump.
- **E1.2 upstream half** - the check-rows continuation-row strictness
  proposal (docs-health repo) parked; the repo-side driver + note are
  done.
- **E3 ADR-id sync check** - parked: needs a decision-id source of
  truth outside the exporter.
- **D9 stale-arrow hygiene in the kept-live reports** - the 12-17 /
  14-19 reports still carry open arrows that only B3's closeout may
  convert (deliberate: archive-time work).

## c) NOT STARTED (unchanged gates, no work attempted this session)

- **O1 the owner sitting** (C42/C44/C39-C41/C46, pbx blessing, D1/D2,
  Resend key, policy batch, REPORT-RENAME/CADENCE, AGENTS cap,
  C36/C37/Q5) - the 1% that gates >51%.
- **O3 verdict recording** (O1-gated), **A1** (#552103 webui comment -
  owner review), **A2** (#563651 follow-up - owner go), **A5.2-3**
  (their push + CI watch + live verify - external workstream),
  **B1-B3** (pbx blessing -> landing -> corridor tail),
  **C1-C10** (all verdict executions), **D1-D4** (SystemNix/BuildFlow
  lanes, their repos), **D10** (O1-gated prep pack),
  **E4/E5/E8-E14** (backlog/external/standing), **E17/E18** (rides).

## d) TOTALLY FUCKED UP

- **The demo FIFO console job hung for hours**: my driver script
  connected the fifo to NOTHING (`run-demo-vm > log` without the
  recipe's `cat in |`), then killed the wrapper PID while QEMU
  survived as an orphan holding the demo disk lock. Fixed by killing
  the orphan, re-reading CONTRIBUTING's exact recipe, and re-running
  with a hard `timeout` + belt-and-braces `pkill`. The transcript then
  landed in one clean pass. Lesson: the CONTRIBUTING recipe is exact -
  `cat in | run-demo-vm > log` - and every ad-hoc VM driver script
  needs a global timeout.
- **/tmp was swept mid-session twice**: the v1 driver log and the
  probe script vanished between runs (one run failed with
  FileNotFoundError on the script path). The v1 numbers survive via the
  session record and are superseded by v2/v3; raw v2/v3 logs + the
  demo console capture are persisted in the probe dir. Lesson:
  transcripts get copied into `docs/probes/` IMMEDIATELY, not at the
  end.
- **Probe-design flaw v1/v2**: the test driver runs succeed-compounds
  with errexit - `cmd; echo RC:$?` NEVER captures cmd's failure (the
  compound aborts at cmd). v1's assert even killed the script before
  LEG3/LEG4. v3 worked around it (`|| true`-style capture via files,
  timeout guards) - and the driver's errexit datum itself (exit 9 /
  exit 2 surfacing as the compound's code) became part of the
  transcript.

## e) WHAT WE SHOULD IMPROVE

1. Mechanize the demo FIFO console like vm-debug (`scripts/demo-console.sh`)
   - the recipe is one wrong redirection away from a hang.
2. Document the test-driver errexit-compound semantics in CONTRIBUTING's
   VM debug rules - it silently eats `cmd; echo RC:$?` capture patterns.
3. vm-debug.sh should refuse `/tmp` script paths or copy them into its
   out-dir (the /tmp sweep broke a run).
4. Background jobs need self-timeouts by default (job 185 had none).
5. The A4 estimate was 45 m; reality ~2 h across three VM runs - price
   VM-probe tasks at 3 runs minimum.
6. The Ω-plan's "50 next things" should auto-absorb fresh discoveries
   (stalwart_1_0 watch, lazy queue series) - they currently live in
   ROADMAP/AGENTS only.
7. jscpd's native-config discovery is BuildFlow-relevant (their repo):
   "jscpd honors `.jscpd.json` even when `exclude:` is inert" deserves
   a fleet-wide note in the BuildFlow skill.
8. A4's venue call (local-only) was mine - if the owner wants the
   framework datum filed upstream, verify-before-filing needs a clean
   minimal repro against a stock nixpkgs test (cheap to produce).
9. TELEMETRY.md's 0.15-era sections could be compressed now that the
   caveat is retired (history stays, but the "right way" baseline is
   0.16-shaped).
10. The demo smoke script should become a checked-in probe script
    (docs/probes/.../probe.py) so the next smoke is one command.

## f) NEXT (prioritized, ~50)

1. Run the FULL `nix flake check` (redirect, never pipe; ~4-6 min).
2. Run `buildflow --max-time 40m` (never concurrent with the flake gate).
3. Write the CHANGELOG [Unreleased] entry - edit + commit in the SAME
   tool call (daemon races it).
4. Final commit (incl. the probe-script deletions), push, watch origin
   CI by STEP name.
5. **O1 - THE OWNER SITTING** (~70 min; unblocks >51% of everything).
6. O3 record verdicts (decision-batch + TODO re-rows + sheet ANSWERED
   prefixes + banner).
7. A1: #552103 webui comment -> owner review -> re-verify at PR head ->
   github-voice -> post + record id.
8. A2: #563651 follow-up (owner go; re-verify the host-less
   `[opensearch]` shape first).
9. A3: at the next mailsuite-advancing bump, verify their `starttls`
   opt-out satisfies parsedmarc.
10. A5: when the hub workstream lands - their push -> first full-9-source
    run -> live-verify catalog.home.lan (T8 checklist).
11. B1: pbx `mkVMOverride` landing (post-blessing) + their full gate.
12. B2: nix-email CHANGELOG + TODO close + issue #4 cross-link.
13. B3: corridor tail closeout (three deferred reports -> archived).
14. C1: C42 execution (dmarc-monitor retire or keep).
15. C2: C44 execution (account-secrets doctrine).
16. C3: C39 MemoryMax landing. 17. C4: C41/C46 recording.
17. C5: policy executions (branch protection, Renovate, Discussions).
18. C6: REPORT-RENAME + REPORT-CADENCE encoding.
19. C7: AGENTS cap resolution (accept-as-floor or the 220 trim).
20. C8: qcow2 purge-or-accept verdict.
21. C9: Resend SASL verify + real smoke (proves `relay.secretFile`).
22. C10: flood posture execution.
23. D1: SystemNix deliverability wiring (their repo).
24. D2: SystemNix CI-debt lanes. 26. D3: BuildFlow upstream batch.
25. D4: BuildFlow binary rebuild + state-DB purge.
26. D5-follow-up: confirm the jscpd step green in the buildflow run
    (this session's gate evidence pending).
27. D7-follow-up: the parked exporter ADR-id sync source-of-truth.
28. E1.2: the check-rows continuation-row strictness proposal upstream
    (docs-health repo session).
29. E2: sheet ANSWERED prefixes + arrow-freshness rule + ID diff script
    decision (O1-adjacent).
30. E4: catalog content refresh + publish receipts (A5-gated).
31. E5: report-ingestion test ideas (traced-verbosity ARF, subtests).
32. E8: vulnix replacement once BuildFlow ships a scanner.
33. E9: OIDC/Pocket ID wiring on the D1 host.
34. E10: 0.16-born wrapper options (catch-all + typed credentials) -
    now also carries the D6 guarded reconcile-retire path as a designed
    candidate.
35. E11: queue-depth surface re-verify + first `queue_rescheduled`
    dashboard/alert row (note its LAZY registration when writing rules).
36. E12: parsedmarc against the real 0.16 deployment (SystemNix).
37. E13: vandelay-vs-imapsync compare on scratch mailboxes (vandelay
    1.0.12 is IN the pin - no source build).
38. E14: rotate the three SystemNix placeholder secrets.
39. E15-follow-up: none owed (clean pass).
40. E16 execution: actually build the `.#ruff-floor` app or the devShell
    floor path + instrument CI timing.
41. E17: pin-advance RIDE (module diff, contacts probe, rename watch,
    delta table) at the next stalwart bump - now watching
    `stalwart_1_0`'s appearance on master.
42. E18: next docs-health pass archives the 10-30/11-01 corridor.
43. scripts/demo-console.sh mechanization (e/1).
44. CONTRIBUTING: the test-driver errexit rule (e/2) + vm-debug /tmp
    guard (e/3).
45. Check in the demo smoke probe script (e/10) + re-run the smoke
    after the next demo-affecting change.
46. MONITORING row 2: add the queue_rescheduled lazy-registration note
    (series absent until a deferral happened).
47. TELEMETRY.md 0.15-era compression pass (e/9, low priority).
48. BuildFlow skill note: "jscpd honors its native `.jscpd.json` even
    when `exclude:` is inert" (e/7, their repo).

## g) QUESTIONS FOR THE OWNER

1. **When will you hold the O1 sitting?** It gates >51% of the plan
   (C42/C44/C39-C41/C46, pbx blessing, D1/D2, Resend key, the policy
   batch, REPORT-RENAME/CADENCE, AGENTS cap, C36/C37/Q5); everything in
   c) is waiting on it.
2. **A4 cleanup depth**: now that both test headers call
   `server = ["10.0.2.3"]` a dead end, do you want the lines REMOVED
   entirely (config change + full e2e re-run to prove dnsmasq behaves
   with zero upstreams), or kept as labelled dead ends (current state)?
3. **A4 venue**: keep the framework datum local-only (current call), or
   should I prepare a minimal upstream repro (stock two-node nixpkgs VM
   test querying 10.0.2.3) for a nixpkgs/discourse note?

## h) COMPLETION ADDENDUM (2026-11-01 03:04 CET, same-corridor continuation)

The b)-residuals are DONE: full `nix flake check` EXIT 0 (12-check
x86_64 set, attrNames-verified against tests/check-expected.json),
`buildflow` EXIT 0 with the jscpd step GREEN (0 clones - the D5 gate
evidence), the CHANGELOG entry committed same-call (0fa32c4), landing
commit e09376f (sweeps the .a4 probe-script deletions, the probe
transcripts, and this report), pushed, origin CI GREEN (run
41262497225, 10m). Incidents en route, all mechanized: BuildFlow's own
ruff autofix converted the annotate driver's %-formatting to
.format() mid-gate (self-test re-verified green, kept); a 9-file
dprint pass over never-before-dprint-checked prose re-verified both
live-corridor check-rows after; and the FIRST CI run failed on a NEW
infra class - the cache-action substituter died with GitHub
`ResourceExhausted: rate limit exceeded` mid store-path copy (every
lint/eval step green), and `gh run rerun --failed` went green.
