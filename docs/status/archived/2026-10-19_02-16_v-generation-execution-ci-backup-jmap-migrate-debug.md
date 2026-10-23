# V-generation execution: CI credibility, 0.16 backup story, JMAP re-verify, and the migrate-e2e debug arc

> STATUS REPORT 2026-10-19 02:16 CEST. Session scope: execution of the
> 2026-10-18 V-generation plan (`docs/planning/2026-10-18_22-20_SUPERB-pareto-v-generation-backlog-burn.md`),
> started ~22:20 2026-10-18. Everything below is THIS session's work only.
> Working tree at report time: CLEAN (auto-commit daemon committed
> everything, HEAD `7ed89bb`). One background VM run was killed by an
> interrupted tool call (see d/1).

## a) FULLY DONE (verified this session)

1. **V3 CI-credibility batch — COMPLETE, CI-verified.**
   - V3.2: pushed head `90c72ad` CI green (run 39163219090).
   - V3.3: evidence gathered — ci.yml had ZERO python linting (only a
     comment matched). The 10-18 ruff-red class shipped silently by
     construction.
   - V3.4/V3.5: fail-closed ruff step added to ci.yml (locked-rev
     nixpkgs ruff, `--select E4,E7,E9,F` version-drift-proof floor,
     negative self-test with an unused-import fixture, SC2016 handling
     mirroring the house pattern), dry-run locally, actionlint+shellcheck
     clean, committed `bc24227`, pushed, **CI green with the step live**
     (run 39164927867). BuildFlow keeps owning the deeper PERF/FURB/BLE
     classes (5 findings open there vs 0 on the CI floor — scoped in the
     TODO row).
   - V3.6 EXE001 root cause: **creator-mode gap, not a stripper** — both
     scripts were created `100644` (transcript: `:000000 100644 ... A` in
     `d0c991e`/`f9ab833`); the exec bit landed in `7ef98a4` and survived
     every later daemon commit (`100755 100755`). Invocation is
     interpreter-explicit in Nix anyway; the bits are for human `./script`
     runs. TODO row closed.
