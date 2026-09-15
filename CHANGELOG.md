# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `services.mail-server.relay` option: outbound smarthost relaying via
  verified `queue.route.<id>` + `queue.strategy.route` generation (v0.15.5
  source-verified key set, IfBlock indexed-key shape, eval assertions for
  IP-literal and half-configured auth), `modules/mail-server.nix`
- `stalwart-relay-e2e` two-node VM test: Stalwart + Mailpit smarthost -
  non-local submission transits the relay, local routing never leaks to it,
  relay hostname resolved via dnsmasq (Stalwart's resolver ignores
  /etc/hosts) (`tests/stalwart-relay-e2e.nix`)
- `metrics.enable` wrapper option wiring `metrics.prometheus.*`, with a
  `/metrics/prometheus` format assertion in the E2E
- `directoryCacheTtlNegative` wrapper option
  (`directory."internal".cache.ttl.negative`)
- `certificate` option tier (`self-signed | acme | manual`) with
  completeness assertions and ignore-warnings; manual mode registers the
  cert as the SNI catch-all via `certificate.<id>.default` (v0.15.5
  source-verified)
- NixOS warning when `httpBind` is non-loopback (README listener doctrine)
- `stalwart-e2e` subtests: DKIM signing (declarative `signature.<id>`,
  header asserted on the stored message), journal hygiene (exactly the 2
  known-benign config-build errors), restart persistence, offline
  backup/restore drill (`--export` → wipe → `--import`)
- `dmarc-eval`: parsedmarc >= 11 version floor guard and forced rendering of
  the real unit config (the ini generation with secret replacement is now
  actually exercised); `StateDirectory` wiring asserted
- CI: `.github/workflows/ci.yml` - fail-closed `nix flake check` with an
  expected-checks guard (asserts every check exists before the gate runs)
- `CONTRIBUTING.md` (verified-facts ledger rules), `docs/THREAT_MODEL.md`
  (loopback-guard boundaries, admin exposure policy, secret inventory),
  `renovate.json` (nix manager, approval-gated, SystemNix pairing note),
  `git-town.toml`
- `nix fmt` support: flake `formatter` output (alejandra) + one full
  formatting pass over all `.nix` files
- GitHub repo topics (mail, nixos, nixos-module, stalwart, dmarc,
  email-server, nix-flake)
- `stalwart-e2e` delivery-behavior subtests: alias (second `emails` entry)
  and catch-all delivery, over-quota message accepted at SMTP but never
  delivered, GTUBE spam detection (X-Spam-Status tagging; v0.15.5 files NO
  Junk folder by default - ledger entry), and the
  negative-cache poisoning + low-TTL recovery regression pair
  (`directoryCacheTtlNegative = 5` in the test)
