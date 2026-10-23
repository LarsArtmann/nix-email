# Status Report: Stalwart 0.16.22 upgrade gate-green; quota journal-silence pinned

**Date:** 2026-10-17 03:34 CEST
**Session scope:** session 4 of the 0.15.5 -> 0.16.22 upgrade (continuation of the 00-03 report). One mission: close the last red subtest (quota), then gate + docs + cleanup.
**Headline:** `nix flake check` passes ALL checks on the 0.16 tree. stalwart-e2e is green 17/17 subtests in a real run. The quota posture is transcript-pinned as JOURNAL SILENCE. Full gate (alejandra + buildflow) EXIT:0. The upgrade itself is functionally DONE; what remains is release doctrine (user-gated), docs-drift sweep, and the backup-story gap.

> NOTE ON FORMAT: the status-report skill's canonical output is a styled HTML
> dashboard; the operator prompt explicitly demanded `.md` at this path, so
> the explicit instruction wins this one time (recorded here, not propagated).

---

## a) FULLY DONE

Each item verified this session with evidence.

1. **Quota journal signature question SETTLED (three debug-driver boots).**
   The 0.15 retry signature `Message rescheduled for delivery` does not
   exist on 0.16.22. driver9 (definitive): message accepted at SMTP with
   `250 2.0.0 Message queued with id 4a77af9fa00000` (SWAKS-EXIT:0), then
   20 x 10 s = 200 s of journal polling with pattern
   `quota|reschedul|422 |451 |defer|tempfail|retry|<qid>` = ZERO matches -
   the journal never re-mentions the queue id at all. Evidence:
   `docs/probes/2026-10-17-quota-journal-silence/` (drivers 7/8/9, trimmed
   - ANSI-stripped, with manifest README).
2. **Quota subtest re-pinned** (`tests/stalwart-e2e.nix`): positive
   assertion on the exact acceptance line (`grep -q 'queued with id'`),
   IMAP-absence probe (21 s), and a NEGATIVE journal assertion
   (`! grep -qiE 'rescheduled|over quota'`) pinning the silence posture.
   The two 0.15-era `wait_until_succeeds` retry-line assertions are gone.
   Committed by the daemon (landed in e5f5da1).
3. **stalwart-e2e GREEN: all 17 subtests, real execution** (not cache).
   Log shows 201 must-succeed/finished lines with per-subtest timings;
   EXIT:0. Includes the four subtests that had NEVER executed on 0.16 in
   any prior full run: native DMARC ingestion (75.5 s), JMAP
   session/mailboxes/needle (0.40 s), restart-persistence (17.5 s), and
   the flood-node rate limiter (2.1 s) - all passed on first exercise.
4. **stalwart-relay-e2e GREEN 3/3** (relay path 0.29 s, local path 5.2 s,
   no crashes): the dnsmasq upstream-forward fix (10.0.2.3, was
   black-hole 192.0.2.1) + account localpart shapes VERIFIED in a real
   run. The previous session's "stale green" is now a fresh green.
5. **Full gate green on the 0.16 tree.** `nix flake check` ->
   "all checks passed!" EXIT:0 (incl. a real parsedmarc-e2e run);
   `nix fmt -- . --check` EXIT:0 (alejandra); `buildflow` EXIT:0
   (35 spawns, nix-checker warnings-only as documented).
6. **ci.yml lockstep verified mechanically** (the TODO row that guards
   against shipping red CI): `nix eval .#checks.x86_64-linux --apply
   builtins.attrNames` matches ci.yml `expected=` exactly (6 checks);
   aarch64 shape matches `[ "dmarc-eval" "module-import-eval" ]`. The
   upgrade added/removed NO check; ci.yml needs no change.
7. **Debug-instrument doctrine captured in AGENTS.md** (VM debug loop
   section, 4 rules): (a) long commands under `machine.execute` return
   -1/28 or die on guest-shell BrokenPipeError -> `machine.succeed` +
   file capture; (b) NEVER manually `systemctl start
   stalwart-provision.service` in debug scripts (boot apply already ran;
   a manual re-run's try-restart races the probe - driver6's 535 on
   VALID credentials); (c) journal greps must exclude systemd noise words
   (`over` alone matches `Consumed ... over Ns`); (d) long poll loops can
   die on driver flakes - rerun, don't redesign.