2. **V6 0.16 backup story — VM-PROVEN on the pin (0.16.22), all legs.**
   One fresh demo-VM boot, FIFO console; transcripts + reproducible host
   scripts archived under `docs/probes/2026-10-18-demo-smoke-backup/`:
   - offline stop + `cp -a` + restart → mail intact (INBOX=2/Junk=1);
   - `stalwart-cli snapshot` (config-only): referential closure enforced
     (Domain→Directory→DnsServer→AcmeProvider→Tenant; cycles need
     `--allow-unresolved PublicKey,Role`), password secrets STRIPPED by
     default (`--include-secrets` opts in);
   - MAIN-binary `stalwart --export/--import <dir>` EXISTS on 0.16.22
     (C45 docs-discrepancy settled: 20 `subspace_*` files; import demands
     a NEVER-STARTED wiped store — upstream refuses "already contains
     data in the key ranges");
   - full restore drill: import + `touch v016-store-migrated` (OUR store
     guard refuses a markerless imported store — its own escape-hatch
     message is the procedure) → 5 listeners back, logins, mail counts,
     post-restore delivery;
   - Vandelay NOT in the pinned nixpkgs (eval-verified).
     Docs: README go-live backup step REWRITTEN from the verified
     procedure (replacing the wrong "no export in 0.16" claim), FEATURES
     backup row updated, CHANGELOG entries, doctrine-note irony corrected.
3. **V11 demo smoke — PRODUCT BUG FOUND AND FIXED.**
   - Layered probes green: guest services; guest loopback (JMAP session
     200 as demo user AND admin); HOST forwards (18080 SPA 200, 2525/2587
     SMTP banners, 2593 TLS 1.3 + IMAP `Authentication successful`).
   - **Demo boot race**: fresh boot provision apply failed at the reload
     op ("no nameservers found in config" — apply beat resolvconf), the
     apply script aborted BEFORE its restart step, stalwart kept the
     built-in listener set (no 587/465), quickstart contract broken.
     FIX: demo pins `DnsResolver."@type" = "Cloudflare"` (the e2e
     pattern). VERIFIED on a fresh rebuilt boot: provision
     Result=success, all 5 listeners bound.
   - Demo banner's "unauthenticated inbound lands in Junk Mail" was
     wrong for 0.16 (score-based: both INBOX and Junk landings observed)
     — banner now says "may land".
   - 0.16 rejects single-label EHLO (`550 5.5.0 Invalid EHLO domain.`)
     — probe recipes need explicit FQDN `--ehlo`.
   - New TODO row: module-level provision-vs-resolv.conf ordering
     question for real late-DNS hosts (deliberately NOT a blind unit
     reorder).
4. **V18 JMAP anti-rot probes (0.16 re-verification).**
   - EventSource: stream opens 200; delivery at t+7.65 s pushes
     `event: state` / `StateChange` with Email/Mailbox/Thread/
     EmailDelivery states; **`closeafter=no` ACCEPTED on 0.16 (the
     0.15.5 `400 Invalid parameters` quirk is GONE; `ping` unprobed)**;
     no ping frames in a 40 s window; connection stays open.
   - Junk-filing automation path (the InboxClean contract):
     `Email/set` mailboxIds move works (`updated: {"eaaaaab": null}`,
     Junk=1/Inbox=2, state saq→sau); Mailbox/query role filters work.
   - Session shape deltas recorded: accountId `c`, NO
     `urn:ietf:params:jmap:core` in primaryAccounts, new
     `urn:stalwart:jmap` + `emailpush` capabilities.
   - `docs/INBOXCLEAN.md` rewritten head: 0.16 RE-VERIFIED banner with
     all deltas; 0.15 sections era-marked.
5. **V7 C42 evidence + record.** Fresh fetch of
   stalw.art /docs/mta/reports/ + /analysis/ + ref pages: failure
   reports (DKIM/SPF/DMARC) AND ARF are auto-analysed inbound; exact
   settings documented (`inboundReportAddresses` incl. wildcard-map
   shape, `inboundReportForwarding`, `inboundReportMaxSize` 25 MB,
   `holdMtaReportsFor` 30 d). decision-batch C42 updated (verdict stays
   owner-gated as [rec]; remaining gap = one runtime ARF e2e probe,
   parked as test-polish).
6. **V9 match-property audit + eval lint → NEW CHECK `provision-plan-eval` (GREEN).**
   Pure-eval, arch-independent: hostname == provisioned Domain name
   (V9.4); reconcile sets MUST carry match; no-match sets only on the
   documented implicit-key allowlist (Domain/MtaRoute/AcmeProvider);
   Account sets match `["name"]`; NetworkListener fallback port set pin
   (25/587/465/993/httpBind); SystemSettings coherence; systemd Exec*
   multi-line lint (V10.2); MtaInboundThrottle description identity.
   Registered in ALL THREE guard sites (checks.nix + both ci.yml lists +
   check-inventory.sh incl. the aarch64 shape). dkim-survival subtest
   added to stalwart-e2e (post-catch-all-patch dual signatures — uses
   the transcript-proven probe patterns; the e2e has NOT been re-run
   since, see b/2).
7. **V13 AGENTS.md diet: 451 → 229 lines (-49%).** Every distinct
   concept either compressed in place or pointed at its owning doc
   (demo ports → README quickstart; archive policy → archived/README —
   verified the "user-gated counts as routed" rule lives there;
   flake-structure mechanism comments → flake.nix/checks.nix). Stale
   bits refreshed (demo smoke no longer "pending"; DnsResolver pin
   noted; provision-plan-eval referenced). Pipes-lint clean. The last 9
   lines vs the 220 cap are C41's call.
8. **V14 THREAT_MODEL 0.16 revisit.** New "0.16 exposure delta" section:
   REST removal shrinks; provision-plan secrets in the world-readable
   store GROW (C44-pending note; real hosts must not ship passwords in
   plans until C44); migration artifacts + `--include-secrets` outputs
   are secrets-on-disk; MemoryMax = C39 pending. Fixed the now-FALSE
   "Secrets prevented by construction" row (split verdict); spam row
   re-scored ("Scored; filing varies" — today's VM observation); catch-all
   row 0.16-ized (`Domain.catchAllAddress`). SECURITY.md cross-checked
   (v0.4.0 = accurate; bumps with v0.5.0).
9. **V15 0.16.22→0.16.26 delta table in README** (C45 decision input,
   fetched from the upstream CHANGELOG): 0.16.23 adds `bit_and` (the
   exact function 0.16.22's broken default DNSBL rows reference);
   0.16.24 rule updates are insert-only (second argument for our
   reconcile posture) + JMAP push VAPID fix; 0.16.25 DNSBL scoring/negTTL
   - global-queue-quota-never-enforced; 0.16.26 **BREAKING x86-64-v2 CPU
     requirement** (+ `sd_notify` — touches the vendored module's
     "no systemd notify" comment) — any 0.16.26 overlay ALSO needs a VM
     cpu-type change before our gate can boot it. No CVEs in the window.
10. **V19 0.15-only reference sweep.** All living docs grepped; only ONE
    stale hit (README status banner's "backup GONE" claim) — fixed with
    the corrected 0.16 fact; everything else already era-marked.
11. **V21 docs-truth residue.** `.config/metadata.yaml` (tool artifact
    the daemon had committed; referenced nowhere) untracked +
    gitignored; 19-23 strike-marker reconcile MOOT (plan is archived; no
    living doc restates the ~350 claim — rows deleted); CHANGELOG
    theme-coverage audit vs 156 commits since 10-05 (25 non-daemon
    commits all map to `[Unreleased]` entries; no missing major theme);
    correction note added to `[Unreleased]` (the 06-58 b/6 overstatement).
12. **V26 repo hygiene.** Stale `result-1`/`result-2` trashed; old debug
    GC roots already gone; session GC root dropped after use; **demo
    disk CWD footgun FIXED**: the `apps.vm` wrapper now pins
    `NIX_DISK_IMAGE` to `~/.cache/nix-email-demo/demo.qcow2` (HOME-unset
    fallback preserved), README quickstart + AGENTS updated (no more
    "run from a scratch dir").
13. **V25.3 host-parse-fixture flake app** added (`apps.host-parse-fixture`,
    x86_64; evals as `app`). NOT yet dry-run end-to-end.
14. Housekeeping: everything dprint-formatted + pipes-linted after each
    docs batch; `nix fmt` clean at each pause; the interrupted edit was
    recovered (file state verified, app evals).

## b) PARTIALLY DONE

~~1. **V8 migrate-e2e two-node redesign — WRITTEN, REGISTERED, 6/7 of the~~ done — fixed + green 9/9 next day (W1, runs 6-10; three stacked root causes)
way, ONE REAL PRODUCT BUG OPEN.** Design: mig015 (0.15.5 raw module)
seeds domain+principal via the REST API; the store travels as a TAR
through the framework's writable `/tmp/shared` virtfs dir; mig016
(consumer shape, httpBind 8082) swaps its store, trips the guard,
simulates poison, runs `--backup-dir` migration, re-applies
provision, asserts the 0.15 password authenticates on 0.16 + restart
persistence. Registered in all THREE guard sites. Debug arc (each
run ~5-7 min, diagnosis from transcripts):

- run 1: custom virtfs share was read-only → framework's `/tmp/shared`;
- run 2: `cp -a` over virtfs fails chown → tar relay both ways;
- run 3: `wait_for_unit` races a completed oneshot ("inactive") →
  house pattern (stalwart.service + port + `Result=success`);
- run 4: nested-double-quote python syntax error → single-quoted
  strings;
- run 5: post-migration provision TIMEOUT — the test's 0.15 node had
  ONLY the 18098 api listener, so the converted store bound no 8080
  and provision's probe (cfg.url, then built-in 8080) could never
  reach the server → 0.15 node made REALISTIC (webadmin listener on
  8080 added; README caveat written for exotic-bind hosts);
- run 6: **subtests 1-6 ALL PASS (phase A, handoff, baseline,
  guard-refusal, poison-refusal, --backup-dir migration, marker) —
  then the post-migration NORMAL boot PANICS exit-101 "Migration
  aborted: Upgrading to version 0.16 is a multi-step process"**.
  The script's recovery-mode apply ran clean (`Done: 0 destroyed, 4
     updated, 2 created (0 failed)`) but did NOT complete the binary's
  store migration on the LIVE store. Upstream `UPGRADING/v0_16.md`
  fetched in full: recovery mode itself is supposed to detect old
  data, wipe incompatible subspaces, and come up on 8080. Prime
  suspect: convert's `config.json` datastore path (which store did
  recovery actually wipe?) or the poisoned-settings interaction.
  Run 7 (instrumented: dump `migration-v016/config.json` +
  `recovery.log` + dir listings) was killed by an interrupted tool
  call — it never executed (0-byte log).

2. **V16 flood/bounce/polish — not started**; the stalwart-e2e file now **→ TODO_LIST rows (bounce-path, runtime trim, ping probe; flood watch)**
   carries the untested dkim-survival subtest.
   ~~3. **V12 MONITORING — blocked on a fresh metrics dump**: the demo has~~ done — W7 landed 2026-10-19 (37-series inventory + NO-GAUGE verdict)
   metrics off by design; the series names must come from the (final
   gate) stalwart-e2e log's `/metrics/prometheus` dump (the subtest
   prints it for exactly this purpose). The queue-depth row is
   0.15.5-era ("no gauge") and needs the 0.16 answer.
   ~~4. **V10 remainder**: gate-log "running N flake checks" 4-vs-7~~ done — count line attributed buildflow-emitted (2026-10-19); lockstep landed (X9)
   reconciliation not done; lockstep guard exists (check-inventory hook,
   extended via the new registrations).
3. **V23 BuildFlow noise**: binary rebuild still deliberately blocked **→ TODO_LIST BuildFlow row (rebuild + count gaps)**
   (concurrent session owns that checkout); count-gap reproduction was
   session-1 work; no issues filed in their repo yet this session.
   ~~6. **TODO_LIST harvest**: partially done inline (rows closed/deleted as~~ done (docs-health pass 2026-10-23)
   work completed: backup story, EXE001, CI python-lint, 19-23 moot,
   content-diff; new rows added: module-level DNS race). A final
   end-of-session harvest pass is still owed.

## c) NOT STARTED

- **V4** release prep (CHANGELOG date/link pass, gates-green proof on **→ TODO_LIST v0.5.0 row (C43-gated)**
  the release tree, scratch-tag dry-run; the REAL tag stays C43-gated).
- **V5** SystemNix pin advance (needs v0.5.0). **→ TODO_LIST (blocked on v0.5.0)**
  ~~- **V17** dmarc-eval hardening + IFD cleanup.~~ done — W9 (drop-detectors + negative self-test + IFD cleanup, 2026-10-19)
  ~~- **V20** guard-tooling batch (pipes argless mode, prose-wrap lint,~~ done — W11 (list-marker lint, drift alarm, README completeness, nix-health, pre-push parity)
  check-set drift alarm, demo ports single-source, check-inventory CI
  twin, nix bisect helper).
  ~~- **V22** upstream evidence filings (#552103 comment, dnsmasq note,~~ done — #552103 comment filed (W12.2, 6258512488); dnsmasq + T13b routed to the TODO filings row
  dprint T13b).
- **V24** SystemNix CI debt (their repo). **→ TODO_LIST SystemNix CI-debt row**
- **V25 remainder**: convert-smoke fixture for migrate_v016.py (0.15 **→ convert-smoke/debug-driver/apps.vm/fixture-dedup done (W10, X16); TLS-node open (TODO row)**
  dump fixture → convert → plan diff), TLS-node coverage, debug-driver
  script pin, apps.vm store-closure eval guard, fixture-dedup decision.
- **V27** D1 enablement slice (owner-gated: secrets rotation, live **→ TODO_LIST D1-gated rows**
  dmarc poll, alert-channel encoding, canary skeleton).
- **V1/V2 owner sittings** (all of C39-C46 + ratifications + D1/D2 + **→ decision-batch sittings (open)**
  Resend key + CI bandit/vulture scope doctrine) — untouched, still the
  top gates on the plan.
  ~~- **The FULL GATE has not run since the check-set grew to 9** (demo-eval~~ done — first full gate green 2026-10-19 (W2); set now 11 checks, origin green 2026-10-22
  ran green earlier; provision-plan-eval green; the edited stalwart-e2e
  and the new migrate-e2e are UNPROVEN as checks).
  ~~- Final `nix flake check` + fmt + commit + push + CI watch.~~ done — origin green chain through run 39864876276 (2026-10-22)
  ~~- 10-17 P-plan "superseded-by-V" annotation (docs-health sweep item).~~ done — W15 annotated both plans with per-task dispositions

## d) TOTALLY FUCKED UP (honesty section)

1. **I killed my own 7-minute VM run**: the tool call that added the
   host-parse-fixture app was interrupted, taking the run-7 background
   shell with it (0-byte log, no GC root). The artifact-dump
   instrumentation that would have answered the run-6 panic is sitting
   in the test file UNVERIFIED. Fix: run long builds detached (nohup) so
   an interrupted call cannot destroy them.
2. **The `rg -r` replace trap hit me TWICE** (`rg -rn`/`rg -rln` replace
   matches with the next arg) — the exact lesson AGENTS.md documents
   from two PRIOR incidents in this repo. Output looked plausible-then-
   garbage both times.
3. **A multiedit placeholder botch** (an `XPLACEHOLDERX` marker survived
   an edit pair) during the AGENTS diet — caught by grep immediately,
   cleaned same session.
4. **Introduced a 996-for-993 port typo** in README while pasting
   context into the delta-table edit — caught by re-reading my own diff
   (the mechanical-check discipline WORKED, but the error was mine).
5. **Daemon edit-collisions**: the modified-since-read guard fired ~5
   times on AGENTS.md/TODO_LIST.md (daemon re-committing between my read
   and edit); I worked around via re-view + python edits instead of
   fighting the guard.
6. **AGENTS diet line-count grind**: multiple "compression" edits that
   saved 0-1 lines each (prose re-wrapping eats the savings); the diet
   plateaued at 229 vs the 220 cap and I stopped gold-plating rather
   than damage density.

## e) WHAT WE SHOULD IMPROVE (process, observed this session)

- **Detach long-running verification builds** (nohup + explicit log
  path) so tool-call interruptions cannot kill 7-minute VM runs; the
  current background-shell coupling cost one full debugging iteration.
- **Mechanical identifier discipline on MY OWN edits too**: the 996 typo
  and the rg trap both happened while WRITING, not reading — `git diff`
  read-back after every prose/table edit is cheap and caught two of
  three self-inflicted wounds.
- **The migrate-e2e taught the real lesson of the task**: the original
  single-node test's post-migration assertions had NEVER run (the 2026-
  10-17 wedge). "Written but never executed" test halves are
  unverified code — the two-node redesign should have been run to green
  BEFORE registering it in the guard sites (I registered first, then
  debugged; the registration is currently red-in-principle until run 7+
  passes — mitigated only by the fact that the check will fail LOUDLY
  in the gate, not silently).
- **Snapshot-generated plans carry no Account matchOn** (id-keyed
  upserts) while our wrapper sets match `["name"]` — both work, but the
  divergence deserves a ledger line once V9's allowlist doctrine is
  written down (V9.6 option-surface review ride).
- The migration script's "[DONE] migration complete" banner currently
  overstates: the run-6 panic proves at least one flow where the
  banner prints but the next normal boot refuses. The banner should not
  print DONE until the end-state is actually bootable.

## f) NEXT (ranked, up to 50)

~~1. Re-run the instrumented migrate-e2e (run 7) DETACHED; read~~ done — W1 runs 6-10: fixed and green 9/9 (2026-10-19)
`migration-v016/config.json` + `recovery.log`.
~~2. Root-cause the run-6 panic (which store did recovery wipe?); fix~~ done — three stacked causes transcript-pinned + fixed (W1)
`stalwart-migrate-from-015` (likely: config.json store path or the
poisoned-store wipe interaction); re-run to green.
~~3. Full gate `nix flake check` (9 checks) — first run with~~ done — W2 first full gate green (2026-10-19)
provision-plan-eval + migrate-e2e + the edited stalwart-e2e.
~~4. Triage any red by step name; fix; re-gate.~~ done — W2 statix red root-caused + fixed with CI's exact pin
~~5. Push; watch CI green (`gh run watch`, --log-failed triage).~~ done — green chain through run 39864876276 (2026-10-22)
~~6. Harvest the gate log's `/metrics/prometheus` dump → 0.16 series~~ done — W7 37-series inventory (MONITORING 5.5)
names (V12.1).
~~7. Write the MONITORING queue-depth rule from those series (or record~~ done — W7 NO-GAUGE verdict + counter-divergence proxy
the 0.16 no-gauge verdict if still absent) + provision-failure alert

- 60 s verify-budget note (V12).
  ~~8. TELEMETRY.md key spot-check vs 0.16.22 binary (V12.5).~~ done — W7 0.16.22 spot-check banner
  ~~9. Dry-run `nix run .#host-parse-fixture <fixture> --check~~ done — W10 end-to-end dry-run (-- separator nuance recorded)
   parsedmarc-e2e` (V25.3 verification).
  ~~10. `nix run .#vm` smoke after the disk-wrapper change (boot + one probe~~ done — W10.5 re-smoke 2026-10-19 (HTTP 200)
  - confirm ~/.cache disk).

11. V4.1 CHANGELOG `[Unreleased]` date/link pass. **→ TODO_LIST v0.5.0 row (Unreleased date/link pass)**
12. V4.3 scratch-tag dry-run of the CONTRIBUTING release procedure. **→ TODO_LIST v0.5.0 row (C43-gated)**
13. V16.1 flood subtest transcript check (pre-wait or relaxed bound). **→ TODO_LIST flood watch row**
14. V16.2 relay bounce-path via Mailpit/queue state (never the journal). **→ TODO_LIST row**
15. V16.3 e2e runtime trim investigation (35 s TTL + 75 s reports). **→ TODO_LIST row**
    ~~16. V16.4 restart-persistence: provision must NOT re-run after~~ done — W6: provision NOT re-run pinned across restart
    `systemctl restart`.
    ~~17. V17.1 dmarc-eval unit-hardening eval pin (lines ~568/584/589).~~ done — W9 drop-detectors
    ~~18. V17.2 negative test: flip one key, eval must fail loudly.~~ done — W9 build-time negative self-test
    ~~19. V17.3 IFD cleanup: build-time grep instead of `builtins.readFile`.~~ done — W9 build-time greps
    ~~20. V20.1 check-md-table-pipes.sh argless mode + indented fences.~~ done — W11
    ~~21. V20.2 prose-wrap list-marker lint (awk word-boundary rule).~~ done — W11 (empirically scoped against dprint)
    ~~22. V20.3 check-set drift alarm lint (names/counts restated = fail).~~ done — W11
    ~~23. V20.4 demo ports/credentials single-source audit.~~ done — README quickstart + banner own them (07-18 AGENTS restructure points there)
    ~~24. V20.5 check-inventory CI twin evaluation + decision.~~ done — decided: pre-push mirror + CI README-completeness + lockstep (W11/X9)
    ~~25. V20.6 nix health-check bisect helper into the devShell.~~ done — nix-health in the devShell (W11)
    ~~26. V20.7 CI wiring + one deliberate-failure proof each.~~ done — W11 self-tests on planted fixtures
    ~~27. V22.1 verify-before-filing gates over each upstream claim.~~ done — passed for #552103 (W12.2)
    ~~28. V22.2 nixpkgs #552103 evidence comment (ExecStartPost-restart +~~ done — filed 2026-10-19 (comment 6258512488)
    bootstrap-fallback transcripts — bind-e2e logs).
16. V22.3 dnsmasq-forward upstream note (VM-test resolver rule). **→ TODO_LIST upstream-filings row**
17. V22.4 dprint T13b filing (eaten-cells incident). **→ TODO_LIST upstream-filings row**
    ~~31. V22.5 link filings into the upstream-watch TODO row.~~ done — watch row carries the filed comment + pending files (2026-10-23 update)
18. V23.1 rebuild BuildFlow binary once the concurrent session lands; **→ TODO_LIST BuildFlow row**
    `git log ef32fa0..HEAD` delta review.
19. V23.2 reconcile nix-checker 12-vs-2 and bandit 54-vs-4 count gaps. **→ TODO_LIST BuildFlow row**
20. V23.3 file the ruff findings-identity bug (`missing_file=55`). **→ TODO_LIST BuildFlow row**
21. V23.4 detect-only-under-sibling-failure proposal to BuildFlow. **→ TODO_LIST BuildFlow row**
    ~~36. V25.1 convert-smoke: 0.15 dump fixture → `migrate_v016.py convert`~~ done — migrate-convert-eval check (W10)
    → plan diff (cheap, host-side).
22. V25.2 TLS-node coverage for Netease + LinkedIn fixtures. **→ TODO_LIST row**
    ~~38. V25.4 debug-driver recipe as a script (GC root + test-script dance).~~ done — scripts/vm-debug.sh (X16)
    ~~39. V25.5 apps.vm store-closure eval guard.~~ done — resolved-as-redundant (W10)
    ~~40. V25.6 fixture-dedup decision (shared tests/fixtures.nix).~~ done — decided AGAINST (W10)
23. V24 SystemNix CI-debt assessment (their repo; Actions credential, **→ TODO_LIST SystemNix row**
    digest allowlist, pin flips, scheduled-vs-push divergence).
    ~~42. V13 finish: trim AGENTS to <=220 OR record the C41 blessing ask.~~ done — 220/220 (07-18 pass); C41 moot
    ~~43. TODO_LIST final harvest + this report's routing.~~ done (docs-health pass 2026-10-23)
    ~~44. Annotate the 10-17 P-plan superseded-by-V (docs-health sweep).~~ done — W15 annotated both plans
24. V1 owner sitting #1 (C43/C45/C44/C42/C39/C41/C46 + ratifications). **→ decision-batch (open)**
25. V2 owner sitting #2 (policy batch, CI bandit/vulture scope, demo **→ decision-batch (open)**
    g1/g2 + qcow2 verdict — note the qcow2 question is now MOOT via the
    disk fix, D1/D2 timeline, Resend key).
26. V4 real: cut v0.5.0 (post-V1) → V5 SystemNix pin advance. **→ TODO_LIST v0.5.0 row**
27. V27 D1 slice (post-D1): secrets rotation, live dmarc poll, **→ TODO_LIST D1-gated rows**
    vandelay-vs-imapsync compare, alert-channel encoding, canary
    skeleton.
    ~~49. Session-end: drop /tmp/migrate-e2e-root GC root; trash /tmp probe~~ done (docs-health pass 2026-10-23)
    scripts (archived copies live in docs/probes/).
    ~~50. Record the snapshot-vs-wrapper matchOn divergence as a ledger line~~ done — README ledger line (VM-proven 2026-10-18; X6 confirmed 2026-10-19)
    during the next CONTRIBUTING ledger pass.

## g) QUESTIONS (cannot be figured out from the repo)

1. **V4/C43**: cut v0.5.0 (WITH the vendored module) once the gate is **→ decision-batch C43**
   green, or hold for your explicit ratification first? The [rec] says
   cut; the plan gates the tag on V1 which is an owner sitting. (The
   migrate-e2e panic in b/1 is arguably also a hold signal until the
   migration path is actually bootable.)
   ~~2. **b/1 direction**: fix-forward the `stalwart-migrate-from-015` bug~~ done — answered by W1: fixed-forward, green 9/9 same day
   tonight (root-cause via the run-7 artifacts, patch the script, run to
   green) — or park the registered check red-in-principle with the
   diagnosis written up and prioritize the remaining V-tasks instead?
   ~~3. **V13/C41**: is the 229-line AGENTS.md acceptable (bless a repo-local~~ done — 220/220 reached (07-18 pass); C41 moot
   cap of ~230), or do you want the hard 220 trim enforced before this
   row closes?

---

_Owned next steps live in TODO_LIST.md; this snapshot routes there. No
code or docs were changed in writing this report._
