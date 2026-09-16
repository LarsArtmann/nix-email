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
  dir first: `-o` requires an EXISTING directory). NOTE: the references grep
  yields the driver's `.drv`; `nix-store -r` prints the realized OUTPUT path,
  and the binary is at `<output>/bin/nixos-test-driver` (calling
  `<output>/nixos-test-driver` directly is a silent-looking "no such file").
  The driver's python runs
  on the HOST - anything touching VM ports must be a packaged script or a
  machine.succeed("...") command, never host-side socket code.
- Gate commands never wear pipes (`cmd | tail` can print PASSED on a failing
  run); test assertions are transcribed from observed transcripts, not from
  expected output (the swaks `<**` vs `<-` lesson).
- `nix fmt .` (WITH the path): bare `nix fmt` forwards no paths, so
  alejandra 4.0.0 reads STDIN and dies with `unexpected end of file` -
  check-mode is `nix fmt -- . --check` (what CI enforces).
- After editing ONE check, build THAT check first
  (`nix build .#checks.x86_64-linux.<name> -L`), then the full gate - a
  full-gate run just to discover a single subtest's typo costs ~9 min.
- VM-test fixture traps (2026-09-15, both live-observed): dovecot settings
  values must NOT use the `<path` prefix (that is dovecot's
  read-value-from-file syntax - the NixOS module then inlines file CONTENTS
  into dovecot.conf and doveconf dies parsing the first PEM line as a
  path); the parsedmarc ini generator renders bools Python-style
  (`ssl=True`, NOT `ssl=true`) - grep assertions must match `True`.

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine). Bump both
  together; note in README when nixpkgs moves `services.stalwart` past
  0.15.5. The full bump + consumer-pin + workaround-retirement procedure
  is the README "Pin-advance runbook" (SystemNix's pin references release
  tags; current: v0.2.0).
- Wrapper options are `services.mail-server` / `services.dmarc-monitor`
  (NOT `services.stalwart-mail` - collides with an nixpkgs rename alias).
- All wrapper defaults are `mkDefault`; consumers override via
  `services.stalwart.settings` / `services.parsedmarc.settings`.
  EXCEPTION: `networking.firewall.allowedTCPPorts` in mail-server.nix is a
  plain definition. Root cause (2026-09-15, verified via
  `options.<opt>.definitionsWithLocations`): the module system keeps only
  lowest-priority defs (lib/modules.nix `filterOverrides'`), and base nixpkgs
  ships unconditional `[]` defs at priority 100 on that option (podman
  network-socket.nix `lib.optional`, udp-over-tcp.nix `getFirewallPorts`) -
  so any mkDefault list there is discarded wholesale. Lists concat only
  within one priority tier; `services.openssh.ports` has no such base def.
- Tests: VM E2E for behavior (stalwart-e2e), eval contract for wiring
  (dmarc-eval). Never weaken module defaults to make a test deterministic -
  fix the test (e.g. swaks --timeout), keep the product honest.
- E2E ordering matters: provision domain/accounts BEFORE any SMTP probe -
  a RCPT/MAIL FROM probe poisons the directory negative cache (1 h TTL)
  and the domain then routes to MX instead of local (see README ledger).
  Related API gotchas (also in the README ledger): individuals created via
  `POST /api/principal` need `"roles": ["user"]` or submission is refused;
  relay `queue.route` IfBlocks need INDEXED keys and resolvable hostnames.
  More (README ledger, 2026-09-15): over-quota mail is ACCEPTED at RCPT and
  retried forever - assert IMAP absence, not SMTP refusal; a catch-all
  (`"@domain"` address) makes every local part deliverable, so it must be
  created AFTER any unknown-recipient-rejection probe; and IMAP LOGIN
  resolves by principal NAME, not by the principal's email addresses.
- SystemNix layers (sops, ports.nix, Gatus, onFailure, backup-coordination)
  belong to the CONSUMER wrapper, not here.

## Working rules (learned the hard way)

- Gate commands redirect, never pipe: `nix flake check > /tmp/gate.log 2>&1;
  echo "EXIT:$?" >> /tmp/gate.log`, then read the log. A pipe reports the
  FILTER's exit code - two fake greens shipped that way in one session.
- No new test assertion without a transcript: grep the line you assert from
  an existing test log or a debug VM run first. Reading it in upstream source
  is NOT evidence of what the journal/log prints (the `Mailbox over quota.`
  vs `Message rescheduled for delivery` lesson, 2026-09-15).
- In-VM test assertions are file-based, never `producer | grep -q`: the test
  shell runs pipefail, and grep -q's early exit EPIPEs the producer - the
  metrics curl once failed CI with exit 23 (write error) on a MATCHING
  payload (2026-09-15), and under pipefail the negated form
  `! producer | grep -q` can phantom-green. Dump to /tmp, then grep the file.
- Extract cross-file identifiers mechanically (`grep -o`, `od`, `git diff`
  read-back after multi-line edits) rather than trusting eyes or memory;
  from-memory identifiers have produced corrupted store paths and wrong
  option names.
- Before creating a file at the repo root, `ls` the WHOLE repo including
  `docs/` - a duplicate `THREAT_MODEL.md` was once created beside
  `docs/THREAT_MODEL.md` by checking only the root.

## Documentation map

- `README.md` - architecture, module docs, go-live runbook, VERIFIED-FACTS
  LEDGER (fact + method + date; do not re-derive config keys from memory).
- `FEATURES.md` - honest feature inventory by status.
- `TODO_LIST.md` - open bounded work. `ROADMAP.md` - long-term themes,
  non-goals, and the open user decisions (D1/D2, spam→Junk) that gate them.
- `CHANGELOG.md` - what changed. `docs/{status,planning,reviews}/` -
  point-in-time session snapshots; `archived/` subdirectories hold the
  snapshots whose items are fully resolved or routed into the living docs.
- `docs/TELEMETRY.md` - Stalwart telemetry best-practices guide (from
  stalw.art docs fetched 2026-09-15; carries an upstream-object-model vs
  pinned-0.15.5 version-skew caveat - verify keys against the binary
  before wiring). `docs/THREAT_MODEL.md` - threat model.
