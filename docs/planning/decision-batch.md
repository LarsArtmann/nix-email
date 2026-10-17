# Decision Batch — every open call, one page

| Field         | Value                                                                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Date          | 2026-09-22 (execution session)                                                                                                              |
| Purpose       | Unblock the 19 decision-gated todos (Pareto plan M2; plan file `archived/2026-09-22_19-23_pareto-master-plan-super-email-monitoring.md` §1) |
| How to answer | Reply with the decision IDs (`D1: retire`, `C24: discord`, ...). Defaults marked **[rec]** execute on your go.                              |

## The big two (gate ~15 todos incl. the entire production build-out)

### D1 — Google Workspace fork

Retire Workspace mailboxes for the Stalwart VPS, or keep Workspace and run only
the parsedmarc/monitoring half?

- **[rec] Retire** (the whole ROADMAP theme 1-3 build-out assumes it; monitoring-only leaves the DR/backup/canary work half-built).
- Unblocks: M22 provisioning+DKIM, M23 backup/DR, M24 DNS Terraform, M25 migration+cutover, M26 DMARC-live+OIDC, C12 live rua validation, C14 secret rotation, C43-C51.
- Cost of delay: the "super system" end state stays a test-fleet; monitoring keeps running against reports that only exist because Workspace still sends mail.

### D2 — VPS placement and budget

Hetzner project/location, size ceiling (CX22-class?), backup target (evo-x2 btrfs pool vs StorageBox).

- **[rec]** CX22 at the same project as the domains repo; backup to the evo-x2 btrfs pool with a StorageBox second copy later.
- Unblocks: M23 backup target choice, M24 module defaults, firewall/port-25 request calendar.
- Cost of delay: blocks M22-M26 even after D1 lands.

## Session questions (from the 2026-09-22 status report)

### C24 — Alert channel (non-mail rule: alerts must not ride the mail stack they watch)

- **[rec] Discord** via the existing SystemNix DiscordSync layer (already in-fleet, phone-reachable); ntfy as fallback.
- Unblocks: M11 taxonomy routing table, M15 auth alerts, M12 queue alerts, M13 dead-man switch.

### C29 — Round-trip canary vantage (send→receive SLO probe)

- **[rec] evo-x2** (residential, independent network + DNS path; cron/systemd timer sending via Resend to a canary mailbox, asserting delivery SLO).
- Unblocks: M18 canary implementation.

## Repo policy (2-min answers)

### C18 — Branch-protection bypass

Pushes currently bypass the required `nix flake check` ("Bypassed rule violations" on push). Keep for auto-commit-daemon velocity, or strict?

- **[rec] Keep bypass** for `master` (the daemon + CI-red-on-preexisting-failures history makes strict mode high-friction), but require the check on any protected future branch.

### C19 — Renovate

Install the GitHub app or drop `renovate.json`? App NEVER ran on this repo (verified 2026-09-16); Dependabot already covers github-actions.

- **[rec] Drop the config** (dead config is drift; Dependabot just opened its first branch `dependabot/github_actions/actions-b7aede57ad`, proving the coverage path works).

### C20 — mailsuite STARTTLS issue

File the prepared draft (`docs/planning/mailsuite-starttls-issue-draft.md`, all 5 verify-before-filing gates PASSED) or skip?

- **[rec] File it.**

### C22 — GitHub Discussions

- **[rec] Keep issues-only** (single-maintainer repo; Discussions = another inbox).

### C34 — Webmail: goal or non-goal? (new question, 2026-09-22)

Stalwart ships a webadmin, not a user webmail. Roundcube/SnappyMail would be a new service in the wrapper's scope.

- **[rec] Non-goal for the wrapper** (consume via IMAP/JMAP clients; revisit only on a real demand signal). Record in ROADMAP non-goals.

## ROADMAP Q-answers (30-sec each)

### Q4 — README ops-detail level

Public README carries go-live runbook detail (migration window, DR design) with recon value.

- **[rec] Keep as-is** until D1 lands, then re-decide with the runbook actually exercised.

### Q5 — Declarative provisioning philosophy

`services.mail-server` grows `domains`/`accounts` options (idempotent oneshot vs management API), or account state stays imperative/webadmin?

- **[rec] Add the options** — the e2e already provisions via `POST /api/principal` mechanically; declarative is the NixOS contract and makes the demo/canary reproducible. (Same verdict powers M22.)

### Q6 — Spam/Junk ownership (0.15.5 tags `X-Spam-Status` but never files to Junk; settings-sieve cannot fileinto — source-verified wall)

(a) wrapper-owned JMAP provisioning automation, (b) user-managed sieve per account, (c) tag-only documented end state, (d) upstream feature request then revisit.

