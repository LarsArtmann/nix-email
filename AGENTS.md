# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(upstream-flake pattern). Architecture, runbook, and the VERIFIED-FACTS
LEDGER live in README.md - READ THE LEDGER before touching Stalwart or
parsedmarc config keys (several "obvious" keys are wrong; the 0.16 object
model broke most 0.15 intuitions - ledger "Stalwart 0.16" owns the full
transcript-pinned dialect).

## Commands

- `buildflow` - the quality gate wrapper (skips with rationale in
  `.buildflow.yml`; tools run inside the flake devShell - must stay
  resolvable). Warning-level findings do NOT fail the gate (threshold:
  error); "N tools unavailable" = expected noise for a Nix-only repo.
  Budget `--max-time` >= 30m - the per-step deadline kills VM-e2e builds.
- `nix flake check` - the full gate: eval contract checks + x86_64-only
  VM E2E (~4-6 min CI). Check set is SINGLE-SOURCED: canonical machine
  list = `tests/check-expected.json` (read by ci.yml's lockstep steps,
  `scripts/check-inventory.sh`, and the `check-set-lockstep` check,
  which throws on drift); README "What is built and verified" owns the
  prose restatement - never restate the list here; live
  truth: `nix eval .#checks.x86_64-linux --apply builtins.attrNames`.
  Failed results are CACHED (`--no-build` = fast eval-noise triage).
  After editing ONE check, build THAT check first
  (`nix build .#checks.x86_64-linux.<name> -L`), then the full gate.
- Host binary spike = DEAD END for Stalwart (listeners never bind on the
  host); host loops are fine for client-side forensics only (swaks + a
  python SMTP sink; swaks attachments take `@path`, not `<path>` - that
  sends the path STRING).
- `nix run .#vm` (x86_64) - throwaway demo VM; ports/credentials live in
  the README quickstart + login banner (single source); demo disk at
  ~/.cache/nix-email-demo/ (app pins NIX_DISK_IMAGE; no CWD pollution).
  Debug: FIFO console - CONTRIBUTING "VM debug loops". Probe LAYERED:
  guest service -> guest loopback -> HOST port; "connects but never
  answers" behind a forward is a FIREWALL signature (ledger (k)).
- VM-test/demo debug loops (driver realization, GC root, payload/probe
  rules (a)-(d)) and the 0.16-upgrade loop rules (a)-(g) live in
  CONTRIBUTING "VM debug loops" - consult BEFORE rerunning a failed VM
  test or debugging a demo VM.
- Gate commands redirect, never pipe (`cmd | tail` can print PASSED on a
  failing run): `nix flake check > /tmp/gate.log 2>&1; echo "EXIT:$?" >>
  /tmp/gate.log`. Never run `buildflow` and `nix flake check`
  CONCURRENTLY. An EMPTY `nix build` log means CACHE HIT - force with
  `--rebuild` when execution is the claim. `--rebuild` TRAP (2026-10-30,
  hit twice): on a derivation that was NEVER built, `--rebuild` errors
  with "some outputs are not valid, so checking is not possible" - it
  implies --check against a prior build; drop it for first builds (they
  execute anyway).
- Repo-tool traps: `rg -rln` is NOT "recursive + line-number" (`-r`
  REPLACES matches with the next arg and corrupts output; use `rg -l -n`); bare `nix fmt` forwards no paths and dies on
  STDIN (check-mode: `nix fmt -- . --check`; run before yielding on any
  session that touched `.nix` - the daemon pushes mid-session); extract
  cross-file identifiers mechanically (`grep -o`, `git diff` read-back),
  never from memory.
- Adding/removing a flake check = TWO sites: edit
  `tests/check-expected.json` AND the README check list (CI-enforced
  anti-drift); a missed site ships red master (daemon pushes bypass the
  hook). Pre-flight: `grep -rn '<name>' .github scripts tests README.md`.
- A red CI run is NEVER "the known one" without reading the failing STEP
  name (`gh run view --log-failed`); two causes can stack. A working-tree
  gate red may belong to ANOTHER session's in-flight fix: check
  `git status` for files you didn't touch, date outputs via
  `nix path-info --json registrationTime`, never edit the foreign file.
- Markdown is dprint-formatted (markdown plugin PINNED 0.28.2, 2026-10-26:
  <=0.22.1 silently DROPPED overflow table cells, 0.28.2 keeps them):
  escape a literal `|` in a cell as `\|` (GFM splits on raw pipes anyway;
  lint: `scripts/check-md-table-pipes.sh`); never let a mid-sentence
  `-`/`+` start a line - `git diff` after every dprint pass over prose.
  The archived corridors (`docs/{status,planning}/archived/**`) are
  dprint-EXCLUDED (frozen snapshots; the pipe lint still covers them).
