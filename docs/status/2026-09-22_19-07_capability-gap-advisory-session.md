# Capability-Gap Advisory Session — Status Report

| Field                       | Value                                                                                                                |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Date                        | 2026-09-22 19:07 CEST                                                                                                |
| Session type                | **Read-only advisory** — zero code/config changes until this report file                                             |
| Scope                       | 3 turns: capabilities question → monitoring-gap analysis → this report                                               |
| Repo state at session start | `master`, working tree **clean**, HEAD `b54f5c3` (auto-commit daemon), tags `v0.1.0`–`v0.3.1`                        |
| Commits made this session   | 0 by the agent (this file goes to the auto-commit daemon; no manual commit per Crush contract)                       |
| Tests run                   | None — nothing was changed that could break                                                                          |
| Research discipline         | Honored per instruction: SystemNix repo, `docs/THREAT_MODEL.md`, `docs/TELEMETRY.md` content deliberately NOT opened |

---

## Straight answers to the three headline questions

### What did you forget?

1. **The threat model.** Answering "what's missing for a super email system" (turn 2) without consulting
   `docs/THREAT_MODEL.md` risks re-inventing or contradicting abuse/detection items already modeled there.
   Gap #3 (inbound abuse defense), #7 (capacity/retention), #10 (IR switches) overlap-risk: **unverified**.
2. **Memory protocol timing.** The 10-gap analysis existed ONLY in chat until this report. The aggressive
   update protocol says route at the moment of discovery — the gaps should have been appended to
   `ROADMAP.md` raw ideas in turn 2, not held for a status report. This is the exact entombment trap the
   status-report skill warns about; a session ending one turn earlier would have lost the analysis.
3. **A 2-command freshness anchor.** `git tag` + `git log` in turn 2 would have exposed immediately that
   `v0.3.1` already exists — making TODO_LIST's "pin bump blocked, tag is not cut" row and ROADMAP Q8
   stale. Instead the drift surfaced only during THIS report's state check. Advice in turn 2 was built on
   docs last swept 2026-09-17 without checking reality first.
4. **Epistemic labels.** The gap answer stated "parsedmarc can parse TLS reports (verify against the
   pinned version)" from memory, with no source pointer. The repo doctrine (no assertion without
   transcript; verify-external-claims) deserved explicit `[verified]`/`[assumed]` markers on every claim.
5. Minor: turn 1's chat summary omitted devShell/formatter/Renovate details (recovered in this report via
   FEATURES.md; the substance was right).

### What could you have done better?