8. **README ledger quota facts updated (3 places)**: the per-account
   semantics bullet (0.16 exact acceptance + journal silence), the
   stalwart-e2e check bullet (green status), and the old 2026-09-15
   storage-QUOTA ledger entry (marked SUPERSEDED, both 0.15 strings
   declared do-not-grep on 0.16).
9. **TODO_LIST: 4 rows closed with evidence** (quota signature, relay-e2e
   rebuild, full gate, ci.yml lockstep).
10. **Probe transcripts archived durably** at
    `docs/probes/2026-10-17-quota-journal-silence/` per repo convention
    (manifest lists what each driver proves, incl. the two failures).
11. **Cleanup done**: GC roots (`/tmp/st-e2e-root`, `/tmp/st-driver-root`),
    `/tmp/st-debug-driver` symlink, `/tmp/debug.py`, stale `/tmp` build
    logs removed. Parked demo VM from session 3 confirmed ALREADY DEAD
    (background shells do not survive sessions) - nothing to kill. No
    qemu of ours left running.

## b) PARTIALLY DONE

~~1. **0.16.22 -> 0.16.26 delta table (README ledger): NOT WRITTEN.** This~~ done — written into the README ledger (V15, 2026-10-19)
   was in the inherited next-steps list (docs sweep item); I updated the
   quota facts but never wrote the version-delta table (what 0.16.23-26
   change: the DNSBL `bit_and` class fixed in 0.16.23, x86-64-v2
   requirement in 0.16.26). Effort: S. Belongs next to the C45 decision.
~~2. **Evidence citations: two TODO rows cite deleted `/tmp` logs.** The~~ done — rows rewritten onto durable evidence (2026-10-17/19 passes)
   relay-e2e row cites `/tmp/relay-build1.log` and the gate row cites
   `/tmp/gate-flake-check.log` etc. - I wrote the citations, THEN deleted
   the logs in cleanup. The quota row cites the durable probes dir (good).
   The gate facts are trivially re-derivable (reruns are cheap), but the
   citations are broken as written. Effort: S (rerun + archive, or point
   rows at the rerun evidence).
~~3. **Concurrent-session docs sweep: unverified.** A second Crush session~~ done — FEATURES/CHANGELOG swept to the 0.16 truth (V19 + CHANGELOG, 2026-10-18)
   is actively editing FEATURES/ROADMAP/CHANGELOG in this repo (observed
   live commits e5f5da1, dd40a90 + uncommitted edits). I deliberately
   stayed out of those files. Unverified: whether FEATURES.md's
   stalwart-e2e row still carries the stale `Message rescheduled`
   claim, and whether CHANGELOG's Unreleased entry mentions the
   journal-silence posture. My quota facts live in README/TODO_LIST/
   probes where that session's harvest reads from.
~~4. **README status banner is now stale.** The concurrent session's banner~~ done — banner corrected 2026-10-18 (V19)
   says "stalwart-e2e one subtest from green (quota retry signature)" -
   superseded by this session. Left untouched (their file, point-in-time
   dated); the banner points at TODO_LIST for live status, which is
   current.
~~5. **INBOXCLEAN.md re-verification on 0.16.22: only partially covered.**~~ done — re-verified 2026-10-18 (V18; INBOXCLEAN 0.16 banner)
   The e2e now exercises JMAP basic-auth as `user2@example.test`, the
   session endpoint, Mailbox/Email query+get on 0.16.22 - the auth-
   identity shape (synthesized `name@<Domain>` address) is e2e-proven.
   The full adapter contract (label mapping, eventSource behavior,
   host-rewrite rules) has NOT been re-verified against a live 0.16 demo
   VM. Effort: M (needs the demo smoke below).
~~6. **Session 3's demo-VM JMAP probe transcripts: not archived.** The 0.16~~ done — docs/probes/2026-10-18-demo-smoke-backup/ (V11/V18)
   JMAP surface was transcript-pinned on the demo VM last session, but
   those transcripts lived in the (now dead) VM's /tmp. Only this
   session's driver logs are in the repo. The demo smoke (below) should
   regenerate them under `docs/probes/`.
