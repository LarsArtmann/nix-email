# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
