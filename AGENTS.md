# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(upstream-flake pattern). Architecture, runbook, and the VERIFIED-FACTS
LEDGER live in README.md - READ THE LEDGER before touching Stalwart or
parsedmarc config keys: several "obvious" keys are wrong, and the 0.16
object model broke most 0.15 intuitions (ledger "Stalwart 0.16" owns the
full transcript-pinned dialect; the 0.15.5 clusters are era-marked).

## Commands

- `buildflow` - the quality gate wrapper. Skips with rationale live in
  `.buildflow.yml`. Tools run inside the flake devShell (it must stay
  resolvable). Warning-level findings do NOT fail the gate (threshold:
  error). "N tools unavailable" (jest/pnpm/...) is expected noise.
- `nix flake check` - the full gate: eval contract checks + x86_64-only
  VM E2E (~4-6 min CI). The check set is SINGLE-SOURCED: canonical list =
  the ci.yml lockstep `expected=` list / README "What is built and
  verified" - never restate it here (a restated count rotted within hours
  once); live truth: `nix eval .#checks.x86_64-linux --apply
  builtins.attrNames`. Failed check results are CACHED - a rerun without
  an input change replays the old verdict. `--no-build` = fast eval-noise
  triage.
- Host binary spike = DEAD END for Stalwart (listeners never bind on the
  host; fine in the VM). Host loops are fine for client-side forensics
  only (swaks + a tiny python SMTP sink decodes attachment bytes from
  swaks's `->` echo lines - exposed `--attach <path>` sending the path
  string vs `@path` reading the file).
- `nix run .#vm` (x86_64) - throwaway demo VM; ports/credentials live in
  the README quickstart and the login banner (single source). The demo
  disk is CWD-relative ./demo.qcow2 - run from a scratch dir. Debug
  pattern: FIFO console (`mkfifo in && cat in |
  <vm-closure>/bin/run-demo-vm > log` + a `sleep infinity > in` holder)
  - more reliable than the driver for ad-hoc runs (driver wait_for_unit
  wedges when a unit under test never activates). Probe LAYERED: guest
  service -> guest loopback -> HOST port; "connects but never answers"
  behind a forward is a FIREWALL signature (ledger (k)).
- VM debug loop: realize the driver from the e2e check closure's
  references (binary at `<output>/bin/nixos-test-driver`), run
  `--test-script /tmp/debug.py` (`-o` needs an EXISTING dir); driver
  python runs on the HOST - VM-port work must be a packaged script or
  machine.succeed, never host socket code. KEEP A GC ROOT (`nix build -o
  /tmp/root .#checks...stalwart-e2e`). Debug-script rules: (a) long
  `machine.execute` payloads die silently (status -1/28) - capture via
  succeed("... > /tmp/f.log 2>&1") and cat; (b) NEVER `systemctl start
  stalwart-provision.service` manually mid-test - a manual RE-run's
  try-restart races the probe (535 on VALID creds); wait for
  `stalwart.service` + `wait_for_open_port`; (c) journal greps quote
  concrete phrases (bare `over` matches every "Consumed ... over Ns"
  line); (d) a BrokenPipeError driver death = rerun, not redesign.
- Gate commands redirect, never pipe (`cmd | tail` can print PASSED on a
  failing run): `nix flake check > /tmp/gate.log 2>&1; echo "EXIT:$?" >>
  /tmp/gate.log`. Never run `buildflow` and `nix flake check`
  CONCURRENTLY (timing analytics become contention noise). An EMPTY
  `nix build` log means CACHE HIT - force with `--rebuild` when execution
  is the claim.
- `rg -rln` is NOT "recursive + line-number": `-r` REPLACES matches with
  the next arg and silently corrupts output (bit this repo twice - use
  `rg -l -n`). Extract cross-file identifiers mechanically (`grep -o`,
  `git diff` read-back), never from memory.
- `nix fmt .` (WITH the path; bare `nix fmt` reads STDIN and dies).
  Check-mode: `nix fmt -- . --check`. Run before yielding on any session
  that touched `.nix` files - the daemon pushes mid-session.
- After editing ONE check, build THAT check first
  (`nix build .#checks.x86_64-linux.<name> -L`), then the full gate.
