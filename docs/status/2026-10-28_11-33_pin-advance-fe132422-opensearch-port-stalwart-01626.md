# Pin advance fe132422: OpenSearch port, Stalwart 0.16.26, parsedmarc 11.0.2 (2026-10-28 11:33 CET)

> Scope: THIS session only ("make sure everything is on the latest version and
> superb"). Baseline `234c6ec` (clean tree), 20+ concurrent crush processes
> (normal), no foreign same-day corridor report at start. BuildFlow skill
> loaded before any gate/formatter work. All artifacts under /tmp (gate.log,
> stalwart-e2e.log, parsedmarc-e2e*.log, parse-*.json).
> STATE AT WRITE: tree committed by the daemon; parsedmarc-e2e rerun PENDING
> after the ReadWritePaths wrapper fix — see (b)/(f).
> **CLOSED 2026-10-28 ~20:30 CET — the Appendix dispositions every f-item;
> the flake gate, buildflow, and both VM re-proofs are GREEN.**

## a) FULLY DONE (verified, with evidence)

1. **Drift discovered, not assumed**: SystemNix's lock had advanced nixpkgs to
   `fe132422` (2026-10-16) while this repo sat at `6774f7bc` (2026-09-22) —
   the compat doctrine (same rev, both locks) was violated with THIS repo
   behind. SystemNix also floats `github:LarsArtmann/nix-email` (master; lock
   at our HEAD) + `nixpkgs.follows` — their `checks.nix-email-contract`
   forces their pin onto the wrapper, so the stale tree's
   `provision.elasticsearch` definition could not eval against the consumer
   pin (their gate is red until they pull our master).
2. **Lockstep catch-up landed**: flake.nix URL + flake.lock +
   `flake-modules/lock-guards.nix` `fleetNixpkgsPin` all at `fe132422`;
   flake-parts confirmed ALREADY at upstream HEAD (`024633cd`, 2026-10-01 =
   SystemNix's node) — no action needed; follows guard green.
3. **Presence list re-verified at the new pin** (`nix eval` per the
   source-assessment discipline — rev, not registry): stalwart_0_16
   **0.16.26**, parsedmarc **11.0.2** (py3.14 default scope), imapclient
   **4.1.0**, stalwart-cli 1.0.13, mailpit 1.31.4, imapsync 2.314, swaks
   20240103.0; `pkgs.stalwart` still 0.15.5 + nixpkgs PR #552103 still OPEN →
   vendored 0.16 module stays; PR #566282 (OpenSearch rework) IS in the pin.
4. **imapclient py3.13 pin REVERTED** (modules/dmarc-monitor.nix):
   `parsedmarcPackage` binding + `ExecStart = mkForce` override deleted; the
   module's own `pkgs.parsedmarc` ExecStart (py3.14) is back. Verified:
   dmarc-eval GREEN, greps assert `python3.14-parsedmarc`.
5. **elasticsearch -> opensearch PORTED** (module + both tests): `provision
   .opensearch = mkDefault false`; strip-guard re-targets `[opensearch]`
   (host-less-section bug persists, nixpkgs #563651 still open — confirmed
   against the fetched new-pin module source: `opensearch.cert_path` path-type
   CA default + `.ssl` bool survive the null/[]/{} filter). dmarc-eval GREEN
   with `[opensearch]` in the strip script and `"opensearch":false` rendered.
6. **Host parser dry-runs BEFORE the VM** (AGENTS rule): pinned 11.0.2 env
   realized from the check drv closure; ALL FIVE fixtures parse GREEN
   (aggregate zip, 3 failure .eml, inline TLS-RPT json). The three transcribed
   `arrival_date_utc` values (09:20:27 / 08:48:42 / 02:09:00) and aggregate
   identity fields (report_id 2940, XYZ Corporation, policy_published.domain
   example.com) byte-identical to the test assertions.
7. **Stalwart 0.16.26 absorbed**: `tests/common.nix` gains `v2CpuPatches`
   (`virtualisation.qemu.options = ["-cpu" "max"]` — TCG-safe; `host` is
   invalid without KVM on CI), imported by every 0.16 VM node (stalwart-e2e
   machine+flood, bind-e2e machine+guarded, migrate-e2e mig016, relay-e2e
   smtp) + the demo host.
8. **stalwart-e2e GREEN on 0.16.26** (`EXIT:0`, /tmp/stalwart-e2e.log): the
   0.16.26 binary boots and passes the full subtest set incl. provisioning
   dialect, DKIM, IMAPS/JMAP, quota, GTUBE, native DMARC + ARF ingestion,
   flood limiter. The object-shape re-verification the runbook demands at a
   `stalwart_0_16` move is transcript-proven (schema-adjacent:
   provision-plan-eval also green in the gate's eval phase).
9. **Docs single-sourced and honest** (details in CHANGELOG `[Unreleased]`):
   README (architecture version, ledger #563651/#563652 entries, external
   issues, runbook step 2 EXECUTED notes, 0.16.22->0.16.26 delta section =
   C45 SUPERSEDED, DNSBL reconcile rationale now posture+0.16.24-insert-only
   (behavior unchanged), PIN DISCIPLINE records SystemNix's float-master
   drift, stalwart-e2e check row green-0.16.26, 0.16 ledger ride-along
   banner); TODO_LIST rows 78 (premise superseded — no more ?ref=v0.4.0), 86
   (C45 DONE-by-supersession), 100 (executed notes); decision-batch C45
   SUPERSEDED banner; AGENTS.md compat line + DNSBL line; FEATURES/ROADMAP
   workaround triggers; INBOXCLEAN pending-reverification note.
10. **Formatter/lints**: alejandra clean (2 fixes applied); markdown pipe lint
    green; eval guards (attrNames x86_64 + aarch64) green; check-set lockstep
    unchanged (no check added/removed).

## b) PARTIALLY DONE (in flight when the report was requested)

~~1. **parsedmarc-e2e port — 2 of 3 legs proven**:~~ done — GREEN run 5, all 8 subtests both nodes after two transcript-diagnosed rounds (Appendix 1: 226/NAMESPACE + evaluated-once `-` prefix mechanics)
   - Run 1 RED: new-pin localMail wires NO dovecot at all (PR #566282 rework:
     postfix + `[maildir]` watch only) — `wait_for_unit("dovecot.service")`
     dead by construction. Ported the test per upstream's own updated test
     (`nixos/tests/parsedmarc/default.nix` @ fe132422, fetched): machine node
     rides the maildir flow (dovecot + home_mailbox dropped); tls node now
     OWNS its mail stack (dovecot IMAPS 993 + postfix + static dmarc user +
     `settings.imap` through the WRAPPER; upstream externalMail shape;
     DynamicUser=mkForce false for determinism); secret-replacement proof
     moved to tls as a POSITIVE grep.
   - Run 2: **tls leg WORKING** (journal: `imap-login: Logged in:
     user=<dmarc>, method=PLAIN, ..., TLS` — the production-shaped IMAPS
     poll authenticates end-to-end); machine leg RED with a REAL wrapper gap:
     parsedmarc's maildir source mkdirs `.Archive` inside the provisioned
     spool maildir and our `ProtectSystem=strict` kills it
     (`OSError Errno 30 /var/spool/mail/dmarc/.Archive`).
   - **FIX APPLIED** (wrapper, not test): `ReadWritePaths` now appends
     `${postfix mail_spool}/${recipientName}` under
     `provision.localMail.enable`, mirroring the module's own
     `maildir_path` expression. RERUN NOT YET DONE — this is THE next action.
~~2. **Full `nix flake check` gate**: run 1 aborted at parsedmarc-e2e; bind /~~ done — gate2.log EXIT:0, first new-pin verdicts for bind/migrate/relay (Appendix 2)
   migrate / relay VM tests got NO verdict at the new pin (their drvs built;
   the abort came first). Needs the rerun.
~~3. **buildflow gate**: not run this session (must not run concurrently with~~ done — --fix run EXIT:0 (Appendix 3, incl. the SHA-verified action bump)
   the flake gate; queued after it).

## c) NOT STARTED

~~1. CardDAV/contacts probe re-baseline (TODO row 104 — explicitly triggered by~~ done — RUN 2026-10-28: 17/18 PASS on 0.16.26, baseline reproduced (Appendix 2/1); row 104 closed, re-arms at the next bump
   any stalwart bump; 17/18 PASS baseline is 0.16.22-era; needs a demo-VM
   boot; INBOXCLEAN note says claims stay 0.16.22-pinned until then).
~~2. README STATUS banner flip (line 10 still carries the 2026-10-17 banner;~~ done — flipped post-proof (Appendix 5)
   new banner written only after the gate is green).
~~3. dprint pass over this session's markdown edits (buildflow format owns it).~~ done — read-back clean (Appendix 4)
~~4. Session status report — this file (was c) item, now done).~~ done — this file (Appendix 24)
~~5. v0.5.0 release cut — deliberately NOT started: owner-gated (C43~~ routed — C43 ANSWERED CUT 2026-10-28: v0.5.0 RELEASED same day (Appendix 2/3; decision-batch C43)
   ship-vendored vs wait-for-PR); C45's dissolution does not answer C43.
~~6. SystemNix-side pull of our master to re-green their contract check~~ routed — their repo, their cadence; flagged to the owner (Appendix 11)
   (their repo, their cadence — noted here because the risk is live now).

## d) TOTALLY FUCKED UP (honest)

1. **`rg -rn` hook trap fired AGAIN on this host** (documented as third
   strike): I knew the rule, still typo'd `-rn` for `-n`. No damage (hook
   blocked it) — but that is now strike three WITH the rule in context.
2. **Four multiedits bounced by the modified-since-read guard**: I had read
   those test files via `sed`/`rg` in bash and forgot the AGENTS rule that
   only `view` arms the guard. Pure waste of a round trip.
3. **bind-e2e edit failed on a multi-site match** (imports+stateVersion
   appears twice) — needed two more passes; the second site (`guarded` node)
   was caught only by the follow-up audit grep. The audit grep also caught
   `flood` (stalwart-e2e) which my first wiring pass MISSED — a node running
   0.16 without v2CpuPatches would have failed the gate 30 minutes later.
4. **Claim-before-transcript**: I wrote "stalwart-e2e green on 0.16.26" into
   the README runbook WHILE the run was still executing. It passed — luck,
   not discipline. Should have written the runbook note after EXIT:0.
5. **Gate run 1 wasted ~30 min**: I had ALREADY fetched the new-pin
   parsedmarc.nix and grepped it for opensearch — but never grepped for
   `dovecot|localMail` wiring. The dovecot removal was discoverable in
   seconds before the 25-minute VM build. Same class, smaller: the
   ProtectSystem/Errno 30 interaction was also predictable from the fetched
   module (the `[maildir]` section) + our own hardening block.

## e) WHAT WE SHOULD IMPROVE (systemic, from this run)

1. **Pin-advance runbook step 2 needs a "diff the module" step**: fetch the
   new-pin `nixos/modules/services/monitoring/parsedmarc.nix` (and stalwart
   module state) and grep for REMOVED wiring (dovecot, localMail shape),
   not just the known workaround keys. Both gate-1 and run-2 failures were
   in the diff.
2. **The wrapper-vs-module storage contract should be asserted at eval
   time**: the ReadWritePaths/localMail gap only surfaced at runtime. A
   dmarc-eval assertion ("under localMail, ReadWritePaths contains the
   maildir path") would have caught it in ~10 s.
3. **Stop hand-writing runbook claims mid-run**: docs edits that assert a
   run's outcome belong AFTER the exit code. (Corollary of the no-assertion
   -without-transcript rule; I violated its spirit, not its letter.)
4. **README PIN DISCIPLINE said "SystemNix COMPLIES"** — stale for weeks
   (they float master now). Nobody re-verified the consumer's input
   definition between 10-05 and today. Cheap `grep nix-email` in their
   flake.nix on every pin-advance would keep that block truthful.
5. **v2CpuPatches import is per-node by hand** — a future test node will
   forget it (the flood/guarded near-miss proves the failure mode). Consider
   an eval-time assertion: any node importing mail-server.nix in a VM test
   must carry a v2-capable cpu (or document why 0.15.x).

## f) NEXT (up to 50, ordered)

~~1. Rerun `nix build .#checks.x86_64-linux.parsedmarc-e2e -L` (ReadWritePaths~~ done — GREEN run 5 (Appendix 1)
   fix is in; expect machine maildir leg green, then full subtests).
~~2. If green: full `nix flake check > /tmp/gate.log` (bind/migrate/relay get~~ done — gate2.log EXIT:0 (Appendix 2)
   their first new-pin verdicts).
~~3. `buildflow --max-time 35m` (never concurrent with the flake gate).~~ done — Appendix 3
~~4. dprint pass + `git diff` read-back over prose (dprint rewrap trap).~~ done — Appendix 4
~~5. README STATUS banner flip to the 2026-10-28 pin-advance state.~~ done — Appendix 5
~~6. dmarc-eval: add the localMail/ReadWritePaths eval assertion (e/2).~~ done — Appendix 6
~~7. Consider the v2CpuPatches eval-time guard for VM nodes (e/5).~~ done — assertion approach PROVEN IMPOSSIBLE (recursion + qemu-vm options everywhere); structural fix = test-level `defaults` (Appendix 7)
~~8. CardDAV probe re-baseline on 0.16.26 (row 104): demo VM boot +~~ done — RUN: 17/18 PASS reproduced (Appendix 2/1)
   `docs/probes/2026-10-19-carddav-demo-vm/carddav_probe.py`, expect 17/18;
   diff the README "Contacts surface" dialect notes.
~~9. Update TODO row 104 with the probe outcome; INBOXCLEAN banner re-pin to~~ done — row closed, re-arms at the next stalwart bump (Appendix 9)
   0.16.26 (or keep the pending note if probes not run).
~~10. Verify the dovecot2.protocols warning actually disappeared in the new~~ done — warning GONE in the run-5 log (Appendix 10)
    gate log (runbook predicted it; confirm and strike the note).
~~11. Notify/verify SystemNix pulls our master (their contract check re-greens;~~ routed — their repo, their cadence (Appendix 11)
    their repo — flag only).
~~12. Consumer-side x86-64-v2 CPU check reminder for real hosts (pbx, evo-x2,~~ done — stalwart-cpu-preflight.service shipped in the wrapper (Appendix 2/2)
    VPS) before their next rebuild ships 0.16.26 (their follows already
    carries the rev).
~~13. Add a CHANGELOG "Fixed" bullet for the ReadWritePaths/localMail wrapper~~ done — Appendix 13
    gap once proven by the rerun.
~~14. Sweep remaining `0.16.22`-as-current mentions in corridor LIVE docs~~ done — Appendix 14
    (dated evidence stays; only current-tense claims change) — CONTRIBUTING
    - TELEMETRY spot-check.
~~15. If parsedmarc-e2e still red: read the new traceback FIRST (the two prior~~ NOT-DO — green path taken (Appendix 15)
    reds were both precisely diagnosable from the journal; no guessing).
~~16. Update FEATURES.md parsedmarc-e2e row to the new two-shape architecture~~ done — Appendix 16
    (maildir + test-owned IMAPS) after green.
~~17. Check whether dmarc-eval's `execStartPreCount >= 2` still holds under~~ done — strip-last pinned by NAME (Appendix 17)
    the maildir flow (no [imap] secret on machine — strip-guard still last).
~~18. Confirm the machine node's spool delivery semantics (mbox file vs~~ done — maildir TREE, pinned in the test comment (Appendix 18)
    maildir tree at /var/spool/mail/dmarc) from the green run's journal and
    pin the finding in the test comment (currently riding upstream-CI-green).
