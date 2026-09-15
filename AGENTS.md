# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(InboxClean/DiscordSync upstream-flake pattern). Full architecture, runbook,
and the verified-facts ledger live in README.md - READ THE LEDGER before
touching Stalwart/parsedmarc config keys; several "obvious" keys are wrong
(see `certificate.self-signed`, `[imap]` vs `[mailbox]`).

## Commands

- `nix flake check` - the full gate: eval contract + Stalwart VM E2E test
  (~2-4 min; the SMTP subtest intentionally waits out ~60 s of resolver
  timeouts in the DNS-less VM). NOTE: failed check results are CACHED - a
  rerun without an input change replays the old verdict.
- Local debug loop (much faster than the VM): run the pinned binary by hand
  with a minimal config in /tmp - see the pattern in the verified-facts
  ledger history (bind high ports, `certificate.self-signed = true`).
- VM debug loop: realize the driver
  (`nix-store -r $(nix-store -q --references $(nix eval --raw
  .#checks.x86_64-linux.stalwart-e2e.drvPath) | grep nixos-test-driver)`)
  and run a custom script with `--test-script /tmp/debug.py` (create output
  dir first: `-o` requires an EXISTING directory). The driver's python runs
  on the HOST - anything touching VM ports must be a packaged script or a
  machine.succeed("...") command, never host-side socket code.
- Gate commands never wear pipes (`cmd | tail` can print PASSED on a failing
  run); test assertions are transcribed from observed transcripts, not from
  expected output (the swaks `<**` vs `<-` lesson).

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine). Bump both
  together; note in README when nixpkgs moves `services.stalwart` past
  0.15.5.
- Wrapper options are `services.mail-server` / `services.dmarc-monitor`
  (NOT `services.stalwart-mail` - collides with an nixpkgs rename alias).
- All wrapper defaults are `mkDefault`; consumers override via
  `services.stalwart.settings` / `services.parsedmarc.settings`.
  EXCEPTION: `networking.firewall.allowedTCPPorts` in mail-server.nix is a
  plain definition - a `mkDefault` list on that option is silently dropped
  to `[]` by the base firewall modules on this nixpkgs pin (verified
  empirically; `services.openssh.ports` mkDefault behaves normally).
- Tests: VM E2E for behavior (stalwart-e2e), eval contract for wiring
  (dmarc-eval). Never weaken module defaults to make a test deterministic -
  fix the test (e.g. swaks --timeout), keep the product honest.
- E2E ordering matters: provision domain/accounts BEFORE any SMTP probe -
  a RCPT/MAIL FROM probe poisons the directory negative cache (1 h TTL)
  and the domain then routes to MX instead of local (see README ledger).
  Related API gotchas (also in the README ledger): individuals created via
  `POST /api/principal` need `"roles": ["user"]` or submission is refused;
  relay `queue.route` IfBlocks need INDEXED keys and resolvable hostnames.
- SystemNix layers (sops, ports.nix, Gatus, onFailure, backup-coordination)
  belong to the CONSUMER wrapper, not here.

## Documentation map

- `README.md` - architecture, module docs, go-live runbook, VERIFIED-FACTS
  LEDGER (fact + method + date; do not re-derive config keys from memory).
- `FEATURES.md` - honest feature inventory by status.
- `TODO_LIST.md` - open bounded work. `ROADMAP.md` - long-term themes,
  non-goals, and the open user decisions (D1/D2 license) that gate them.
- `CHANGELOG.md` - what changed. `docs/{status,planning,reviews}/` -
  point-in-time session snapshots (historical; annotated as work resolves).
