# nix-email

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

## What is built and verified (2026-09-14)

| Piece | State |
| --- | --- |
| `modules/mail-server.nix` | Done. VM-tested E2E (see below) |
| `modules/dmarc-monitor.nix` | Done. Eval contract-tested; needs a live IMAP mailbox to exercise |
| Mailpit for dev/CI | Use nixpkgs `services.mailpit.instances` directly - no wrapper adds value |
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
  INBOX fetched back over IMAPS, no panics.
- `dmarc-eval`: eval-time contract - enables parsedmarc, heavy sinks off,
  `general.output` lands, `_secret` password survives the option types.

## Module: `services.mail-server`

Enables nixpkgs `services.stalwart` with one RFC-compliant listener set:

| Port | Listener | Notes |
| --- | --- | --- |
| 25 | smtp | inbound MX, STARTTLS advertised |
| 587 | submission | client auth + STARTTLS |
| 465 | submissions | implicit TLS |
| 993 | imaps | implicit TLS |
| httpBind (default `127.0.0.1:8080`) | http | web admin / JMAP - reverse-proxy it, never expose raw |

Options: `enable`, `hostname` (FQDN, asserted to contain a dot), `httpBind`,
`stateVersion` (passed to the nixpkgs module, default `"26.11"`). Everything
else flows through `services.stalwart.settings` (all wrapper values are
`mkDefault` - consumer settings win). Defaults set: listeners above and
`certificate.self-signed = true` so implicit-TLS works out of the box
(override with real certs/ACME on the VPS). Firewall: the wrapper opens
exactly 25/465/587/993 (nixpkgs' `openFirewall` is off - it would also open
the loopback admin port on every interface); consumer port lists merge
additively.

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

Gatus checks for the VPS (on evo-x2, external viewpoint):

```yaml
- name: smtp-mx
  url: "starttls://mail.<domain>:25"
  conditions: [ "[CONNECTED] == true", "[CERTIFICATE_EXPIRATION] > 720h" ]
- name: imaps
  url: "tls://mail.<domain>:993"
  conditions: [ "[CONNECTED] == true", "[CERTIFICATE_EXPIRATION] > 720h" ]
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
   + `%{file:/run/credentials/stalwart.service/<key>%}` macro in settings
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
- parsedmarc `_secret` values must be PATHS (store paths / sops template
  paths), not strings, and never path literals in flake source (pure eval).
- swaks marks SMTP error-response lines with `<**`, success with `<-`; RCPT
  policy checks (SPF/DNSBL) stall ~30 s per lookup in a DNS-less VM - tests
  need `--timeout 120`.
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
  + `certificate.<id>.private-key`; built-in ACME is `acme.<id>.directory`,
  `.contact`, `.challenge`, `.renew-before` (default 30d), DNS-challenge
  extras `.origin`, `.polling-interval`, `.propagation-timeout`.
- nixpkgs module secret injection: `services.stalwart.credentials` (attrsOf
  path) becomes systemd LoadCredential files, referenced in settings as
  `%{file:/run/credentials/stalwart.service/<key>%}` - the sops-compatible
  way to feed the relay and admin secrets.
- Inbound auth defaults need NO config: SPF/DMARC/iprev verification only
  runs on port 25 (`local_port == 25` conditions), disabled on submission
  ports; DKIM verify is `relaxed` everywhere.

## Non-goals

Piler (archiving - maildir snapshots + paperless cover personal use),
Mailcow/Mailu (Docker-first, heavy), Elasticsearch for parsedmarc (a search
stack to read 16 domains' DMARC mail), a wrapper around
`services.mailpit.instances` (single option, nothing to layer).