- HOST-SIDE PARSER DRY-RUN before any VM test feeding a fixture to a
  python service: `python3 scripts/host-parse-fixture.py <fixture>
  --check parsedmarc-e2e` (~30 s, reproduces VM parser reds in seconds;
  when a fixture fails to parse, diff the newest upstream copy first).
- VM-test fixture traps: dovecot settings values must NOT
  use the `<path` prefix (read-from-file syntax inlines file CONTENTS
  into dovecot.conf); parsedmarc ini bools render Python-style
  (`ssl=True`); `arrival_date_utc` assertions are timezone-normalization
  proofs (keep fixtures in >=1 non-UTC offset).

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine; bump both
  together - README "Pin-advance runbook"). ADVANCED 2026-10-28
  6774f7bc -> fe132422: SystemNix moved first (their lock floats
  nixos-unstable and their flake floats `github:LarsArtmann/nix-email`
  master + `nixpkgs.follows`) - the contract test via follows is the
  operative doctrine; a trailing lock here breaks THEIR gate, not just
  ours. STALWART SURFACE: the wrapper VENDORS the 0.16 module
  (`modules/stalwart-module/`, nixpkgs PR #552103; provenance +
  retirement checklist in-file; PR still OPEN 2026-10-28 - `pkgs.stalwart`
  remains the 0.15.5 line); binary = the pin's `stalwart_0_16` = 0.16.26
  since fe132422 (C45 SUPERSEDED - the overlay question dissolved when
  the pin itself shipped 0.16.26; x86-64-v2 absorbed in VMs by
  tests/common.nix `v2CpuPatches` = `-cpu max`, TCG-safe, applied at
  TEST level via `defaults = common.v2CpuPatches;` in every
  runNixOSTest so a node cannot forget it - real hosts need a
  consumer-side v2 CPU check. An assertion-based guard is IMPOSSIBLE:
  reading `virtualisation.qemu.options` from assertions recurses via
  system.build.toplevel (which renders assertions), and
  options-existence cannot discriminate VM evals - qemu-vm.nix
  declares its options in EVERY NixOS eval (provision-plan-eval
  proved it). Proven 2026-10-28).
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
  Hardening defaults OFF by design (`rateLimits`, `spamFilter.dnsbl`) -
  do NOT "fix" to ON; the DNSBL plan section ALWAYS carries the
  (empty-by-default) reconcile set (posture: DNSBL off by default; the
  0.16.22 broken-defaults rationale is history - 0.16.23 fixed bit_and,
  and 0.16.24 made upstream rule updates insert-only, the standing
  argument for declarative reconcile). Limiter identity: `MtaInboundThrottle` matches on
  `description` (no `name`); key vocabulary `authenticated_as` (NOT
  auth_as); dnsbl zone/tag are QUOTED expression constants.
- Tests: VM E2E for behavior, eval contract for wiring. Never weaken
  module defaults to make a test deterministic - fix the test.
- Shared VM-test/demo blocks live in tests/common.nix: the DNS-less-VM
  provision patches (DnsResolver Cloudflare + pyzor off -
  nodes with a REAL resolver, e.g. relay-e2e's dnsmasq, must NOT import
  it), the /etc/test-admin-secret fallback-admin file, and the upstream
  DMARC aggregate fixture each have ONE canonical copy there - import,
  never restate. flake8 E501 guards python inside writers'' strings:
  keep lines <= 79 chars AFTER the nix 4-space strip (<= 83 in the file).
- STALWART 0.16 DOCTRINE: the wrapper renders `services.stalwart.provision`
  plans; `services.stalwart.settings` is ONLY the config.json datastore
  descriptor; the admin is a REQUIRED systemd credential. The FULL dialect
  plus every sharpest edge (local-part-only `User.name`/`EmailAlias.name`,
  `#id` refs resolve against EARLIER same-plan ops, upserts must carry
  their match property, IMAP/JMAP login keys on the SYNTHESIZED address,
  `hostname` = provisioned Domain (auth 535 / MAIL FROM 501), provision
  BEFORE any SMTP probe (1 h directory negative cache), catch-all AFTER
  unknown-recipient probes, over-quota = SMTP-accept + IMAP absence +
  JOURNAL SILENCE) live in the README ledger - do NOT restate here
  (split-brain rule); `provision-plan-eval` + the e2e checks pin the
  load-bearing ones in code.
