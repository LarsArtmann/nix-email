# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(InboxClean/DiscordSync upstream-flake pattern). Full architecture, runbook,
and the verified-facts ledger live in README.md - READ THE LEDGER before
touching Stalwart/parsedmarc config keys; several "obvious" keys are wrong
(see `certificate.self-signed`, `[imap]` vs `[mailbox]`).

## Commands

- `buildflow` - the quality gate wrapper (fmt/lint/repairs + nix targets).
  Skips with rationale live in `.buildflow.yml` (vulnix, pytest-test,
  mypy-check - reasons inline there). Tools run inside the flake devShell:
  `devShells.<system>.default` must stay resolvable (`nix develop -c echo
  ok`), else every tool fails with "does not provide attribute
  'devShells..."'. Warning-level findings (nix-checker
  hardcoded-hash) do NOT fail the gate (default threshold: error) - see
  Working rules for the deliberate non-fixes. "N tools unavailable"
  (jest/knip/madge/pnpm tools, interrogate) is expected noise for a
  Nix-only repo.
- `nix flake check` - the full gate: eval contract + Stalwart VM E2E test
  (~2-4 min; the SMTP subtest intentionally waits out ~60 s of resolver
  timeouts in the DNS-less VM). NOTE: failed check results are CACHED - a
  rerun without an input change replays the old verdict.
- Host binary spike = DEAD END for Stalwart (2026-09-16): the pinned binary
  boots and parses config on the host but listeners never bind (futex-wait
  after external-resource downloads); the same binary boots fine in the VM.
  Use the VM debug loop below instead. Host loops remain fine for pure
  client-side forensics (swaks/SMTP sink, see below).
- `nix run .#vm` (x86_64) - throwaway demo VM (`nixosConfigurations.demo`,
  end-to-end host-smoked 2026-09-22, README "Try it in a VM"): web/API
  host :18080 (admin/demo-admin), SMTP :2525, submission :2587
  (demo@mail.demo.invalid / demo), IMAPS :2593. Debug pattern that worked:
  FIFO console (`mkfifo in && cat in | <vm-closure>/bin/run-demo-vm > log`
  with a `sleep infinity > in` holder) - more reliable than the
  nixos-test-driver for ad-hoc demo runs, because the driver's
  wait_for_unit/boot waits wedge when a unit under test never activates.
  Probe LAYERED: guest service -> guest loopback -> HOST port. "Connects
  but never answers" behind a forward is a FIREWALL signature, not a
  transport bug (ledger (k)); the demo disk is CWD-relative ./demo.qcow2 -
  run from a scratch dir; unit scripts need ABSOLUTE binary paths (ledger
  (l)).
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
  machine.succeed("...") command, never host-side socket code. KEEP A GC
  ROOT while debugging: `nix build -o /tmp/st-e2e-root
  .#checks.x86_64-linux.stalwart-e2e` pins the test closure via the
  out-link so a background GC cannot yank the driver mid-loop (drop it
  with `rm /tmp/st-e2e-root`). CI-side gc-roots are pointless - runners
  are ephemeral and flakehub-cache owns persistence there.
- Gate commands never wear pipes (`cmd | tail` can print PASSED on a failing
  run); test assertions are transcribed from observed transcripts, not from
  expected output (the swaks `<**` vs `<-` lesson).
- swaks/SMTP forensics without a server (host, minutes): run a tiny python
  asyncio SMTP sink on a high port (greet, accept, print DATA), point swaks
  at it, and decode attachment bytes from swaks's own `->` echo lines
  (base64). This exposed `--attach <path>` sending the path STRING as body
  (no filename=) vs `@path` reading the file - before any VM run.
- `rg -rln` is NOT "recursive + line-number": `-r` REPLACES matches with
  the next arg ("n") and silently corrupts output. Recursive listing is
  `rg -l -n` or `rg --line-number`.
- `nix fmt .` (WITH the path): bare `nix fmt` forwards no paths, so
  alejandra 4.0.0 reads STDIN and dies with `unexpected end of file` -
  check-mode is `nix fmt -- . --check` (what CI enforces).
- Run `nix fmt -- . --check` BEFORE yielding on any session that touched
  `.nix` files: the auto-commit daemon pushes mid-session, so unformatted
  edits reach CI and the fail-closed alejandra step goes red on a push you
  never explicitly made (2026-09-16, two red runs, fix was pure
  re-indentation).
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
  is the README "Pin-advance runbook". CORRECTED 2026-09-22: SystemNix
  consumes this flake via floating `?ref=master` (flake.nix:671), NOT a
  release tag - the old "current: v0.2.0" claim was stale; hard-pinning
  the URL is an open decision (decision-batch C17).
- Wrapper hardening options (2026-09-22, M14): `rateLimits` and
  `spamFilter.dnsbl.servers` default OFF by design - v0.15.5 already
  ships two conservative inbound limiters via DEFAULT_SETTINGS (boot.rs,
  README ledger (i)) and DNSBL has no master switch + needs real DNS
  (ledger (j)). Do NOT "fix" the defaults to ON; the eval test asserts
  the absence posture (module-import-eval). Limiter key vocabulary:
  `authenticated_as` (NOT auth_as); dnsbl zone/tag are emitted as QUOTED
  expression constants.