- **Route-as-you-go** instead of report-later (see forget #2).
- **Verify before claiming**: two library-capability claims (parsedmarc TLS-RPT; Stalwart 0.15.5 knob
  existence for items 15/16/21/22/25) were flagged "verify" but never even source-pointed. A grep of the
  pinned sources or the README ledger would have upgraded or killed them in minutes.
- **Decision-ready output**: the Pareto recommendation was a chat table; it should have been drafted as
  ROADMAP open-question text so the user decision (alert channel, canary vantage) lands in the repo's
  decision ledger, not in scrollback.
- **Anchored advising**: run the freshness anchor BEFORE answering "what should we do next" so the answer
  doesn't inherit stale-doc drift.

### What could you still improve?

- **Monitoring coverage matrix**: FEATURES.md inventories features, nobody owns a single table of
  "observable today / planned / gap" across metrics-logs-alerts-DR. This session produced the raw
  material (10 gaps) but the repo has no home where that state stays current (proposed item #29).
- **ROADMAP theme 4 shape**: it is a bullet pile; reorganizing around detect → alert → respond → verify
  would make future gap-additions piecemeal-free (item #30).
- **Claim-labeling convention** for advisory answers (`[verified]` / `[assumed]` / `[verify-needed]`) so
  follow-up execution sessions start from a known epistemic state.
- **Advisory-session ritual**: freshness anchor (`git tag`, `git log`, TODO sweep date) before advising.

---

## a) FULLY DONE

Work that is verifiably complete this session, with evidence.

| # | Item                                                                                                                                                                                                                                                 | Evidence                                                                                                                                                                                                  | Scope               |
| - | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| 1 | Capabilities answer ("what can this project do") — honest, status-quoted, no round-up                                                                                                                                                                | `FEATURES.md` read in full; answer reflected PARTIAL/PLANNED rows verbatim (dmarc-monitor live polling 🟡, declarative provisioning ⚪, VPS ⚪)                                                           | Chat answer, turn 1 |
| 2 | Capability-gap analysis for a "super email management & monitoring system" — 10 gaps, each labeled Gap / Partial / Undecided against ROADMAP evidence, plus Pareto-3 (TLS-RPT consumption, outbound deliverability telemetry, inbound abuse defense) | `ROADMAP.md` themes 1–5 + non-goals cross-checked; `TODO_LIST.md` rows cross-checked; existing plans (Gatus, Prometheus, RBL self-reputation, TLS-RPT publishing) subtracted so no duplicate was proposed | Chat answer, turn 2 |
| 3 | Status report authored per skill, format `.md` (user override of the HTML default), date-anchored, repo-state-anchored                                                                                                                               | `date` → 2026-09-22 19:07; `git status` clean; `git tag -l` → v0.1.0…v0.3.1; this file                                                                                                                    | This file           |
| 4 | Out-of-scope research discipline honored                                                                                                                                                                                                             | No opens of SystemNix, THREAT_MODEL, TELEMETRY despite them being adjacent and one command away                                                                                                           | Session-wide        |

## b) PARTIALLY DONE

| # | Item                            | What works                                                     | What remains                                                                                                                               | Blocker                           | Effort   |
| - | ------------------------------- | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------- | -------- |
~~| 1 | Gap analysis → living docs      | Analysis delivered (10 items, in section f below)              | 0 of 10 routed into `TODO_LIST.md`/`ROADMAP.md`; HARVEST deliberately NOT run (user said WAIT FOR INSTRUCTIONS)                            | User go-ahead                     | S        |~~ routed + done - the 10 gaps were consolidated into the 19-23 master plan (C24-C42) and executed by the 21-10/22-50 sessions (MONITORING.md, M14 options, ledger (a)-(h))
~~| 2 | Verification debt on gap claims | Gaps labeled with verify-need                                  | parsedmarc TLS-RPT support unverified; THREAT_MODEL/TELEMETRY overlap unchecked; Stalwart 0.15.5 knobs for items 15/16/21/22/25 unverified | None — but must precede wiring    | S–M each |~~ done - the M9 verify pass closed it: TLS-RPT verified AND wired e2e (21-10 a/8); Stalwart 0.15.5 knobs source-verified into README ledger (a)-(h)
~~| 3 | Repo-state anchoring            | Tags/HEAD/log/tree checked this turn                           | Whether SystemNix actually bumped its pin past v0.2.0 (consumer repo — out of scope by instruction, flagged only)                          | Scope instruction                 | S        |~~ done - SystemNix floats ?ref=master (the v0.2.0-pin premise was WRONG; corrected 2026-09-22 in README/FEATURES/AGENTS/decision-batch)
~~| 4 | Drift findings                  | Observed directly (`git tag` contradicts TODO_LIST/ROADMAP Q8) | Not yet swept into corrections; not deep-verified (e.g. whether the 21-07 demo-VM hostfwd hang is still open)                              | User go-ahead (item #4/#5)        | S        |~~ done - ROADMAP Q8 closed + pin-bump row fixed (21-10 a/13); hostfwd-hang recorded then ROOT-CAUSED + FIXED (02-58 a/3)
~~| 5 | This report                     | Complete below                                                 | HARVEST of section (f) into TODO_LIST/ROADMAP pending                                                                                      | Explicit user instruction to wait | S        |~~ done - section (f) routed via the 19-23 master plan C01-C57 (its Sources field names this report)

## c) NOT STARTED

Everything in section (f) is unstarted — grouped by WHY, since "not started" without a reason is noise:

| Group                                                  | Items                  | Why not started                                                                         |
| ------------------------------------------------------ | ---------------------- | --------------------------------------------------------------------------------------- |
| Verified bounded backlog (pre-existing TODO_LIST rows) | #1–3, #6–10            | Session was advisory; execution never requested                                         |
| Session-discovered gaps                                | #11–17, #19–26, #28–31 | Discovered THIS session; analysis only                                                  |
| Drift repairs                                          | #4–5                   | Noticed this turn during report state-check; awaiting go                                |
| D1-gated (live enablement)                             | #32–45                 | Hard-gated on the D1/D2 user decisions (ROADMAP open questions 1–2)                     |
| User-decision gates                                    | #23, #46–50            | Q6/Q7/bypass/Renovate/mailsuite — Lars's calls, drafts/recommendations already recorded |

## d) TOTALLY FUCKED UP

Radical honesty. Nothing this session BROKE (zero mutations), but these are fucked and in-scope-noticed:

1. **CVE coverage is ZERO.** vulnix 1.12.5 crashed fleet-wide (NVD retired the legacy JSON feeds), the
   scan is skipped in `.buildflow.yml`, and no replacement scanner exists yet (ROADMAP §5 waits on
   BuildFlow). Severity: silent — the mail stack ships unaudited against CVEs. Mitigation: none in-repo.
2. **Living docs contradict observed reality.** `git tag` shows `v0.3.1` exists; TODO_LIST still carries
   "SystemNix pin bump blocked — the tag is not cut" and ROADMAP open question 8 still asks "cut a fast
   v0.3.1 or batch?" — a question reality already answered. Severity: medium — the next execution session
   can burn time re-deciding an answered question. Evidence: tag listing vs TODO_LIST row (sweep 09-17
   morning) vs the `2026-09-17_21-07_v031-release-…` report title.
3. **In-flight work with no TODO row.** The 09-17 21:07 report title references demo-VM work AND a
   "hostfwd hang"; TODO_LIST contains no demo-VM/hostfwd row. If that investigation is open, its state
   lives only in a timestamped file. Severity: medium (context loss risk). Needs the #5 sweep to verify.
4. **The CI contract is advisory, not enforced.** Pushes bypass the required `nix flake check`
   (branch-protection "Bypassed rule violations", recorded in TODO_LIST). A red gate can reach master and
   consumers pin it. Policy decision still open (item #48).
5. **Session process fuckup (mine):** roadmap-fuel held chat-only for the entire session until this
   report — the entombment trap, self-inflicted (see forget #2).

## e) WHAT WE SHOULD IMPROVE

| # | Improvement                         | Pain today                                                                      | Concrete fix                                                                                              |
| - | ----------------------------------- | ------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
~~| 1 | Route-as-you-go for roadmap-fuel    | Analyses die in chat/scrollback                                                 | Append raw ideas to ROADMAP.md in the same turn they are produced; HARVEST only for bounded items         |~~ done(practiced) - later sessions route at discovery (21-10/22-50 folded their findings straight into living docs)
| 2 | Epistemic labels on advisory claims | Follow-up sessions can't tell verified from assumed                             | Convention: tag every factual claim `[verified: source]` / `[assumed]` / `[verify-needed: how]`           |
| 3 | Freshness anchor before advising    | Advice inherits stale docs (v0.3.1 drift proved it)                             | 3-command ritual at advisory-session start: `git tag -l`, `git log --oneline -5`, TODO sweep-date check   |
~~| 4 | Single monitoring-coverage matrix   | Gap state scattered across ROADMAP bullets + chat                               | `docs/TELEMETRY.md` companion table: observable today / planned / gap × metrics/logs/alerts/DR (item #29) |~~ done - docs/MONITORING.md (see f/29)
~~| 5 | ROADMAP theme 4 structure           | Monitoring ideas accrete as an unstructured pile                                | Reorganize around detect → alert → respond → verify (item #30)                                            |~~ done - detect → alert → respond → verify (21-10 a/11)
~~| 6 | TELEMETRY skew debt                 | `docs/TELEMETRY.md` keys unverified against pinned 0.15.5; blocks items #26/#27 | One verification pass against the binary/config schema, then remove the skew caveat                       |~~ done(core) - metrics/tracing/autoconfig/expiry/audit keys source-verified 2026-09-22 (ledger (a)-(f)); webhooks/alert-objects remain flagged (TODO_LIST docs-audit row)
~~| 7 | Threat-model ↔ roadmap consistency  | Gap lists can duplicate or contradict THREAT_MODEL                              | Cross-check pass (item #31) + future gap analyses must read it first                                      |~~ done - MONITORING threat-model cross-check table (21-10 a/9)

## f) Top 50 things to get done next

Ranked by impact within four tiers; Source: **T**=TODO_LIST row, **S**=session gap, **R**=ROADMAP idea,
**D**=drift noticed this session. Effort: S <30min, M 30min–2h, L >2h. **These are brainstorm+backlog,
not a commitment list — HARVEST routing rigor applies (extra items → ROADMAP raw ideas).**

### Tier 1 — Quick, verified, no gates (do first)

| #  | Task                                                                                                                     | Source | Impact | Effort | Category      |
| -- | ------------------------------------------------------------------------------------------------------------------------ | ------ | ------ | ------ | ------------- |
~~| 1  | Eval guard asserting our pinned nixpkgs rev equals SystemNix's pin (mechanize the compat doctrine)                       | T      | High   | M      | Quality       |~~ done - SHIPPED: flake.nix pin-identity eval guard, negative-tested (21-10 a/1)
~~| 2  | Eval guard asserting `flake-parts/nixpkgs-lib` still `follows = "nixpkgs"` in the lock                                   | T      | Med    | S      | Quality       |~~ done - SHIPPED: follows-guard in flake.nix (21-10 a/1)
~~| 3  | `checks` entry: `nixosModules.default` imports cleanly via `nixosSystem` on both arches                                  | T      | Med    | M      | Quality       |~~ done - SHIPPED: checks.module-import-eval on BOTH arches (21-10 a/4; CHANGELOG 0.4.0)
~~| 4  | Docs-drift sweep: close ROADMAP Q8 ("cut v0.3.1?") and fix the TODO pin-bump blocker row — `v0.3.1` exists per `git tag` | D      | High   | S      | Documentation |~~ done - Q8 closed + TODO pin row fixed (21-10 a/13)
~~| 5  | Reconcile demo-VM/hostfwd-hang state from the 21-07 report into TODO_LIST (row exists or explicit done)                  | D      | Med    | S      | Documentation |~~ done - row recorded (21-10 a/13), then ROOT-CAUSED + FIXED with host smoke (02-58 a/3-a/5)
~~| 6  | Relay `queue.route` IfBlock hardening (indexed keys, resolvable hostnames)                                               | T      | Med    | M      | Bug           |~~ done - verified PRE-EXISTING (21-10 a/5: indexed keys + hostname assertion already present; row stale)
~~| 7  | Over-quota surface: decide + write the consumer warning/doc (accept-at-RCPT, retry-forever behavior)                     | T      | Med    | M      | Documentation |~~ done - swept by verdict: README documents accept-at-RCPT/retry-forever; no option owed (21-10 a/18)
~~| 8  | Catch-all ordering footgun: module-level assertion or ledger-linked doc note                                             | T      | Med    | S      | Quality       |~~ done - README "Per-account semantics" ordering footgun landed (02-58 a/10)
~~| 9  | Investigate why `nix flake lock` evaluates `checks` far enough to die on a broken flake                                  | T      | Med    | S      | Bug           |~~ done - SOLVED: lock fails only on parse-time scope errors, never output eval (21-10 a/6; AGENTS.md)
~~| 10 | Watch the four upstream filings (nixpkgs #563651/#563652/#563777, mjs/imapclient #662/#663)                              | T      | Med    | S      | Chore         |~~ done - standing watch; #663 MERGED 2026-09-18 evidence propagated (02-58 a/1); nixpkgs trio still open (TODO_LIST row)

### Tier 2 — Session-gap work: observability & defense (verify keys on 0.15.5 before wiring each)

| #  | Task                                                                                                                                              | Source | Impact | Effort   | Category      |
| -- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | -------- | ------------- |
~~| 11 | Verify parsedmarc (pinned nixpkgs) TLS-RPT report support; if present, extend `dmarc-monitor` to consume TLS reports — closes the DNS-estate loop | S      | High   | M        | Feature       |~~ done - verified AND wired: RFC 8460 e2e asserts smtp_tls.json/csv (21-10 a/8)
~~| 12 | Alert taxonomy + routing design; hard rule: alert channel must not depend on the monitored mail stack                                             | S      | High   | S        | Feature       |~~ done(spec) - docs/MONITORING.md severity taxonomy + non-mail-channel rule (21-10 a/9); encoding C24-gated
~~| 13 | Resend outbound telemetry spike: webhooks/events (deliveries, bounces, complaints) → ingestion decision                                           | S      | High   | M        | Feature       |~~ routed - decision-batch C16-adjacent (needs Resend account; user-gated)
~~| 14 | Resend SASL shape verification + one real smtp.resend.com:587 smoke (proves `relay.secretFile`)                                                   | T      | High   | S        | Verification  |~~ routed - TODO_LIST blocked row (doc-verified shape; live smoke needs an API key)
~~| 15 | Inbound RBL usage in Stalwart filters (verify 0.15.5 config keys; document default policy)                                                        | S      | High   | M        | Feature       |~~ done - spamFilter.dnsbl.servers wrapper option shipped (typed entries; default inert - ledger (j); 22-50 a/1)
~~| 16 | Rate-limiting + auth-failure ban: verify 0.15.5 knobs, wire via settings passthrough + eval assertion                                             | S      | High   | M        | Feature       |~~ done - rateLimits wrapper option shipped; flood-node runtime trip (22-50 a/1; 02-58 a/8)
~~| 17 | Failed-auth alerting rule from Stalwart telemetry/journal (consumer-side rule definition)                                                         | S      | High   | M        | Feature       |~~ done(spec) - MONITORING §5.3 failed-auth spec; encoding C24-gated
~~| 18 | Round-trip canary design: periodic send→receive probe, message-level SLO (vantage = open question g-2)                                            | S      | Med    | S design | Feature       |~~ done(spec) - MONITORING §6 canary design; vantage decision C29-gated
~~| 19 | Dead-man switch/heartbeat on the monitors themselves (Gatus, Prometheus scrape, parsedmarc freshness)                                             | S      | Med    | M        | Feature       |~~ done(spec) - MONITORING §5.2 dead-man spec; encoding C24-gated
~~| 20 | Capacity metrics: disk growth + per-mailbox quota series from `/metrics` (verify series exist)                                                    | S      | Med    | M        | Feature       |~~ done(verdict) - 0.15.5 exposes NO queue/capacity series (transcript-proven); spec = consumer API poll (MONITORING row 2)
~~| 21 | Stalwart auto-expiry (Junk/Trash retention): verify 0.15.5 knobs, wire wrapper options + E2E assertion                                            | S      | Med    | M        | Feature       |~~ done(verdict) - auto-expunge defaults verified (30d/3d, ledger (d)); no per-mailbox Junk knob exists
~~| 22 | Client autoconfiguration: verify RFC 6186 SRV/autoconfig support; else document manual setup / DNS records                                        | S      | Low    | S        | Feature       |~~ done(verdict) - autoconfig HTTP routes present (ledger (e)); DNS/SRV record note rides the D1 DNS theme
~~| 23 | Webmail goal/non-goal: add as a ROADMAP open question (Roundcube/SnappyMail vs JMAP-only)                                                         | S      | Med    | S        | Documentation |~~ routed - decision-batch C34 (open)
~~| 24 | IR runbook: queue hold/pause switch + quarantine review workflow                                                                                  | S      | Med    | M        | Feature       |~~ done(spec) - queue hold/pause/inspect levers SOURCE-VERIFIED in MONITORING §5.4 (pinned queue.rs)
~~| 25 | Admin audit trail: verify Stalwart audit logging on 0.15.5; retention + shipping decision                                                         | S      | Med    | M        | Feature       |~~ done(verdict) - audit stream NOT AVAILABLE in 0.15.5 (ledger); tracing/journal is the surface
~~| 26 | Stalwart telemetry wiring per `docs/TELEMETRY.md` AFTER the 0.15.5 key-verification pass (skew caveat)                                            | R      | High   | M–L      | Feature       |~~ done(spec) - metrics/tracing keys source-verified (ledger (a)-(b)); webhooks/alert-objects keys still unverified (TODO_LIST docs-audit row)
~~| 27 | Queue-depth/queue-age alert rules off the Prometheus endpoint                                                                                     | R      | High   | M        | Feature       |~~ done(spec, corrected) - NO such series in 0.15.5; spec rewritten to the GET /api/queue/messages consumer poll (MONITORING row 2 + §5.4)
~~| 28 | Gatus external-view checks (starttls :25, tls :993, cert expiry) in the SystemNix consumer                                                        | R      | High   | M        | Feature       |~~ done(spec) - MONITORING §5.1 Gatus templates; implementation consumer-side (D1)
~~| 29 | Monitoring coverage matrix doc (today/planned/gap × metrics/logs/alerts/DR) beside `docs/TELEMETRY.md`                                            | S      | Med    | M        | Documentation |~~ done - docs/MONITORING.md IS the matrix (14-row signal inventory + coverage matrix; 21-10 a/9)
~~| 30 | Reorganize ROADMAP theme 4 into detect → alert → respond → verify                                                                                 | S      | Low    | S        | Documentation |~~ done - detect → alert → respond → verify reorg (21-10 a/11)
~~| 31 | Cross-check the 10 session gaps against `docs/THREAT_MODEL.md` + `docs/TELEMETRY.md` for overlap/contradiction                                    | S      | Med    | S        | Documentation |~~ done - MONITORING carries the threat-model cross-check table (21-10 a/9)

### Tier 3 — D1/D2-gated (unblocked the day the decisions land)

| #  | Task                                                                                            | Source | Impact | Effort | Category      |
| -- | ----------------------------------------------------------------------------------------------- | ------ | ------ | ------ | ------------- |
~~| 32 | dmarc-monitor live validation against the real rua mailbox (first poll, JSON/CSV lands)         | T      | High   | S      | Feature       |~~ routed - TODO_LIST D1-gated row (unchanged)
~~| 33 | Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)              | T      | Med    | M      | Verification  |~~ routed - TODO_LIST D1-gated row (unchanged)
~~| 34 | Rotate the three placeholder secrets in SystemNix `nix-email.yaml` + sops-key-audit check       | T      | Med    | S      | Security      |~~ routed - TODO_LIST D1-gated row (unchanged)
~~| 35 | Stalwart OIDC (Pocket ID) admin-UI wiring via settings passthrough                              | R      | Med    | M      | Feature       |~~ routed - ROADMAP §5 + D1-gated M26 (unchanged)
~~| 36 | Unattended provisioning oneshot: verified `POST /api/principal` recipe → systemd unit           | R      | High   | M      | Feature       |~~ routed - ROADMAP §1 + D1-gated M22 (unchanged)
~~| 37 | DKIM keygen automation (`POST /api/dkim`), keys into sops, selector rotation                    | R      | High   | M      | Feature       |~~ routed - ROADMAP §1 + D1-gated M22 (unchanged)
~~| 38 | Backup/DR build-out: `--export` timer + offsite pull + recovery-age key + MONTHLY restore drill | R      | High   | M–L    | Feature       |~~ routed - ROADMAP §1 + D1-gated M23 (unchanged)
~~| 39 | `stalwart-mail` Terraform DNS module: MX, SPF, DKIM, DMARC+rua, MTA-STS, TLS-RPT, TLSA          | R      | High   | L      | Feature       |~~ routed - ROADMAP §2 + D1-gated M24 (unchanged)
~~| 40 | rDNS automation via Hetzner API (or documented manual step)                                     | R      | Low    | S–M    | Feature       |~~ routed - ROADMAP §2 (unchanged)
~~| 41 | Canary-domain cutover runbook: TTL lowering, dual-MX window, rollback steps                     | R      | Med    | M      | Documentation |~~ routed - ROADMAP §3 + D1-gated M25 (unchanged)
~~| 42 | Post-cutover parity checks: SPF/DKIM/DMARC alignment, mail-tester, per-account parity           | R      | Med    | S      | Documentation |~~ routed - ROADMAP §3 + D1-gated M25 (unchanged)
~~| 43 | DMARC policy ladder (none → quarantine → reject) driven by parsedmarc data                      | R      | Med    | M      | Feature       |~~ routed - ROADMAP §4 + D1-gated M26 (unchanged)
~~| 44 | Paperless mail accounts off Gmail app passwords onto own IMAP; smartd alert decoupling          | R      | Med    | M      | Feature       |~~ routed - ROADMAP §4 (cross-repo, unchanged)
~~| 45 | InboxClean JMAP/IMAP spike post-migration                                                       | R      | Low    | M      | Feature       |~~ routed - ROADMAP §4 (cross-repo, unchanged)

### Tier 4 — User-decision gates (5-minute calls that unblock hours)

| #  | Task                                                                                         | Source | Impact | Effort | Category |
| -- | -------------------------------------------------------------------------------------------- | ------ | ------ | ------ | -------- |
~~| 46 | Q6 spam→Junk verdict (recorded recommendation: tag-only now + upstream feature request path) | R      | Med    | S      | Decision |~~ routed - decision-batch Q6 (open; rec: tag-only now + upstream path)
~~| 47 | Q7 demo-VM boundary verdict (product-side vs consumer-side)                                  | R      | Med    | S      | Decision |~~ RESOLVED - demo VM shipped in THIS repo (ROADMAP Q7 closed; nix run .#vm green 2026-09-22)
~~| 48 | Branch-protection bypass policy: keep daemon velocity or enforce the required check          | T      | Med    | S      | Decision |~~ routed - decision-batch C18 (open)
~~| 49 | Renovate: install the GitHub app or drop `renovate.json` (app has NEVER run on this repo)    | T      | Med    | S      | Decision |~~ routed - decision-batch C19 (open)
~~| 50 | mailsuite auto-STARTTLS issue: file the verified draft or skip it                            | T      | Low    | S      | Decision |~~ routed - decision-batch C20 (open; draft ready)

## g) Questions I cannot figure out myself

~~1. **Alert channel:** Where should mail-stack alerts land (Discord, ntfy, something else)? This gates~~ routed - decision-batch C24 (answer pending; gates MONITORING encoding rows)
   items #12/#17/#27/#28 — nothing in either repo answers the preference, and the smartd note proves the
   circular-dependency rule needs a chosen non-mail channel before routing can be designed.
~~2. **Canary vantage:** Does an external vantage point exist (or a tiny budget for one — e.g. a Resend or~~ routed - decision-batch C29 (answer pending)
   secondary-provider sender) for the round-trip canary (#18), or should it be designed vantage-less?
   This is infrastructure outside any repo; it decides whether the SLO is measured end-to-end or
   half-path only.
~~3. **HARVEST now or wait:** Section (f) is the primary input for `docs-health` HARVEST, and the drift~~ done - routed via the 19-23 master plan (its Sources field cites this report) and executed by the 21-10/22-50 sessions
   findings (#4/#5) rot while they sit here. You said WAIT FOR INSTRUCTIONS — so: on your go, do I run
   HARVEST (routing the drift repairs + Tier-2 gaps into TODO_LIST/ROADMAP), with backlog-first ordering
   (Tier 1 before Tier 2)? My recommendation: yes, Tier 1 immediately, Tier 2 as ROADMAP raw ideas.

---

_Point-in-time snapshot. Items in (f) feed docs-health HARVEST. Written 2026-09-22 19:07 CEST; session
ends here pending instructions._
