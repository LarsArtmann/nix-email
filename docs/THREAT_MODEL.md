# Threat model

Scope: the two wrapper modules in this repo (`services.mail-server`,
`services.dmarc-monitor`) as consumed by SystemNix hosts. Every claim marked
VERIFIED points at the README verified-facts ledger; ASSUMED means it rests
on upstream defaults we have not independently probed.

## 0.16 exposure delta (2026-10-18 revisit)

The 0.16 object model moved the threat surface in BOTH directions:

- SHRANK: the 0.15 REST management API (`/api/principal`, `/api/reports`,
  `/api/dkim`) is GONE - the loopback listener now serves the web admin,
  JMAP, and the management API the provisioning CLI speaks. The
  "proxy forwards /api/" misconfiguration class below is historical
  (0.15); a proxy must not forward the JMAP/management paths instead.
- GREW: declarative provision plans carry account passwords in PLAINTEXT
  in the world-readable Nix store (`credentials[].secret` in the plan
  NDJSON; 0.15 exposed only salted hashes through the API). The demo
  accepts this for a throwaway VM; REAL hosts must NOT - decision C44
  (pending) owns the doctrine: admin-created accounts (b), sops-rendered
  runtime apply (a), or credential-file secrets (c). Until C44 lands,
  real-host plans should provision principals WITHOUT password
  credentials.
- GREW (operator-side, not network-side): the 0.15->0.16 migration
  artifacts (`<dataDir>/migration-v016/`: settings.json, principals.json,
  export.json) and `stalwart-cli snapshot --include-secrets` outputs
  contain secrets - dataDir-local, root/stalwart-owned; do not copy them
  off-host unencrypted (backup story: probe transcripts 2026-10-18).
- Store-guard boundary: the wrapper's `ExecStartPre` guard makes the
  poison-class (0.16 binary writing into a 0.15 store, destroying the
  dump path) a loud refusal instead of a crash loop - integrity, not
  confidentiality, but it is part of the 0.16 posture.
