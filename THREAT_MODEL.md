# Threat Model — nix-email

Scope: the nixpkgs wrapper modules in this repo (`services.mail-server`,
`services.dmarc-monitor`) and their VM-verified behavior. The consuming host
layer (sops, reverse proxy, firewall aggregation, monitoring) belongs to the
consumer wrapper (SystemNix `modules/nixos/services/nix-email.nix`) and is
listed under [Out of scope](#out-of-scope--consumer-responsibilities).

Every claim below is backed by the verified-facts ledger in `README.md` or by
a test in `tests/` (file + subtest named inline). No threat is claimed
"mitigated" without a mechanism that can be pointed at.

## System context

```
Internet ──25──▶ Stalwart (inbound MX, SPF/DMARC/iprev on :25 only)
Internet ◀─587── Stalwart (submission, authenticated principals)
Stalwart ──587──▶ upstream smarthost (optional `relay.*`, STARTTLS/implicit TLS)
parsedmarc ◀─143── dovecot localMail (reads DMARC reports from a local mailbox)
parsedmarc ──files──▶ output directory (aggregate JSON/CSV, consumer-collected)
Prometheus ◀─8080── Stalwart /metrics/prometheus (loopback)
admin ◀─8080────── Stalwart HTTP admin (loopback, basic auth)
```

The wrapper binds Stalwart's HTTP listener to `127.0.0.1:8080` by default;
`mailBind`/`imapsBind` follow the same doctrine. A NixOS assertion **warns**
when `httpBind` is configured non-loopback (`modules/mail-server.nix`,
assertions block). There is no path in this repo that publishes a Stalwart
port beyond what the wrapper's own firewall definitions open, and the
firewall defaults exist only to keep the IANA mail ports reachable for MX
duty.

## Trust boundaries

| Boundary | Crossing | Trust assumption |
| --- | --- | --- |
| Internet → Stalwart :25/:587 | SMTP | Untrusted. Inbound filter verification (SPF/DMARC/iprev) runs on :25 only; submission requires an authenticated principal with `roles: ["user"]` (verified: role-less principals authenticate but get `550 5.7.1`, README ledger). |
| Stalwart → smarthost | SMTP client | Trusted relay credential, untrusted network. TLS via `relay.tls.implicit` or STARTTLS; relay target must be a resolvable hostname (IP literals fail), loopback targets are REFUSED ("host resolves loopback address") — an SSRF guard by the upstream binary, relied on by the two-node relay test design. |
| local process → Stalwart :8080 | HTTP admin + JMAP + metrics | Loopback-only by default. Admin requires basic auth; anonymous admin API returns 401 (asserted across a service restart in `tests/stalwart-e2e.nix`). Metrics endpoint is UNAUTHENTICATED by default and therefore must stay loopback (`metrics.prometheus.auth.*` exists for when it must cross a boundary). |
| sops/LoadCredential → Stalwart | secret injection | Secrets never appear in the Nix store or `stalwart.toml` as literals: the consumer sops-renders them to files, systemd `LoadCredential`s them, and settings reference `%{file:...}%` macros (README ledger, "nixpkgs module secret injection"). The wrapper only declares `secretFile` path options; it never reads secret content at eval time. |
| parsedmarc → dovecot :143 | IMAP read of report mailbox | Loopback/localMail only. Credentials via `imap.password._secret` (path string contract, verified against the nixpkgs ini generator). |
| parsedmarc → output directory | files | The output directory is consumer-owned state (`StateDirectory` set by the wrapper after root-cause 2026-09-15). DMARC aggregate reports contain sending-infrastructure metadata; treat the directory as semi-sensitive and let only the consumer's collector read it. |

## Assets and secret inventory

| Secret | Where it lives | Rotation surface |
| --- | --- | --- |
| `mail-server.relay.secretFile` | consumer sops secret → LoadCredential file | smarthost account credential |
| `mail-server.certificate.manual.keyFile` / ACME keys | consumer sops file or nixpkgs ACME integration | TLS private key for the mail domains |
| `services.stalwart.credentials` (fallback-admin, relay) | consumer sops secret → LoadCredential | admin password, relay password |
| `dmarc-monitor.settings.imap.password._secret` | consumer sops secret (`dmarc-imap-password` in the SystemNix wrapper) | mailbox password |
| DKIM private keys (`signature.<id>.private-key`) | declaratively in the wrapper config today; for production use `%{file:...}%` against a consumer secret (supports the macro, README ledger) | domain signing identity |

This repo ships no secret material; its only embedded key material is the
test-only RSA key in `tests/stalwart-e2e.nix` (clearly marked as published
test fixture, PKCS#8, VM-internal).

## What the loopback guard does and does NOT protect

**Does:**
- Keeps the admin API, JMAP-over-HTTP and the unauthenticated metrics
  endpoint unreachable from other hosts on the default configuration
  (bind address, not just firewall: a listener bound to 127.0.0.1 is closed
  even with a firewall hole).
- Makes accidental exposure a *deliberate* act: non-loopback binds trigger
  an eval-time warning naming the option and the doctrine.

**Does NOT protect against:**
- **Local processes.** Anything running on the mail host can reach the admin
  port. The admin credential is the only gate; keep the host's local process
  surface trusted (this is the standard NixOS multi-service trust model).
- **The admin credential itself.** `fallback-admin` authenticates with basic
  auth over plaintext HTTP on loopback. On a single-tenant host this is
  acceptable; do not terminate this port on a shared reverse proxy without
  TLS from the proxy to the operator.
- **Firewall misconfigurations by consumers.** The wrapper's firewall defs
  open the IANA mail ports. A consumer that publishes 8080 in its own
  `allowedTCPPorts` defeats the bind only if the bind was also moved;
  binding and firewall are independent layers and this repo enforces the
  bind layer.
- **Metadata-level threats.** Envelope headers, DMARC aggregate XML, and
  mail logs carry third-party addresses. Backup and monitoring pipelines
  (consumer-owned) must apply the consumer's data-handling policy.

## Administrative exposure policy

1. Admin stays loopback; operate it via ssh tunnel or a consumer reverse
   proxy route with authentication in front (SystemNix Caddy pattern).
2. The fallback-admin secret must be LoadCredential/sops-sourced on any
   real host, never inline in a git-tracked module (the wrapper's docs and
   the SystemNix consumer both do this; the VM tests use throwaway
   declarative secrets by design).
3. Account provisioning happens through the authenticated admin API; the
   documented API shape includes the `roles: ["user"]` requirement to avoid
   the silent-refusal failure mode (README ledger "Account provisioning
   API").

## Attacker scenarios considered

| Scenario | Outcome | Mechanism / evidence |
| --- | --- | --- |
| Internet host relays through this server (open relay) | Refused | Stalwart submission requires authenticated local principals; non-local destinations route via the smarthost credential (`queue.route` IfBlocks, `tests/stalwart-relay-e2e.nix`). |
| Mail to an address on a not-yet-provisioned domain is used to probe the topology | Negative-cache poisoning, not disclosure | Documented operational trap: `is_local_domain` misses cache negatively for 1 h by default, misrouting subsequent mail to the MX path (README ledger; regression-guard subtest planned in `tests/stalwart-e2e.nix`). It is an availability bug class, not an information leak. |
| SSRF via relay target configuration or user-influenced routing | Refused for loopback | Upstream refuses loopback relay targets ("host resolves loopback address"); relay `address` requires a resolvable hostname (README ledger LIVE SPIKE 2026-09-14). |
| Anonymous access to the admin API, incl. across restarts | 401 | `tests/stalwart-e2e.nix` restart subtest asserts the admin API stays locked after `systemctl restart`. |
| Spam into user mailboxes | Filtered | Stalwart spam filter enabled by the wrapper (`spam-filter.*` namespace verified against the binary); GTUBE-based Junk-delivery subtest guards the behavior. |
| Secrets leak through the Nix store or module system | Prevented by construction | Secrets are files via LoadCredential + `%{file:...}%` macros; the wrapper declares path options only (README ledger; consumer wrapper wiring). |
| Tampered/oversized mail exhausts storage | Bounded per-principal | Stalwart per-principal quota; over-quota delivery subtest guards the mechanism (quota subtest in `tests/stalwart-e2e.nix`). |

## Out of scope / consumer responsibilities

- sops secret provisioning and encryption-key policy (SystemNix `sops.nix`,
  `.sops.yaml` age keys).
- Reverse proxy / TLS termination for any published route, incl. the admin
  route and metrics scraping.
- Firewall aggregation conflicts: base nixpkgs modules can silently drop
  `mkDefault` list definitions on `networking.firewall.allowedTCPPorts`
  (root-caused, README ledger + AGENTS.md) — the wrapper uses a plain
  definition there precisely so consumer layers cannot be outranked.
- Backup confidentiality/integrity of the mail store and the parsedmarc
  output directory (SystemNix backup-coordination).
- Monitoring/on-call: consumer onFailure units and Gatus checks (SystemNix
  registry `monitored = true`).
- Inbound MX reachability (Hetzner :25 unblock request, README runbook).
