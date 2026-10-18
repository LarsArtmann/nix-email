# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(upstream-flake pattern). Architecture, runbook, and the VERIFIED-FACTS
LEDGER live in README.md - READ THE LEDGER before touching Stalwart or
parsedmarc config keys (several "obvious" keys are wrong; the 0.16 object
model broke most 0.15 intuitions - ledger "Stalwart 0.16" owns the full
transcript-pinned dialect).

## Commands

- `buildflow` - the quality gate wrapper (skips with rationale in
  `.buildflow.yml`). Tools run inside the flake devShell (must stay
  resolvable). Warning-level findings do NOT fail the gate (threshold:
  error); "N tools unavailable" is expected noise for a Nix-only repo.
- `nix flake check` - the full gate: eval contract checks + x86_64-only
  VM E2E (~4-6 min CI). The check set is SINGLE-SOURCED: canonical list =
  ci.yml lockstep `expected=` / README "What is built and verified" -
  never restate it here (a restated count rotted within hours once);
  live truth: `nix eval .#checks.x86_64-linux --apply
  builtins.attrNames`. Failed results are CACHED; `--no-build` = fast
  eval-noise triage. After editing ONE check, build THAT check first
  (`nix build .#checks.x86_64-linux.<name> -L`), then the full gate.
- Host binary spike = DEAD END for Stalwart (listeners never bind on the
  host); host loops are fine for client-side forensics only (swaks + a
  tiny python SMTP sink - swaks's `->` echo lines exposed `--attach
  <path>` sending the path string vs `@path` reading it).
- `nix run .#vm` (x86_64) - throwaway demo VM; ports/credentials live in
  the README quickstart and the login banner (single source). Demo disk
  is CWD-relative ./demo.qcow2 - run from a scratch dir. Debug pattern:
  FIFO console (`mkfifo in && cat in | <vm-closure>/bin/run-demo-vm >
  log` + a `sleep infinity > in` holder) - more reliable than the driver
  for ad-hoc runs. Probe LAYERED: guest service -> guest loopback ->
  HOST port; "connects but never answers" behind a forward is a
  FIREWALL signature (ledger (k)).
- VM debug loop: realize the driver from the e2e closure's references
  (binary at `<output>/bin/nixos-test-driver`), `--test-script
  /tmp/debug.py` (`-o` needs an EXISTING dir); driver python runs on the
  HOST - VM-port work must be packaged scripts or machine.succeed, never
  host socket code. KEEP A GC ROOT (`nix build -o /tmp/root
  .#checks...stalwart-e2e`). Rules: (a) long `machine.execute` payloads
  die silently (status -1/28) - capture via succeed("... > /tmp/f.log
  2>&1") and cat; (b) NEVER `systemctl start stalwart-provision.service`
  manually mid-test - a manual RE-run's try-restart races the probe (535
  on VALID creds); wait for `stalwart.service` + `wait_for_open_port`;
  (c) journal greps quote concrete phrases (bare `over` matches every
  "Consumed ... over Ns" line); (d) BrokenPipeError driver death = rerun.
- Gate commands redirect, never pipe (`cmd | tail` can print PASSED on a
  failing run): `nix flake check > /tmp/gate.log 2>&1; echo "EXIT:$?" >>
  /tmp/gate.log`. Never run `buildflow` and `nix flake check`
  CONCURRENTLY. An EMPTY `nix build` log means CACHE HIT - force with
  `--rebuild` when execution is the claim.
- Repo-tool traps: `rg -rln` is NOT "recursive + line-number" (`-r`
  REPLACES matches with the next arg and corrupts output - bit this
  repo twice; use `rg -l -n`); bare `nix fmt` forwards no paths and
  dies on STDIN (check-mode: `nix fmt -- . --check`; run before
  yielding on any session that touched `.nix` - the daemon pushes
  mid-session); extract cross-file identifiers mechanically (`grep
  -o`, `git diff` read-back), never from memory.
- Adding/removing a flake check = THREE guard sites in the same change:
  BOTH ci.yml lists (x86_64 lockstep + aarch64 shape) AND
  `scripts/check-inventory.sh` (own copies); a missed site ships red
  master (daemon pushes bypass the hook). Pre-flight:
  `grep -rn '<existing-check-name>' .github scripts`.
- A red CI run is NEVER "the known one" without reading the failing STEP
  name (`gh run view --log-failed`); two causes can stack. A
  working-tree gate red may belong to ANOTHER session's in-flight fix:
  check `git status` for files you didn't touch, date outputs via
  `nix path-info --json registrationTime`, never edit the foreign file.
- Markdown is dprint-formatted: a table cell with a literal `|` MUST
  escape it `\|` (dprint DROPS overflow cells; lint:
  `scripts/check-md-table-pipes.sh`); never let a mid-sentence `-`/`+`
  land at a line start (parses as a nested list item) - `git diff` after
  every dprint pass over prose.
- HOST-SIDE PARSER DRY-RUN before any VM test feeding a fixture to a
  python service: `python3 scripts/host-parse-fixture.py <fixture>
  --check parsedmarc-e2e` (~30 s, reproduces VM parser reds in seconds;
  when a fixture fails to parse, diff the newest upstream copy first -
  upstream "samples" have been malformed and later repaired).
- VM-test fixture traps (live-observed): dovecot settings values must
  NOT use the `<path` prefix (read-from-file syntax inlines file
  CONTENTS into dovecot.conf); parsedmarc ini bools render Python-style
  (`ssl=True`); `arrival_date_utc` assertions are timezone-normalization
  proofs (keep fixtures in >=1 non-UTC offset).

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine; bump both
  together - README "Pin-advance runbook"). SystemNix HARD-PINNS this
  flake's release tags. STALWART SURFACE: the wrapper VENDORS the 0.16
  module (`modules/stalwart-module/`, nixpkgs PR #552103; provenance +
  retirement checklist in-file); binary = the pin's `stalwart_0_16`; the
  0.16.26-overlay question is decision C45.