- SystemNix layers (sops, ports, Gatus, onFailure, backup-coordination)
  belong to the CONSUMER wrapper, not here.

## Working rules (learned the hard way)

- systemd namespace semantics (three VM runs, 2026-10-28):
  ReadWritePaths with the `-` prefix is evaluated ONCE at namespace
  setup - a path that appears LATER (e.g. postfix's localMail maildir
  at first delivery) never gets the rw bind and ProtectSystem=strict
  keeps it read-only forever (silent Errno 30). And EVERY ExecStartPre
  command is namespaced - the `+` prefix exempts only
  user/group/credentials, NOT mounts, so a pre-creation step dies at
  `226/NAMESPACE` before its command runs. Pre-create such paths via
  systemd.tmpfiles (boot time) and whitelist UNPREFIXED so regressions
  fail the unit loudly; the dmarc localMail contract is eval-pinned in
  dmarc-eval's localMail-shape eval.

- The 0.15 -> 0.16 store boundary is a POISON class (pbx outage
  2026-10-17): the 0.16 binary PANICS (exit 101) on a pre-0.16 store AND
  poisons the settings subspace for 0.15.5 BEFORE panicking - the unit
  guard (default.nix) is the hard boundary; the migration script's poison
  preflight is a hard stop; the dump runs from a pre-0.16 copy
  (--backup-dir) while recovery mode fixes the LIVE store (port =
  STALWART_RECOVERY_MODE_PORT - never assume 8080).
- Flake-structure rules (mechanism comments live in flake.nix and
  flake-modules/checks.nix): keep the outputs-lambda ELLIPSIS
  (`outputs = inputs@{flake-parts, nixpkgs, ...}:` - flake-parts consumes
  the whole inputs set; deadnix/BuildFlow strip named-but-unused args;
  dropping it once killed the whole flake); outputs live in
  `flake-modules/*.nix` (module args carry `inputs`/`self`); in perSystem
  use the built-in `pkgs` (redefining `_module.args.pkgs` leaves pkgs
  UNBOUND - proven) and `pkgs.lib`, never bare `lib`; `nix flake lock`
  fails on UNDEFINED VARIABLES (parse-time) but not on a `throw` inside
  outputs. Reference-first for structural migrations: first draft = the
  sibling repo's verbatim shape, verify green, THEN deviate one step at a
  time; run the two `nix eval` guards (check attrNames + aarch64 shape)
  IMMEDIATELY after every flake-structure write (the daemon commits
  mid-session).
