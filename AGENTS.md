# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(InboxClean/DiscordSync upstream-flake pattern). Full architecture, runbook,
and the verified-facts ledger live in README.md - READ THE LEDGER before
touching Stalwart/parsedmarc config keys; several "obvious" keys are wrong
(see `certificate.self-signed`, `[imap]` vs `[mailbox]`).

## Commands

- `nix flake check` - the full gate: eval contract + Stalwart VM E2E test
  (~2-4 min; the SMTP subtest intentionally waits out ~60 s of resolver
  timeouts in the DNS-less VM).
- Local debug loop (much faster than the VM): run the pinned binary by hand
  with a minimal config in /tmp - see the pattern in the verified-facts
  ledger history (bind high ports, `certificate.self-signed = true`).

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine). Bump both
  together; note in README when nixpkgs moves `services.stalwart` past
  0.15.5.
- Wrapper options are `services.mail-server` / `services.dmarc-monitor`
  (NOT `services.stalwart-mail` - collides with an nixpkgs rename alias).
- All wrapper defaults are `mkDefault`; consumers override via
  `services.stalwart.settings` / `services.parsedmarc.settings`.
- Tests: VM E2E for behavior (stalwart-e2e), eval contract for wiring
  (dmarc-eval). Never weaken module defaults to make a test deterministic -
  fix the test (e.g. swaks --timeout), keep the product honest.
- SystemNix layers (sops, ports.nix, Gatus, onFailure, backup-coordination)
  belong to the CONSUMER wrapper, not here.
