<!-- ROADMAP.md - LONG-TERM DIRECTION and raw ideas.
     No bounded tasks (those live in TODO_LIST.md), no status indicators. -->

# Roadmap

> Long-term direction and raw ideas. Items here are NOT actionable tasks.
> When an idea is refined into bounded work, it moves to TODO_LIST.md.
> Most of this is gated on the two big user decisions below - nothing here is
> commitment, it is the de-risked plan that unlocks once they land.

## Themes

### 1. Production mail delivery (gated on D1/D2)

Self-hosted inbound on a Hetzner VPS (residential evo-x2 can never be an MX),
outbound relayed through Resend. The research-as-code foundation is done and
verified; the build-out is deliberately parked until the decisions land.

Raw ideas:

- VPS host: NixOS via the domains-repo cloud-init path, rDNS/PTR, firewall
  review, log retention, disk/quota policy
- Hetzner port-25/465 limit request the day the 1-month + first-invoice gate
  clears (verified policy, README ledger - calendar it)
- Real ACME TLS replacing the self-signed default (DNS-01 or HTTP-01)
- Unattended admin bootstrap: SUPERSEDED 2026-10-17 - declarative
  provisioning SHIPPED with the 0.16 upgrade (the wrapper renders
  `services.stalwart.provision` plans; no management-API recipe needed)
- DKIM keygen automation: 0.15's `POST /api/dkim` recipe is DEAD (REST
  removed on 0.16); the 0.16 path is declarative `DkimSignature` objects
  (the server derives public keys - e2e-verified); selector rotation into
  sops stays an open idea
- Backup/DR: RE-RESEARCH OWED on 0.16 - `stalwart --export`/`--import` is
  REMOVED upstream with no replacement shipped (2026-10-16 transcript);
  the 0.15 export-timer design below is historical until a 0.16 answer
  (file-level cold copies vs a datastore snapshot mechanism) exists.
  0.15-era record: `stalwart --export` timer + offsite pull + recovery age
  key in the sops key group + MONTHLY restore drill
- Queue-depth/queue-age alerting: the `GET /api/queue/messages` lever was
  0.15.5-verified (transcript-proven 2026-09-22, MONITORING.md row 2 +
  §5.4); 0.16 removed the REST family - the 0.16 queue-observability
  surface needs re-verification before the consumer poll is built

### 2. DNS estate (gated on D1)

Terraform is the right home for mail DNS truth (the domains repo already owns
every zone).

Raw ideas:

- `stalwart-mail` Terraform module: MX, SPF (`v=spf1 mx -all`), DKIM TXT,
  DMARC with `rua`, MTA-STS, `_smtp._tls` TLS-RPT, plus TLSA records if
  DANE inbound is wanted (source-verified present on 0.15.5)
- ONE DNS owner rule: Terraform is sole DNS truth; if a 0.16+ migration
  ever brings Stalwart's automated DNS management, leave Stalwart's
  updater unconfigured (split-brain guard, master plan §10 26e)
- Canary-domain-first rollout; TTL lowering + dual-MX window + rollback steps
  before touching the other domains
- rDNS automation via the Hetzner API (or a documented manual step)

### 3. Migration and cutover (gated on D1)

- Migration tooling decision (stalwart-vandelay vs imapsync 2.314) on scratch
  mailboxes - R6, the last unexecuted research task
- Full mailbox migration BEFORE the MX switch; Workspace alive ~2 weeks as
  rollback
- Post-cutover checks: SPF/DKIM/DMARC alignment, mail-tester, parity per
  account

### 4. Monitoring, DMARC, and downstream consumers

Reorganized 2026-09-22 into the detect → alert → respond → verify arc;
the verified-source work (what the wrapper OWNS) is done or specified in
`docs/MONITORING.md`, the alerting itself is consumer-layer.

**Detect** (wrapper-owned, sources):

- dmarc-monitor live on evo-x2 against the `dmarc@` mailbox; DMARC ladder
  (`none → quarantine → reject`) driven by parsedmarc data