- **[rec] (c) now + (d)** (ROADMAP's standing recommendation); filing C21 upstream follows automatically.

### Demo-VM residue (report 21-07 g1/g2)

- **g1 Host port:** keep `18080` host-forward (an unidentified process owns `:8080` on this host) — **[rec] keep 18080 permanently**.
- **g2 dmarc-monitor in the demo:** against a local Mailpit sink (faked rua mail) — **[rec] yes, add it after the hostfwd hang is fixed** (makes the demo the full-stack story).

## Cross-repo approvals

### C17 — SystemNix push + CI debt + cache sweep

- **[rec] Approve push** once the pin question below is answered; CI debt list triaged in the same pass.
- CORRECTED 2026-09-22: there is NO tag pin to bump — SystemNix's input floats `github:LarsArtmann/nix-email?ref=master` (flake.nix:671, verified today; the old "pins v0.2.0" claim was stale). What I did locally (committed by the daemon, UNPUSHED): added the `flake-parts` dedupe follow + relocked (nix-email now 2659abb); `nix-email-contract` check GREEN. Open calls: (a) hard-pin the URL to `?ref=v0.3.1` per this repo's pin-discipline doctrine, or keep floating master; (b) the push itself (~1 commit here + the fleet's ~47-commit CI-debt backlog).
- UPDATE 2026-09-23: `v0.4.0` is cut, pushed, and CI-green (full `nix flake check` on the tag, 8m32s) — the stable ref C17a was waiting for now EXISTS (`?ref=v0.4.0`). The recommendation above is executed; only the SystemNix-side pin choice and push remain (user-gated, T16-T19 class).
- EXECUTED 2026-10-05 (Agent-execution adoptions below): SystemNix pushed through `c6aaa6c5` with the input HARD-PINNED `?ref=v0.4.0` (contract check green against the tag). This entry is CLOSED pending owner ratification.

### C16-adjacent — Resend account actions (not strictly decisions; user actions)

The SASL shape is now DOC-VERIFIED (resend.com/docs/send-with-smtp, 2026-09-22):
`smtp.resend.com`, username `resend`, password = API key, 587 STARTTLS /
465 implicit — exactly the wrapper relay shape. Still needs FROM LARS:
(a) an API key for the one live :587 smoke (TODO row), (b) webhook
endpoint setup for outbound bounce/complaint telemetry (MONITORING.md row 14).

## Cross-repo integration (2026-09-30 InboxClean JMAP session; harvested 2026-10-05)

### C35 — JMAP spike sequencing: start now on the demo VM, or hold until D1/D2 land?

The demo VM is a complete test bed (host-smoked 2026-09-22; JMAP rides the
already-forwarded HTTP listener on :18080), so the spike is technically
unblocked today; the real mailbox it will eventually serve appears only
after the production cutover.

- **[rec] Start now** (S/M effort, de-risks the adapter early; production enablement stays D1-gated regardless). Unblocks the four JMAP-seam TODO rows.

### C36 — Deployment topology: where do InboxClean + the corpus live?

evo-x2 at home, or the VPS beside Stalwart? Decides where THE backup
physically lives, its DR design, row-175 deployment, and the auth path
(LAN/tunnel vs public).

- **[rec] evo-x2** (corpus-as-backup wants a failure domain independent of the VPS; the Gatus section already treats evo-x2 as the always-on home box). Final call can ride the D1/D2 sitting.

### C37 — InboxClean build order: adapter-first (row 173) or corpus-first (row 174)?

The corpus does NOT depend on JMAP (it can be built and fed from the Gmail
adapter alone) — ADR-023's build order is a choice, not a constraint.
Corpus-first delivers "backup ALL emails" sooner; adapter-first de-risks
the Stalwart dependency sooner.

- **[rec] Corpus-first**, with the JMAP spike running in parallel (it is S/M and demo-VM-bound, so it does not compete for the same block).

### C38 — Daemon flush policy at session end (recurring; from the 17-15-11 and 09-29 reports)

Wait-for-push before yielding (verifiable CI-green handoff) or keep riding
the auto-commit daemon's own cycle?

- **[rec] Keep riding the cycle** (zero friction; the sync + CI-green state is verifiable at the NEXT session start — as verified 2026-10-05). Answering retires the recurring "push posture unknown at yield" note.

### C14 — Rotate the 3 placeholder secrets (SystemNix `nix-email.yaml`)

Gated on D1 (rotation-due check before live enablement). **No recommendation needed** — it executes as part of M22/M26 when D1 lands.

### Next release tag — cut `v0.4.0` now or batch? (new 2026-09-22) — RESOLVED 2026-09-23

`[Unreleased]` carries a release-worthy payload: M14 hardening options, fleet eval guards, `module-import-eval`, TLS-RPT e2e, the nixpkgs pin advance (+ workaround retirement).

- **[rec] Cut `v0.4.0` now** — checkpoints the pin advance for the fleet and gives SystemNix's hard-pin call (C17a) a stable ref to pin to. ~~RESOLVED: user approved 2026-09-23; v0.4.0 cut, pushed, tag CI green, GitHub release published (Latest).~~

### C39 — MemoryMax ownership (new 2026-10-16, from the nix-review session)

Neither wrapped service sets `MemoryMax`; upstream doesn't either (verified in
the pinned nixpkgs module 2026-10-05). A mail server's legitimate memory
scales with its store, so a wrong default OOM-kills delivery — but leaving it
unset forever means a runaway stalwart is bounded only by the host.

- **[rec] Consumer-layer ownership**: the wrapper ships NO `MemoryMax`
  (same doctrine as sops/Gatus/onFailure — deployment policy belongs to the
  consumer layer); record the decision in THREAT_MODEL.md + the module
  headers so the next review stops re-finding it.
- Unblocks: closes the nix-review session's one open policy finding
  (11-53 report f/1 + g/1).
- Cost of delay: every future nix-review re-flags it; unbounded stalwart on
  the future VPS.

### C40 — v0.5.0 release timing (new 2026-10-16, carried from the 11-14 report g/1)

> SUPERSEDED-BY-SCOPE 2026-10-17: the release is now the BREAKING 0.16
> upgrade - the timing question folded into **C43** (ship the vendored
> module vs wait). Answer C43; this entry remains for the record.

CHANGELOG `[Unreleased]` is release-ready: JMAP subtest + `docs/INBOXCLEAN.md`

- probe transcripts, CI hardening pair (md-table-pipe lint, statix step,
  pre-push inventory mirror), `flake.nix` split, parsedmarc breadth fixtures,
  `scripts/host-parse-fixture.py`, `demo-eval`, SECURITY.md.

* **[rec] Cut now** — the payload is a release-worthy surface and the
  SystemNix hard-pin (`?ref=v0.4.0`) would happily ride a newer tag.
* Unblocks: the v0.5.0 TODO row; the next docs-health pass boundary.
* Cost of delay: `[Unreleased]` keeps growing; consumers pin a stale tag.

### C41 — AGENTS.md size floor (new 2026-10-16, F22.3 verdict call)

AGENTS.md sits at ~23.5 KB (measured 2026-10-16; 22.8 KB before that
day's docs pass) — above the 15 KB skill target, below the 30 KB flag.
The 2026-10-05 diet verdict stands: the current size is the floor without
deleting distinct paid-for lessons.

- **[rec] Accept the current size as the floor** (no enforced budget, no
  gate); re-visit only if the flag threshold (30 KB) approaches.
- Unblocks: retires the recurring F22.3 line from every docs pass.

## What is NOT a decision

- Q7 (demo VM boundary): RESOLVED 2026-09-17 — demo VM lives in THIS repo.
- Q8 (tag cadence): RESOLVED 2026-09-17 — `v0.3.1` cut.
- TLS-RPT / telemetry / RBL / rate-limit / expiry / audit / autoconfig wiring: not user-gated — execution follows the M9 verify verdicts (this session).

## Agent-execution adoptions (2026-10-05 full-execution mandate)

The owner mandate for the 2026-10-05 session was "execute the WHOLE
plan". T1/T2 are owner calls, so agent work adopted the staged `[rec]`
ONLY where unblocking required it, and every adoption below is
reversible (re-answering the entry supersedes it). Entries NOT listed
here stay OPEN owner calls.

- **C35 (JMAP spike: start now)** — ADOPTED `[rec] start-now` and
  EXECUTED same day: demo-VM probe transcripts
  (`docs/probes/2026-10-05-jmap-demo-vm/`), push-vs-poll verdict +
  `docs/INBOXCLEAN.md`, JMAP e2e subtest in `stalwart-e2e`. All four
  High-impact JMAP rows closed.
- **C17a (SystemNix pin: hard-pin `?ref=v0.4.0`)** — ADOPTED `[rec]` and
  EXECUTED in the SystemNix repo (pinned, lock updated,
  `nix-email-contract` green against the tag, pushed). Reversible:
  re-floating is a one-line input change.
- **C17 (SystemNix push)** — EXECUTED: the 12-commit backlog + the pin
  - the statix sweep are pushed (through c6aaa6c5).
- **C20 (mailsuite filing: file it)** — ADOPTED `[rec] file it` and
  FILED as seanthegeek/mailsuite#65 (gates re-verified same day).
- **C38 (daemon flush: ride the cycle)** — FOLLOWED implicitly: the
  daemon raced several commits; nothing was suppressed or force-flushed.
- **Q6 (spam→Junk)** — the "upstream ask" half is MOOT (Gate-2 verdict:
  auto-move exists upstream since 0.5.0; see the TODO row); the
  "tag-only now" half stays as recorded. RESIDUE RESOLVED 2026-10-05:
  there IS no 0.15.5 setting name - the auto-move is hard-coded in
  crates/email/src/message/ingest.rs:344 (INBOX-targeted deliveries of
  spam-verdict messages go to JUNK_ID), gated only by
  `spam-filter.enable` + the score thresholds (README ledger). A wrapper
  `junkFiling` option is therefore NOT implementable as a Stalwart
  setting; Q6 can be closed on the facts, owner ratification pending.

Explicitly still blocked, for the record: T17 (needs the real Resend
API key), T19 (needs explicit force-push approval), T20 (D1/D2 +
production infra), T21 (C24/C29 monitoring encoding calls).

## Stalwart 0.16 batch (new 2026-10-17, docs-health pass; the upgrade landed 2026-10-16/17)

### C42 — `services.dmarc-monitor` retire-or-keep, 0.16-conditioned

Stalwart 0.16 natively imports inbound DMARC **and TLS** aggregate reports
(DMARCbis - RFC 9989/9990/9991 - added in 0.16.12; live-verified against the
upstream tagged CHANGELOG 2026-10-16, 08-26 report a/6). parsedmarc still
uniquely owns: inbound forensic/failure-report parsing (the one unknown:
whether 0.16 PARSES inbound failure reports - one stalw.art docs fetch
settles it), file-sink outputs, arbitrary-mailbox polling, and the
watcher-outside-the-watched decoupling.

- **[rec] Keep through 0.16 stabilization**; re-decide once the live webadmin
  exists (D1) and the 0.16 native report surface has been inspected hands-on.
- Cost of delay: the wrapper may be partially redundant on 0.16; the
  rationale text in README/FEATURES carries the 0.16 caveat meanwhile.

### C43 — v0.5.0 release doctrine: ship the vendored module, or wait?

The 0.16 upgrade VENDORS nixpkgs PR #552103 (rev `9b15e1f`) under
`modules/stalwart-module/` with two documented patches (meta.doc dropped;
`partOf` dropped + `ExecStartPost` stalwart restart). SystemNix hard-pins
release tags, so this decides when the consumer fleet can move to 0.16.

- **[rec] Cut v0.5.0 WITH the vendored module** once the gate is green (the
  fleet is pinned to v0.4.0 = the 0.15 world; vendoring is the only current
  0.16 delivery; the retirement trigger + checklist live in the module
  header and README "0.16 provisioning").
- Cost of delay: consumers stuck on 0.15.5 while the vendored tree sits green.

### C44 — Real-host account-secrets pattern on 0.16

0.16 provision plans carry account passwords in the world-readable Nix store
(0.15 exposed only salted hashes). Options: (a) sops-rendered runtime
`stalwart-cli apply`, (b) admin-created accounts (WebUI/CLI), (c) a
credential-file secret type wired through the wrapper.

- **[rec] (b) for interactive accounts + document (a) for automation**; build
  (c) only on a real consumer demand signal. Record in THREAT_MODEL.md when
  answered.
- Cost of delay: SystemNix hosts have no blessed pattern at the v0.5.0 pin
  advance.

### C45 — Stalwart package version: 0.16.22 (pin) vs overlay 0.16.26

The pinned nixpkgs rev ships `stalwart_0_16` 0.16.22 with two known bugs: the
reload-doesn't-rebind-listeners gap (upstream #352, open since 2024 - our
ExecStartPost patch covers it) and the broken default DNSBL rows (fixed
upstream in 0.16.23, commit `87de8601` - our always-reconcile makes it moot
here). 0.16.26 requires x86-64-v2 and drifts from the consumer pin.

- **[rec] Stay on 0.16.22 for v0.5.0**; revisit an overlay only if a 0.16.22
  bug bites in production.
- Cost of delay: none today (both bugs are neutralized in-tree).

### C46 — Deploy-time provision-restart flap tolerance

The vendored unit restarts stalwart after every successful apply (listeners
do not re-spawn on reload - transcript-verified), so every plan-changing
deploy bounces the mail ports for a few seconds. Accept as-is, or gate the
restart on a plan-hash change (store the last-applied hash and skip no-op
restarts)?

- **[rec] Accept for v0.5.0** (mail queues absorb a seconds-long flap; the
  hash gate adds statefulness for a single-host fleet).
- Cost of delay: cosmetic.