- `parsedmarc-e2e` VM test fixes for the Dovecot 2.4 pin: explicit
  `dovecot_config_version`/`dovecot_storage_version` (nixpkgs localMail
  omits them), the renamed `dovecot.service` unit (was `dovecot2.service`),
  a plaintext dovecot fixture (mailsuite auto-activates advertised
  STARTTLS; no cert material in the VM - WRONG_VERSION_NUMBER), and
  corrected sample-report assertions (parsed org_name is "XYZ
  Corporation"; `jq -e` without slurp)
- `LICENSE` (MIT); `docs/THREAT_MODEL.md` extended with the attacker-scenario
  table and the out-of-scope/consumer-responsibilities list

### Changed

- parsedmarc wrapper now sets `StateDirectory` + `ReadWritePaths`: the
  nixpkgs unit runs as a DynamicUser with no writable state, so the default
  `/var/lib/parsedmarc/reports` output could never have worked (found by
  forcing the unit; parsedmarc 11.0.1 makedirs()es the output dir as the
  dynamic user) - `modules/dmarc-monitor.nix`

### Fixed

- parsedmarc dies at its first IMAP connect on this nixpkgs pin
  (imapclient 3.1.0 assigns `imaplib.IMAP4.file`, read-only since python
  3.14; AttributeError, exit 255). The wrapper pins the unit's binary to
  the same parsedmarc 11.0.1 built on python 3.13 (same rev, same
  contract); `dmarc-eval` asserts the pin (README ledger entry;
  upstream-able)
- parsedmarc unit fails to start with parsedmarc 11 ("hosts setting
  missing from the elasticsearch config section"): nixpkgs' module
  materializes a host-less `[elasticsearch]` section (cert_path + ssl
  survive the empty filter) even with `provision.elasticsearch = false`.
  The wrapper now strips that section from the rendered ini (guarded:
  only while ES is off), and `dmarc-eval` asserts the workaround
  (README ledger entry; upstream-able)
- `dmarc-eval` encoded the wrong `_secret` contract: the nixpkgs ini
  generator requires an absolute path STRING (`isString` gate) and throws on
  path values - a real host unit would have failed to build its config. The
  ledger entry was corrected accordingly (README)
- Relay E2E transcript assertion now accepts the observed `<~*` swaks marker
  (550 RCPT refusal arrives with the timeout-receive variant, not `<-` /
  `<**`); lesson recorded in the README ledger

## [0.1.0] - 2026-09-14

### Added

- NixOS flake exporting `nixosModules.default/.mail-server/.dmarc-monitor`,
  nixpkgs pinned to SystemNix's lock rev (`eaad089`, NixOS 26.11)
- `services.mail-server` wrapper: RFC listener set (25/587/465/993 + loopback
  http), FQDN assertion, `certificate.self-signed = true` default so
  implicit-TLS works out of the box (`modules/mail-server.nix`)
- `services.dmarc-monitor` wrapper: parsedmarc with heavy sinks forced off,
  JSON/CSV output directory default, `_secret` password pattern
  (`modules/dmarc-monitor.nix`)
- `stalwart-e2e` VM test: real Stalwart 0.15.5 - declarative fallback-admin
  bootstrap, domain/account provisioning via the management API, unknown
  recipient 550 rejection, authenticated submission on 587 delivering into a
  real INBOX fetched over IMAPS, no-crash journal gate (`tests/stalwart-e2e.nix`)
- `dmarc-eval` eval-contract test for the dmarc-monitor wiring
  (`tests/dmarc-eval.nix`)
- README verified-facts ledger (fact + method + date; zero unverified claims)
  and go-live runbook: Hetzner port policy (ports 25/465 blocked by default,
  per account, both directions - verified against official docs), outbound
  relay recipe (`queue.route` + `queue.strategy.route`, incl. the IfBlock
  indexed-keys and DNS-hostname gotchas from the live Mailpit spike), native
  `stalwart --export`/`--import` backup, metrics endpoint, DKIM/ACME key
  names, directory negative-cache poisoning (1h TTL) and the
  provision-before-SMTP ordering rule, `roles: ["user"]` requirement for
  API-created accounts
- Repository hygiene: `.gitignore`, `dprint.json` (json/yaml/markdown/
  dockerfile), GitHub publication (public repo)
- Docs-health pass (2026-09-14): living docs `TODO_LIST.md`, `FEATURES.md`,
  `ROADMAP.md`, this changelog; historical reports annotated

### Changed

- `services.mail-server` firewall behavior: opens exactly the four public
  listener ports (25/465/587/993) via an explicit list; nixpkgs'
  `openFirewall` is now disabled by the wrapper because it would also punch
  the loopback-only admin port (8080) through the firewall on every interface
  (`modules/mail-server.nix`)
- `stalwart-e2e` check restricted to x86_64-linux (aarch64 VM test was a
  never-executed slow-TCG trap; `dmarc-eval` stays arch-independent)

### Fixed

- E2E delivery: provisioning moved before all SMTP traffic - a MAIL FROM/RCPT
  probe against a not-yet-provisioned domain poisons the directory negative
  cache and routes mail to the MX path for 1 hour
- E2E assertion bugs: `curl -f` exiting 22 on the expected 401; API-created
  accounts need `"roles": ["user"]` or submission is refused 550 5.7.1
- Hostname option example genericized from a real-looking domain to
  `mail.example.com` (recon-value hardening of the public repo)