- Known lint noise - deliberate non-fixes, do NOT "repair": the
  parsedmarc-e2e fetchurl sha256 fixture pin (nix-checker hardcoded-hash
  findings are wrong about fixtures); ruff F821 in
  tests/fixtures/debug-template.py (silenced in-file - the driver injects
  names at runtime); `{ ... }` vs `{...}` in tests/*.nix coexist
  intentionally; nix-checker port-collision findings are cross-context
  false positives (root-fixed in the checker - keep the step); bandit
  B404/B603/B108 on host-parse-fixture.py and vulture `auth` on
  migrate_v016.py = accepted noise / false positive (requests.Session
  attribute).
- Workflow edits need a LOCAL actionlint WITH shellcheck (devShell or the
  pre-push `nix shell` fallback - bare `nix run nixpkgs#actionlint` is
  blind); heredocs with quoted delimiters dissolve the SC2016/2064/1012
  quoting crab-walk. statix W20 is FIXED, not tolerated: collapse
  `services = { stalwart = { ... }; }` blocks ALL the way down in VM-test
  node configs. vulnix crashes fleet-wide (NVD retired the legacy feeds),
  skipped in .buildflow.yml (BuildFlow's "unscannable store path" hint is
  a misdiagnosis of that crash).
- Release procedure: CONTRIBUTING owns the checklist. The daemon races
  explicit commits on release-critical files - edit and commit in the
  SAME tool call. `core.hooksPath` can dangle silently - when touching
  hook config: `git config core.hooksPath && ls "$(git config
  core.hooksPath)"`; it is repo-LOCAL (fresh clones re-set it; CI's
  alejandra step is the real gate).
- No new test assertion without a transcript: grep the asserted line from
  an existing test log or debug VM run first (upstream source is NOT
  evidence of what the journal prints - the `Mailbox over quota.`
  lesson). In-VM assertions are file-based, never `producer | grep -q`
  (pipefail + EPIPE exit-23 class; the negated form phantom-greens) -
  mechanized by the CI awk lint (word boundaries there are
  `([^[:alnum:]]|$)`, NOT `\b` - gawk treats `\b` as backspace).
- Known gate noise: the gate log's "running N flake checks" count line
  can disagree with the defined set - trust the attrNames eval. Before
  creating a repo-root file, `ls` the WHOLE repo incl. `docs/` first.
- Session-start baseline ritual: `git status --short`, `pgrep -af crush`,
  scan EVERY corridor dir (`docs/status`, `docs/planning`, `docs/reviews`)
  for same-day reports BEFORE the first edit; never
  edit a file another session is mid-iterating on - hand off via
  TODO_LIST rows. Register reads with `view` (bash does NOT arm the
  modified-since-read guard). Annotated status reports are
  formatter-fragile (dprint REWRAPS struck rows and EATS overflow cells):
  strike rows in the per-cell canonical form, run `annotate.go
  check-rows` after every formatter pass.
- Stalwart source-assessment discipline: ground every "pinned version" claim in flake.lock (parse rev, then
  `nix eval github:NixOS/nixpkgs/<rev>#stalwart_0_16.version`) - bare
  `nix eval nixpkgs#...` answers the REGISTRY, not this deployment (a
  whole review ran against 0.16.26 while the lock ships 0.16.22).
  Wire-claims stay source-level until a demo-VM transcript set exists
  under docs/probes/ - the INBOXCLEAN transcript rule extends to
  CardDAV/JMAP-contacts. Upstream issues: no filing without a measured
  victim (filing gate = demo-VM benchmark at 10k+ cards); verdict, source
  facts + citations live in
  docs/status/archived/2026-10-19_02-35_stalwart-contacts-assessment.md.

## EventCatalog integration (catalog.home.lan)

- `scripts/export-catalog.py` is the ONLY content source for the
  eventcatalog-hub adoption; edit its data dicts, never a generated tree.
  Adoption lives in the HUB's `sources.manual.json` (depgraph discovers
  Go modules only - a `.eventcatalog-hub.json` convention file here would
  be dead weight). After hub-side edits: `scripts/generate-sources.sh`
  regenerates `sources.json` (never hand-edit), commit both together.
- Hard contract pins (selftest-enforced): service `version` LOCKSTEP
  `1.0.0` with the hub's `render-inventory.py` (a mismatch forks the id's
  version set in the union); NO `badges` (deployment chips union in from
  the SystemNix inventory tree, merge.py unions by content); NO
  `catalog.index.json` manifest (manifest-free sources render "-"); all
  `appliesTo` pointers and the `owners` reference (`users/lars.mdx` is
  shipped in-tree) must resolve inside the exported tree - the hub's
  per-source linter checks each source IN ISOLATION.
- Export invocation is ALWAYS `python3 scripts/export-catalog.py -o ...`
  (CI clone dirs are NOEXEC - never `./scripts/...`); re-export must stay
  idempotent (the hub RETRIES export jobs; the outdir guard only refuses
  dirs that are not a previous export of ours).
- ADR statuses are honest: `parsedmarc-keep-or-retire` (C42) and
  `stalwart-pin-vs-overlay` (C45) ship `proposed`; flip them in the
  exporter data when the owner decides.

## Documentation map

- `README.md` - architecture, module docs, go-live runbook, VERIFIED-FACTS
  LEDGER, canonical check-set list, quickstart (incl. demo ports/creds).
- `FEATURES.md` - feature inventory by status; `TODO_LIST.md` - open
  bounded work; `ROADMAP.md` - themes + gating decisions; `CHANGELOG.md`.
- `docs/{status,planning,reviews}/` - snapshots; `archived/` holds
  resolved ones (archive policy + strike form:
  `docs/status/archived/README.md`; dprint BEFORE the `git mv`).
- `docs/TELEMETRY.md` (0.15.5-era caveat: verify keys against the pin);
  `docs/THREAT_MODEL.md`; `SECURITY.md`; `CONTRIBUTING.md` (ledger rules,
  wrapper-change rules, the gate, the release procedure, the pre-push
  hook, the arch-diagram regen).
- `docs/INBOXCLEAN.md` - InboxClean JMAP contract (0.16 re-verified
  2026-10-18); transcripts under `docs/probes/<date>/` (docs-health sweep
  targets). `docs/MONITORING.md` - wrapper sources here, routing/Gatus/
  scrape on the CONSUMER host; alerts never ride the stack they watch;
  every checker is dead-man-monitored.