- Stalwart telemetry: keys SOURCE-VERIFIED in the pinned 0.15.5
  (metrics.prometheus.enable, tracing.level._, tracing.history._ - README
  ledger 2026-09-22); 0.16 CAVEAT (2026-10-17): re-verify against the
  0.16.22 binary before wiring (TODO_LIST row); TLS-RPT reports ride the
  parsedmarc rua poll (e2e-asserted 2026-09-22) - 0.16 also ingests TLS
  aggregates natively (C42 watch)
- Gatus external-view checks (starttls :25, tls :993, cert expiry) and
  Prometheus scrape of `/metrics/prometheus` via reverse proxy or tunnel
- Blacklist (RBL) monitoring for the VPS IP
- Gatus freshness check over the parsedmarc `aggregate.json` sink (verify it
  does not duplicate the consumer registry's `backup.maxAgeHours` coverage)

**Alert** (consumer-owned routing, `docs/MONITORING.md` taxonomy):

- Queue-depth/queue-age alerting via the consumer poll of
  `GET /api/queue/messages` (0.15.5 ships NO queue-depth/age Prometheus
  series - transcript-proven 2026-09-22; MONITORING.md row 2 + §5.4;
  any series that IS used must transcribe from the stalwart-e2e metrics
  dump, never be guessed). 0.16: the REST family is GONE - re-verify the
  queue surface before building this
- Failed-auth burst alerts from the tracing/journal surface; rate limits
  (`queue.limiter.inbound`) as the mechanized response
- The non-mail-channel rule: alerts never ride the mail stack (C24)

**Respond** (runbooks):

- Queue IR levers via the management API - pause/inspect/hold/drop, all
  SOURCE-VERIFIED in the pinned 0.15.5 queue.rs (MONITORING.md §5.4);
  0.16 re-verification owed (REST removed)
- Reload-smoke ops step for the live host: 0.15-verified
  (`/api/reload` silently no-ops while ANY config error exists,
  source-verified 2026-09-16, README ledger); on 0.16 the vendored unit
  RESTARTS stalwart after every apply (listeners never re-bind on
  reload - upstream #352), which changes the ops shape; flap tolerance is
  decision C46
- Spam/Junk policy productization: 0.15.5 only TAGS spam (`X-Spam-Status`)
  and hard-coded INBOX-targeted spam to Junk (no setting name -
  ingest.rs:344); 0.16's filing behavior is UNVERIFIED (the GTUBE subtest
  rides the quota fix) - open question 6 re-opens only if 0.16 changed it

**Verify** (prove the probes themselves):

- Tiny DMARC viewer over the JSON/CSV output (the monitoring report's gap #3)
  - DEFERRED (2026-09-15 verdict, master plan §10 06b): Stalwart 0.15.5
    already stores analyzed reports natively with a CLI readout; build
    nothing until the live webadmin is inspected (D1) AND parsedmarc JSON
    proves insufficient
- Optional PostgreSQL sink for parsedmarc (psycopg override experiment)
- Round-trip canary (MONITORING.md §6; vantage = C29)
- Paperless mail accounts off Gmail app passwords onto own IMAP; smartd
  remote-alert path decoupled from the mail relay (circular-dependency risk);
  InboxClean JMAP adapter post-migration - DECIDED 2026-09-30 (InboxClean
  ADR-023: JMAP-first provider abstraction, this stack is the target; IMAP
  only on a real legacy-provider need); the bounded seam work (demo-VM
  probe, push test, contract doc, e2e subtest) EXECUTED 2026-10-05
  (probe transcripts, push-vs-poll verdict, `docs/INBOXCLEAN.md`, e2e
  subtest); production enablement stays D1-gated, topology by C36

### 5. Repo excellence

- Stalwart OIDC (Pocket ID) for the admin UI - verified
  present in the 0.15.5 source (`common/src/auth/oauth/{openid,oidc}.rs`,
  master plan §10 06c); re-verify on the 0.16 source before wiring;
  settings-passthrough wiring when the D1 host exists
- Post-cutover: retire-or-keep decision documentation for the Resend-only path
- Retire the in-repo workarounds once upstream fixes land - re-check on
  every nixpkgs bump; module comments carry the revert conditions:
  (a) the two parsedmarc workarounds (host-less `[elasticsearch]`
  emission; imapclient on python 3.13) - TRIGGER UPDATED 2026-10-16:
  nixpkgs PR #566282 (parsedmarc overhaul + OpenSearch rename) MERGED
  2026-10-13 (`22579286`) - the port procedure in the README runbook
  step 2 is mandatory at the first pin advance past it; (b) NEW 2026-10-17:
  the VENDORED stalwart module (`modules/stalwart-module/`, PR #552103 @
  `9b15e1f`) - retires when that PR merges into the pinned rev (restore
  `meta.doc` + `partOf`, drop the ExecStartPost patch; checklist in the
  module header); (c) the Stalwart version surface is decision C45
  (0.16.22 vs overlay 0.16.26, which needs x86-64-v2)
- Arch-diagram content-freshness audit (routed 2026-09-22 from the
  16_19-16 report): `docs/architecture-understanding/*.d2` renders are
  label-verified but the CONTENT vs module reality (relay, DKIM
  dual-sign, flood node) has no standing re-check - audit on the next
  diagram session
- Split `modules/mail-server.nix` options into a `mail-server/options.nix`
  ONLY if the file keeps growing (verdict 2026-10-05: acceptable at ~667
  documented lines; re-check on the next option addition)
- Replace the vulnix CVE scan once BuildFlow ships a working scanner
  (NVD retired the legacy JSON feeds that crashed vulnix 1.12.5
  fleet-wide; `.buildflow.yml` carries the skip rationale)
- Formatter stack decision: treefmt-nix standard stack vs the current
  minimal-alejandra flake formatter. Narrowed 2026-09-17: the flake-parts
  migration REJECTED adding treefmt-nix to this repo (it would swap
  alejandra for nixfmt, reformat everything, and break the
  `nix fmt -- . --check` CI contract - recorded in AGENTS.md Conventions);
  what remains open is only whether the fleet ever standardizes on it
- aarch64: VM tests stay x86_64-gated (emulated run attempted 2026-09-15:
  guest builds+boots but boot alone exceeds the driver timeout -
  documented-manual, not CI-worthy); residue is an occasional local
  `nix flake check --all-systems` to keep the eval posture honest

## Non-goals

Things deliberately NOT pursued (see README "Non-goals" for the full rationale):

- **Mailcow/Mailu:** Docker-first and heavy (6-8 GiB) - rejected for a CX22-class
  target; Stalwart is one Rust binary.
- **Piler archiving:** maildir snapshots + paperless cover personal use already.
- **Elasticsearch/OpenSearch for parsedmarc:** a search stack to read 16
  domains' DMARC mail; JSON/CSV files are the zero-dependency output.
- **A mailpit wrapper:** `services.mailpit.instances` is a single option;
  wrapping adds nothing.
- **POP3 in the wrapper's listener contract:** compiled into Stalwart 0.15.5
  but deliberately excluded (25/465/587/993 only); consumers can add it via
  `services.stalwart.settings` if a legacy client appears.
- **FTS offload (Meilisearch etc.):** same doctrine as the Elasticsearch
  rejection - the built-in Community full-text search already serves a
  single-user deployment.
- **Direct-to-MX outbound from the VPS:** fresh-IP reputation trap; Resend
  relay is the design.

## Open questions (user decisions)

These gate large parts of the themes above. None of them is answerable from
any repo; they are Lars's calls. Recommendations + cost-of-delay per decision
are batched in `docs/planning/decision-batch.md` (2026-09-22) - answer there.

1. **D1 - Google Workspace fork:** retire Workspace mailboxes for a Stalwart
   VPS, or keep Workspace and run only the parsedmarc/monitoring half? Gates
   the VPS, Terraform, and migration themes entirely.
2. **D2 - VPS placement and budget:** which Hetzner project/location, size
   ceiling (CX22-class?), backup target (evo-x2 btrfs pool vs Hetzner
   StorageBox)?
3. **License choice:** ~~repo is public (D3 visibility decided 2026-09-14) but
   has no LICENSE.~~ RESOLVED 2026-09-15 (confirmed by the user after an
   intermediate rejection): MIT, as shipped in `LICENSE`
   (`Copyright (c) 2026 Lars Artmann`). AGPL Stalwart is only wrapped, not
   relicensed.
4. **README ops-detail level:** the public README carries go-live runbook
   detail (migration window, DR design) with recon value. Keep as-is, trim to
   outline, or move detail into a private consumer doc?
5. **Declarative provisioning philosophy:** should `services.mail-server` grow
   `domains`/`accounts` options (idempotent systemd oneshot against the
   management API), or does account state stay imperative/webadmin per
   Stalwart doctrine? Arguable either way (declarative drift vs operational
   simplicity).
6. **Spam/Junk ownership:** 0.15.5 tags spam (`X-Spam-Status`) but never files
   it to Junk. The 2026-09-15 answer "wrapper-owned" hit a source-verified
   wall: settings-defined sieve scripts CANNOT fileinto in 0.15.5 (trusted
   runtime drops FileInto; delivery runs only the per-account active script
   from the store - README ledger). Revised options: (a) per-account JMAP
   provisioning automation in the wrapper (heavy, couples to account
   lifecycle - adjacent to open question 5), (b) user/webmail-managed sieve
   per account (zero wrapper code, manual per account), (c) tag-only as the
   documented end state, (d) upstream feature request for declarative
   server-side filing and revisit on 0.16+. ~~Recommendation: (c) now + (d)
   as the path to (a) later; awaiting the final call.~~ RESIDUE RESOLVED
   2026-10-05 (source-verified, commit `099ba9d`): there IS no 0.15.5
   setting name - the auto-move is HARD-CODED in
   `crates/email/src/message/ingest.rs:344` (INBOX-targeted deliveries of
   spam-verdict messages go to `JUNK_ID` + the `$Junk` keyword, gated only
   by `spam-filter.enable` + score thresholds). (d) is MOOT (the feature
   exists upstream since 0.5.0); a wrapper `junkFiling` option is NOT
   implementable as a Stalwart setting; (c) tag-only stands as the
   documented end state and (a)'s JMAP automation is the only declarative
   path (TODO_LIST Low row). Owner ratification pending (decision-batch
   Agent-execution adoptions, Q6).
7. ~~**Demo VM boundary (2026-09-17 flake-parts session):** a runnable
   throwaway mail VM in THIS repo (`nix run .#vm`, telephony's `apps.vm`
   pattern), or does "boot the stack" belong to the consumer layer
   (SystemNix) with this repo staying tests-only? AGENTS.md assigns
   SystemNix layers to the consumer, but a demo VM is arguably
   product-side - the line is Lars's call.~~ RESOLVED 2026-09-17: user
   answered "add the demo VM to THIS repo"; `nixosConfigurations.demo` +
   `apps.vm` shipped same day. RESOLVED FULLY 2026-09-22: the hostfwd/API
   hang root-caused (guest firewall never opened the non-loopback
   `httpBind` port; module fixed conditionally) plus the provisioning
   no-op (systemd-PATH `curl`) fixed; end-to-end host smoke green with
   transcripts (README "Try it in a VM", ledger (k)/(l)).
8. ~~**Next release tag cadence:** the flake-parts migration sits in
   CHANGELOG [Unreleased] - cut a fast `v0.3.1` so SystemNix can bump
   and dedupe early, or batch it into the next feature release? Gates
   the SystemNix pin advance (TODO_LIST).~~ RESOLVED 2026-09-17: `v0.3.1`
   cut (git tag exists; CHANGELOG updated). The SystemNix pin advance is
   now unblocked - actionable work item in TODO_LIST.
