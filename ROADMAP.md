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
- Unattended admin bootstrap: provisioning oneshot translating the verified
  `POST /api/principal` recipe into a systemd unit
- DKIM keygen automation (`POST /api/dkim`), keys into sops, selector rotation
- Backup/DR: `stalwart --export` timer + offsite pull + recovery age key in
  the sops key group + MONTHLY restore drill
- Queue-depth/queue-age alerting off the Prometheus metrics

### 2. DNS estate (gated on D1)

Terraform is the right home for mail DNS truth (the domains repo already owns
every zone).

Raw ideas:

- `stalwart-mail` Terraform module: MX, SPF (`v=spf1 mx -all`), DKIM TXT,
  DMARC with `rua`, MTA-STS, `_smtp._tls` TLS-RPT
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

- dmarc-monitor live on evo-x2 against the `dmarc@` mailbox; DMARC ladder
  (`none → quarantine → reject`) driven by parsedmarc data
- Gatus external-view checks (starttls :25, tls :993, cert expiry) and
  Prometheus scrape of `/metrics/prometheus` via reverse proxy or tunnel
- Tiny DMARC viewer over the JSON/CSV output (the monitoring report's gap #3)
- Optional PostgreSQL sink for parsedmarc (psycopg override experiment)
- Paperless mail accounts off Gmail app passwords onto own IMAP; smartd
  remote-alert path decoupled from the mail relay (circular-dependency risk);
  InboxClean JMAP/IMAP spike post-migration
- Blacklist (RBL) monitoring for the VPS IP

### 5. Repo excellence

- CI, nix formatter, Renovate (nixpkgs input must stay paired with SystemNix)
- Threat-model doc; Stalwart OIDC (Pocket ID) for the admin UI if supported
- Post-cutover: retire-or-keep decision documentation for the Resend-only path

## Non-goals

Things deliberately NOT pursued (see README "Non-goals" for the full rationale):

- **Mailcow/Mailu:** Docker-first and heavy (6-8 GiB) - rejected for a CX22-class
  target; Stalwart is one Rust binary.
- **Piler archiving:** maildir snapshots + paperless cover personal use already.
- **Elasticsearch/OpenSearch for parsedmarc:** a search stack to read 16
  domains' DMARC mail; JSON/CSV files are the zero-dependency output.
- **A mailpit wrapper:** `services.mailpit.instances` is a single option;
  wrapping adds nothing.
- **Direct-to-MX outbound from the VPS:** fresh-IP reputation trap; Resend
  relay is the design.

## Open questions (user decisions)

These gate large parts of the themes above. None of them is answerable from
any repo; they are Lars's calls.

1. **D1 - Google Workspace fork:** retire Workspace mailboxes for a Stalwart
   VPS, or keep Workspace and run only the parsedmarc/monitoring half? Gates
   the VPS, Terraform, and migration themes entirely.
2. **D2 - VPS placement and budget:** which Hetzner project/location, size
   ceiling (CX22-class?), backup target (evo-x2 btrfs pool vs Hetzner
   StorageBox)?
3. **License choice:** repo is public (D3 visibility decided 2026-09-14) but
   has no LICENSE. MIT is the default recommendation; AGPL Stalwart is only
   wrapped, not relicensed, but the call is yours.
4. **README ops-detail level:** the public README carries go-live runbook
   detail (migration window, DR design) with recon value. Keep as-is, trim to
   outline, or move detail into a private consumer doc?
5. **Declarative provisioning philosophy:** should `services.mail-server` grow
   `domains`/`accounts` options (idempotent systemd oneshot against the
   management API), or does account state stay imperative/webadmin per
   Stalwart doctrine? Arguable either way (declarative drift vs operational
   simplicity).
