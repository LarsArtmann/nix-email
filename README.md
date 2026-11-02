# nix-email

[![CI](https://github.com/LarsArtmann/nix-email/actions/workflows/ci.yml/badge.svg)](https://github.com/LarsArtmann/nix-email/actions/workflows/ci.yml)

Declarative mail stack for LarsArtmann hosts: an opinionated
[Stalwart](https://stalw.art) mail-server wrapper + a light parsedmarc
DMARC/TLS-RPT monitor, packaged as a NixOS flake for consumption by
[SystemNix](../SystemNix) (upstream-flake pattern, like InboxClean/DiscordSync).

> **STATUS 2026-10-28: nixpkgs pin advanced to fe132422 - Stalwart 0.16.26,
> parsedmarc 11.0.2, GATE GREEN.** SystemNix's lock moved first and their
> `follows` forces their pin onto the wrapper's contract check, so this
> repo caught up to the shared rev (the compat doctrine; their
> `checks.nix-email-contract` re-greens when they pull this master).
> Ride-alongs, each per the Pin-advance runbook: nixpkgs PR #566282
> ported (`provision.opensearch`, strip-guard re-targeted, #563651
> still open), the imapclient py3.13 pin REVERTED (pin ships 4.1.0),
> 0.16.26's x86-64-v2 requirement absorbed (test-level
> `defaults = common.v2CpuPatches` in every VM test - structurally
> unforgottable), and the localMail STORAGE contract landed (new-pin
> localMail watches a postfix maildir; the wrapper pre-creates it at
> boot via tmpfiles and whitelists it UNPREFIXED - a `-` prefix is
> evaluated-once at namespace setup and silently leaves the spool
> read-only; eval-pinned in `dmarc-eval`'s localMail-shape eval).
> State at this banner's date: **GATE GREEN** - `nix flake check`
> passes the full check set on 0.16.26/11.0.2 (stalwart-e2e,
> parsedmarc-e2e both ends, bind/migrate/relay re-proven at the pin;
> buildflow EXIT:0 same day). **v0.5.0 was CUT this same day** (owner
> verdict C43: cut) - tagged, tag-CI green, GitHub release published;
> the CardDAV probe baseline re-pinned on 0.16.26 (17/18 reproduced,
> `docs/probes/2026-10-28-carddav-01626/`).
>
> - live status in
>   [TODO_LIST.md](TODO_LIST.md), the transcript-pinned fact set in the
>   ledger's "Stalwart 0.16" section.
>
> **Line-by-line verify (D7, 2026-10-31):** every section claim re-checked
> against the code/pin this day - option surface, firewall set, ms
> conversion, check list vs `tests/check-expected.json`, runbook status
> lines; fixes this pass: parsedmarc version (11.0.2), vandelay IS in the
> pin (1.0.12), C43/C45 statuses, junk-filing pending note retired, SSE
> verdict re-dated, 0.16 demo smoke landed, mailsuite#65 closure recorded.

Architecture (design note: the internal
`~/projects/reports/selfhosted-email-guide.md` study): self-hosted
**inbound** on a Hetzner VPS (residential evo-x2 can never be an MX),
**outbound** relayed through Resend (clean-IP deliverability), DMARC reports
polled and parsed on evo-x2. Heavy stacks (Mailcow 6-8 GiB, Elasticsearch for
parsedmarc, Piler archiving) are deliberately rejected: Stalwart is one Rust
binary (~512 MB-1 GiB RAM) with spam filter, DKIM, JMAP, CalDAV/CardDAV and
web admin built in.

## Architecture

Current runtime shape (d2 source; rendered SVGs in
`docs/architecture-understanding/`):

```d2
direction: down

internet: Internet {
  mx_senders: Remote MX senders {shape: cloud}
  clients: Mail clients (IMAPS 993, JMAP, submission 587/465) {shape: person}
  verifiers: DMARC verifiers (rua reports) {shape: cloud}
}

proxy: Reverse proxy (Caddy on consumer host, TLS)

stalwart: Stalwart 0.16.26 (services.mail-server wrapper) {
  smtp_in: SMTP listeners (25 MX, 587 submission, 465 submissions)
  imaps: IMAPS listener (993, implicit TLS)
  http: HTTP listener (127.0.0.1:8080, loopback only)
  queue: Queue + routing strategy (is_local_domain -> local, else -> relay)
  spam: Spam filter (GTUBE, rules)
  provision: declarative plans via stalwart-cli apply (accounts, Domain, DKIM, routes)
  dkim: DKIM signer (declarative DkimSignature: rsa + ed25519)
  flood: Inbound rate limiter (opt-in, MtaInboundThrottle)
  probe: Deliverability probe timer (DNS/DNSBL/transport/canary)
  directory: Internal directory (negative-cache TTL option)
  acme: ACME client (self-signed | acme | manual tiers)
  metrics: Metrics singleton (/metrics/prometheus)
  store: RocksDB mail store {shape: cylinder}
}

relay: Smarthost relay (optional; e.g. smtp.resend.com, SASL) {shape: cloud}
dns: DNS resolver (SPF, DNSBL, MX, DKIM keys) {shape: cloud}
letsencrypt: Let's Encrypt (ACME) {shape: cloud}

parsedmarc: parsedmarc 11 (services.dmarc-monitor wrapper) {
  poller: IMAP poller (watch) on rua mailbox
  output: Report sink (JSON + CSV files) {shape: cylinder}
}

viewer: Report viewer over the JSON/CSV sink {style.stroke-dash: 4}

secrets: Consumer secrets (sops templates, SystemNix)
prometheus: Prometheus scraper {shape: person}

internet.mx_senders -> stalwart.smtp_in: delivers mail on 25
internet.clients -> stalwart.smtp_in: AUTH + STARTTLS/TLS
internet.clients -> stalwart.imaps: fetches mail
internet.clients -> proxy: JMAP / webadmin
proxy -> stalwart.http: forwards (loopback bind)
internet.verifiers -> stalwart.smtp_in: aggregate reports to rua address
stalwart.queue -> internet.mx_senders: direct-to-MX when relay = null
stalwart.queue -> relay: non-local mail when services.mail-server.relay set
stalwart.smtp_in -> stalwart.store: local delivery
stalwart.directory -> stalwart.store: principal/domain lookups
stalwart.spam -> stalwart.store: tags X-Spam-Status (GTUBE/rules); no auto-Junk filing - 0.16 re-verified by the e2e GTUBE subtest (INBOX-select probe green on 0.16.22 2026-10-17 and 0.16.26 2026-10-28; filing would be consumer sieve territory)
stalwart.provision -> stalwart.store: declarative Domain/Account/DkimSignature/MtaRoute objects
stalwart.dkim -> stalwart.queue: signs outbound (dual rsa+ed25519)
stalwart.probe -> stalwart.smtp_in: transport health + round-trip canary
stalwart.probe -> dns: MX/SPF/DMARC/DKIM/DNSBL battery
stalwart.acme -> letsencrypt: issues certificates
stalwart.smtp_in -> dns: SPF/DNSBL/DKIM lookups
stalwart.queue -> dns: MX resolution
parsedmarc.poller -> stalwart.imaps: polls rua mailbox (IMAP 993)
parsedmarc.poller -> parsedmarc.output: save_output (fixed filenames)
parsedmarc.output -> viewer: JSON/CSV files (future read path)
secrets -> stalwart.http: "systemd LoadCredential + %{file:/run/credentials/...}% macros"
prometheus -> proxy: GET /metrics/prometheus
```

The target deployment shape (SystemNix layering: sops, Caddy, Gatus,
onFailure alerting, backups) is
`docs/architecture-understanding/2026-09-15_09_23-nix-email-improved.svg`;
the rendered current-state SVG sits next to it.

## What is built and verified

| Piece                                          | State                                                                               |
| ---------------------------------------------- | ----------------------------------------------------------------------------------- |
| `modules/mail-server.nix`                      | Done. VM-tested E2E (see below)                                                     |
| `modules/dmarc-monitor.nix`                    | Done. VM-tested E2E (parsedmarc-e2e); a live production mailbox remains for go-live |
| Mailpit for dev/CI                             | Use nixpkgs `services.mailpit.instances` directly - no wrapper adds value           |
| VPS host, DNS cutover, migration, Gatus wiring | Planned - see "Go-live runbook" and ROADMAP.md (gated on the D1/D2 decisions)       |

Open work lives in [TODO_LIST.md](TODO_LIST.md); the honest feature
inventory in [FEATURES.md](FEATURES.md); long-term direction and the gating
user decisions in [ROADMAP.md](ROADMAP.md).

Doctrine note (nixos-mailserver lessons, from a deep study of
simple-nixos-mailserver at the pinned era, 2026-09-14): that project
historically SHIPPED backup and monitoring options and later REMOVED
them - upstream mail software already has native/complementary answers
(Stalwart: `--export`/`--import`, `/metrics/prometheus`), and wrapper
options for them rot into a second implementation to maintain. That
removal independently validates this repo's thin-wrapper doctrine:
wrap only what needs NixOS wiring (listeners, certs, firewall, systemd
units), pass everything else through the provision model. (Correction
2026-10-18, VM-proven on the pin: 0.16 did NOT remove the main binary's
`--export`/`--import` - only the `stalwart-cli --export` + REST
variants; see the go-live backup step and
`docs/probes/2026-10-18-demo-smoke-backup/`.)

`nix flake check` runs the full check set against the SAME nixpkgs pin as
SystemNix (`fe132422`, NixOS 26.11). The canonical machine list is
`tests/check-expected.json` - one file read by ci.yml's lockstep steps,
`scripts/check-inventory.sh` (pre-push), and the `check-set-lockstep`
check itself; a check add/remove edits that list plus the prose row here,
and nothing else:

- `check-set-lockstep`: pure-eval guard asserting the declared check set
  equals the JSON canonical list on BOTH arches - drift throws from
  `nix flake check` with both sets spelled out (eval-time, so it fails
  before any VM build). Makes the 2026-09-23 missing-entry class fail
  locally regardless of pre-push hook state.
- `deprecated-alias-lint`: pure-build guard (python, no VM) that parses
  every `warnAlias` name out of the pinned `pkgs/top-level/aliases.nix`
  and rejects code references to them, with comments and string bodies
  masked (`${...}` interpolations stay visible). A `warnAlias` attribute
  warns on every force, so a default naming one - `package =
  pkgs.stalwart` in the 0.15 migration leg - printed on every consumer
  rebuild while the gate and the deployment stayed green (2026-11-01
  pbx-artmann switch noise); the fix is always the versioned attribute
  (`stalwart_0_15`). Self-tests both directions before scanning, and a
  parse-yield floor (>= 150 aliases) fails loudly if nixpkgs ever
  reformats `aliases.nix` instead of scanning vacuously. Known blind
  spots (deliberate, see the checker docstring): only `pkgs.<name>`
  selections are matched - `with pkgs;`-scoped bare names, quoted
  selections (`pkgs."name"`), and programmatic construction
  (`mkPackageOption pkgs "name"`, `pkgs.${name}`) are invisible to it.
- `stalwart-e2e`: real Stalwart 0.16.26 in a VM (0.16.22 until the
  2026-10-28 fe132422 advance) - declarative provisioning
  plan applied clean (accounts incl. quota + alias, dual declarative DKIM
  rsa+ed25519, listeners, singletons; idempotent second apply),
  unknown-recipient 550 rejection, implicit-TLS IMAPS greeting, JMAP
  session at `/.well-known/jmap` -> `/jmap/session`, fallback admin via a
  systemd credential, authenticated submission on 587 delivering into a
  real INBOX fetched back over IMAPS, dual DKIM signatures asserted,
  Prometheus metrics endpoint, journal hygiene, alias delivery, the
  runtime catch-all via a second `stalwart-cli apply` (in-plan `#id`
  ordering + match-property dialect), and the over-quota contract
  (SMTP-accept `250 Message queued with id`, IMAP absence, 0.16 journal
  silence). GREEN end-to-end on 0.16.22 as of 2026-10-17 AND on 0.16.26
  as of 2026-10-28 (fe132422 advance, `-cpu max` v2CpuPatches) - all 17
  subtests incl. GTUBE, native DMARC ingestion, and the flood limiter.
- `stalwart-bind-e2e`: dedicated non-default `httpBind` (`127.0.0.1:8082`,
  the pbx-artmann consumer shape) on a virgin store - the bootstrap class
  `stalwart-e2e` cannot cover (its bind coincides with the built-in 8080,
  so the deadlock was untestable there by construction): the provision
  unit falls back to the built-in `127.0.0.1:8080`, applies against it,
  restarts stalwart, and the plan's listener set replaces the built-ins
  (8080 gone; 8082 + 25 bound; admin JMAP session served on the dedicated
  port; plain-restart persistence). Both endpoints must identify as
  Stalwart by their unauthenticated JMAP session, and a SECOND node
  (`guarded`) pins the refusal: a foreign HTTP service on the built-in
  8080 (the 2026-10-23 pbx shape - the webphone) never receives the plan,
  the unit names it in the journal and fails at its start timeout. GREEN
  2026-10-23 (nix-email#4 + the identity fix).
- `stalwart-relay-e2e`: TWO-node VM - Stalwart with `relay` (SASL
  credentials) -> Mailpit smarthost node enforcing AUTH. Non-local
  submission lands in Mailpit through the generated 0.16 MtaRoute relay
  objects, local domains still deliver locally (and never leak to the
  relay), relay hostname resolved via dnsmasq forwarding upstream to the
  QEMU resolver (0.16's reload validation resolves SpamPyzor via the
  system resolver - a black-hole upstream starves the whole boot).
- `parsedmarc-e2e`: TWO-node VM - a Dovecot fixture mailbox seeded with the
  upstream sample DMARC aggregate report, polled by the real parsedmarc 11
  unit; JSON/CSV output asserted (row counts, org metadata), the runtime ini
  asserted free of the inert `[elasticsearch]` section, and a second node
  exercising the production-shaped IMAPS 993 path with DEFAULT certificate
  verification (machine-trusted fixture CA, `ssl=True`, no
  skip-verification).
- `deliverability-e2e`: the continuous deliverability checks
  (`services.mail-server.deliverabilityChecks`): one VM running the real
  stack + a real local DNS zone (dnsmasq: MX/SPF/DMARC/DKIM records, a PTR,
  and a mock DNSBL with one listed + one clean IP). The probe unit runs the
  full battery green (DNS records, 25/465/587/993 transport TLS, cert
  expiry, self-signed tier = tls-verification WARN under opportunistic
  mode), the round-trip canary delivers + cleans up within the SLO, the
  emission contract holds (report.json, Prometheus textfile gauges incl.
  the dead-man timestamp, timer enabled with `OnCalendar *:0/15` +
  Persistent), and the negative paths fire: a DNSBL-listed IP fails the
  run naming the zone, wrong canary credentials fail at phase=send (the
  send-vs-delivery distinction MONITORING.md section 6 demands). The eval
  half pins the unit shape: LoadCredential for the canary password, no
  wrapper-side OnFailure (alert routing is consumer doctrine).
- `dmarc-eval`: eval-time contract - enables parsedmarc, heavy sinks off,
  `general.output` lands, `_secret` password survives the option types AND
  the real ini generation (the unit's config render is forced, so a wrong
  `_secret` shape fails here, not on a host).
- `migrate-convert-eval`: the vendored upstream `migrate_v016.py`'s first
  functional test - the real `convert` subcommand runs at build time
  against a minimal 0.15 dump fixture, pinning the DataStore descriptor,
  the Domain/Account/SystemSettings plan shape (local-part names,
  restore-<id> account ids, `#id` references), and the `--patch-paths`
  rewrite the migration script depends on. Arch-independent.
- `module-import-eval`: pure eval on BOTH arches - the full wrapper toplevel
  (mail-server + dmarc-monitor merged in ONE nixosSystem), pinning the
  export surface and the default-OFF hardening posture (`rateLimits` unset,
  DNSBL reconcile set empty).
- `demo-eval`: pure eval pinning the demo VM's human contract (quickstart
  port pairs, provisioned account role + catch-all, fallback admin
  credential, pyzor off) - the demo toplevel itself is already forced by
  the gate.
- `provision-plan-eval`: pure-eval contract over the rendered provision
  plan - the provisioned Domain name equals `services.mail-server.hostname`
  (the auth-535 / MAIL-FROM-501 class), every `reconcile` set carries an
  explicit `match` property, object sets outside the implicit-key
  allowlist are match-pinned, the fallback port posture, a multi-line
  `Exec*` lint, and the `MtaInboundThrottle` identity (description match
  key, `authenticated_as` vocabulary). Arch-independent.
- `stalwart-migrate-e2e`: TWO-node VM - a phase-A 0.15.5 node seeds a real
  store (domain + principal through the management API), the store travels
  to the consumer node, which proves the unit GUARD refusal (the binary
  never runs on a 0.15 store), the poison simulation + script refusal, the
  full `--backup-dir` migration (0.15.5 probe dump, convert with paths
  rewritten to the LIVE store, clean-copy restore, recovery-mode wipe +
  apply, marker), the VERIFIED end-state boot (stable unit + provision
  apply), the 0.15 password authenticating on 0.16, and restart
  persistence.

## Module: `services.mail-server`

Enables the vendored Stalwart 0.16 module (`modules/stalwart-module/`, from
nixpkgs PR #552103) with one RFC-compliant listener set:

| Port                                | Listener    | Notes                                                 |
| ----------------------------------- | ----------- | ----------------------------------------------------- |
| 25                                  | smtp        | inbound MX, STARTTLS advertised                       |
| 587                                 | submission  | client auth + STARTTLS                                |
| 465                                 | submissions | implicit TLS                                          |
| 993                                 | imaps       | implicit TLS                                          |
| httpBind (default `127.0.0.1:8080`) | http        | web admin / JMAP - reverse-proxy it, never expose raw |

Options: `enable`, `hostname` (FQDN with a dot; on 0.16 it ALSO becomes the
provisioned Domain value, so account addresses synthesize as
`name@<hostname>` - it must pass 0.16 hostname validation, e.g. `.invalid`
TLDs are rejected), `httpBind` (loopback default; a NixOS warning fires on
non-loopback binds; a non-8080 port bootstraps provisioning through the
built-in 8080 endpoint and replaces it at apply), `publicUrl` (0.16 renders absolute URLs from it;
defaults to `https://hostname`), `admin.username`/`admin.secretFile`
(the 0.16 fallback admin is a REQUIRED systemd credential - it is the
provisioning CLI's only auth path, so the wrapper refuses to eval without
the secret), `stateVersion`, `relay` (outbound smarthost, see below),
`metrics.enable` (`/metrics/prometheus` on the HTTP listener),
`directoryCacheTtlNegative`, `certificate` (`self-signed | acme | manual`
tier with completeness assertions), `deliverabilityChecks` (continuous
deliverability probes - see the next section), and the hardening options
`rateLimits` (opt-in sustained inbound damper - see the sizing note below)
and `spamFilter.dnsbl.servers` (typed DNS blocklist entries, default `{}`;
the plan ALWAYS carries an empty-by-default reconcile set - the
"DNSBL off by default" posture, mechanized; see the delta table below
for the 0.16.22-era broken-defaults history).

`services.stalwart.settings` is now ONLY the config.json datastore
descriptor - everything else (domains, accounts, DKIM, routes, catch-all)
lives in the datastore as JMAP objects and is provisioned declaratively via
`services.stalwart.provision.singletons/.objects` (consumer plans MERGE into
the wrapper's; replacing a wrapper-owned object id needs `mkForce`).
Durations on 0.16 are integer milliseconds (the wrapper options stay in
seconds and convert). Account passwords are zxcvbn-strength-enforced by the
server. Firewall: the wrapper opens exactly 25/465/587/993, plus the
`httpBind` port when the bind is non-loopback (nixpkgs' `openFirewall` is
off - it would also open the loopback admin port on every interface);
consumer port lists merge additively.

### Stalwart 0.16.22 -> 0.16.26 delta (evidence for C45, fetched

### 2026-10-18 from the upstream CHANGELOG/releases)

| Version | Headline changes relevant to THIS wrapper                                                                                                                                                                                                                                                                                                                                                 |
| ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0.16.23 | ADDS the `bit_and` expression function - the exact function 0.16.22's 18 shipped default DNSBL rows reference (and the .22 parser rejects; the wrapper's empty-reconcile workaround predates this fix). Mailing-list-of-lists, DMARC aggregate `spf`/`version`, DSN fixes.                                                                                                                |
| 0.16.24 | Spam-rule UPDATES are insert-only in .22-.23 ("upstream changes to existing rules, DNSBL servers, HTTP lookups ... never reach an existing installation") - a second argument for the wrapper's declarative reconcile posture. JMAP push VAPID `aud` signing fix (security-adjacent). PowerDNS provider added.                                                                            |
| 0.16.25 | DNSBL multi-return-code scoring (Spamhaus ZEN SBL+PBL) + negative-TTL caching fixes; three DKIM ROTATION bugs (we are declarative/Manual, unaffected); the GLOBAL queue quota created on first start is never enforced on .22-.24.                                                                                                                                                        |
| 0.16.26 | **BREAKING: x86_64 builds (except musl) require x86-64-v2 CPUs and REFUSE to start otherwise** (QEMU default CPU models affected - a 0.16.26 overlay must set VM `host` cpu; real hosts need a v2 CPU check first). Adds `sd_notify` support (relevant to the vendored module's "stalwart does not notify systemd" comment); RocksDB blob-GC rewrite fix; OIDC email-claim account build. |

No CVEs in the window (CVE-2026-81036 affects through 0.16.19 only; the
pin's 0.16.22 is past it). C45 (stay on the pin's 0.16.22 vs overlay a
newer 0.16.x) stayed owner-gated until **2026-10-28: SUPERSEDED - the
consumer-driven pin advance to fe132422 landed `stalwart_0_16` 0.16.26
via the PIN** (SystemNix's lock moved first; their `follows` already
forced that rev onto the wrapper's contract check). The overlay arm is
moot; the delta table above is now the landed-change record. The VM
cpu-type requirement is absorbed by `tests/common.nix` `v2CpuPatches`
(`-cpu max`, TCG-safe); REAL hosts need an x86-64-v2 CPU check on the
consumer side before deploying the advanced pin (their follows already
carries it).

### Rate-limit sizing (`rateLimits`)

The wrapper's `rateLimits` adds ONE inbound limiter NEXT to the two
upstream defaults (per remote_ip 5/1s + per sender_domain+rcpt 25/1h -
every matching limiter must allow a message, so yours only binds on
sustained volume). Sizing for a small fleet: set `rate` to ~2-3x your
legitimate peak per bucket (the `600/1h` default fits a ~10-user host;
newsletters or burst senders want their own keyed limiter instead of
raising the global one). `keys` picks the bucket: `remote_ip` (per-source
damper), `sender_domain` (per-tenant), `authenticated_as` (per-account
submission damper). Verify a trip by CONNECTION counts, never SMTP codes -
a tripped limiter is a pre-SMTP hangup (ledger (m); the e2e flood subtest
asserts exactly this shape). CONDITIONAL limiters (IfBlock `match`
expressions, e.g. only for unauthenticated sessions) are passthrough-only:
write `queue.limiter.inbound.<id>.match` via `services.stalwart.settings` -
same for conditional DNSBL zones (`spam-filter.dnsbl.server.<id>.zone`
IfBlocks).

### Per-account semantics (declarative provision objects, VM-verified 0.16 2026-10-16/17)

- **Quota** is `quotas.maxDiskQuota` (bytes) on the User object; there is
  no wrapper option because it is per-account data, not host config. An
  over-quota message is ACCEPTED at SMTP (0.16.22 exact acceptance:
  `250 2.0.0 Message queued with id <id>`) but never delivered. 0.16
  JOURNAL SILENCE (debug-driver transcript, 2026-10-17): 0.15's `Message
  rescheduled for delivery` is GONE - across 200 s of post-accept
  polling the journal carries no quota/retry/reschedule/4xx line and
  never re-mentions the queue id (default verbosity logs nothing
  per-message); the queue's long-term fate (0.15: retried forever) is
  NOT journal-observable on 0.16. Asserting the behavior means asserting
  delivery-absence over IMAP + journal silence, never SMTP refusal.
- **Catch-all** is `Domain.catchAllAddress` pointing at an ACCOUNT's email
  address (0.16 object model; the 0.15 `"@<domain>"` principal shape is
  dead). It makes EVERY local part deliverable, which silently disables
  unknown-recipient 5xx rejection for that domain - catch-all and strict
  rejection cannot coexist on one domain. ORDERING FOOTGUN (re-learned
  live on 0.16): create the catch-all AFTER any unknown-recipient-rejection
  probe, and note the runtime plan dialect: ops apply SEQUENTIALLY, `#id`
  references resolve only against EARLIER ops in the same plan, an upsert
  patching an existing object must carry its match property (`name` for
  Domain), and `credentials` must be the indexed-map form. Provisioning
  order also matters more broadly: any SMTP probe touching a domain before
  it is provisioned poisons the directory negative cache and routes it to
  MX instead of local (0.15-verified mechanism; TTL knob:
  `directoryCacheTtlNegative`).

### Outbound relay (`services.mail-server.relay`)

null (default) = direct-to-MX. When set, non-local mail transits the
smarthost - the wrapper renders the 0.16 MtaRoute relay object (with the
outbound strategy expression); the shape is exercised by the two-node VM
test `stalwart-relay-e2e` (green on 0.16.22 and, after the 2026-10-28
fe132422 advance, 0.16.26; the 0.15-era
`queue.route` IfBlock rendering is retired with the upgrade):

```nix
services.mail-server.relay = {
  address = "smtp.resend.com"; # hostname REQUIRED - IP literals are refused
  port = 587;                  # 587 = STARTTLS, 465 = implicit (tlsImplicit)
  username = "resend";
  secretFile = "/run/secrets/resend-smtp-password"; # LoadCredential + %{file:...}% macro
};
```

Local-domain delivery is untouched (local routing stays on the local
queue). Relaying to loopback targets is refused by Stalwart (SSRF guard);
the auth-less form (`username = null`) is valid for trusted internal
smarthosts. The relay secret rides systemd `LoadCredential` and is
referenced through the `%{file:/run/credentials/...}%` macro mechanism.

Outbound smarthost relaying (Stalwart -> Resend) needs nothing beyond the
`relay` option on 0.16 - the object rendering is wrapper-owned (verified
in the two-node VM test, not guessed).

### Continuous deliverability checks (`services.mail-server.deliverabilityChecks`)

A systemd timer (default `OnCalendar *:0/15`, `Persistent`) runs the probe
unit `mail-deliverability-probe.service` - DNS (MX/SPF/DMARC/DKIM
selectors), DNSBL listing per outbound IP (IPv4 and IPv6,
family-correct reverse notation), transport health on 25/465/587/993
(STARTTLS/implicit TLS, SASL login when canary credentials are set),
certificate expiry (implicit-TLS 993/465 legs AND the 25/587 STARTTLS
legs via `openssl -starttls smtp`), and the round-trip canary (submit a
token-unique mail as the canary account on 587, assert IMAPS arrival
within `sloSeconds`, delete it - send-failure and delivery-timeout are
distinguished in the report, per MONITORING.md section 6; arrival in
Junk instead of INBOX is its own delivered-to-junk WARN verdict). Every
check runs under a wall-clock budget (`--check-timeout`, 300 s default)
so one wedged check fails as a timeout instead of hanging the probe.
Optional legs: `canaryInbound` (submit UNAUTHENTICATED via :25 to the
canary mailbox - the world-facing inbound path; the recipient must
EXIST before the first run, the 1 h directory negative-cache trap),
`metricsUrl` (assert the `metrics.enable` endpoint serves Prometheus
exposition format), and `dmarcSinkDirectory` (parsedmarc output
freshness, warning severity). VM-e2e'd by `deliverability-e2e` (green
battery + the negative paths).

```nix
services.mail-server.deliverabilityChecks = {
  enable = true;
  dkimSelectors = ["rs" "ed"];
  dnsblZones = ["zen.spamhaus.org"]; # only where the host resolves recursively itself
  canary = {
    address = "canary@example.com";   # an EXISTING account (provision it yourself - C44 doctrine)
    secretFile = "/run/secrets/mail-canary-password";
  };
  canaryInbound = true;               # also probe the unauthenticated :25 inbound path
  metricsUrl = "http://127.0.0.1:8080/metrics/prometheus";  # with metrics.enable
  dmarcSinkDirectory = "/var/lib/dmarc-monitor/reports";    # freshness check
};
```

EMISSION ONLY, by doctrine (docs/MONITORING.md owns the wiring specs):

- **exit code** - any CRITICAL failure fails the unit: SystemNix's
  `onFailure` layer alerts on the unit NAME
  `mail-deliverability-probe.service` (Discord/ntfy push -> desktop);
  the wrapper itself never sets OnFailure.
- **`/var/lib/mail-deliverability-probe/report.json`** (+ pruned
  `history/`) - the structured last-run report (jq-friendly).
- **`/var/lib/mail-deliverability-probe/metrics.prom`** - Prometheus
  textfile (`mail_deliverability_probe_success`, per-check
  `mail_deliverability_check_success{check=...}` / `..._warn`,
  `mail_deliverability_dnsbl_listed{zone=...,ip=...}`, and the dead-man
  gauge `mail_deliverability_probe_timestamp_seconds` - scrape it and
  alert on staleness; SigNoz consumes it like any Prometheus source).
- **vantage runs** - the SAME probe is exported as the flake package/app
  `deliverability-probe`, so evo-x2/SystemNix can run the outside-view
  battery (plus Gatus's own TCP/TLS/DNS checks) without redeploying the
  mail host:

```console
$ nix run github:LarsArtmann/nix-email#deliverability-probe -- \
    --host mail.example.com --domains example.com \
    --dnsbl-zones zen.spamhaus.org \
    --canary-address canary@example.com \
    --canary-password-file /run/secrets/mail-canary-password \
    --prom-out /var/lib/mail-canary/metrics.prom
```

Self-signed-tier note: `tlsVerification = "opportunistic"` (default) WARNs
on untrusted certificates instead of failing - switch to `"required"`
together with `certificate.mode = "acme"`/`"manual"` on production hosts.

## Migrating from 0.15 (the store guard + `stalwart-migrate-from-015`)

The 0.16 binary REFUSES to boot against a 0.15-era store (exit 101, panic
in `crates/migration/src/lib.rs:95`), and every attempted boot POISONS the
settings subspace for 0.15.5 before panicking - a crash-looping unit
destroys its own recovery path, because the sanctioned migration dumps the
old settings/principals through a running 0.15.x (upstream
`UPGRADING/v0_16.md`, vendored here as `migrate_v016.py`). Both halves are
covered:

- **Unit guard** (0.16 packages only): `ExecStartPre` fails the unit with
  migration instructions when a non-empty store exists without
  `<dataDir>/v016-store-migrated`. Virgin stores self-mark, so fresh
  installs never trip it; a store migrated before the guard shipped
  self-marks once via the printed escape hatch.
- **`stalwart-migrate-from-015`** (add
  `config.services.stalwart.migrateFrom015.script` to
  `environment.systemPackages`, run as root): poison preflight ->
  `cp -a` backup -> 0.15.x dump probe on a dedicated loopback port ->
  vendored `migrate_v016.py` dump+convert (dump-store paths rewritten to
  the LIVE store - the dump serves the probe's EFFECTIVE settings, so an
  unrewritten DataStore path made recovery migrate the `--backup-dir`
  COPY while the live store stayed pre-0.16 and the first normal boot
  panicked with the multi-step message; migrate-e2e runs 6-7,
  2026-10-18/19) -> when `--backup-dir` is used, the clean copy is
  RESTORED into the live store path first (recovery mode's one-shot wipe
  only triggers on a CLEAN pre-0.16 store; poisoned settings skip the
  detection, the built-in Role objects are never re-seeded, and the apply
  dies on `x:Account/set` "Role not found" - run 9; the freshest
  poisoned-live mail survives in the `.v015-premigrate` backup) ->
  recovery-mode 0.16 as the SERVICE USER on `migrateFrom015.recoveryPort`
  (default 18080, NEVER the built-in 8080 - real hosts own that port) ->
  `stalwart-cli apply` (accounts keep their 0.15 ids via the
  `restore-<id>` mechanism, so mail linkage survives) -> marker -> a
  VERIFIED end state: the script boots `stalwart.service` itself,
  requires stable-active with zero restarts, runs the provision apply,
  and only then prints `[DONE]` (a failed verification removes the
  marker so the guard refuses further boots). When the live store is
  already poisoned, `--backup-dir PATH` dumps from an unpacked pre-0.16
  copy instead and still recovers the live store.

Listeners, rate limits, and report settings do NOT ride the migration
(0.16 objects) - the provision plan recreates them at the next start.
CAVEAT (migrate-e2e run-5 lesson, 2026-10-18): the converted store DOES
carry the 0.15 listener objects, and the provision unit's probe only
looks for `cfg.url` and the built-in `127.0.0.1:8080` - a 0.15 host
whose ONLY http listener was on a NON-standard port leaves the migrated
server unreachable by provision (apply times out). Standard installs
(webadmin on 8080) are fine; exotic binds need a one-time manual
`STALWART_URL=http://127.0.0.1:<port> stalwart-cli apply --file <plan>`
after migration. Quota counters are reset by upstream's recovery mode;
recalculate them from the webadmin's task panel afterwards. The
migration path is exercised by `tests/stalwart-migrate-e2e.nix` as a
TWO-NODE VM test (phase-A 0.15.5 node seeds the store, the 0.16 consumer
node boots with it via the shared test directory): guard refusal, poison
refusal, `--backup-dir` recovery, 0.15 password authenticating on 0.16,
provision re-apply, restart persistence.

**Module verdict: DNS-arrival race (decided 2026-10-19).** On hosts
whose resolver config arrives LATE (DHCP-written `/etc/resolv.conf`,
the demo's resolvconf ordering), 0.16's reload validation reads an
empty resolver config during the provision apply, the apply fails at
the reload op BEFORE its restart step, and stalwart keeps the built-in
listener set with a failed provision unit (probe transcript
`docs/probes/2026-10-18-demo-smoke-backup/`). The fix is NOT unit
ordering: `network-online.target` is a no-op under dhcpcd - precisely
the late-DNS case - so ordering after it guarantees nothing. The
required pattern for late-DNS hosts is the resolver singleton the e2e
nodes and the demo all pin:

```nix
services.stalwart.provision.singletons.DnsResolver."@type" = "Cloudflare";
```

Static-DNS hosts (the consumer VPS shape) never see the race. The
wrapper deliberately does NOT default the singleton: DNS policy
(all lookups via Cloudflare) belongs to the consumer.

## Module: `services.dmarc-monitor`

Enables nixpkgs `services.parsedmarc` (11.0.2 at the fe132422 pin) with the heavy sinks OFF:
parsedmarc polls the `rua` mailboxes over IMAP and writes JSON+CSV reports to
`outputDirectory` (default `/var/lib/parsedmarc/reports`). Options: `enable`,
`outputDirectory`, `settings` (passthrough). Closes domains-repo findings
H1/H2 (rua reports go nowhere today).

0.16 CAVEAT (updated 2026-10-17, stalw.art/docs/mta/reports): Stalwart 0.16
natively imports and ANALYZES inbound DMARC and TLS AGGREGATE reports
(DMARCbis, 0.16.12+) AND inbound authentication-failure reports (DKIM/SPF/
DMARC, ARF), so parsedmarc's parsing monopoly is gone - it still uniquely
owns file-sink outputs and arbitrary-mailbox IMAP polling. Retire-or-keep
is decision C42 (decision-batch, evidence recorded 2026-10-17); the module
stands until that call.

## SystemNix integration (planned shape)

```nix
# flake.nix input (repo is public; git+ssh also works)
nix-email.url = "github:LarsArtmann/nix-email";
# consumer wrapper (DiscordSync pattern): import nixosModules.default, layer
# sops template for the IMAP password, port registration (lib/ports.nix),
# harden overrides, onFailure -> Discord (incl. the deliverability probe
# unit mail-deliverability-probe.service), Gatus checks,
# backup-coordination for outputDirectory.
```

The consumer wrapper already exists as
`SystemNix/modules/nixos/services/nix-email.nix` (sops secrets for the IMAP
password / fallback-admin / relay password, onFailure alert routing, the
integration-registry backup-freshness entry) and is eval-contract-tested in
`SystemNix/tests/test-nix-email.nix` - enabling dmarc-monitor on evo-x2 is a
consumer-config flip plus filling the real
`platforms/nixos/secrets/nix-email.yaml` secret, not new wiring.

PIN DISCIPLINE: consumers of this flake SHOULD pin it by a hard rev/tag
(not `?ref=master`): the wrapper is verified against a SPECIFIC Stalwart
version (0.16.26 via the vendored module + the pin's `stalwart_0_16`
since the 2026-10-28 fe132422 advance) at a specific
nixpkgs rev, and both repos deliberately pin the SAME nixpkgs rev (compat
doctrine - bump both together; Renovate PRs are approval-gated so a nixpkgs
move never lands unreviewed). STATUS 2026-10-28: SystemNix currently
FLOATS `github:LarsArtmann/nix-email` (master; lock at our HEAD -
verified) instead of the earlier `?ref=v0.4.0` tag pin (C17a): their
stated mitigation is upstream master's own CI + the E2E suites and the
`nixpkgs.follows`-forced contract check (`checks.nix-email-contract`),
which is why the lockstep catch-up here was urgent - a trailing wrapper
lock breaks THEIR gate. The v0.5.0 tag SHIPPED 2026-10-28 (C43
answered CUT); the pin-point remains available for consumers wanting a
hard rev, while SystemNix stays on the float by their own choice.
InboxClean's `?ref=master` is fine
there because it has no
nixpkgs-version-sensitive contract; this repo does.

Gatus checks for the VPS (on evo-x2, external viewpoint):

```yaml
- name: smtp-mx
  url: "starttls://mail.<domain>:25"
  conditions: ["[CONNECTED] == true", "[CERTIFICATE_EXPIRATION] > 720h"]
- name: imaps
  url: "tls://mail.<domain>:993"
  conditions: ["[CONNECTED] == true", "[CERTIFICATE_EXPIRATION] > 720h"]
```

## EventCatalog (catalog.home.lan)

nix-email is a fully governed EventCatalog source:
`scripts/export-catalog.py` emits the catalog tree (authored service
pages for `mail-server` and `dmarc-monitor` plus seven ADRs) and the
eventcatalog-hub consumes it via its `sources.manual.json` - a MANUAL
source, because the hub's depgraph only discovers Go modules.
Composition rule: our tree provides the service BODIES, deployment
badges union in from the SystemNix inventory tree (first-wins body,
badges union through - merge.py contract). The exporter is stdlib-only,
byte-deterministic, and `--selftest`-guarded (version lockstep 1.0.0
with the hub's inventory renderer, appliesTo resolution, no badges, no
catalog.index.json manifest). ADR statuses are honest: C42
(parsedmarc keep-or-retire) ships `proposed` until the owner decides;
C45 (stalwart pin vs overlay) flipped to `superseded` 2026-10-31 - it
was resolved by events (the pin advance shipped 0.16.26), not by an
owner call. Content edits happen in the
exporter's data dicts, never in generated trees; details in AGENTS.md
"EventCatalog integration".

## Go-live runbook (outline)

1. Provision Hetzner VPS (CX22-class); NixOS via the existing
   domains-repo cloud-init path. Set rDNS/PTR to the mail hostname.
   VERIFIED against Hetzner's official docs (docs.hetzner.com/cloud/servers/faq,
   2026-09-14): Hetzner Cloud blocks ports **25 and 465 by default on all
   cloud servers, enforced per account, both directions** - so inbound MX
   traffic on :25 is blocked too for a new account. After 1 month + first
   paid invoice, file a limit request (Hetzner Console > Limits) to unblock,
   case-by-case approval. Port 587 is never blocked (Resend relay
   unaffected). Plan the go-live AFTER the unblock is granted.
2. Stalwart admin bootstrap (0.16): set `services.mail-server.admin.username`
   - `admin.secretFile` (REQUIRED - the 0.16 fallback admin is a systemd
     credential and the provisioning CLI's only auth path; the wrapper's eval
     assertion refuses to build without it). Domain/account/DKIM provisioning
     is DECLARATIVE on 0.16 (`services.stalwart.provision.singletons/.objects`
     merged into the wrapper's plan - see "Per-account semantics" above); the
     web admin moved to `/admin` (a downloadable Application bundle served by
     stalwart - reverse-proxy the loopback httpBind). On the VPS the secret
     comes from a credential file (sops on the consumer side). Remote admin
     access plan (2026-09-30): the
     NetBird VPN on the pbx box replaces ad-hoc SSH tunnels as the standard
     path (SystemNix
     `docs/brainstorming/2026-09-30_netbird-larsartmann-cloud-selfhosted-vpn.md`
     Phase 3); SSH tunnels stay the break-glass fallback.

3. Terraform (`domains` repo): new `stalwart-mail` module - MX, SPF
   (`v=spf1 mx -all`), DKIM txt, DMARC with `rua=mailto:dmarc@<domain>`,
   MTA-STS + `_smtp._tls` TLS-RPT records; point `rua` mailboxes at the VPS.
   Outbound relay through Resend - the wrapper's `relay` option renders the
   0.16 MtaRoute objects (no hand-written settings).
4. Migrate mailboxes BEFORE the MX switch (imapsync 2.314 is in nixpkgs);
   lower MX TTL first, keep Workspace alive ~2 weeks as rollback.
5. evo-x2: enable `dmarc-monitor` against the `dmarc@` IMAP mailbox; drive
   the DMARC ladder (`none -> quarantine -> reject`) from the report data.
   Enablement goes through the SystemNix consumer wrapper
   (`modules/nixos/services/nix-email.nix`): flip `services.dmarc-monitor.enable`
   in the host config and fill the real IMAP-password secret - the sops
   wiring, onFailure alerting, and backup-freshness check are already layered
   and eval-tested there (see "SystemNix integration" above).
6. Backups (0.16, VM-VERIFIED 2026-10-18 on the pin - full transcripts:
   `docs/probes/2026-10-18-demo-smoke-backup/`):
   - **Full store**: stop stalwart, `stalwart --config <cfg> --export
     <dir>` (offline; 20 `subspace_*` files), restart. Restore = wipe
     `/var/lib/stalwart`, recreate `db/`, `--import <dir>` BEFORE the
     first start (the binary refuses a store that was ever started:
     "already contains data in the key ranges"), then `touch
     /var/lib/stalwart/v016-store-migrated` or the wrapper's store
     guard refuses the boot - verified end-to-end incl. listeners,
     logins, mail counts, and post-restore delivery.
   - **Config-only**: `stalwart-cli snapshot Domain Account Directory
     DnsServer DnsResolver AcmeProvider Tenant --allow-unresolved
     PublicKey,Role > plan.ndjson` (env `STALWART_URL/_USER/_PASSWORD`);
     secrets stripped by default (`--include-secrets` to include);
     restore via `stalwart-cli apply`. Snapshot enforces referential
     closure and rejects cycles without `--allow-unresolved`.
   - **Hot copy**: stop + `cp -a /var/lib/stalwart` + start is a valid
     full backup (verified: mail intact after restart); schedule as a
     stop/copy/start unit or accept btrfs-snapshot fallback; pull
     results to the evo-x2 pool via backup-coordination.
   - **Per-account mail**: `stalwart-vandelay` (Stalwart's own export
     tool) IS in the pin since at least fe132422 (1.0.12, eval-verified
     2026-10-31 - the older "not in nixpkgs" note is dead), but it is
     UNVERIFIED against a live store here; per-account export rides
     imapsync (2.314 in the pin) until the migration-tooling compare
     (ROADMAP, plan E13) runs on scratch mailboxes.
     The wrapper wires none of this (thin-wrapper doctrine); SystemNix
     owns the scheduling + backup-coordination layer (their repo).
7. DR: sops secrets for the VPS must also encrypt to a repo-level recovery
   age key, not only the VPS host key - a rebuilt VPS gets a new host key
   and would otherwise lose every secret (chicken-and-egg).

## Pin-advance runbook (consumer pin + workaround re-check)

Run this whenever nixpkgs moves (Renovate is approval-gated; python deps
inside nixpkgs are invisible to it, so the checks below are manual):

1. **Bump both locks together** (compat doctrine): `nixpkgs` input in THIS
   flake and in SystemNix's - same rev, same commit. Never land one without
   the other.
2. **Re-check the shipped workarounds - the presence list** (module comments
   carry the code side; this is the procedure side; every bullet is a fact
   the module depends on, re-verify each against the new pin):
   - `[elasticsearch]`/`[opensearch]` emission: rerun `nix build
     .#checks.x86_64-linux.dmarc-eval`
     and the `parsedmarc-e2e` VM test. **EXECUTED 2026-10-28 at the
     fe132422 advance**: nixpkgs PR #566282 (merged 2026-10-13) is IN the
     pin - the wrapper ports to `provision.opensearch` (mkRemovedOption
     on the elasticsearch name). The strip-guard STAYS (same shape,
     renamed `[opensearch]`; nixpkgs #563651 still open).
   - DIFF the parsedmarc module source at every advance, not just the
     known workaround keys (lesson 2026-10-28: the #566282 dovecot
     removal was discoverable in the fetched module in seconds, but was
     only found via a 25-minute VM red): fetch
     `nixos/modules/services/monitoring/parsedmarc.nix` at the new rev
     and grep for REMOVED wiring (`dovecot`, `localMail` shape, unit
     hardening changes) before building any VM check. **EXECUTED
     2026-10-28**: localMail no longer wires dovecot at all (postfix +
     a `[maildir]` watch only), which surfaced a REAL wrapper gap - the
     ProtectSystem=strict sandbox vs parsedmarc's `.Archive` mkdirs in
     postfix's spool. Fixed by the wrapper's storage contract (boot-time
     `tmpfiles` pre-creation of the maildir + an UNPREFIXED
     ReadWritePaths entry; a `-` prefix is silently evaluated-once at
     namespace setup and an ExecStartPre pre-creation dies at
     `226/NAMESPACE` - systemd namespaces EVERY ExecStartPre command);
     the whole contract is eval-pinned in `dmarc-eval`'s localMail-shape
     eval (three transcript-diagnosed VM runs, all evidence in
     CHANGELOG [Unreleased]/Fixed).
   - imapclient/python pin: check the NixOS python scope's `imapclient`
     version. Revert `parsedmarcPackage` in `modules/dmarc-monitor.nix` (and
     the `dmarc-eval` pin assertion) when the pin ships imapclient >= 4.1.0
     (mjs/imapclient#663). **EXECUTED 2026-10-28**: fe132422 ships 4.1.0
     (`nix eval`) + parsedmarc 11.0.2 on the py3.14 default scope - the
     py3.13 pin and the `ExecStart = mkForce` override are REVERTED; all
     five e2e fixtures re-verified host-side first
     (`scripts/host-parse-fixture.py`, incl. the three transcribed
     `arrival_date_utc` values and the aggregate identity fields).
   - Stalwart version surface (updated 2026-10-28): the wrapper vendors
     the 0.16 module (`modules/stalwart-module/`, nixpkgs PR #552103 -
     still OPEN 2026-10-28, `pkgs.stalwart` is still the 0.15.5 line at
     fe132422, so the vendored dir stays) and the binary is the pin's
     `stalwart_0_16` - **0.16.26** since the fe132422 advance (was
     0.16.22). The re-verification surface at a bump: (a) when PR
     #552103 merges into the pinned rev, retire the vendored dir
     (checklist in the module header); (b) re-verify the wrapper's 0.16
     object shapes if `stalwart_0_16` moves (schema.json diff via the
     provision check + the plan typecheck; DONE 2026-10-28 -
     provision-plan-eval green, stalwart-e2e green on 0.16.26);
     (c) 0.16.26's x86-64-v2 requirement is LIVE since the advance:
     every VM node running the 0.16 binary sets `-cpu max`
     (tests/common.nix `v2CpuPatches`, TCG-safe - `host` is invalid
     without KVM); REAL hosts need a v2-capable CPU check on the
     consumer side. The 0.16.26-overlay question (C45) is superseded -
     the pin itself now ships 0.16.26.
3. **Advance the SystemNix consumer pin**: update the `nix-email` input rev
   (hard rev or release tag - see PIN DISCIPLINE above), `nix flake update
   nix-email`, restore any option-gated test cases the old pin forced out
   (the relay-credential assertions were the first instance), delete dead
   option-existence guards, then `nix flake check` in BOTH repos. Gate
   commands never wear pipes. Since the 2026-09-17 flake-parts migration,
   the bump also decides what happens to nix-email's `flake-parts` input:
   dedupe it (`inputs.nix-email.inputs.flake-parts.follows =
   "flake-parts"` in SystemNix - the fleet already carries one
   flake-parts node) or accept a second lock node; nix-email floats
   flake-parts (lock-pinned), so `nix flake update flake-parts` moves it
   independently of nixpkgs.
4. Tag a release here when the modules changed; SystemNix's pin should
   reference it (the consumer contract is versioned by the tag, the exact
   rev stays locked in flake.lock).

## Development

Language note: the project vocabulary (plan, reconcile set, match
property, singleton, datastore descriptor, ...) is defined in
[docs/DOMAIN_LANGUAGE.md](docs/DOMAIN_LANGUAGE.md) - read it before the
module docs if the provisioning terms are new.

The devShell carries the tooling (`nix develop`): alejandra, actionlint +
shellcheck (actionlint without shellcheck on PATH is blind to shell
findings), python3 for the scripts. The quality gates, in order of
authority:

- `nix flake check` - the full gate: eval contract + the VM E2E tests.
- `nix fmt -- . --check` - what CI enforces (bare `nix fmt` forwards no
  paths on alejandra 4.0.0 and dies on stdin - always pass `.`).
- `buildflow` - the fmt/lint/repair wrapper around both (see
  `.buildflow.yml` for deliberate skips; AGENTS.md documents known lint
  noise).

Gate commands never wear pipes (`cmd \| tail` can print PASSED on a failing
run) - redirect to a file and read it. See CONTRIBUTING.md for the
verified-facts ledger rules and the architecture-diagram regen command.

### Try it in a VM (demo stack; reworked for 0.16, runtime smoke verified)

`nix run .#vm` (x86_64-linux) boots a throwaway QEMU VM with the full
mail-server stack, a declaratively provisioned `demo@mail.demo.test`
account, and a catch-all. All state dies with the process. Host-side
endpoints (bound to 127.0.0.1 only):

| Host port | Guest | Purpose                                                                                      |
| --------- | ----- | -------------------------------------------------------------------------------------------- |
| 18080     | 8080  | web admin (`/admin` bundle) / JMAP - admin login `admin` / `demo-admin` (systemd credential) |
| 2525      | 25    | SMTP (unauthenticated inbound; catch-all accepts ANY local part)                             |
| 2587      | 587   | submission, STARTTLS + AUTH (`demo@mail.demo.test` / `demo-nixemail-2026`)                   |
| 2593      | 993   | IMAPS (`demo@mail.demo.test` / `demo-nixemail-2026`)                                         |

0.16 notes: there is NO REST API (the 0.15-era `GET /api/principal` probe
is dead) - provisioning is the declarative plan applied by
`stalwart-provision` at boot, and the account password is
`demo-nixemail-2026` (0.16 enforces zxcvbn strength; `demo` is rejected).
The domain is `mail.demo.test`, not `mail.demo.invalid` - 0.16 hostname
validation rejects the special-use `.invalid` TLD. **Fresh 0.16.26 smoke:
DONE 2026-10-31** (anon JMAP session shape, AUTH submission -> IMAPS
round-trip, catch-all SMTP-accept + strict rejection outside the
provisioned domain; transcript
`docs/probes/2026-10-31-demo-smoke-01626/`); one-command re-smoke since
2026-11-01: `scripts/demo-console.sh` boots + `scripts/demo-smoke.py`
probes all five legs (transcript
`docs/probes/2026-11-01_demo-smoke-tooling/`).

The demo VM runs with `deliverabilityChecks` OFF on purpose: the probe
needs real DNS (MX/SPF/DMARC/DKIM + DNSBL zones) and a provisioned
canary account to be meaningful, and the slirp NAT demo has neither -
the battery would run all-WARN/FAIL noise, not signal. The probe's own
behavior is VM-e2e'd by `deliverability-e2e` against a real local DNS
zone instead (that test node is the reference posture for a real
host).

Known cosmetic startup noise in the demo journal: `Spam classifier model
not found` and `Resource error` lines (the spam-filter resource's ASN/GeoIP
CSV downloads from cdn.jsdelivr.net fail in the slirp NAT - non-fatal, the
lookups just miss).

One VM at a time per user: the demo disk lives at
`~/.cache/nix-email-demo/demo.qcow2` (2026-10-18: the app wrapper pins
`NIX_DISK_IMAGE` there - it is no longer CWD-relative, so boots never
pollute the working directory) and QEMU takes a write lock on it, so a
second concurrent `nix run .#vm` by the same user dies on the lock
(observed during the InboxClean spike, 2026-10-05). Serialize, or set
`NIX_DISK_IMAGE` yourself before `nix run .#vm`.

#### JMAP quickstart (0.16 shape; transcript-pinned on the demo VM 2026-10-16/17)

The session document MOVED in 0.16: `GET /jmap` is 404 for everyone; the
entry point is `/.well-known/jmap` (307 -> `location: /jmap/session`).
Anonymous session requests return 200 with `primaryAccounts: {}` (the real
enforcement point is the API POST, which 401s unauthenticated). Basic-auth
username is the FULL synthesized address (`name@<hostname>`), and every URL
in the session is absolute - rewrite it to `127.0.0.1:18080` before use
(or read `apiUrl` from the session doc and strip scheme+authority):

```sh
# session document (capabilities, accounts, URL templates)
curl -fsSL -u demo@mail.demo.test:demo-nixemail-2026 http://127.0.0.1:18080/.well-known/jmap

# mailboxes: take apiUrl from the session doc (ends in /jmap/), then
curl -fsS -u demo@mail.demo.test:demo-nixemail-2026 http://127.0.0.1:18080/jmap/ \
  -H 'Content-Type: application/json' -d '{
    "using": ["urn:ietf:params:jmap:core", "urn:ietf:params:jmap:mail"],
    "methodCalls": [["Mailbox/query", {"accountId": "<from primaryAccounts>"}, "a"]]}'
```

Push is SSE (`/jmap/eventsource/?types=Email`); the 0.15-era
`{closeafter}`/`{ping}` rejection verdict is RETIRED - 0.16 re-verified
2026-10-26 (probe `docs/probes/2026-10-26-es-ping/`: `closeafter=no`
accepted, the 0.15.5 `400 Invalid parameters` quirk gone; numeric `ping`
accepted but inert, non-numeric rejected). The InboxClean contract
(`docs/INBOXCLEAN.md`) is the 0.16-verified authority; transcripts in
`docs/probes/2026-10-05-jmap-demo-vm/` are 0.15-historical.

#### Contacts quickstart (CardDAV + JMAP contacts; probe-pinned 2026-10-19/20)

The same HTTP listener serves the contacts surface. CardDAV discovery
starts at `/.well-known/carddav`; addressbooks are MKCOL-able collections
under `/dav/card/<address>/<book>/`; JMAP contacts speak
`urn:ietf:params:jmap:contacts` at the session's `apiUrl`. The full
chain (discovery, CRUD, conditional PUT, multiget, addressbook-query,
sync-collection) is probe-verified on the deployed 0.16.26 pin
(re-baselined 2026-10-28 after the fe132422 advance: 17/18 PASS, the
0.16.22 baseline reproduced unchanged — transcripts
`docs/probes/2026-10-28-carddav-01626/`; the original run and the
server-dialect notes that bit the first mirror (`If-Match` REQUIRED on
overwrite, `no-uid-conflict`, async ingestion, sync-level 1) live in
`docs/probes/2026-10-19-carddav-demo-vm/README.md`).
No webmail frontend ships in the package (verified-facts ledger below) —
the contacts story is the API surface; the Kith CRM out-mirror consumes
exactly this.

## Platform support

The VM tests gate `stalwart-e2e`/`stalwart-relay-e2e` to **x86_64-linux
ONLY**. Nobody has ever executed them under qemu-aarch64 (slow-TCO trap
noted in the flake); `dmarc-eval` is arch-independent and runs everywhere.
ARM users: the modules themselves are arch-neutral Nix - only the VM test
gate is missing - but treat aarch64 as untested until someone runs it.

`nix fmt` (alejandra) formats all `.nix` files; dprint covers
json/yaml/markdown.

## Verified-facts ledger

The transcript- and source-pinned fact set (the 0.16 dialect, every
sharp edge, and the 0.15.5-era history) lives in
[docs/LEDGER.md](docs/LEDGER.md). Read it before changing Stalwart or
parsedmarc config keys - several "obvious" upstream keys are wrong.

## Non-goals

Re-confirmed 2026-10-31 against the 0.16.26 wrapper (E15 pass): every entry
below still stands, nothing overtaken by events - the listener contract is
25/465/587/993 (POP3 provable absent, `modules/mail-server.nix` listener
set), the relay stays the opt-in smarthost path, and no search-stack or
archiving dependency has entered the tree.

Piler (archiving - maildir snapshots + paperless cover personal use),
Mailcow/Mailu (Docker-first, heavy), Elasticsearch for parsedmarc (a search
stack to read 16 domains' DMARC mail), a wrapper around
`services.mailpit.instances` (single option, nothing to layer), direct-to-MX
outbound (fresh-IP reputation; the Resend relay is the design). POP3 is
deliberately NOT in the wrapper's listener contract (25/465/587/993 only) -
a consumer can add it via `services.stalwart.settings` if a legacy client
ever needs it. Offloading
Stalwart's internal full-text search to Meilisearch or friends: same
doctrine as the Elasticsearch rejection (the built-in Community FTS already
serves a single-user deployment).

## External upstream issues

Diagnosed here, filed upstream, watched on every nixpkgs bump (retirement
conditions in the module comments and the Pin-advance runbook):

- [NixOS/nixpkgs#563651](https://github.com/NixOS/nixpkgs/issues/563651) -
  parsedmarc module materializes a host-less `[elasticsearch]` ini section
  with `provision.elasticsearch = false` (parsedmarc 11 exits 255). Wrapper
  workaround: guarded `ExecStartPre` strip. UPSTREAM REWORK MERGED
  2026-10-13 (nixpkgs PR #566282): master dropped `provision.elasticsearch`
  (`mkRemovedOptionModule` - the filed repro no longer evals) in favor of
  `provision.opensearch` (default TRUE), but the bug SHAPE PERSISTS: with
  `provision.opensearch = false` the module still materializes a host-less
  `[opensearch]` section (unconditional `ssl`/`cert_path` defaults survive
  the null filter) and parsedmarc still exits 255 ("hosts setting missing
  from the opensearch config section", cli.py re-verified on parsedmarc
  master 2026-10-19). Issue still OPEN, zero maintainer response; the
  wrapper port landed 2026-10-28 at the fe132422 pin (guard + tests on
  the `[opensearch]` shape; see the NIXPKGS BUG ledger entry).
- [NixOS/nixpkgs#563652](https://github.com/NixOS/nixpkgs/issues/563652) -
  imapclient `starttls()` assigns the read-only `imaplib.IMAP4.file` on
  python 3.14. Wrapper workaround: unit pinned to the py3.13 build. UPSTREAM
  FIX LANDED: [mjs/imapclient#663](https://github.com/mjs/imapclient/pull/663)
  MERGED 2026-09-18 and released in imapclient 4.1.0 (maintainer comment on
  the nixpkgs issue; no further movement - the 2026-10-01 touch was only a
  title rename); the 2026-10-28 fe132422 pin ships 4.1.0 (`nix eval`),
  so the py3.13 pin is RETIRED (workaround reverted 2026-10-28; the
  module's own py3.14 ExecStart is back). [mjs/imapclient#662](https://github.com/mjs/imapclient/issues/662)
  (the upstream crash report) is CLOSED as fixed.
- [NixOS/nixpkgs#563777](https://github.com/NixOS/nixpkgs/issues/563777) -
  parsedmarc module ships no systemd `Restart` policy: the poller exits 255
  on a transient boot race (observed in the TLS IMAPS VM variant) and stays
  failed. Fixture adds `Restart = on-failure` to stay deterministic; filed
  2026-09-16 asking for `Restart = lib.mkDefault "on-failure"`. Re-checked
  2026-10-19: still OPEN, zero comments, and the reworked master module
  still contains no `Restart` (grep-verified).
- [mjs/imapclient#662](https://github.com/mjs/imapclient/issues/662) -
  the upstream crash report for the py3.14 `starttls()` bug (same root
  cause as nixpkgs#563652). CLOSED as fixed via the #663 merge (see the
  nixpkgs#563652 entry above for the retirement condition).
- [seanthegeek/mailsuite#65](https://github.com/seanthegeek/mailsuite/issues/65) -
  mailsuite auto-STARTTLS cannot be opted out of: `ssl=False` still
  upgrades when the server advertises STARTTLS (same trap as
  parsedmarc#534). Filed 2026-10-05 after the verify-before-filing gates
  (master `imap.py` byte-identical at the quoted lines, no duplicate
  issue). RESOLVED UPSTREAM 2026-10-27 without our involvement: CLOSED
  COMPLETED, fixed by their PR #67 `feat/imap-starttls-opt-out` (a
  `starttls` opt-out on IMAPClient/IMAPConnection and `send_email`;
  releases 2.3.3/2.3.4) - the planned nudge is moot; residual = verify
  their `starttls` opt-out satisfies parsedmarc at the next
  mailsuite-advancing bump. Wrapper impact today: none - the parsedmarc
  e2e runs TLS IMAPS with DEFAULT verification.