- flake-parts: FLOATING input (lock-pinned only - the fleet's control);
  `nixpkgs-lib.follows = "nixpkgs"` is NOT optional (a dropped follow
  smuggles a second nixpkgs into every consumer lock). Rejected without
  new evidence: treefmt-nix (breaks the alejandra CI contract), the
  `systems` input, git-hooks-nix (BuildFlow owns pre-commit).
- Wrapper options: `services.mail-server` / `services.dmarc-monitor`
  (NOT `services.stalwart-mail` - nixpkgs rename-alias collision).
  Defaults are `mkDefault`; consumers override via
  `services.stalwart.settings` / `services.parsedmarc.settings`.
  EXCEPTION: `networking.firewall.allowedTCPPorts` in mail-server.nix is
  a plain definition - base nixpkgs ships unconditional `[]` defs at
  priority 100 there, so mkDefault lists are discarded wholesale.
  Hardening defaults OFF by design (`rateLimits`, `spamFilter.dnsbl`)
  - do NOT "fix" to ON; the DNSBL plan section ALWAYS carries the
    (empty-by-default) reconcile set destroying 0.16.22's 18
    shipped-broken default rows. Limiter identity:
    `MtaInboundThrottle` matches on `description` (no `name`); key
    vocabulary `authenticated_as` (NOT auth_as); dnsbl zone/tag are
    QUOTED expression constants.
- Tests: VM E2E for behavior, eval contract for wiring. Never weaken
  module defaults to make a test deterministic - fix the test.
- STALWART 0.16 DOCTRINE: the wrapper renders `services.stalwart.provision`
  plans; `services.stalwart.settings` is ONLY the config.json datastore
  descriptor; the admin is a REQUIRED systemd credential. FULL dialect
  in the README ledger - do NOT restate (split-brain rule). Sharpest
  edges: `User.name`/`EmailAlias.name` = LOCAL PART only; `#id` refs
  resolve only against EARLIER ops in the SAME plan; an upsert patching
  an existing object MUST carry its match property; IMAP/JMAP login
  keys on the SYNTHESIZED address; `hostname` must equal the
  provisioned Domain value (else auth 535 / MAIL FROM 501; pinned by
  `provision-plan-eval`). E2E ordering: provision BEFORE any SMTP probe
  (an unprovisioned-domain probe poisons the directory negative cache,
  1 h TTL); catch-all applies AFTER unknown-recipient probes (runtime
  second plan). Over-quota mail is ACCEPTED at RCPT but never delivered
  - assert IMAP absence + 0.16 JOURNAL SILENCE, never SMTP refusal
    (0.15's `Message rescheduled` signature is GONE).
- SystemNix layers (sops, ports, Gatus, onFailure, backup-coordination)
  belong to the CONSUMER wrapper, not here.

## Working rules (learned the hard way)

- The 0.15 -> 0.16 store boundary is a POISON class (pbx outage
  2026-10-17): the 0.16 binary PANICS (exit 101) on a pre-0.16 store
  AND poisons the settings subspace for 0.15.5 BEFORE panicking - the
  unit guard (default.nix) is the hard boundary; the migration script's
  poison preflight is a hard stop; the dump runs from a pre-0.16 copy
  (--backup-dir) while recovery mode fixes the LIVE store (port =
  STALWART_RECOVERY_MODE_PORT - never assume 8080).
- Flake-structure rules (mechanism comments live in flake.nix and
  flake-modules/checks.nix): keep the outputs-lambda ELLIPSIS
  (`outputs = inputs@{flake-parts, nixpkgs, ...}:` - flake-parts consumes
  the whole inputs set; deadnix/BuildFlow strip named-but-unused args;
  dropping it once killed the whole flake); outputs live in
  `flake-modules/*.nix` (module args carry `inputs`/`self`); in
  perSystem use the built-in `pkgs` (redefining `_module.args.pkgs`
  leaves pkgs UNBOUND - proven) and `pkgs.lib`, never bare `lib`;
  `nix flake lock` fails on UNDEFINED VARIABLES (parse-time) but not on
  a `throw` inside outputs. Reference-first for structural migrations:
  first draft = the sibling repo's verbatim shape, verify green, THEN
  deviate one step at a time; run the two `nix eval` guards (check
  attrNames + aarch64 shape) IMMEDIATELY after every flake-structure
  write (the daemon commits mid-session).
- Known lint noise - deliberate non-fixes, do NOT "repair": the
  parsedmarc-e2e fetchurl sha256 fixture pin (nix-checker
  hardcoded-hash findings are wrong about fixtures); ruff F821 in
  tests/fixtures/debug-template.py (silenced in-file - the driver
  injects names at runtime); `{ ... }` vs `{...}` in tests/*.nix
  coexist intentionally; nix-checker port-collision findings are
  cross-context false positives (root-fixed in the checker - keep the
  step); bandit B404/B603/B108 on host-parse-fixture.py and vulture
  `auth` on migrate_v016.py = accepted noise / false positive
  (requests.Session attribute).
- Workflow edits need a LOCAL actionlint WITH shellcheck (devShell or
  the pre-push `nix shell` fallback - bare `nix run nixpkgs#actionlint`
  is blind); heredocs with quoted delimiters dissolve the SC2016/2064/
  1012 quoting crab-walk. statix W20 is FIXED, not tolerated: collapse
  `services = { stalwart = { ... }; }` blocks ALL the way down in
  VM-test node configs. vulnix crashes fleet-wide (NVD retired the
  legacy feeds) - skipped in .buildflow.yml; BuildFlow's "unscannable
  store path" hint is a misdiagnosis of that crash.
- Release procedure: CONTRIBUTING owns the checklist. The daemon races
  explicit commits on release-critical files - edit and commit in the
  SAME tool call. `core.hooksPath` can dangle silently - when touching
  hook config: `git config core.hooksPath && ls "$(git config
  core.hooksPath)"`; it is repo-LOCAL (fresh clones re-set it; CI's
  alejandra step is the real gate).
- No new test assertion without a transcript: grep the asserted line
  from an existing test log or debug VM run first (upstream source is
  NOT evidence of what the journal prints - the `Mailbox over quota.`
  lesson). In-VM assertions are file-based, never `producer | grep -q`
  (pipefail + EPIPE exit-23 class; the negated form phantom-greens) -
  mechanized by the CI awk lint (word boundaries there are
  `([^[:alnum:]]|$)`, NOT `\b` - gawk treats `\b` as backspace).
- Known gate noise: the gate log's "running N flake checks" count line
  can disagree with the defined set - trust the attrNames eval. Before
  creating a repo-root file, `ls` the WHOLE repo incl. `docs/` first.
- 0.16-upgrade loop rules: (a) PROBE BEFORE RERUN - boot the FIFO
  console before rerunning a failed VM test; (b) NEVER trust a sibling
  report's "green" - read the stored log / registrationTime; (c) NO
  SCHEMA CLAIM without an apply transcript (Rust doc comments lied
  once: `User.name`); (d) let provisioning settle before probing
  (port-open != server-ready; the ExecStartPost restart window eats
  connections); (e) logged artifacts dump on failure by default; (f)
  dnsmasq must FORWARD upstream (10.0.2.3) - 0.16 reload validation
  resolves via the system resolver (the demo's 2026-10-18 boot race
  was this class; the demo pins DnsResolver = Cloudflare); (g)
  serialize heavy VM builds ACROSS repos (concurrent builds OOM-killed
  a run once).
- Session-start baseline ritual: `git status --short`, `pgrep -af
  crush`, scan `ls docs/status` for same-day reports BEFORE the first
  edit; never edit a file another session is mid-iterating on - hand
  off via TODO_LIST rows. Register reads with `view` (bash does NOT
  arm the modified-since-read guard). Annotated status reports are
  formatter-fragile (dprint REWRAPS struck rows and EATS overflow
  cells): strike rows in the per-cell canonical form, run
  `annotate.go check-rows` after every formatter pass.

## Documentation map

- `README.md` - architecture, module docs, go-live runbook, VERIFIED-FACTS
  LEDGER, canonical check-set list, quickstart (incl. demo ports/creds).
- `FEATURES.md` - feature inventory by status; `TODO_LIST.md` - open
  bounded work; `ROADMAP.md` - themes + gating decisions; `CHANGELOG.md`.
- `docs/{status,planning,reviews}/` - snapshots; `archived/` holds
  resolved ones (archive policy + strike form:
  `docs/status/archived/README.md`; dprint BEFORE the `git mv`).
- `docs/TELEMETRY.md` (0.15.5-era caveat: verify keys against the pin);
  `docs/THREAT_MODEL.md`; `SECURITY.md`; `CONTRIBUTING.md` (ledger
  rules, wrapper-change rules, the gate, the release procedure, the
  pre-push hook, the arch-diagram regen).
- `docs/INBOXCLEAN.md` - InboxClean JMAP contract (0.16 re-verified
  2026-10-18); transcripts under `docs/probes/<date>/` (docs-health
  sweep targets). `docs/MONITORING.md` - wrapper sources here,
  routing/Gatus/scrape on the CONSUMER host; alerts never ride the
  stack they watch; every checker is dead-man-monitored.