- Adding/removing a flake check = THREE guard sites in the same change:
  BOTH ci.yml lists (x86_64 lockstep + aarch64 shape) AND
  `scripts/check-inventory.sh` (carries its own copies). A missed site
  ships red master (daemon pushes bypass the hook). Pre-flight grep:
  `grep -rn '<existing-check-name>' .github scripts`.
- A red CI run is NEVER "the known one" without reading the failing STEP
  name (`gh run view --log-failed`); two distinct causes can stack.
- A working-tree gate red may belong to ANOTHER session's uncommitted
  in-flight fix: check `git status` for files you didn't touch, date
  outputs via `nix path-info --json registrationTime`, never edit the
  foreign file - report it.
- Markdown is dprint-formatted: a table cell with a literal `|` MUST
  escape it `\|` (dprint DROPS overflow cells; two rows were once eaten).
  Lint: `scripts/check-md-table-pipes.sh`. dprint also mangles prose
  wraps: never let a mid-sentence `-`/`+` land at a line start (parses as
  a nested list item); `git diff` after every dprint pass over prose.
- HOST-SIDE PARSER DRY-RUN before any VM test feeding a fixture to a
  python service: `python3 scripts/host-parse-fixture.py <fixture>
  --check parsedmarc-e2e` (~30 s, reproduces VM parser reds in seconds).
  When a fixture fails to parse, diff the newest upstream copy first -
  upstream "sample" artifacts have been malformed and later repaired.