~~19. Run `scripts/check-md-table-pipes.sh` + `annotate.go check-rows` if any~~ done — pipe lint green; check-rows n/a then (Appendix 19)
    corridor tables were touched by dprint.
~~20. Owner-sitting backlog is unchanged: C43 (v0.5.0 doctrine), C44 (secrets),~~ routed — C43 answered 2026-10-28 (Appendix 2/3); C44/C39/C41/C46 remain on the sitting sheet
    C39/C41/C46, D1/D2 — this session dissolved only C45 + row 78's premise.
~~21. After gates green + probes done: consider whether the 2026-10-26~~ done — z-gen banner updated (Appendix 21)
    z-generation plan's A-lane (v0.5.0 cut) precondition set shrank further
    (C45 gone) and annotate the plan's O2 row accordingly (owner-facing).
~~22. Re-check nixpkgs #563651 follow-up comment draft (docs/drafts/) — the~~ routed — ON HOLD per owner 2026-10-28, draft review before posting (Appendix 2/4; TODO_LIST upstream-watch row)
    port evidence (fe132422 transcript) strengthens the filing; still
    gh-auth-blocked per row 94/102.
~~23. Optional: pin the fixture CA cert SANs against the tls node's~~ done — Appendix 23
    `host = "127.0.0.1"` (cert has IP:127.0.0.1 SAN — the login proof
    passed, so hostname verification against the IP worked; note it).