- flake-parts input policy (decided 2026-09-17): FLOATING
  `github:hercules-ci/flake-parts`, pinned by flake.lock only - both
  reference flakes (SystemNix, nix-international-telephony) float it too,
  so the lock pin is the fleet's reproducibility control; a URL-hard rev
  would diverge from fleet posture without adding safety. The
  `nixpkgs-lib.follows = "nixpkgs"` follow is NOT optional - a dropped
  follow smuggles a second nixpkgs rev into every consumer lock (eval
  guard tracked in TODO_LIST).
- Flake-parts adoption decisions (2026-09-17, do not re-litigate without
  new evidence): treefmt-nix REJECTED (swaps alejandra for nixfmt,
  reformats the whole repo, breaks the `nix fmt -- . --check` CI
  contract); the flake-parts `systems` input REJECTED (the hardcoded
  two-system list matches both references); git-hooks-nix REJECTED
  (BuildFlow owns pre-commit).
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

- NEVER "clean up" the flake outputs lambda signature: Nix ALWAYS passes
  `self` to outputs, and flake-parts additionally consumes the whole
  `inputs` set, so the pattern needs the ellipsis
  (`outputs = inputs@{flake-parts, nixpkgs, ...}:`). Commit a4fc343
  (2026-09-16) dropped the "unused" self as a lint nit and the whole flake
  died ("function 'outputs' called with unexpected argument 'self'"; every
  tool cascaded red). A named-but-unused `self` is not an option either -
  deadnix flags it every run and BuildFlow's deadnix auto-fix strips it
  (deadnix alone is report-only by default; the removal path is BuildFlow's
  edit mode). The ellipsis is the only shape that survives both.
- flake-parts perSystem (2026-09-17 migration): `pkgs` comes from
  flake-parts' built-in nixpkgs module (`inputs'.nixpkgs.legacyPackages`) -
  do NOT redefine `_module.args.pkgs` inside perSystem (verified 2026-09-17
  on flake-parts 31729ca8: pkgs ends up UNBOUND when checks eval; both
  reference flakes - nix-international-telephony, SystemNix - just
  destructure `pkgs` and use `pkgs.lib`, not a bare `lib`, inside
  perSystem). dmarc-eval still receives the raw `nixpkgs` input, so its
  own legacyPackages semantics are unchanged.
- `nix flake lock` fails on an UNDEFINED VARIABLE in flake.nix (parse-time
  scope error) but NOT on a `throw` inside outputs/checks (lock forces
  neither) - the 2026-09-17 lock-mystery verdict, measured (21-10 report
  a.6; mechanism comment lives in flake.nix).
- Reference-first for structural migrations: when a sibling repo carries
  the proven pattern, the first draft is its verbatim shape - verify
  green, THEN deviate one step at a time with evidence (2026-09-17: a
  from-memory `_module.args.pkgs` "improvement" produced a dead flake the
  reference shape would have prevented). Run the two `nix eval` guards
  (`nix eval .#checks.x86_64-linux --apply 'builtins.attrNames'` + the
  aarch64 shape) IMMEDIATELY after every flake-structure write - the
  auto-commit daemon commits mid-session, so a dead flake becomes git
  history within minutes.
- Known lint noise - deliberate non-fixes, do NOT "repair":
  tests/parsedmarc-e2e.nix:39 fetchurl sha256 pin is intentional
  reproducibility (nix-checker hardcoded-hash/inline-hash findings are
  wrong about fixtures); ruff
  F821 in tests/fixtures/debug-template.py is silenced in-file (the
  nixos-test-driver injects start_all/machine at runtime); `{ ... }` vs
  `{...}` in tests/*.nix coexists intentionally (commit ba7645c was a
  manual edit, no formatter involved: alejandra 4.0.0 preserves `{ ... }`
  on round-trip and dprint has no nix plugin - do not normalize either
  style).
- statix W20 is FIXED, not tolerated (2026-09-16, reversing the earlier
  deliberate non-fix per user decision): VM-test node configs use fully
  collapsed `services = { ... }` blocks. The warning fires when a
  first SEGMENT repeats 3+ times within ONE attrset level and RECURSES
  after each collapse (`services = { stalwart.settings.x = ...; }`
  gets re-flagged on repeated `stalwart`), so collapse common prefixes
  all the way down (`services = { stalwart = { settings = { ... }; }; }`).
  A 2-repeat partial collapse passes today and trips on the next entry.
- vulnix crashes fleet-wide: NVD retired the legacy JSON feeds (404 on
  nvdcve-2.0-modified.json.gz; vulnix 1.12.5 unmaintained) - BuildFlow's
  "unscannable store path ./result" hint is a MISDIAGNOSIS of that crash,
  and `rm result` + rebuild does not help. Skipped via .buildflow.yml.
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
  Mechanized in CI since 2026-09-16 (the "Ban piped grep/tail/head" awk
  step; `| tail`/`| head` are the same exit-code-eating class and are
  banned too). Word boundaries in that awk are `([^[:alnum:]]|$)`, NOT
  `\b` - gawk 5.x regex constants treat `\b` as backspace, which made the
  first version of the lint a never-firing false green (caught by local
  negative test).
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