- VM-test fixture traps (live-observed): dovecot settings values must
  NOT use the `<path` prefix (read-from-file syntax inlines file
  CONTENTS into dovecot.conf); the parsedmarc ini generator renders
  bools Python-style (`ssl=True`); `arrival_date_utc` assertions are
  timezone-normalization proofs (keep fixtures in >=1 non-UTC offset).

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine; bump both
  together - README "Pin-advance runbook" owns the procedure). SystemNix
  HARD-PINNS this flake's release tags. STALWART SURFACE: the wrapper
  VENDORS the 0.16 module (`modules/stalwart-module/`, nixpkgs PR
  #552103; provenance + retirement checklist in-file); binary = the
  pin's `stalwart_0_16`; the 0.16.26-overlay question is decision C45.
- flake-parts input policy: FLOATING flake-parts input (pinned by
  flake.lock only - the fleet's control); `nixpkgs-lib.follows =
  "nixpkgs"` is NOT optional (a dropped follow smuggles a second nixpkgs
  into every consumer lock). Rejected-without-new-evidence: treefmt-nix
  (breaks the alejandra CI contract), the `systems` input, git-hooks-nix
  (BuildFlow owns pre-commit).
- Wrapper options: `services.mail-server` / `services.dmarc-monitor`
  (NOT `services.stalwart-mail` - nixpkgs rename-alias collision).
  Defaults are `mkDefault`; consumers override via
  `services.stalwart.settings` / `services.parsedmarc.settings`.
  EXCEPTION: `networking.firewall.allowedTCPPorts` in mail-server.nix is
  a plain definition - base nixpkgs ships unconditional `[]` defs at
  priority 100 on that option, so mkDefault lists are discarded
  wholesale (verified via `options.<opt>.definitionsWithLocations`).
- Wrapper hardening defaults OFF by design (`rateLimits`,
  `spamFilter.dnsbl.servers`) - do NOT "fix" them to ON. The DNSBL plan
  section ALWAYS carries the (empty-by-default) reconcile set destroying
  0.16.22's 18 shipped-broken default rows - do not simplify it away.
  Limiter identity: `MtaInboundThrottle` matches on `description` (no
  `name`); key vocabulary `authenticated_as` (NOT auth_as); dnsbl
  zone/tag are QUOTED expression constants.
- Tests: VM E2E for behavior, eval contract for wiring. Never weaken
  module defaults to make a test deterministic - fix the test.
- STALWART 0.16 DOCTRINE: the wrapper renders `services.stalwart.provision`
  plans; `services.stalwart.settings` is ONLY the config.json datastore
  descriptor; the admin is a REQUIRED systemd credential. FULL dialect
  in the README ledger - do NOT restate (split-brain rule). Sharpest
  edges: `User.name`/`EmailAlias.name` = LOCAL PART only; `#id` refs
  resolve only against EARLIER ops in the SAME plan; an upsert patching
  an existing object MUST carry its match property; IMAP/JMAP login keys
  on the SYNTHESIZED address; `hostname` must equal the provisioned
  Domain value (else auth 535 / MAIL FROM 501 - now also pinned by the
  `provision-plan-eval` check).
- E2E ordering: provision domain/accounts BEFORE any SMTP probe (a probe
  on an unprovisioned domain poisons the directory negative cache, 1 h
  TTL); catch-all applies AFTER any unknown-recipient-rejection probe
  (runtime second plan). Over-quota mail is ACCEPTED at RCPT (`250 ...
  queued`) but never delivered - assert IMAP absence + 0.16 JOURNAL
  SILENCE, never SMTP refusal (0.15's `Message rescheduled` signature is
  GONE on 0.16).
- SystemNix layers (sops, ports, Gatus, onFailure, backup-coordination)
  belong to the CONSUMER wrapper, not here.

## Working rules (learned the hard way)

- The 0.15 -> 0.16 store boundary is a POISON class (pbx outage
  2026-10-17): the 0.16 binary PANICS (exit 101) on a pre-0.16 store AND
  poisons the settings subspace for 0.15.5 BEFORE panicking - the unit
  guard (default.nix) is the hard boundary; the migration script's
  poison preflight is a hard stop; the dump runs from a pre-0.16 copy
  (--backup-dir) while recovery mode fixes the LIVE store. Recovery
  port is STALWART_RECOVERY_MODE_PORT - never assume 8080.
- NEVER "clean up" the flake outputs lambda signature: keep the ellipsis
  (`outputs = inputs@{flake-parts, nixpkgs, ...}:`) - flake-parts
  consumes the whole `inputs` set and deadnix/BuildFlow strip
  named-but-unused args; dropping the ellipsis once killed the whole
  flake (mechanism comment in flake.nix). `flake.nix` is a thin shell;
  outputs live in `flake-modules/*.nix` (module args carry
  `inputs`/`self`; only `flake-parts` stays in the destructure).
- flake-parts perSystem: `pkgs` comes from the built-in nixpkgs module -
  do NOT redefine `_module.args.pkgs` inside perSystem (pkgs ends up
  UNBOUND; proven the hard way). Use `pkgs.lib`, not bare `lib`, inside
  perSystem.
- `nix flake lock` fails on an UNDEFINED VARIABLE (parse-time) but NOT
  on a `throw` inside outputs (lock forces neither).
- Reference-first for structural migrations: first draft = the sibling
  repo's verbatim shape, verify green, THEN deviate one step at a time
  with evidence. Run the two `nix eval` guards (check attrNames + the
  aarch64 shape) IMMEDIATELY after every flake-structure write - the
  daemon commits mid-session.
- Known lint noise - deliberate non-fixes, do NOT "repair": the
  parsedmarc-e2e fetchurl sha256 fixture pin (nix-checker
  hardcoded-hash findings are wrong about fixtures); ruff F821 in
  tests/fixtures/debug-template.py (silenced in-file - the driver
  injects names at runtime); `{ ... }` vs `{...}` in tests/*.nix
  coexist intentionally; nix-checker port-collision findings are
  cross-context false positives (root-fixed in the checker - keep the
  step); bandit B404/B603/B108 on host-parse-fixture.py = accepted
  noise; vulture `auth` on migrate_v016.py = false positive
  (requests.Session attribute).
- Workflow edits need a LOCAL actionlint WITH shellcheck (devShell or
  the pre-push `nix shell` fallback - bare `nix run nixpkgs#actionlint`
  is blind). SC2016/SC2064/SC1012 quoting fixes have a crab-walk
  quality - heredocs with quoted delimiters dissolve all three.
- statix W20 is FIXED, not tolerated: collapse `services = { stalwart =
  { ... }; }` blocks ALL the way down in VM-test node configs (the
  warning recurs after each partial collapse).
- vulnix crashes fleet-wide (NVD retired the legacy feeds) - skipped in
  .buildflow.yml; BuildFlow's "unscannable store path" hint is a
  misdiagnosis of that crash.
- Release procedure: CONTRIBUTING "Release procedure" owns the
  checklist. The daemon races explicit commits on release-critical
  files - edit and commit in the SAME tool call.
- `core.hooksPath` can dangle silently - when touching hook config:
  `git config core.hooksPath && ls "$(git config core.hooksPath)"`. It
  is repo-LOCAL config; fresh clones must re-set it (CI's alejandra step
  is the real gate).
- No new test assertion without a transcript: grep the asserted line
  from an existing test log or debug VM run first (reading upstream
  source is NOT evidence of what the journal prints - the
  `Mailbox over quota.` lesson).
- In-VM assertions are file-based, never `producer | grep -q`
  (pipefail + EPIPE exit-23 class; negated form phantom-greens) -
  mechanized by the CI awk lint; word boundaries there are
  `([^[:alnum:]]|$)`, NOT `\b` (gawk treats `\b` as backspace - the
  first lint version never fired).
- Before creating a file at the repo root, `ls` the WHOLE repo including
  `docs/` (a duplicate THREAT_MODEL.md was once created).
- 0.16-upgrade loop rules: (a) PROBE BEFORE RERUN - boot the FIFO
  console before rerunning a failed VM test; (b) NEVER trust a sibling
  report's "green" - read the stored log / registrationTime; (c) NO
  SCHEMA CLAIM without an apply transcript (Rust doc comments lied
  once: `User.name`); (d) let provisioning settle before probing
  (port-open != server-ready; the ExecStartPost restart window eats
  connections); (e) logged artifacts dump on failure by default; (f)
  VM-test dnsmasq must FORWARD upstream (10.0.2.3) - 0.16 reload
  validation resolves through the system resolver (the demo's boot
  race 2026-10-18 was the same class; the demo now pins DnsResolver =
  Cloudflare); (g) serialize heavy VM builds ACROSS repos (concurrent
  builds OOM-killed a run once).
- Session-start baseline ritual: `git status --short`, `pgrep -af
  crush`, scan `ls docs/status` for same-day reports BEFORE the first
  edit; never edit a file another session is mid-iterating on - hand
  off via TODO_LIST rows. Register reads with `view` (bash sed/grep
  does NOT arm the modified-since-read guard).
- Annotated status reports are formatter-fragile (dprint REWRAPS struck
  rows and EATS overflow cells): strike rows in the per-cell canonical
  form, run `annotate.go check-rows` after every formatter pass, never
  hand-roll row repairs.
- Known gate noise: the gate log's "running N flake checks" count line
  can disagree with the defined set - trust the attrNames eval.

## Documentation map

- `README.md` - architecture, module docs, go-live runbook, VERIFIED-FACTS
  LEDGER (fact + method + date), canonical check-set list, quickstart.
- `FEATURES.md` - honest feature inventory by status. `TODO_LIST.md` -
  open bounded work. `ROADMAP.md` - long-term themes + gating user
  decisions. `CHANGELOG.md` - what changed.
- `docs/{status,planning,reviews}/` - point-in-time snapshots;
  `archived/` holds resolved/routed ones (archive policy + per-cell
  strike form: see `docs/status/archived/README.md` and the annotate
  rules above; FORMAT BEFORE ARCHIVE: dprint before the `git mv`).
- `docs/TELEMETRY.md` - telemetry guide (0.15.5-era caveat: verify keys
  against the pinned binary). `docs/THREAT_MODEL.md` - threat model.
  `SECURITY.md` - security policy.
- `docs/INBOXCLEAN.md` - the InboxClean JMAP contract (0.16
  re-verified 2026-10-18); raw transcripts under `docs/probes/<date>/`
  with README manifests - both are docs-health sweep targets.
- `docs/MONITORING.md` - monitoring taxonomy + coverage matrix; owner
  split: wrapper-side sources here, routing/Gatus/scrape on the
  CONSUMER host. Alerts never ride the stack they watch; every checker
  is dead-man-monitored.
- `CONTRIBUTING.md` - ledger rules, wrapper-change rules, the gate, the
  release procedure, the pre-push hook, the arch-diagram regen command.