~~24. Housekeeping: /tmp parse-*.json + fixture paths are throwaway; the~~ done — Appendix 24
    presence-list evals are recorded in flake.nix comments (done).

## g) QUESTIONS (cannot figure out myself)

~~1. **C43 / v0.5.0**: the pin advance dissolved C45, but C43 (cut v0.5.0 with~~ routed — ANSWERED CUT: v0.5.0 RELEASED 2026-10-28 (Appendix 2/3; decision-batch C43 verdict)
   the VENDORED 0.16 module, vs wait for nixpkgs PR #552103) is still your
   call. SystemNix already consumes master directly, so the tag is now
   traceability, not a deployment gate. Ratify C43 = cut, or keep waiting?
~~2. **Real-host x86-64-v2 exposure**: SystemNix's `follows` already forces~~ routed — HANDLED: stalwart-cpu-preflight.service shipped in the wrapper (Appendix 2/2)
   fe132422 (Stalwart 0.16.26, v2-only on x86_64) onto their evals — their
   next rebuild deploys it to pbx/evo-x2/VPS. Do you want that CPU check
   raised/handled in SystemNix now (their repo, but the risk is live
   today), and is any of that fleet pre-v2?
~~3. **CardDAV probe re-baseline (row 104)**: it needs a demo-VM boot~~ routed — RUN: 17/18 PASS on 0.16.26, transcripts docs/probes/2026-10-28-carddav-01626/ (Appendix 2/1)
   (~30 min TCG) and gates the INBOXCLEAN/CRM dialect claims on 0.16.26.
   Run it at the end of THIS session, or leave it as the TODO row for a
   dedicated sitting?

## Verdict

The "latest version" goal is materially met in-tree (lock + port + revert +
cpu absorption, stalwart-e2e/dmarc-eval/dry-runs green); "superb" is one
parsedmarc-e2e rerun, one full gate, and one buildflow away — plus the
probe/banner/docs tail above. Nothing in this session's residue is
mysterious: every red had a precise, source-level diagnosis.

## Appendix — closure transcript (2026-10-28 ~20:30 CET)

The f-list, dispositioned. All evidence under /tmp unless a repo path is
named; every gate claim below has its EXIT line.

1. **parsedmarc-e2e GREEN** (run 5, `/tmp/parsedmarc-e2e5.log` EXIT:0, all
   8 subtests on both nodes) — but it took TWO more transcript-diagnosed
   rounds: run 4 died at `status=226/NAMESPACE` spawning the MODULE's own
   `+`-prefixed ExecStartPre, proving systemd applies the mount namespace
   to EVERY ExecStartPre command (`+` exempts only user/group/credentials,
   NOT mounts) — an ExecStartPre pre-creation of the ReadWritePaths target
   is structurally impossible. Final mechanism: BOOT-TIME
   `systemd.tmpfiles.rules` pre-creation + UNPREFIXED ReadWritePaths (the
   `-` prefix is evaluated ONCE at namespace setup; a path absent at exec
   time is silently skipped and the spool stays read-only forever — run 3's
   Errno 30 was exactly this). Pinned in the wrapper comments, the runbook
   (new "DIFF the parsedmarc module" step), AGENTS.md working rules, and
   `dmarc-eval`'s NEW localMail-shape eval (whitelist == the module's
   rendered `settings.maildir.maildir_path`, no-dash doctrine, tmpfiles
   rule, strip still last — ~10 s instead of a 25-min VM red).
