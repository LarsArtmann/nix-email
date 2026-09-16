# nix-email

[![CI](https://github.com/LarsArtmann/nix-email/actions/workflows/ci.yml/badge.svg)](https://github.com/LarsArtmann/nix-email/actions/workflows/ci.yml)

Declarative mail stack for LarsArtmann hosts: an opinionated
[Stalwart](https://stalw.art) mail-server wrapper + a light parsedmarc
DMARC/TLS-RPT monitor, packaged as a NixOS flake for consumption by
[SystemNix](../SystemNix) (upstream-flake pattern, like InboxClean/DiscordSync).

Architecture (per `~/projects/reports/selfhosted-email-guide.md`): self-hosted
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

stalwart: Stalwart 0.15.5 (services.mail-server wrapper) {
  smtp_in: SMTP listeners (25 MX, 587 submission, 465 submissions)
  imaps: IMAPS listener (993, implicit TLS)
  http: HTTP listener (127.0.0.1:8080, loopback only)
  queue: Queue + routing strategy (is_local_domain -> local, else -> relay)
  spam: Spam filter (GTUBE, rules)
  dkim: DKIM signer (signature.<id>)
  directory: Internal directory (negative-cache TTL option)
  acme: ACME client (self-signed | acme | manual tiers)
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
stalwart.spam -> stalwart.store: tags X-Spam-Status (GTUBE/rules); INBOX by default, no auto-Junk filing
stalwart.dkim -> stalwart.queue: signs outbound
stalwart.acme -> letsencrypt: issues certificates
stalwart.smtp_in -> dns: SPF/DNSBL/DKIM lookups
stalwart.queue -> dns: MX resolution
parsedmarc.poller -> stalwart.imaps: polls rua mailbox (IMAP 993)
parsedmarc.poller -> parsedmarc.output: save_output (fixed filenames)
parsedmarc.output -> viewer: JSON/CSV files (future read path)
secrets -> stalwart.http: "LoadCredential + %{file:...}% config macros"
prometheus -> proxy: GET /metrics/prometheus
```

The target deployment shape (SystemNix layering: sops, Caddy, Gatus,
onFailure alerting, backups) is
`docs/architecture-understanding/2026-09-15_09_23-nix-email-improved.svg`;
the rendered current-state SVG sits next to it.

## What is built and verified

| Piece                                          | State                                                                         |
| ---------------------------------------------- | ----------------------------------------------------------------------------- |
| `modules/mail-server.nix`                      | Done. VM-tested E2E (see below)                                               |
| `modules/dmarc-monitor.nix`                    | Done. Eval contract-tested; needs a live IMAP mailbox to exercise             |
| Mailpit for dev/CI                             | Use nixpkgs `services.mailpit.instances` directly - no wrapper adds value     |
| VPS host, DNS cutover, migration, Gatus wiring | Planned - see "Go-live runbook" and ROADMAP.md (gated on the D1/D2 decisions) |

Open work lives in [TODO_LIST.md](TODO_LIST.md); the honest feature
inventory in [FEATURES.md](FEATURES.md); long-term direction and the gating
user decisions in [ROADMAP.md](ROADMAP.md).

`nix flake check` runs both tests against the SAME nixpkgs pin as SystemNix
(`eaad089`, NixOS 26.11):

- `stalwart-e2e`: real Stalwart 0.15.5 in a VM - service up, full SMTP
  dialogue with unknown-recipient 550 rejection, implicit-TLS IMAPS greeting,
  loopback HTTP admin, declarative `fallback-admin` bootstrap, accounts via
  the management API, authenticated submission on 587 delivering into a real
  INBOX fetched back over IMAPS, DKIM signing of the submission
  (`DKIM-Signature` asserted on the stored message), Prometheus metrics
  endpoint, journal-hygiene count (exactly the 2 known-benign config errors),
  restart persistence, offline backup/restore drill (`--export`, wipe,
  `--import`, message survives), no panics.
- `stalwart-relay-e2e`: TWO-node VM - Stalwart with `relay` -> Mailpit
  smarthost node. Non-local submission lands in Mailpit through the
  generated `queue.route`/`queue.strategy.route`, local domains still
  deliver locally (and never leak to the relay), relay hostname resolved via
  dnsmasq (Stalwart's resolver ignores /etc/hosts).
- `parsedmarc-e2e`: TWO-node VM - a Dovecot fixture mailbox seeded with the
  upstream sample DMARC aggregate report, polled by the real parsedmarc 11
  unit; JSON/CSV output asserted (row counts, org metadata), the runtime ini
  asserted free of the inert `[elasticsearch]` section, and a second node
  exercising the production-shaped IMAPS 993 path with DEFAULT certificate
  verification (machine-trusted fixture CA, `ssl=True`, no
  skip-verification).
- `dmarc-eval`: eval-time contract - enables parsedmarc, heavy sinks off,
  `general.output` lands, `_secret` password survives the option types AND
  the real ini generation (the unit's config render is forced, so a wrong
  `_secret` shape fails here, not on a host).

## Module: `services.mail-server`

Enables nixpkgs `services.stalwart` with one RFC-compliant listener set:

| Port                                | Listener    | Notes                                                 |
| ----------------------------------- | ----------- | ----------------------------------------------------- |
| 25                                  | smtp        | inbound MX, STARTTLS advertised                       |
| 587                                 | submission  | client auth + STARTTLS                                |
| 465                                 | submissions | implicit TLS                                          |
| 993                                 | imaps       | implicit TLS                                          |
| httpBind (default `127.0.0.1:8080`) | http        | web admin / JMAP - reverse-proxy it, never expose raw |

Options: `enable`, `hostname` (FQDN, asserted to contain a dot), `httpBind`
(loopback default; a NixOS warning fires on non-loopback binds),
`stateVersion`, `relay` (outbound smarthost, see below), `metrics.enable`
(`/metrics/prometheus` on the HTTP listener), `directoryCacheTtlNegative`
(kills the 1h negative-cache trap on dev/test hosts), and `certificate`
(`self-signed | acme | manual` tier with completeness assertions). Everything
else flows through `services.stalwart.settings` (all wrapper values are
`mkDefault` - consumer settings win). Defaults set: listeners above and the
self-signed certificate tier so implicit-TLS works out of the box. Firewall:
the wrapper opens exactly 25/465/587/993 (nixpkgs' `openFirewall` is off -
it would also open the loopback admin port on every interface); consumer
port lists merge additively.

### Outbound relay (`services.mail-server.relay`)

null (default) = direct-to-MX. When set, non-local mail transits the
smarthost - the wrapper generates `queue.route.<routeId>` +
`queue.strategy.route` (IfBlock shape verified against the v0.15.5 source
AND a live two-node VM test, `stalwart-relay-e2e`):

```nix
services.mail-server.relay = {
  address = "smtp.resend.com"; # hostname REQUIRED - IP literals are refused
  port = 587;                  # 587 = STARTTLS, 465 = implicit (tlsImplicit)
  username = "resend";
  secretFile = "/run/secrets/resend-smtp-password"; # LoadCredential + %{file:...}% macro
};
```

Local-domain delivery is untouched (`is_local_domain` stays on the local
queue). Relaying to loopback targets is refused by Stalwart (SSRF guard) and
exercised by the two-node E2E; the auth-less form (`username = null`) is
valid for trusted internal smarthosts.

Outbound smarthost relaying (Stalwart -> Resend) is a per-host `settings`
addition - the verified keys are in the ledger below (confirmed against the
v0.15.5 source, not guessed).

## Module: `services.dmarc-monitor`

Enables nixpkgs `services.parsedmarc` (11.0.1) with the heavy sinks OFF:
parsedmarc polls the `rua` mailboxes over IMAP and writes JSON+CSV reports to
`outputDirectory` (default `/var/lib/parsedmarc/reports`). Options: `enable`,
`outputDirectory`, `settings` (passthrough). Closes domains-repo findings
H1/H2 (rua reports go nowhere today).

## SystemNix integration (planned shape)

```nix
# flake.nix input (repo is public; git+ssh also works)
nix-email.url = "github:LarsArtmann/nix-email";
# consumer wrapper (DiscordSync pattern): import nixosModules.default, layer
# sops template for the IMAP password, port registration (lib/ports.nix),
# harden overrides, onFailure -> Discord, Gatus checks, backup-coordination
# for outputDirectory.
```

The consumer wrapper already exists as
`SystemNix/modules/nixos/services/nix-email.nix` (sops secrets for the IMAP
password / fallback-admin / relay password, onFailure alert routing, the
integration-registry backup-freshness entry) and is eval-contract-tested in
`SystemNix/tests/test-nix-email.nix` - enabling dmarc-monitor on evo-x2 is a
consumer-config flip plus filling the real
`platforms/nixos/secrets/nix-email.yaml` secret, not new wiring.

PIN DISCIPLINE: SystemNix pins this repo by a hard rev/tag (not `?ref=master`):
the wrapper is verified against the nixpkgs `services.stalwart` module (0.15.5)
at a specific nixpkgs rev, and both repos deliberately pin the SAME nixpkgs
rev (compat doctrine - bump both together; Renovate PRs are approval-gated so
a nixpkgs move never lands unreviewed). InboxClean's `?ref=master` is fine
there because it has no nixpkgs-version-sensitive contract; this repo does.

Gatus checks for the VPS (on evo-x2, external viewpoint):

```yaml
- name: smtp-mx
  url: "starttls://mail.<domain>:25"
  conditions: ["[CONNECTED] == true", "[CERTIFICATE_EXPIRATION] > 720h"]
- name: imaps
  url: "tls://mail.<domain>:993"
  conditions: ["[CONNECTED] == true", "[CERTIFICATE_EXPIRATION] > 720h"]
```

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
2. Stalwart admin bootstrap: set `authentication.fallback-admin`
   (`user` + `secret` - VERIFIED to work with an empty internal directory,
   no first-run wizard needed) or use the web wizard over an SSH tunnel to
   the loopback httpBind: create accounts/domains, DKIM keys. On the VPS the
   secret must come from a credential file: `services.stalwart.credentials`
   - `%{file:/run/credentials/stalwart.service/<key>%}` macro in settings
     (sops on the consumer side).
3. Terraform (`domains` repo): new `stalwart-mail` module - MX, SPF
   (`v=spf1 mx -all`), DKIM txt, DMARC with `rua=mailto:dmarc@<domain>`,
   MTA-STS + `_smtp._tls` TLS-RPT records; point `rua` mailboxes at the VPS.
   Outbound relay through Resend - verified keys in the ledger below
   (`queue.route."resend"` type=relay + `queue.strategy.route`).
4. Migrate mailboxes BEFORE the MX switch (imapsync 2.314 is in nixpkgs);
   lower MX TTL first, keep Workspace alive ~2 weeks as rollback.
5. evo-x2: enable `dmarc-monitor` against the `dmarc@` IMAP mailbox; drive
   the DMARC ladder (`none -> quarantine -> reject`) from the report data.
   Enablement goes through the SystemNix consumer wrapper
   (`modules/nixos/services/nix-email.nix`): flip `services.dmarc-monitor.enable`
   in the host config and fill the real IMAP-password secret - the sops
   wiring, onFailure alerting, and backup-freshness check are already layered
   and eval-tested there (see "SystemNix integration" above).
6. Backups (VERIFIED against v0.15.5 source): the binary ships a NATIVE
   consistent export - `stalwart --config ... --export <dir>` (offline op:
   runs instead of serving, then exits) writes lz4-framed dumps of ALL store
   families (data, directory, blob, config, changelog, queue, report,
   telemetry, tasks); `--import <dir>` restores. This is the preferred
   primitive - no RocksDB-crash-consistency folklore needed. It is offline,
   so schedule it as a stop/export/start unit or accept btrfs-snapshot
   fallback for hot copies. Pull results to the evo-x2 pool via
   backup-coordination.
7. DR: sops secrets for the VPS must also encrypt to a repo-level recovery
   age key, not only the VPS host key - a rebuilt VPS gets a new host key
   and would otherwise lose every secret (chicken-and-egg).

## Pin-advance runbook (consumer pin + workaround re-check)

Run this whenever nixpkgs moves (Renovate is approval-gated; python deps
inside nixpkgs are invisible to it, so the checks below are manual):

1. **Bump both locks together** (compat doctrine): `nixpkgs` input in THIS
   flake and in SystemNix's - same rev, same commit. Never land one without
   the other.
2. **Re-check the two shipped workarounds** (module comments carry the code
   side; this is the procedure side):
   - `[elasticsearch]` emission: rerun `nix build .#checks.x86_64-linux.dmarc-eval`
     and the `parsedmarc-e2e` VM test. If nixpkgs stops materializing the
     host-less section (check `nixos/modules/services/monitoring/parsedmarc.nix`
     for a fixed `filterAttrsRecursive`/option shape), delete the guarded
     `ExecStartPre` strip in `modules/dmarc-monitor.nix` and the matching
     `dmarc-eval`/`parsedmarc-e2e` assertions in the same change.
   - imapclient/python pin: check the NixOS python scope's `imapclient`
     version. Revert `parsedmarcPackage` in `modules/dmarc-monitor.nix` (and
     the `dmarc-eval` pin assertion) when nixpkgs ships an imapclient whose
     `starttls()` no longer assigns `imaplib.IMAP4.file` on python 3.14
     (imapclient 4.x fixed the plain connect path but NOT starttls as of
     2026-09-15 - README ledger).
   - Watch for `services.stalwart` passing 0.15.5: the wrapper's verified key
     set (relay IfBlocks, certificate tiers) must be re-verified against the
     new source before riding the bump.
3. **Advance the SystemNix consumer pin**: update the `nix-email` input rev
   (hard rev or release tag - see PIN DISCIPLINE above), `nix flake update
   nix-email`, restore any option-gated test cases the old pin forced out
   (the relay-credential assertions were the first instance), delete dead
   option-existence guards, then `nix flake check` in BOTH repos. Gate
   commands never wear pipes.
4. Tag a release here when the modules changed; SystemNix's pin should
   reference it (the consumer contract is versioned by the tag, the exact
   rev stays locked in flake.lock).

## Platform support

The VM tests gate `stalwart-e2e`/`stalwart-relay-e2e` to **x86_64-linux
ONLY**. Nobody has ever executed them under qemu-aarch64 (slow-TCO trap
noted in the flake); `dmarc-eval` is arch-independent and runs everywhere.
ARM users: the modules themselves are arch-neutral Nix - only the VM test
gate is missing - but treat aarch64 as untested until someone runs it.

`nix fmt` (alejandra) formats all `.nix` files; dprint covers
json/yaml/markdown.

## Verified-facts ledger (do not re-derive from memory)

- nixpkgs `services.stalwart` runs **0.15.5**; `stalwart_0_16` exists but is
  module-incompatible. The report's "0.16.20" praise does not apply to the
  module until nixpkgs moves.
- TLS cert key is `certificate.self-signed` (NO `.default` level) - verified
  against the binary and a live handshake. Without any cert, implicit-TLS
  listeners log "No TLS certificates available" and serve nothing.
- parsedmarc 11: connection settings MUST be in the `[imap]` ini section
  (missing host/user/password raises ConfigurationError); `[mailbox]` is
  behavior flags only. nixpkgs' typed `_secret` support exists only on
  `settings.imap.*`. There is NO SQLite sink; JSON/CSV files are the
  zero-dependency output. A `[postgresql]` sink exists but needs the
  `psycopg` extra (not in the nixpkgs package; psycopg 3.3.4 is available
  for an override).
- parsedmarc `_secret` values must be absolute path STRINGS
  (`password._secret = "/run/secrets/dmarc-imap-password";`) - the nixpkgs
  ini generator gates on `isString v._secret` and THROWS on path values
  ("unsupported type path"), and path literals are forbidden in flake source
  anyway (pure eval). Corrected 2026-09-15: an earlier phrasing here said
  "PATHS, not strings", which read as "path values" - it always meant
  "a path pointing at the secret file, given as a string".
- swaks marks SMTP error-response lines with `<**`, success with `<-`, AND
  (observed 2026-09-15, relay VM) a 550 RCPT refusal can arrive with the
  `<~*` marker (its timeout-receive variant) - assert the marker set you
  OBSERVED in the transcript, never the one you expected; tests need
  `--timeout 120` because RCPT policy checks (SPF/DNSBL) stall ~30 s per
  lookup in a DNS-less VM.
- Two "Configuration build error" journal lines at startup in the DNS-less
  VM are BENIGN (details only visible via `journalctl -o verbose`):
  `resolver.type: no nameservers found in config` (nixpkgs module default
  `resolver.type = "system"` + empty resolv.conf) and
  `spam-filter.pyzor.host` lookup failure. A host with a resolver hits
  neither.
- The self-signed cert (`certificate.self-signed`, generated by rcgen) is
  created ASYNCHRONOUSLY at first start and can take >80 s in the
  entropy-poor DNS-less VM - implicit-TLS checks must POLL, not single-shot
  (this is what made the pre-account E2E test flaky).
- Stalwart downloads ASN/Geo IP data from cdn.jsdelivr.net at first start -
  offline environments log "Resource error" lines (benign) and need egress.
- Hetzner Cloud port policy (VERIFIED against docs.hetzner.com/cloud/servers/faq,
  "Why can I not send any mails from my server?", 2026-09-14): ports 25 and
  465 are blocked BY DEFAULT on all cloud servers, enforced per account,
  both directions. Unblock via a limit request after 1 month + first paid
  invoice (case-by-case). Port 587 is never blocked. Consequence: the
  hybrid design is safe on outbound (relay via 587), but INBOUND MX on :25
  requires the unblock before go-live - the community guides claiming
  "Hetzner port 25 open by default" are outdated.
- Metrics (VERIFIED against v0.15.5 source): `metrics.prometheus.enable =
  true`, optional `metrics.prometheus.auth.username`/`auth.secret` (HTTP
  basic auth). Endpoint is `/metrics/prometheus` ON THE HTTP LISTENER - with
  the loopback default that means a reverse-proxy route or ssh tunnel for
  Prometheus; do not expose the whole admin port for it.
- Outbound relay (VERIFIED against v0.15.5 source, closes the old "do not
  guess" item): since 0.13 routing is expression-based. A smarthost is
  `[queue.route."<id>"]` with `type = "relay"`, `address`, `port`,
  `protocol = "smtp"`, `auth.username`, `auth.secret`, optional
  `tls.implicit`. Select it with `queue.strategy.route` (an expression;
  default routes local domains to `'local'`, everything else to `'mx'`).
  The nixpkgs module ASSERTS against the pre-0.13 `queue.*.next-hop`.
  LIVE SPIKE 2026-09-14 (local binary + Mailpit): (a) an IfBlock route
  needs INDEXED keys - `queue.strategy.route.1.if` / `.1.then` /
  `.2.else`; a bare `if`/`then`/`else` fails to parse, and `else` must
  sort AFTER `if` (else-before-if is a parse error); (b) the relay
  address is resolved via DNS A lookup - a bare IP literal fails with
  "record not found for MX", so use a resolvable hostname
  (e.g. `smtp.resend.com`); (c) Stalwart REFUSES to relay to loopback
  addresses ("host resolves loopback address") - a good SSRF guard, and
  the reason the VM E2E cannot exercise the smarthost path.
- Bootstrap admin (VERIFIED): `authentication.fallback-admin.user`/`.secret`
  work with an empty internal directory. This is how the E2E test gets an
  admin declaratively (the upstream reference config ships exactly this).
- Account provisioning API (VERIFIED against webadmin source + live VM):
  `POST /api/principal` (basic auth as admin) with `{"type": "individual",
  "name": ..., "emails": [...], "secrets": ["<sha512-crypt $6$ hash>"]}` -
  passwords are hashed CLIENT-side (pwhash sha512_crypt format).
  `{"type": "domain", "name": ...}` makes a domain local (returns
  `{"data": <id>}`). DKIM keygen via `POST /api/dkim`. GOTCHA: individuals
  need `"roles": ["user"]` - without it auth succeeds but submission is
  refused with 550 5.7.1 "not authorized to use this service" (the webadmin
  adds the role silently).
- Local-domain routing (VERIFIED in VM + source read, 2026-09-14): the
  default queue route is `is_local_domain('*', rcpt_domain) -> 'local'`,
  else MX. The directory NEGATIVELY caches `is_local_domain` misses for
  1 HOUR (`directory.<id>.cache.ttl.negative`, default 3600s, e.g.
  `directory."internal".cache.ttl.negative`;
  crates/directory/src/core/cache.rs - positive cache is 24h). Consequence:
  ANY SMTP traffic (even a MAIL FROM probe) touching a domain before it is
  provisioned poisons the cache and routes that domain's mail to the MX
  path - in the VM that means DNS timeouts, never local delivery. Provision
  domains before first traffic, or lower the negative TTL on dev/test hosts.
- DKIM signing (VERIFIED): keys live under `signature.<id>` with
  `algorithm` (`rsa-sha256`/`ed25519-sha256`), `private-key` (inline PEM,
  supports `%{file:...}%` macros), `domain`, `selector`. `auth.dkim.sign`
  is an expression defaulting to sign local-domain mail with ids
  `['rsa-' + sender_domain, 'ed25519-' + sender_domain]` - exactly the ids
  the webadmin generates via `POST /api/dkim`.
- TLS/ACME (VERIFIED key names): manual certs are `certificate.<id>.cert`
  - `certificate.<id>.private-key`; built-in ACME is `acme.<id>.directory`,
    `.contact`, `.challenge`, `.renew-before` (default 30d), DNS-challenge
    extras `.origin`, `.polling-interval`, `.propagation-timeout`.
- nixpkgs module secret injection: `services.stalwart.credentials` (attrsOf
  path) becomes systemd LoadCredential files, referenced in settings as
  `%{file:/run/credentials/stalwart.service/<key>%}` - the sops-compatible
  way to feed the relay and admin secrets.
- Inbound auth defaults need NO config: SPF/DMARC/iprev verification only
  runs on port 25 (`local_port == 25` conditions), disabled on submission
  ports; DKIM verify is `relaxed` everywhere.
- Stalwart's system resolver reads ONLY /etc/resolv.conf - it IGNORES
  /etc/hosts (observed 2026-09-15, relay VM: dnsmasq on 127.0.0.1 bridging
  /etc/hosts made `relay` resolvable; the NixOS test driver's /etc/hosts
  injection alone did not). Same mechanism any VM test needs for hostname
  relay targets.
- The nixpkgs parsedmarc unit runs as a DynamicUser and prepares NO writable
  state; parsedmarc 11.0.1 os.makedirs()es its output directory on first
  write, which fails on root-owned /var/lib without `StateDirectory`
  (verified 2026-09-15 against parsedmarc.nix + parsedmarc/__init__.py:3478;
  the wrapper now sets StateDirectory).
- `mkDefault` lists on `networking.firewall.allowedTCPPorts` are silently
  dropped (ROOT-CAUSED 2026-09-15, closing the 2026-09-14 symptom-only
  entry): `lib/modules.nix filterOverrides'` keeps only numerically-lowest
  priority definitions - lists concat WITHIN a tier, never across - and base
  nixpkgs ships unconditional `[]` defs at priority 100 on that option from
  modules whose services are DISABLED: podman `network-socket.nix:95`
  (`lib.optional (enable && openFirewall) port`) and `udp-over-tcp.nix:276`
  (`getFirewallPorts`). Verified via
  `options.<name>.definitionsWithLocations` (the debugging tool for any
  "where did my definition go" mystery) plus a priority bisect (100
  survives, 101 drops). The `lib.optional`-instead-of-`mkIf` shape is the
  upstream anti-pattern: `mkIf false` contributes NO definition, an
  evaluated `[]` still wins its priority tier. `services.openssh.ports` has
  no such base def, which is why mkDefault works fine there.
- Dovecot 2.4 (this nixpkgs pin) ASSERTS on explicit
  `dovecot_config_version`/`dovecot_storage_version` - and nixpkgs'
  parsedmarc `provision.localMail` enables dovecot2 WITHOUT them (also
  still uses the renamed `services.dovecot2.protocols`, warning-only).
  Any localMail consumer must pin both versions itself
  (`tests/parsedmarc-e2e.nix` does; found 2026-09-15). Same migration also
  renamed the UNIT: `systemd.services.dovecot` (was `dovecot2.service`) -
  `wait_for_unit "dovecot2.service"` fails with "inactive, no pending jobs"
  even though dovecot is running (observed in parsedmarc-e2e, 2026-09-15).
- Per-account storage QUOTA (VERIFIED in VM, 2026-09-15): the `quota`
  principal field is an integer byte count on any individual
  (`POST /api/principal` with `"quota": 1`). An over-quota message is
  ACCEPTED at RCPT but never delivered - the queue retries forever with
  "Mailbox over quota." (delivery.rs:225, source-verified); there is no 5xx rejection at
  SMTP time. Assert delivery-absence (IMAP), not SMTP refusal. JOURNAL GOTCHA
  (VM-observed 2026-09-15): the reason string is NOT logged at default
  verbosity - the retry's journal signature is `Message rescheduled for
  delivery`; do not grep for the reason text.
- CATCH-ALL vs unknown-recipient rejection is a TEST-ORDERING trap
  (observed 2026-09-15): a principal with the literal `"@<domain>"` address
  (AddressMapping retries the lookup with `@<domain>`) makes EVERY local
  part deliverable - `RCPT TO:<nobody@example.test>` then answers
  `250 2.1.5 OK` and any "unknown recipient rejected 5xx" assertion fails.
  Create the catch-all principal AFTER the rejection probe (the E2E does).
- Spam filter DEFAULTS (VM-verified 2026-09-15 via GTUBE experiment): the
  built-in rule filter scans authenticated submission on 587 too, adds
  `X-Spam-Status` (GTUBE in the BODY triggers; subject-only text does not
  match the rule), and STILL delivers to INBOX. There is NO server-side
  auto-filing into the Junk mailbox in 0.15.5 - routing spam to Junk is a
  sieve/consumer concern. Journal noise to expect: "Spam classifier model
  not found" (the statistical classifier has no trained model; the rule
  engine works without it). IMAP LOGIN resolves by principal NAME, not by
  the principal's email addresses: a principal named `catchall` with email
  `catchall@example.test` cannot log in as the email address, only as
  `catchall` (accounts whose name IS their address never trip this).
- NIXPKGS BUG (workaround shipped 2026-09-15; filed upstream as
  NixOS/nixpkgs#563651): with
  `provision.elasticsearch = false`, the parsedmarc module's settings
  submodule still MATERIALIZES `elasticsearch.cert_path` (types.path,
  defaults to the CA bundle) and `.ssl` (types.bool, defaults false).
  Both survive the module's null/[]/{} config filter, so the rendered ini
  carries `[elasticsearch]` with no `hosts` - and parsedmarc 11 raises
  "hosts setting missing from the elasticsearch config section"
  (ConfigurationError, exit 255) at start. Neither key can be nulled
  through its option type, so `modules/dmarc-monitor.nix` strips the
  section from the RENDERED ini via a guarded `ExecStartPre` (only while
  ES is off); `tests/dmarc-eval.nix` asserts the workaround stays wired.
  Upstream-able: the module should not emit the section when ES is not
  provisioned. Re-checked against nixpkgs MASTER 2026-09-15: still present
  (`elasticsearch.ssl`/`.cert_path` defaults pass the same
  `lib.filterAttrsRecursive` null/[]/{} filter), so the issue is still live
  upstream, not stale.
- NIXPKGS BUG (workaround shipped 2026-09-15; filed upstream as
  NixOS/nixpkgs#563652): on this rev the NixOS
  python scope resolves imapclient 3.1.0 for parsedmarc, and 3.1.0 is
  incompatible with python 3.14 (the VM's interpreter): its
  `IMAP4WithTimeout.open()` assigns `self.file`, a read-only property
  since 3.14 - parsedmarc dies at the first IMAP connect with
  AttributeError (exit 255) before any polling happens. The SAME rev
  ships parsedmarc 11.0.1 on python 3.13, where 3.1.0 still works, so
  the wrapper pins the unit's ExecStart to the python3.13 build (same
  version, same CLI, same ini contract). `dmarc-eval` asserts the pin.
  Revert when nixpkgs ships an imapclient compatible with 3.14's
  imaplib. Upstream status 2026-09-15: imapclient 4.0.1 (the version on
  nixpkgs master) DROPPED the `imap4.py` `open()` override entirely, so
  the common connect path is fixed - but `imapclient.py` `starttls()`
  still assigns `self._imap.file`, so 4.x on python 3.14 still breaks the
  STARTTLS-upgrade path (`lib/python3.14/imaplib.py:337` is the read-only
  property). Cite both halves when filing.
- mailsuite (parsedmarc's IMAP layer) AUTO-ACTIVATES STARTTLS whenever the
  server advertises the capability (mailsuite/imap.py:284: `if not ssl and
  b"STARTTLS" in self.capabilities()`). A dovecot that advertises STARTTLS
  without usable certificate material therefore breaks plaintext-IMAP
  consumers with `SSL: WRONG_VERSION_NUMBER` at connect - the VM's
  localMail dovecot needed `ssl = "no"` (plaintext fixture, no cert
  material; production rua mailboxes use real TLS). Found while bringing
  `tests/parsedmarc-e2e.nix` green, 2026-09-15.
- The upstream sample DMARC report (estadocuenta1...2940.xml.zip) parses
  with org_name "XYZ Corporation" even though the FILENAME says
  infonacot.gob.mx - parsedmarc reads the XML body, so assertions must use
  the body's metadata. (This bit nobody once, exactly once - 2026-09-15.)
- IMAP/IMAPS LOGIN resolves by principal NAME (VM-verified 2026-09-15 via
  curl-imaps probe): a principal named `catchall` with email
  `catchall@example.test` CANNOT log in as the email address, only as
  `catchall`. Accounts created by the webadmin never trip this because
  their name IS their address - a scripting/API-created account with a
  non-address name must be probed by name.
- CAPABILITY AUDIT vs 0.15.5 (2026-09-15; method: grep of the v0.15.5 git
  tag source tarball + vendor compare page + v0.16.0 release notes - a
  source-tag audit, NOT live-binary proof; presence claims below still need
  runtime confirmation before wiring): automated DKIM rotation and automated
  DNS management are **0.16.0 features** (not on this pin - the manual
  `POST /api/dkim` recipe and Terraform-as-DNS-truth stand); native
  DMARC/TLS-RPT/ARF ingestion IS on 0.15.5 (`smtp/src/reporting/`, report
  store family, CLI/management readout) and is kept as a free complement to
  parsedmarc, not a replacement; OIDC, TOTP, encryption-at-rest, autoconfig,
  POP3, JMAP-WS, MTA-STS/DANE, Zenoh clustering are present in the 0.15.5
  source; PROXY protocol is NOT (0.16+). Verdicts live in
  `docs/planning/2026-09-15_19-23_nix-email-pareto-master-plan.md` §10.
- SIEVE/JUNK-FILING architecture in 0.15.5 (source-verified 2026-09-15
  against the pinned store source, while implementing wrapper-owned Junk
  filing - it is NOT implementable via settings):
  - Settings keys exist (`sieve.trusted.scripts.<id>.contents`,
    `sieve.untrusted.scripts.<id>.contents`; crates/common/src/config/
    scripts.rs `Scripting::parse`) - but the TRUSTED runtime is built with
    `.without_capabilities([FileInto, Mailbox, ...])` (same file), so a
    settings script can NEVER file a message anywhere.
  - Delivery-time sieve runs ONLY the recipient account's ACTIVE script
    fetched from the STORE (crates/email/src/message/delivery.rs:
    `sieve_script_get_active(account_id)`; `None` -> plain INBOX ingest -
    which is why GTUBE mail lands in INBOX).
  - Settings-defined UNTRUSTED scripts are include-libraries for user
    scripts (crates/email/src/sieve/ingest.rs:187), not entry points.
  - `X-Spam-Status` is added at ingest from the SMTP-session spam verdict
    (crates/email/src/message/ingest.rs:319).
  - No OSS management-API endpoint sets an account's active sieve script
    (JMAP per-account, or the enterprise webadmin) - the OSS CLI has no
    sieve subcommand either.
  Consequence: Junk filing on this pin is per-account (webmail-managed
  sieve or per-account JMAP automation), not declarable from the wrapper.
  Revisit if 0.16+ grows server-side filing.

## Non-goals

Piler (archiving - maildir snapshots + paperless cover personal use),
Mailcow/Mailu (Docker-first, heavy), Elasticsearch for parsedmarc (a search
stack to read 16 domains' DMARC mail), a wrapper around
`services.mailpit.instances` (single option, nothing to layer), direct-to-MX
outbound (fresh-IP reputation; the Resend relay is the design). POP3 is
compiled into Stalwart 0.15.5 but deliberately NOT in the wrapper's listener
contract (25/465/587/993 only) - a consumer can add it via
`services.stalwart.settings` if a legacy client ever needs it. Offloading
Stalwart's internal full-text search to Meilisearch or friends: same
doctrine as the Elasticsearch rejection (the built-in Community FTS already
serves a single-user deployment).

## External upstream issues

Diagnosed here, filed upstream, watched on every nixpkgs bump (retirement
conditions in the module comments and the Pin-advance runbook):

- [NixOS/nixpkgs#563651](https://github.com/NixOS/nixpkgs/issues/563651) -
  parsedmarc module materializes a host-less `[elasticsearch]` ini section
  with `provision.elasticsearch = false` (parsedmarc 11 exits 255). Wrapper
  workaround: guarded `ExecStartPre` strip. Filed 2026-09-15, re-verified
  unfixed on nixpkgs master same day.
- [NixOS/nixpkgs#563652](https://github.com/NixOS/nixpkgs/issues/563652) -
  imapclient `starttls()` assigns the read-only `imaplib.IMAP4.file` on
  python 3.14. Wrapper workaround: unit pinned to the py3.13 build. Root fix
  belongs upstream at mjs/imapclient (still present on master as of
  2026-09-16, `imapclient/imapclient.py:387`).