- MemoryMax / resource caps on the stalwart unit: decision C39 (pending)
  owns whether the wrapper ships one; currently unbounded (host OOM
  risk lands on the consumer's own unit tuning).

## Assets and secrets

| Secret                                 | Lives where                                          | How it reaches Stalwart                                                                                                                                                       |
| -------------------------------------- | ---------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `authentication.fallback-admin.secret` | declared per host                                    | `services.stalwart.credentials` (systemd LoadCredential) + `%{file:...}%` macro - the value never lands in the world-readable TOML (VERIFIED macro mechanism, README runbook) |
| Relay password (`relay.secretFile`)    | sops template / credential file                      | same LoadCredential + macro path (`mail-server-relay` key)                                                                                                                    |
| TLS private key (manual cert mode)     | cert/key files                                       | LoadCredential (`mail-server-certificate[-key]`) + macro                                                                                                                      |
| DKIM private keys                      | `signature.<id>` settings (inline or `%{file:...}%`) | config at start; a leaked DKIM key lets attackers sign as the domain until the DNS record is rotated                                                                          |
| Account password hashes                | internal directory (RocksDB)                         | sha512-crypt, hashed CLIENT-side before the API call (VERIFIED); the plaintext never reaches the server                                                                       |

The sops layering (which key store encrypts what, recovery age key for DR)
belongs to the SystemNix consumer wrapper, not this repo (runbook step 7).

## The loopback guard (HTTP listener)

- The admin/web admin/JMAP/REST/metrics listener binds `127.0.0.1:8080` by
  default; the wrapper now emits a NixOS **warning** when `httpBind` is not a
  loopback address. Doctrine: reverse-proxy it (TLS + auth at the proxy),
  never expose the raw listener.
- What this protects: the management API and web admin from direct network
  reach. The firewall never opens the port either (the wrapper's port list
  is exactly 25/465/587/993; nixpkgs' `openFirewall` is disabled because it
  would punch out the admin bind on every interface).
- What this does NOT protect:
  - Local processes: any code running on the host (or SSRF'd into it) can
    reach `127.0.0.1:8080`. Loopback is a network boundary, not an
    authorization boundary. The fallback-admin credential is the actual
    gate for privileged API use (anonymous API access returns 401 -
    VERIFIED in the E2E, including across a restart).
  - Proxy misconfiguration: a reverse proxy that forwards `/api/` without
    auth re-creates the exposure one layer up.
  - A consumer explicitly setting a non-loopback `httpBind`: that is a
    warning, not an assertion - deliberate (legitimate behind-auth proxying
    setups exist) but loud.

## Relay SSRF posture

Stalwart REFUSES to relay to loopback-resolving targets ("host resolves
loopback address" - VERIFIED live spike). The wrapper mechanizes that half
since 2026-09-22: `relay.address` = localhost/127.0.0.1/::1/0.0.0.0 is
rejected at EVAL time (module assertion, negative-tested). The relay
option additionally rejects bare IP literals at eval time (the binary
fails them at runtime with "record not found for MX"). Net effect: the
smarthost path cannot be pointed at localhost services.

## Transport security tiers

- Default `certificate.mode = "self-signed"`: implicit-TLS ports work out of
  the box, but the cert is self-generated - clients get encryption, not
  identity. Any go-live host MUST switch to `acme` or `manual` (assertions
  require their inputs to be complete so the tier cannot silently degrade).
- `manual` mode registers the cert as the SNI catch-all
  (`certificate.<id>.default`), so SNI-less probes still complete a
  handshake (VERIFIED against v0.15.5 source).
- ACME `http-01` needs port 80 reachable; Hetzner blocks 25/465 by default
  (runbook) - plan the cutover accordingly.

## Inbound/outbound mail policy

- Unknown recipients are rejected 5xx by directory lookup before anything
  is queued (VERIFIED in both VM tests) - no open relay through the local
  domain logic, and the local-path test asserts non-existent local
  recipients never leak to the smarthost.
- SPF/DMARC/iprev verification runs only on the :25 listener; DKIM verify is
  relaxed everywhere (VERIFIED ledger). Submission (587/465) expects client
  AUTH (exercised with AUTH in the E2E; the exact unauthenticated-refusal
  policy is upstream default - ASSUMED, not independently probed).
- Outbound by default is direct-to-MX; with `relay` set, non-local mail
  transits the smarthost with credentials from LoadCredential.

## DMARC monitor

parsedmarc runs as a DynamicUser with the full nixpkgs hardening set
(CapabilityBoundingSet empty, ProtectHome/Kernel*, SystemCallFilter
@system-service). The wrapper adds `StateDirectory` so the report output
directory is writable. Its only credentials are the rua IMAP password (sops
template path string - see the ledger for the `_secret` string contract).

## Attacker scenarios considered

| Scenario                                                     | Outcome                                                  | Mechanism / evidence                                                                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Internet host relays through this server (open relay)        | Refused                                                  | Submission requires authenticated local principals; unknown local recipients are rejected before queueing (both VM tests).                                                                                                                                                                                                      |
| Probing the topology by mailing a not-yet-provisioned domain | Availability trap, not disclosure                        | The directory negatively caches `is_local_domain` misses for 1 h by default, misrouting later mail to the MX path (README ledger; the E2E carries a poisoning + low-TTL-recovery regression subtest).                                                                                                                           |
| SSRF via relay targets                                       | Refused for loopback                                     | Upstream refuses loopback-resolving relay targets; the wrapper additionally rejects IP literals at eval (above).                                                                                                                                                                                                                |
| Anonymous admin API access, across restarts                  | 401                                                      | Asserted in the E2E, including after `systemctl restart`.                                                                                                                                                                                                                                                                       |
| Spam into user mailboxes                                     | Scored; filing varies                                    | 0.16 (VM-observed 2026-10-18): unauthenticated inbound landed INBOX on one boot and Junk Mail on another - filing is score-based, NOT a fixed "tag-only, INBOX" rule (the 0.15 GTUBE posture). The e2e still asserts X-Spam-Status tagging; Junk ROUTING defaults are consumer sieve/settings territory.                        |
| Secrets leaking through the Nix store or module system       | Split verdict on 0.16                                    | File-based secrets (LoadCredential/sops, `%{file:...}%`) remain prevented by construction; BUT 0.16 provision plans carry account passwords in the world-readable store NDJSON (see the 0.16 delta above) - real hosts are C44-gated, the throwaway demo accepts it explicitly.                                                 |
| Oversized mail exhausting storage                            | Bounded per-principal                                    | Stalwart per-account quota; the E2E asserts an over-quota message is accepted at SMTP but never delivered (quota subtest).                                                                                                                                                                                                      |
| Enumerating valid local parts by recipient probing           | Impossible once a catch-all exists (deliberate tradeoff) | 0.16: `Domain.catchAllAddress` makes EVERY local part deliverable, so RCPT probing can no longer distinguish real mailboxes from invented ones. The E2E proves the delivery path; the ordering trap (create the catch-all AFTER any unknown-recipient probe, or the 550 assertion fails) is in the README ledger and AGENTS.md. |

## Out of scope / consumer responsibilities

- sops provisioning and key policy (SystemNix `sops` layer, `.sops.yaml`).
- Reverse proxy / TLS termination for any published route (admin route,
  metrics scraping).
- Firewall aggregation conflicts: base nixpkgs modules can silently drop
  `mkDefault` list definitions on `networking.firewall.allowedTCPPorts`
  (root-caused 2026-09-15, README ledger); the wrapper uses a plain
  definition there so consumer layers cannot be outranked.
- Backup confidentiality/integrity of the mail store and the parsedmarc
  output directory (SystemNix backup-coordination).
- Monitoring/on-call: consumer onFailure units and Gatus checks (SystemNix
  integration registry, `monitored = true`).
- Inbound MX reachability (Hetzner :25 unblock request, README runbook).