~~7. **Backup story on 0.16: UNKNOWN and unstarted (promoted here because~~ done — VM-proven 2026-10-18 (V6; README go-live backup step + probes)
   it is bigger than "not started").** 0.16 removed the REST `/api`
   management surface and the `--export`/`--import` backup path (CHANGELOG
   breaking entry). FEATURES.md still lists a backup drill proven on
   0.15. NOTHING this session (or in the upgrade so far) establishes how
   backup works on 0.16. If Stalwart's replacement mechanism differs,
   the wrapper/SystemNix backup-coordination layer may need real work.
   This is the largest UNVERIFIED product claim in the repo right now.

## c) NOT STARTED

(Planned, zero code this session; priority per TODO_LIST/decision-batch.)

1. **v0.5.0 release** - blocked on C43 (user decision: ship vendored **→ decision-batch C43 (open owner gate; TODO_LIST 0.16 release path)**
   module vs wait for nixpkgs PR #552103 in the pin).
2. **SystemNix consumer pin advance** - blocked on the v0.5.0 tag. **→ TODO_LIST 0.16 release path (blocked on the v0.5.0 tag)**
3. **C44 account-secrets doctrine** - provision plans carry account **→ decision-batch C44**
   passwords in the world-readable Nix store (0.15 exposed only salted
   hashes). Options exist in decision-batch; owner decision.
4. **C45 package decision** - stay 0.16.22 vs overlay 0.16.26. **→ decision-batch C45 (delta table written 2026-10-19)**
5. **C42 dmarc-monitor retire-or-keep** - 0.16 natively imports inbound **→ decision-batch C42 (evidence complete 2026-10-18/19)**
   aggregate reports; parsedmarc still owns forensic/failure parsing.
~~6. **Match-property audit + eval-time lint for provision plans** - catch~~ done — provision-plan-eval shipped 2026-10-18; X6 audit closed 2026-10-19
   the "upsert without match property" class at eval time (two paid-for
   bug classes).
~~7. **0.16 runtime demo smoke** (`nix run .#vm` + port/banner probes) +~~ done — V11 2026-10-18 + W10.5 re-smoke 2026-10-19 (probes dir)
   fresh `docs/probes/` manifest (regenerates item b/6).
8. **dmarc-monitor live validation** - blocked on D1 (rua mailbox). **→ TODO_LIST (D1-gated row)**
~~9. **Push + CI watch** - TODO row exists (daemon owns pushes, C38~~ done — origin green end-to-end (run 39864876276, 2026-10-22)
   posture); I did not push or check `gh run list` this session. Origin
   was red on the statix step per the other session's rows; the local
   tree now passes alejandra, so the push should heal it.
~~10. **Queue-depth alerting pack** - now that the quota journal is silent,~~ done — MONITORING 0.16 truth landed (W7: 37-series inventory + NO-GAUGE verdict)
    MONITORING.md's quota guidance needs a metrics-based replacement
    (not started).
~~11. **docs-health sweep** - harvest this report's (f) list; archive the~~ done (docs-health pass 2026-10-23)
    10-16/10-17 status reports whose items are now fully routed
    (archive policy requires dprint-before-git-mv).

## d) TOTALLY FUCKED UP

(Radical honesty section - what THIS session got wrong.)

1. **driver6: a fully wasted run on a self-inflicted 535.** The script
   manually ran `systemctl start stalwart-provision.service` (with
   `check_return=False`, hiding its output) - the boot apply had ALREADY
   completed, the manual re-run's try-restart raced the probe, and swaks
   got `535 Authentication credentials invalid` on credentials that were
   actually VALID. Cost: one ~3-min driver run plus it fed a wrong
   theory (blaming the instrument's execute semantics) at session start.
   The correct script (driver7) simply does NOT touch provision. The
   inherited session summary even said "provision-aware" was the fix -
   it was the bug.
2. **driver7: false-positive "signature captured"** from a bare `over` in
   the journal grep pattern (matches every systemd
   `Consumed ... over 2.438s wall clock` line). Cost: one run + a moment
   of believing the capture worked. Pattern design without a noise audit.
3. **Three edit-guard rejections from racing the concurrent session** -
   I attempted README/TODO_LIST edits against files another live session
   had modified after my read, twice because I had "read" via bash
   sed/grep (which does not register read-state with the edit tool) and
   once because the file changed between my read and edit. Cost: ~4
   wasted tool calls and a near-miss on double-editing a file another
   agent owns. The fix that finally worked (check mtimes for quiescence,
   register reads via `view`, small targeted edits) should have been the
   FIRST move the moment I noticed four live `crush -y` processes.
4. **Self-inflicted broken citations**: wrote `/tmp/...log` evidence paths
   into two TODO rows and then deleted those exact logs during cleanup.
   Sloppy sequencing - archive first, cite durable paths, THEN clean.
5. **Inherited-plan blindness**: I executed the summary's "exact next
   steps" step 2 mostly as written - and its instrument was the broken
   `machine.execute`-swaks pattern that driver6 had already disproven.
   I corrected it, but only after re-deriving the evidence myself. The
   summary was trusted one step longer than it deserved ("trust nothing
   inherited" - including inherited next-step lists).

Severity note: none of these broke the product; all damage was to my own
instrument and citation hygiene. The tree was never left red.

## e) WHAT WE SHOULD IMPROVE

1. **Multi-session collision protocol.** Four concurrent `crush -y`
   sessions on one repo is a split-brain risk that worked out by luck +
   daemon heuristics (my quota edit got committed inside the OTHER
   session's harvest commit e5f5da1). Concrete fix: before editing any
   doc, `pgrep -af crush` + `git status --short` + `stat` mtimes; if a
   file is hot, write to a non-colliding location (probes dir, new
   report) and hand off via TODO_LIST rows. Worth an AGENTS.md rule.
2. **Register reads with the right tool.** bash `sed`/`grep` reads do not
   register with the edit tool's modified-since-read guard; `view` does.
   Every one of this session's edit rejections traces to this. Cheap
   rule: view-before-edit, always, even for one line.
3. **Journal-signature greps need a noise vocabulary.** systemd log lines
   contain `over`, `retry`-adjacent words, unit names. Concrete practice:
   grep a CONCRETE id (queue id, message id) or a quoted phrase, and
   eyeball the matcher against `journalctl -o cat` output once before
   trusting a count.
4. **Archive evidence at capture time, not cleanup time.** The probes-dir
   archival happened at session end; doing it immediately after each
   driver run would have made every TODO citation durable from birth and
   survived any cleanup.
5. **Debug-driver loop should default to `machine.succeed` + file
   capture** for anything non-trivial; `machine.execute` is for short
   commands only. This is now in AGENTS.md - the next step is noticing
   it EARLY (the pattern was in the inherited summary as a warning and I
   still ran driver6 with the failing shape first).
6. **Inherited next-step lists need re-verification against reality.**
   Two of the summary's claims were stale at session start (GC root
   missing; driver pointed at an old closure; the "fix pattern" was the
   bug). A 30-second environment probe (which I did do) should be paired
   with re-deriving the INSTRUMENT, not just the environment.
7. **The quota silence has a monitoring consequence** - the ledger's
   old advice "monitoring/alerting on queue depth is the operator-
   visible signal" is now the ONLY signal (no journal line). MONITORING.md
   should get a concrete queue-depth alert rule with series names from a
   real transcript (the metrics subtest already dumps the full body to
   the build log for exactly this).

## f) TOP 50 THINGS WE SHOULD GET DONE NEXT

Ranked by impact; effort S (<30m) / M (30m-2h) / L (>2h). HARVEST: items
marked [T] are TODO_LIST material (bounded, actionable); [R] are ROADMAP
fuel; [U] need a user decision first.

1. [U] Resolve **C43**: cut v0.5.0 with the vendored 0.16 module, or wait **→ decision-batch C43 (open)**
   for nixpkgs PR #552103 in the pin - blocks release + consumer pin. | Critical | S
2. [U] Resolve **C45**: stay on pin's 0.16.22 vs overlay 0.16.26 (DNSBL **→ decision-batch C45 (open)**
   fix vs x86-64-v2 requirement + consumer-pin drift). | High | S
3. [U] Resolve **C44**: account-secrets doctrine (passwords in **→ decision-batch C44 (open)**
   world-readable store: sops-rendered runtime apply vs admin-created
   accounts vs credential-file type). | High | M
~~4. [T] **Research + document the 0.16 backup story** - `--export`/~~ done — VM-proven 2026-10-18 (V6; README runbook + FEATURES)
   `--import` and REST /api are GONE upstream; find the replacement
   (snapshot-the-data-dir? new CLI?), verify in VM, update wrapper/
   FEATURES/SystemNix contract. | Critical | M
~~5. [T] Write the **0.16.22 -> 0.16.26 delta table** for the README ledger~~ done — README ledger (V15, 2026-10-19)
   (DNSBL fix class, x86-64-v2, other 0.16.23-26 changes). | High | S
~~6. [T] **Push + watch CI to green** (daemon owns; the statix red runs~~ done — green chain through run 39864876276 (2026-10-22)
   should heal - local alejandra passes). | High | S
~~7. [T] Fix the **stale README status banner** ("one subtest from green")~~ done — corrected 2026-10-18 (V19)
   - now wrong; either update or re-date it. | Med | S
~~8. [T] Verify/fix **FEATURES.md** stalwart-e2e row (possible stale~~ done — rows refreshed (e2e 19/19, backup 0.16 posture; docs-health 2026-10-23)
   `Message rescheduled` claim + backup-drill claim needs the 0.16
   caveat from item 4). | High | S
~~9. [T] Verify **CHANGELOG Unreleased** mentions the journal-silence~~ done — journal-silence + relay fix present in [Unreleased]
   posture + the relay dnsmasq fix; add if missing. | Med | S
~~10. [T] **0.16 runtime demo smoke** (`nix run .#vm`, port/banner probes,~~ done — V11 2026-10-18 + W10.5 (probes)
    scratch-dir discipline) + regenerate session 3's JMAP probes under
    `docs/probes/<date>-jmap-016-demo-vm/`. | High | M
~~11. [T] **INBOXCLEAN.md full re-verification** against 0.16.22 runtime~~ done — V18 2026-10-18 (0.16 banner)
    (auth identity = synthesized address, eventSource, label mapping)
    riding item 10's VM. | High | M
~~12. [T] **Match-property audit + eval-time lint** for provision plans~~ done — provision-plan-eval (V9) + X6 closure 2026-10-19
    (upserts must carry their match property; catch both paid-for bug
    classes at eval time). | Med | M
13. [U] Resolve **C42**: dmarc-monitor retire-or-keep (one stalw.art docs **→ decision-batch C42**
    fetch settles inbound-failure parsing; then decide parsedmarc's
    remaining scope). | Med | S
14. [U] Resolve **D1** (rua mailbox) -> unblocks dmarc-monitor live **→ ROADMAP open questions (D1)**
    validation. | Med | S
15. [U] Resolve **D2** + the spam->Junk filing question (ROADMAP open **→ ROADMAP open questions (D2; Junk-filing residue Q6)**
    decisions). | Med | S
~~16. [T] **MONITORING.md quota guidance**: replace the journal-grep alert~~ done — W7 37-series inventory + counter-divergence proxy (2026-10-19)
    with a queue-depth metric rule; series names from the metrics-subtest
    build-log dump (transcript-first). | High | M
~~17. [T] Fix the **broken /tmp citations** in TODO_LIST (relay + gate~~ done — rows rewritten onto durable evidence (2026-10-17/19 passes)
    rows): rerun-and-archive or repoint at durable evidence. | Low | S
~~18. [T] **docs-health HARVEST** of this report's (f) list into~~ done (docs-health pass 2026-10-23)
    TODO_LIST/ROADMAP. | Med | S
~~19. [T] **Archive resolved status reports** (10-16 pair, 21-08, 01-22 -~~ done — 2026-10-17 pass archived the corridor (manifest in archived/README)
    check each against the archive policy; dprint before git mv).
    | Low | S
~~20. [T] **Annotate the 00-03 report** (quota signature section: resolved~~ done — both annotated + archived (2026-10-17 pass)
    as journal silence) + the 01-22 report (statix row: fixed locally,
    push pending). | Low | S
21. [T] Record **C43/C45 verdicts** in decision-batch.md once answered; **→ decision-batch C43/C45 (still open, owner)**
    close the "g3 short retry schedule" option as MOOT with the driver9
    citation. | Low | S
~~22. [T] **AGENTS.md drift pass**: grep for remaining 0.15-era claims~~ done — V13 diet + V19 sweep (2026-10-18/19)
    (ports, quota strings, `Message rescheduled`) and annotate. | Med | S
~~23. [T] **TELEMETRY.md spot-check** against the 0.16.22 binary (doc~~ done — W7 0.16.22 spot-check banner (2026-10-19)
    carries an upstream-object-model vs pinned-version skew caveat).
    | Med | M
~~24. [T] **THREAT_MODEL.md revisit for 0.16**: REST /api removal shrinks~~ done — V14 exposure-delta section (2026-10-18)
    exposure; store-readable secrets (C44) grow it. | Med | M
~~25. [T] **Local lockstep guard**: a flake eval check that asserts~~ done — check-set-lockstep + tests/check-expected.json (X9, 2026-10-19)
    checks.attrNames == the ci.yml expected list, so drift fails locally
    before push (the guard currently exists only in CI). | Med | S
~~26. [T] Consider **upstreaming our ExecStartPost-restart evidence** as a~~ done — filed 2026-10-19 (comment 6258512488, W12.2)
    comment on nixpkgs PR #552103 (reload-doesn't-rebind-listeners,
    issue #352 class) - verify-before-filing first. | Low | S
~~27. [T] **host-parse-fixture.py closure re-check** after the upgrade~~ done — flake app + end-to-end dry-run (W10, 2026-10-19)
    (walks the parsedmarc-e2e closure; parsedmarc unchanged but closure
    moved). | Low | S
28. [T] **Flood-limiter robustness**: the 3-banner/7-hangup assertion on **→ TODO_LIST flood watch row (open)**
    a 1m window is timing-sensitive on slow CI runners; consider a
    pre-wait or relaxed-bound transcript check. | Med | S
29. [R] **Declarative catch-all wrapper option** (currently runtime-plan **→ ROADMAP 0.16-born ideas**
    only; product-shape decision documented in README). | Med | L
30. [R] **Queue-depth observability surface** beyond alerts: export the **→ ROADMAP 0.16-born ideas**
    queue length as a first-class metric + dashboard row. | Med | M
31. [T] **vulnix replacement** (NVD killed the legacy feeds; .buildflow.yml **→ ROADMAP repo-excellence (BuildFlow ships a working scanner)**
    skips it fleet-wide) - pick a maintained scanner (e.g. osv-scanner)
    into BuildFlow. | Med | M
~~32. [T] Re-evaluate the **mypy-check + pytest-test skips** in~~ done — mypy rationale replaced 2026-10-19 (X14); pytest skip stands
    .buildflow.yml (do the original rationales still hold?). | Low | S
~~33. [T] **Demo VM scratch-disk hygiene**: make demo.qcow2 non-CWD-relative~~ done — NIX_DISK_IMAGE pinned to ~/.cache (V26, 2026-10-18)
    or auto-scratch (AGENTS-documented footgun). | Low | S
34. [T] **E2E runtime trim investigation**: 35 s unknown-recipient (TTL) + **→ TODO_LIST (open)**
    75 s reports subtest dominate; check if a test-profile TTL is
    legitimate WITHOUT weakening product defaults (doctrine: fix the
    test, not the module). | Low | M
~~35. [T] **JMAP eventSource probe** on 0.16 (the 0.15 pin rejected~~ done — V18 probes + W6 e2e push subtest (closeafter ACCEPTED)
    closeafter/ping params; INBOXCLEAN push contract needs the 0.16
    shape) - rides item 10. | Med | S
36. [T] **Relay bounce-path test**: non-local submission to a REFUSING **→ TODO_LIST (open)**
    smarthost on 0.16 - with journal silence, assert via Mailpit/queue
    state, not journal. | Med | M
~~37. [T] **AGENTS.md concurrent-session rule** from e/1 (mtime probe,~~ done — session-start baseline ritual in AGENTS
    pgrep, hand-off convention). | Med | S
38. [T] **BuildFlow nix-checker count gap** (summary-vs-detail 12-vs-2 **→ TODO_LIST BuildFlow row**
    warning count) - cross-repo TODO in the BuildFlow repo. | Low | S
~~39. [T] **Roadmap hygiene**: pull any remaining 20-48/21-08 report items~~ done — swept by the 2026-10-17/19 passes
    that were never routed; the archive pass (19) will surface them.
    | Low | S
~~40. [T] **README quickstart re-verify** against the 0.16 demo (port~~ done — W10.5 re-smoke + demo-eval contract (2026-10-19)
    pairs, provision roles/catch-all/absolute-curl, fallback admin - the
    demo-eval pins them, but the human-facing quickstart steps deserve
    one live walk). | Med | M
~~41. [T] **Provision-plan schema lint in CI**: the vendored module's Lua~~ done — provision-plan-eval (V9, 2026-10-18)
    schema check runs at build; confirm it also rejects the indexed-map
    list-value mistakes (credentials array form) or extend it.
    | Med | M
42. [T] **Sequenced release dry-run**: once C43 is decided, walk the **→ TODO_LIST v0.5.0 row (C43-blocked)**
    CONTRIBUTING release procedure end-to-end on a scratch tag before
    the real one (daemon races explicit commits - edit+commit same call).
    | Low | S
43. [R] **Secrets-type in the wrapper** (post-C44): a typed **→ ROADMAP (post-C44)**
    `credentials.<user>.secretFile` option rendered at runtime.
    | High | L
44. [R] **parsedmarc on the 0.16 stack end-to-end**: the e2e passes, but **→ ROADMAP 0.16-born ideas**
    the SYSTEMNIX wiring (report destinations, IMAP polling against
    0.16 JMAP/IMAP) has never run against a real 0.16 deployment.
    | Med | L
~~45. [T] **JMAP subtest hardening**: assert `state` field change after~~ done — JMAP push subtest asserts StateChange (W6)
    delivery (StateChange) or skip - currently the needle query is
    point-in-time; a state assertion would catch stale-cache classes.
    | Low | S
46. [T] ** CHANGELOG date + attribution pass** on release: verify the **→ TODO_LIST v0.5.0 row**
    Unreleased section's dates/links resolve (upstream PR/issue refs
    from this upgrade). | Low | S
~~47. [T] **`docs/probes/` manifests audit**: docs-health sweep includes~~ done — W15 probe-manifest audit clean (2026-10-19)
    probe-dir manifests; the 2026-10-05 dir is 0.15-era and should gain a
    staleness pointer to the 0.16 dir once item 10 lands. | Low | S
~~48. [R] **Wrapper option surface review post-0.16**: which 0.15-era~~ done — X6 closed 2026-10-19 (zero dead options; ROADMAP line updated)
    wrapper options are now dead/no-op under the object model (audit
    `mail-server.nix` against the vendored module's option set).
    | Med | M
~~49. [T] **Restart-persistence subtest extension**: after~~ done — provision-not-rerun pinned across restart (W6)
    `systemctl restart`, also assert the provision unit does NOT re-run
    (idempotence claim is asserted only at boot; the second-apply path
    is tested separately). | Low | S
~~50. [T] **Session-archival convention check**: this report + the 01-22~~ done — every report carries the .md format note (settled in practice)
    report both used `.md` under an HTML-default skill; normalize the
    convention note (or the skill) so the format question stops
    recurring. | Low | S

## g) THREE QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **C43 - Release doctrine.** Cut **v0.5.0** now with the vendored 0.16 **→ decision-batch C43**
   module (SystemNix hard-pins release tags, so the consumer can only
   advance when we tag), or hold until nixpkgs PR #552103 lands in our
   pin and rebase the wrapper onto it? I have the full technical picture
   (gate green, breaking-change inventory done) but the risk call -
   shipping a vendored module vs waiting on upstream review cadence -
   is an ownership tradeoff only you can make. Everything downstream
   (tag, SystemNix pin advance, README banner) queues behind this.
2. **C45 - Package version.** Stay on the pin's `stalwart_0_16` **→ decision-batch C45**
   (0.16.22), or overlay **0.16.26** (fixes the DNSBL `bit_and` class;
   but requires x86-64-v2 - and I do not know the CPU baseline of the
   actual fleet hosts this flake deploys to; that hardware fact lives
   with you). Our wrapper's always-reconcile already neutralizes the
   DNSBL bug in OUR config, so this is mainly about consumer hosts.
3. **C44 - Account-secrets doctrine.** 0.16 provision plans carry account **→ decision-batch C44**
   passwords in the world-readable Nix store (0.15 stored only salted
   hashes). Which posture do you want: sops-rendered runtime
   `stalwart-cli apply`, admin-created accounts outside the plan, or a
   wrapper `secretFile` credential type? This changes the wrapper's data
   model and the THREAT_MODEL; it is a risk-acceptance decision, not a
   technical one.

---

**Handoff:** section (f) is HARVEST input for `docs-health` - items marked
[T] belong in TODO_LIST.md, [R] in ROADMAP.md, [U] in decision-batch.md.
The three open user decisions (g/1-3) already sit in decision-batch.md as
C43/C45/C44; this report adds the driver9 citation that closes the fourth
(quota) decision as MOOT.