2. **Full gate GREEN** (`/tmp/gate2.log` EXIT:0): bind/migrate/relay got
   their first new-pin verdicts (green); aarch64 eval set included.
3. **buildflow**: detect-run RED only at dprint (3 unformatted files);
   `--fix` run **EXIT:0** (`/tmp/bf2.log`, 33/43, warnings don't gate).
   Ride-along fix: `github-actions-pinning` bumped
   flakehub-cache-action 3.24.0 -> 3.24.1 — SHA `3ac6f3c...` verified
   against the real `tags/v3.24.1` ref via `gh api` (not trusted from the
   tool's say-so).
4. **dprint read-back**: FEATURES/TODO_LIST = pure table re-padding; the
   report's `+ TELEMETRY` continuation line was normalized to
   `- TELEMETRY` (accepted — reads as a range, dprint's canonical shape).
   deadnix stripped one unused node arg in parsedmarc-e2e.nix —
   re-verified GREEN post-edit (cache-hit, `/tmp/parsedmarc-e2e6.log`
   EXIT:0).
5. **README STATUS banner flipped** to the 2026-10-28 pin-advance state
   (gate + buildflow claims transcript-backed). Honest sin logged: the
   banner initially cited "buildflow EXIT:0" BEFORE the run — caught
   in-flight, pulled, re-added after /tmp/bf2.log's EXIT line (the d/4
   lesson re-learned the cheap way).
6. **dmarc-eval localMail eval**: DONE (f/6 + e/2 closed).
7. **v2CpuPatches guard (e/5)**: the assertion approach is PROVEN
   IMPOSSIBLE — reading `virtualisation.qemu.options` from assertions
   recurses (its definition pulls `config.system.build.toplevel`, which
   renders assertions; two stack-trace-confirmed attempts), and an
   options-existence probe cannot discriminate VM evals because qemu-vm.nix
   declares its options in EVERY NixOS evaluation (the guard false-fired on
   provision-plan-eval, a pure eval that never boots). STRUCTURAL fix
   instead: `defaults = common.v2CpuPatches;` at TEST level in all four VM
   tests (probe-proven via a throwaway runNixOSTest: `-cpu max` lands in
   every node's options) — a node can no longer forget it. mig015/relay
   nodes get it too (harmless feature superset).
8. **CardDAV probe re-baseline**: NOT run — escalated to the owner (g/3).
9. Row 104 stays open; INBOXCLEAN banner keeps its pending note (correct —
   probes not run).
10. **dovecot2.protocols warning: GONE** (0 occurrences in the run-5 full
    log); the ledger entry carries a SUPERSEDED SURFACE 2026-10-28 note.
11. SystemNix master pull: flagged to the owner (their repo, their
    cadence; the risk note stands).
12. x86-64-v2 fleet exposure: escalated to the owner (g/2).
13. **CHANGELOG `[Unreleased]/Fixed`**: the full localMail storage-contract
    bullet landed (both root causes, both transcripts).
14. **0.16.22-as-current sweep**: CONTRIBUTING had none; TELEMETRY header
    now notes the pin ships 0.16.26; README relay row updated to
    "green on 0.16.22 and 0.16.26"; everything else is dated evidence
    under the ledger ride-along banner.
15. n/a (green path taken).
16. **FEATURES rows updated**: parsedmarc-e2e (two-shape architecture) +
    dmarc-eval (localMail eval).
17. **execStartPreCount answered**: under localMail the list holds TWO
    entries (module ini `+`-step, strip LAST) — the eval pins strip-last
    by NAME now (`parsedmarc-strip-opensearch-section`), not by count.
18. **Spool semantics pinned** in the test comment: postfix 3.11.7 local(8)
    "status=sent (delivered to maildir)" — a MAILDIR TREE at
    /var/spool/mail/dmarc (the module's mail_spool_directory default
    carries postfix's trailing-slash maildir trigger), not an mbox file.
19. Pipe lint GREEN; annotate.go check-rows n/a (no struck rows in this
    report; the tool ships only inside the archived late-pass bundle).
20. **gh auth is LIVE again** (discovered this session: `gh auth status`
    OK) — z-gen O1 is satisfied; the owner-sitting agenda otherwise
    unchanged (C43/C44/C39/C41/C46, D1/D2).
21. **z-gen plan annotated** (dated banner): C1 executed, C45 dissolved,
    C43 still owner-gated; C2's C45 branch moot.
22. **#563651 follow-up comment**: unblocked by auth, but the TODO row
    itself requires owner go-ahead + verify-before-filing + github-voice —
    escalated with the g-questions rather than posted unilaterally.
23. **CA SAN note pinned** in the cert fixture comment: the load-bearing
    SAN is IP:127.0.0.1 and Python's ssl DOES verify IP SANs (login proof
    transcripts runs 2-3).
24. Housekeeping: /tmp artifacts stay throwaway by design; the presence
    evals live in flake.nix comments.

Honesty addendum to (d): the `rg -r` hook trap fired a FOURTH time on this
host this session (`rg -rln` during the defaults research — blocked, no
damage; the rule is in AGENTS.md AND was in context. Muscle memory is the
enemy).

## Appendix 2 — owner verdicts executed (2026-10-28 ~21:50 CET)

The g-questions were answered mid-session; everything below is
transcript-backed.

1. **g/3 CardDAV probe: RUN — 17/18 PASS on 0.16.26, baseline reproduced**
   (the one FAIL is the identical T04.4 server fact). Demo VM booted via
   `extendModules` on host port 28080 (18080 squatted by an unrelated
   `webphone` process — not ours to kill); transcripts +
   `probe-port.diff` (the exact one-line delta vs the 10-19 suite) in
   `docs/probes/2026-10-28-carddav-01626/`; INBOXCLEAN + README +
   FEATURES re-pinned; TODO row 104 closed (re-arms at next bump).
2. **g/2 v2 fleet guard: HANDLED — upstream, in the wrapper.**
   `stalwart-cpu-preflight.service` (boot-time oneshot, Before= +
   RequiredBy= stalwart, glibc v2 flag set) in `modules/mail-server.nix`:
   every consumer inherits it (SystemNix wrapper, pbx direct import,
   demo); SystemNix needs NO local copy. The demo boot caught a real
   false positive before any gate ran (SSE3 is `pni` in /proc/cpuinfo —
   the substring "sse3" only ever appears inside "ssse3") and the fix is
   live-proven (preflight Result=success, stalwart active, 0.16.26).
3. **g/1 C43: CUT — v0.5.0 RELEASED.** Procedure per CONTRIBUTING:
   A1 CHANGELOG audit clean -> cut commit `06ab701` (rename + SECURITY
   bump, same-call commit) -> A2 release-tree proof (flake check EXIT:0,
   buildflow EXIT:0 after replacing the jscpd-flagged archived probe
   script copy with `probe-port.diff`) -> tag -> push -> **tag CI red
   TWICE** (bind-e2e `guarded`: 20s TimeoutStartSec killed provision
   before the named refusal on a stalled CI boot; the master run of the
   same commit was a CACHE HIT and never executed it - "green" was not
   execution) -> fix (ceiling 60s, local green) -> **tag MOVED to the
   fix commit BEFORE the release existed** (delete + re-tag + push,
   never after publish) -> **tag CI GREEN** -> `gh release create`
   (not draft, Latest, pin-evidence footer: rev fe132422, narHash
   advanced from v0.4.0 by design). C43 verdict recorded in
   decision-batch; z-gen banner updated (A-lane executed, A3 skipped in
   favor of the real cut).
4. **#563651: ON HOLD per owner** (draft review before posting) -
   recorded in TODO row 100. gh auth is LIVE again (z-gen O1 satisfied).
5. Lesson harvested: a CI "green" that is a cache hit is NOT execution
   evidence for a NEW derivation - the release gate must read the run's
   step LOGS (build lines present), not just the conclusion. The
   tag-run reds were only visible because the tag run missed the cache
   the master run hit.
