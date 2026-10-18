# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(InboxClean/DiscordSync upstream-flake pattern). Architecture, runbook, and
the VERIFIED-FACTS LEDGER live in README.md - READ THE LEDGER before
touching Stalwart/parsedmarc config keys; several "obvious" keys are wrong
(`certificate.self-signed`, `[imap]` vs `[mailbox]`), and the 0.16 object
model broke most 0.15 intuitions (ledger section "Stalwart 0.16" - REST
recipes, provision-plan dialect, JMAP session path; the 0.15.5 clusters
are era-marked historical).

## Commands

- `buildflow` - the quality gate wrapper (fmt/lint/repairs + nix targets).
  Skips with rationale live in `.buildflow.yml` (vulnix, pytest-test,
  mypy-check - reasons inline there). Tools run inside the flake devShell:
  `devShells.<system>.default` must stay resolvable (`nix develop -c echo
  ok`), else every tool fails with "does not provide attribute
  'devShells...'". Warning-level findings (nix-checker hardcoded-hash) do
  NOT fail the gate (default threshold: error) - see Working rules for the
  deliberate non-fixes. "N tools unavailable" (jest/knip/madge/pnpm tools,
  interrogate) is expected noise for a Nix-only repo.
- `nix flake check` - the full gate: pure eval contract checks + the
  x86_64-only VM E2E tests (~4-6 min on CI for the 7-check set, step-timed
  2026-10-17; the SMTP subtest intentionally waits
  out ~60 s of resolver timeouts in the DNS-less VM; aarch64 evals a
  reduced set, shape-guarded in CI). The check set is SINGLE-SOURCED: the
  canonical list is the ci.yml lockstep `expected=` list / README "What is
  built and verified" - do NOT restate it here (a restated count here rotted
  within hours once); live truth is `nix eval .#checks.x86_64-linux --apply
  builtins.attrNames`. NOTE: failed check results are CACHED - a rerun
  without an input change replays the old verdict. `--no-build` emits the
  eval warnings fast (cheap triage instrument for eval noise). The gate
  also forces the `nixosConfigurations.demo` toplevel incl. its assertions;
  `demo-eval` additionally pins the demo's human contract (quickstart port
  pairs, provision roles/catch-all/absolute-curl, fallback admin, pyzor
  off).
- Host binary spike = DEAD END for Stalwart: the pinned binary boots and
  parses config on the host but listeners never bind (futex-wait after
  external-resource downloads); the same binary boots fine in the VM. Use
  the VM debug loop below instead. Host loops remain fine for pure
  client-side forensics (swaks/SMTP sink, see below).
- `nix run .#vm` (x86_64) - throwaway demo VM (`nixosConfigurations.demo`,
  0.16 shape: declarative plan, `mail.demo.test`, password
  `demo-nixemail-2026`, fallback-admin login `admin` with password
  `demo-admin` via /etc credential; a fresh host-side runtime smoke is
  pending - see TODO_LIST): web admin/JMAP host :18080, SMTP :2525,
  submission :2587, IMAPS :2593. The demo disk is CWD-relative
  ./demo.qcow2 - run from a scratch dir. Debug pattern that worked: FIFO
  console (`mkfifo in && cat in | <vm-closure>/bin/run-demo-vm > log` with
  a `sleep infinity > in` holder) - more reliable than the nixos-test-driver
  for ad-hoc demo runs, because the driver's wait_for_unit/boot waits wedge
  when a unit under test never activates. Probe LAYERED: guest service ->
  guest loopback -> HOST port. "Connects but never answers" behind a
  forward is a FIREWALL signature, not a transport bug (ledger (k)); unit
  scripts need ABSOLUTE binary paths (ledger (l)).
- VM debug loop: realize the driver (`nix-store -r $(nix-store -q
  --references $(nix eval --raw .#checks.x86_64-linux.stalwart-e2e.drvPath)
  | grep nixos-test-driver)`) and run a custom script with `--test-script
  /tmp/debug.py` (create output dir first: `-o` requires an EXISTING
  directory). NOTE: the references grep yields the driver's `.drv`;
  `nix-store -r` prints the realized OUTPUT path, and the binary is at
  `<output>/bin/nixos-test-driver` (calling `<output>/nixos-test-driver`
  directly is a silent-looking "no such file"). The driver's python runs
  on the HOST - anything touching VM ports must be a packaged script or a
  machine.succeed("...") command, never host-side socket code. KEEP A GC
  ROOT while debugging: `nix build -o /tmp/st-e2e-root
  .#checks.x86_64-linux.stalwart-e2e` pins the test closure via the
  out-link so a background GC cannot yank the driver mid-loop (drop it
  with `rm /tmp/st-e2e-root`). CI-side gc-roots are pointless - runners
  are ephemeral and flakehub-cache owns persistence there. DEBUG-SCRIPT
  INSTRUMENT RULES: (a) long commands inside `machine.execute` return
  status -1/28 or die on a guest-shell BrokenPipeError - wrap the payload
  in `machine.succeed("... > /tmp/f.log 2>&1; echo EXIT:$? >> /tmp/f.log")`
  and cat the file; (b) NEVER `systemctl start stalwart-provision.service`
  manually in a debug script - the boot apply already ran (oneshot
  completes ~10 s after stalwart activates) and a manual RE-run's
  try-restart races the probe (535 on VALID credentials); wait for
  `stalwart.service` + `wait_for_open_port` instead; (c) journal signature
  greps must exclude systemd noise words - bare `over` matches every
  `Consumed ... over Ns wall clock` line; quote concrete phrases (`over
  quota`, `rescheduled`) or grep the queue id; (d) the driver can die
  mid-poll-loop (BrokenPipeError) - a rerun is the fix, not a redesign.
- Gate commands never wear pipes (`cmd | tail` can print PASSED on a
  failing run) - full redirect+echo-exit procedure in Working rules below;
  test assertions are transcribed from observed transcripts, not from
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
  alejandra reads STDIN and dies with `unexpected end of file` - check-mode
  is `nix fmt -- . --check` (what CI enforces). Run it BEFORE yielding on
  any session that touched `.nix` files: the auto-commit daemon pushes
  mid-session, so unformatted edits reach CI and the fail-closed alejandra
  step goes red on a push you never explicitly made.
- A working-tree gate red may belong to ANOTHER session's UNCOMMITTED
  in-flight fix, not your edits. Before attributing a red to your diff:
  `git status`/`git diff` for files you didn't touch, and date the check
  output via `nix path-info --json <outPath>` registrationTime - an output
  registered BEFORE your edit window but hashing to the SAME path your
  post-edit tree evals to is content-addressing proof the refactor changed
  nothing. Never edit the foreign in-flight file; report it.
- After editing ONE check, build THAT check first
  (`nix build .#checks.x86_64-linux.<name> -L`), then the full gate - a
  full-gate run just to discover a single subtest's typo costs ~9 min.
- Adding/removing a flake check requires updating THREE guard sites in
  the same change: BOTH ci.yml lists (x86_64 lockstep `expected=` +
  aarch64 shape-guard) AND `scripts/check-inventory.sh`, which carries
  its OWN copy of both lists - the hook fails the push only AFTER
  ci.yml passed, and daemon pushes bypass the hook entirely, so a
  missed site ships red master (2026-10-17: bind-e2e shipped with two
  of three sites; the hook caught the third on the next push). The
  local `nix flake check` runs NONE of these guards. Pre-flight grep
  before editing: `grep -rn '<existing-check-name>' .github scripts`.
- A red CI run is NEVER "the known one" without reading the failing STEP
  name from `gh run view --log-failed` - two distinct causes can stack
  (a known red once masked a lockstep-guard red that had already shipped
  unnoticed master runs).
- Markdown tables in this repo are dprint-formatted: a cell containing a
  literal `|` (journal transcripts, grep patterns) MUST escape it as
  `\|` - dprint re-splits unescaped pipes into phantom columns and DROPS
  the overflow content (two status-report rows were once eaten and had to
  be restored from git). Mechanized in CI:
  `scripts/check-md-table-pipes.sh` (self-tested lint; run it locally
  over edited .md files).
- dprint also mangles PROSE wraps: a bullet-continuation line that STARTS
  with a list marker (`-` or `+`) parses as a NESTED list item (or gets
  marker-normalized `+` -> `-`), and dprint re-indents/rewrites every
  following line under it. When rewrapping bullets or prose, never let a
  mid-sentence `-`/`+` land at a line start. Always `git diff` after a
  dprint fmt pass over edited prose.
- VM-test fixture traps (both live-observed):
  - dovecot settings values must NOT use the `<path` prefix (that is
    dovecot's read-value-from-file syntax - the NixOS module then inlines
    file CONTENTS into dovecot.conf and doveconf dies parsing the first
    PEM line as a path);
  - the parsedmarc ini generator renders bools Python-style (`ssl=True`,
    NOT `ssl=true`) - grep assertions must match `True`;
  - `arrival_date_utc` assertions are TIMEZONE-NORMALIZATION proofs, not
    date greps: the fixture's `+0200`/`+0800`/`+0000` offsets must each
    survive conversion to UTC in the asserted string (the e2e asserts all
    three classes - keep new fixtures in at least one non-UTC offset or
    the assertion proves nothing).
- HOST-SIDE PARSER DRY-RUN before any VM test that feeds a fixture to a
  python service: `python3 scripts/host-parse-fixture.py <fixture> --check
  parsedmarc-e2e` runs the PINNED parser on the fixture in ~30 s (walks
  the check closure, PYTHONPATH = pinned minor's site-packages,
  `parse_report_file(offline=True)`; realize the check first if the
  closure is missing). This reproduces VM parser reds in seconds instead
  of a ~5 min VM build - and proves fixture vs harness blame before the
  IMAP path is ever suspected. Related trap: upstream "sample" artifacts
  can be malformed and later repaired - when a fixture fails to parse,
  diff the newest upstream copy before blaming the parser or hand-building
  a replacement.

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine). Bump both
  together. The full bump + consumer-pin + workaround-retirement procedure
  is the README "Pin-advance runbook". SystemNix HARD-PINNS this flake's
  release tags (the consumer pin rides each release tag from here - README
  PIN DISCIPLINE). STALWART SURFACE: the wrapper NO LONGER uses nixpkgs'
  `services.stalwart` module - the 0.16 module is VENDORED
  (`modules/stalwart-module/`, PR #552103; retirement checklist in the
  module header; nixpkgs watch item = the PR merging into the pinned rev),
  and the binary is the pin's `stalwart_0_16`; the 0.16.26-overlay
  question is decision C45 (TODO_LIST).
- Wrapper hardening options: `rateLimits` and `spamFilter.dnsbl.servers`
  default OFF by design - 0.15.5 shipped two conservative inbound limiters
  via DEFAULT_SETTINGS (README ledger (i)) and DNSBL has no master switch +
  needs real DNS (ledger (j)). Do NOT "fix" the defaults to ON. 0.16
  update: the DNSBL plan section ALWAYS carries an (empty-by-default)
  reconcile set that DESTROYS 0.16.22's 18 shipped-broken default rows
  (fixed upstream 0.16.23; the `defaultDnsblEmpty` posture is contracted
  in module-import-eval) - do not simplify it away. Limiter identity on
  0.16: `MtaInboundThrottle` matches on `description` (no `name`); key
  vocabulary `authenticated_as` (NOT auth_as); dnsbl zone/tag are emitted
  as QUOTED expression constants.
- flake-parts input policy: FLOATING `github:hercules-ci/flake-parts`,
  pinned by flake.lock only - both reference flakes (SystemNix,
  nix-international-telephony) float it too, so the lock pin is the
  fleet's reproducibility control; a URL-hard rev would diverge from fleet
  posture without adding safety. The `nixpkgs-lib.follows = "nixpkgs"`
  follow is NOT optional - a dropped follow smuggles a second nixpkgs rev
  into every consumer lock (eval guard tracked in TODO_LIST).
- Flake-parts adoption decisions (do not re-litigate without new
  evidence): treefmt-nix REJECTED (swaps alejandra for nixfmt, reformats
  the whole repo, breaks the `nix fmt -- . --check` CI contract); the
  flake-parts `systems` input REJECTED (the hardcoded two-system list
  matches both references); git-hooks-nix REJECTED (BuildFlow owns
  pre-commit).
- Wrapper options are `services.mail-server` / `services.dmarc-monitor`
  (NOT `services.stalwart-mail` - collides with an nixpkgs rename alias).
- All wrapper defaults are `mkDefault`; consumers override via
  `services.stalwart.settings` / `services.parsedmarc.settings`.
  EXCEPTION: `networking.firewall.allowedTCPPorts` in mail-server.nix is a
  plain definition. Root cause (verified via
  `options.<opt>.definitionsWithLocations`): the module system keeps only
  lowest-priority defs (lib/modules.nix `filterOverrides'`), and base
  nixpkgs ships unconditional `[]` defs at priority 100 on that option
  (podman network-socket.nix `lib.optional`, udp-over-tcp.nix
  `getFirewallPorts`) - so any mkDefault list there is discarded
  wholesale. Lists concat only within one priority tier;
  `services.openssh.ports` has no such base def.
- Tests: VM E2E for behavior, eval contract for wiring. Never weaken
  module defaults to make a test deterministic - fix the test (e.g. swaks
  --timeout), keep the product honest.
- STALWART 0.16 DOCTRINE: the wrapper vendors nixpkgs PR #552103's module
  (`modules/stalwart-module/`, provenance + retirement trigger in-file)
  and renders `services.stalwart.provision` plans;
  `services.stalwart.settings` is ONLY the config.json datastore
  descriptor; the admin is a REQUIRED systemd credential. The FULL
  transcript-pinned plan dialect + 0.16 object model live in the README
  ledger ("Stalwart 0.16") - do NOT restate them here (split-brain rule;
  they have drifted within hours when duplicated). Sharpest edges:
  `User.name`/`EmailAlias.name` = LOCAL PART only (a full address fails
  apply); `#id` refs resolve ONLY against earlier ops in the SAME plan; an
  upsert patching an existing object MUST carry its match property; IMAP
  LOGIN keys on the synthesized EMAIL ADDRESS (the 0.15
  login-by-principal-name trap is gone); `hostname` = the provisioned
  Domain value (keep them equal or addresses land outside the local
  namespace: auth 535, MAIL FROM 501).
- E2E ordering matters: provision domain/accounts BEFORE any SMTP probe -
  a probe touching an unprovisioned domain poisons the directory negative
  cache (1 h TTL) and the domain then routes to MX instead of local; a
  catch-all (`Domain.catchAllAddress` on 0.16) makes every local part
  deliverable, so it is applied AFTER any unknown-recipient-rejection
  probe (the e2e uses a second runtime plan). Over-quota mail is ACCEPTED
  at RCPT (`250 2.0.0 Message queued with id`) but never delivered -
  assert IMAP absence + 0.16 JOURNAL SILENCE, never SMTP refusal (0.15's
  `Message rescheduled for delivery` signature is GONE on 0.16: no
  quota/retry/reschedule/4xx line ever appears; the re-pinned quota
  subtest asserts exactly this shape).
- SystemNix layers (sops, ports.nix, Gatus, onFailure, backup-coordination)
  belong to the CONSUMER wrapper, not here.

## Working rules (learned the hard way)

- The 0.15 -> 0.16 store boundary is a POISON class (2026-10-17, pbx
  outage): the 0.16 binary panics (exit 101, migration/lib.rs:95) on a
  pre-0.16 store AND writes webui defaults into the settings subspace
  BEFORE panicking, so every crash-loop iteration poisons the store for
  0.15.5 ("Data corruption detected") - and the sanctioned dump needs a
  live 0.15.x. Consequences: never boot 0.16 against an old store without
  the unit guard (default.nix) having passed; the migration script's
  poison preflight is a hard stop, and the dump then runs from a
  pre-0.16 copy (--backup-dir) while recovery mode still fixes the LIVE
  store (the wipe removes the poison with everything else in the
  settings subspace). Recovery mode's port is STALWART_RECOVERY_MODE_PORT
  - never assume 8080 (the built-in; consumer hosts own it).
- NEVER "clean up" the flake outputs lambda signature: Nix ALWAYS passes
  `self` to outputs, and flake-parts additionally consumes the whole
  `inputs` set, so the pattern needs the ellipsis
  (`outputs = inputs@{flake-parts, nixpkgs, ...}:`). A named-but-unused
  `self` is not an option either - deadnix flags it every run and
  BuildFlow's deadnix auto-fix strips it (deadnix alone is report-only by
  default; the removal path is BuildFlow's edit mode). The ellipsis is the
  only shape that survives both (mechanism comment in flake.nix; dropping
  it once killed the whole flake). `flake.nix` is a thin shell (inputs +
  guards + mkFlake `imports`); the outputs live in `flake-modules/*.nix`
  (flake-parts modules: nixos-modules, demo-vm, checks, devshells,
  lock-guards); module files take `inputs`/`self` as module args, and only
  `flake-parts` stays in the outputs destructure (named-but-unused
  patterns trip deadnix + statix - the ellipsis still carries self).
- flake-parts perSystem: `pkgs` comes from flake-parts' built-in nixpkgs
  module (`inputs'.nixpkgs.legacyPackages`) - do NOT redefine
  `_module.args.pkgs` inside perSystem (verified the hard way: pkgs ends
  up UNBOUND when checks eval; see the comment in
  flake-modules/checks.nix). Both reference flakes just destructure `pkgs`
  and use `pkgs.lib`, not a bare `lib`, inside perSystem. dmarc-eval still
  receives the raw `nixpkgs` input, so its own legacyPackages semantics
  are unchanged.
- `nix flake lock` fails on an UNDEFINED VARIABLE in flake.nix (parse-time
  scope error) but NOT on a `throw` inside outputs/checks (lock forces
  neither) - mechanism comment lives in flake.nix.
- Reference-first for structural migrations: when a sibling repo carries
  the proven pattern, the first draft is its verbatim shape - verify
  green, THEN deviate one step at a time with evidence (a from-memory
  `_module.args.pkgs` "improvement" once produced a dead flake the
  reference shape would have prevented). Run the two `nix eval` guards
  (`nix eval .#checks.x86_64-linux --apply 'builtins.attrNames'` + the
  aarch64 shape) IMMEDIATELY after every flake-structure write - the
  auto-commit daemon commits mid-session, so a dead flake becomes git
  history within minutes.
- Known lint noise - deliberate non-fixes, do NOT "repair": the
  tests/parsedmarc-e2e.nix fetchurl sha256 pin is intentional
  reproducibility (nix-checker hardcoded-hash/inline-hash findings are
  wrong about fixtures, warning-severity); ruff F821 in
  tests/fixtures/debug-template.py is silenced in-file (the
  nixos-test-driver injects start_all/machine at runtime); `{ ... }` vs
  `{...}` in tests/*.nix coexists intentionally (alejandra 4.0.0 preserves
  both on round-trip - do not normalize either style). The nix-checker
  port-collision findings were cross-context false positives (demo-VM
  hostfwd GUEST ports inside a throwaway QEMU VM vs a DIFFERENT VM test's
  client connect target vs docs prose inside literalExpression - no shared
  runtime exists), root-fixed in the checker itself (masks
  strings/comments, downgrades privileged-port collisions) - do NOT "fix"
  this repo's Nix for the surviving warning pairs and do NOT skip the
  nix-checker step (it also owns stale-hash/input drift checks with real
  signal). bandit's B404/B603/B108 on scripts/host-parse-fixture.py are
  accepted warning-severity noise (local developer forensic tool:
  subprocess runs developer-controlled nix commands without shell, and
  the /tmp default is the documented --out UX; the gate threshold is
  error, so these never fail). vulture's `unused attribute 'auth'` on
  migrate_v016.py is a false positive (a requests.Session attribute -
  assignment IS the usage; the library reads it).
- Workflow edits need a LOCAL actionlint run WITH shellcheck on PATH:
  CI's actionlint runs WITH shellcheck (preinstalled on runners), but a
  shellcheck-less local machine is blind to shellcheck findings (a trap
  handler + a backtick-bearing printf once shipped as SC2016/SC2064 reds).
  The devShell carries actionlint + shellcheck (buildflow runs tools
  inside it), and the pre-push hook runs actionlint with a `nix shell
  nixpkgs#shellcheck nixpkgs#actionlint` fallback. Outside the devShell,
  bare `nix run nixpkgs#actionlint` alone is STILL blind (it pulls
  actionlint without shellcheck). Quoting fixes there have a crab-walk
  quality - SC2016 wants deferred, SC2064 wants immediate, SC1012 bans
  `\n` in double quotes - heredocs with quoted delimiters dissolve all
  three.
- statix W20 is FIXED, not tolerated: VM-test node configs use fully
  collapsed `services = { ... }` blocks. The warning fires when a first
  SEGMENT repeats 3+ times within ONE attrset level and RECURSES after
  each collapse (`services = { stalwart.settings.x = ...; }` gets
  re-flagged on repeated `stalwart`), so collapse common prefixes all the
  way down (`services = { stalwart = { settings = { ... }; }; }`). A
  2-repeat partial collapse passes today and trips on the next entry.
- vulnix crashes fleet-wide: NVD retired the legacy JSON feeds (404 on
  nvdcve-2.0-modified.json.gz; vulnix 1.12.5 unmaintained) - BuildFlow's
  "unscannable store path ./result" hint is a MISDIAGNOSIS of that crash,
  and `rm result` + rebuild does not help. Skipped via .buildflow.yml.
- Gate commands redirect, never pipe: `nix flake check > /tmp/gate.log 2>&1;
  echo "EXIT:$?" >> /tmp/gate.log`, then read the log. A pipe reports the
  FILTER's exit code - two fake greens shipped that way in one session.
  Also never run `buildflow` and `nix flake check` CONCURRENTLY - the
  timing analytics become contention noise and get reported as phantom
  regressions.
- An EMPTY `nix build` log means CACHE HIT, not a run. When execution
  itself is the claim, force it (`nix build --rebuild`) or grep the log
  for driver output. Dating store outputs: `nix path-info --json
  registrationTime` (mtimes are epoch-normalized). BuildFlow's
  nix-flake-check step is EVAL-ONLY - real VM execution is owned by
  `nix flake check` / CI, never by the buildflow gate.
- Release procedure (cut CHANGELOG -> gates -> annotated tag -> push ->
  tag-CI verify -> gh release): CONTRIBUTING "Release procedure" section
  owns the checklist. The daemon races explicit commits on release-critical
  files - edit and commit in the SAME tool call.
- `core.hooksPath` can dangle silently (it once pointed at `.githooks/`
  for the hook's whole lifetime while the directory did not exist - zero
  symptoms until invoked). When touching hook config, check `git config
  core.hooksPath && ls "$(git config core.hooksPath)"`. It is repo-LOCAL
  config: fresh clones must re-set it - CI's fail-closed alejandra step is
  the real gate.
- No new test assertion without a transcript: grep the line you assert
  from an existing test log or a debug VM run first. Reading it in
  upstream source is NOT evidence of what the journal/log prints (the
  `Mailbox over quota.` vs `Message rescheduled for delivery` lesson).
- In-VM test assertions are file-based, never `producer | grep -q`: the
  test shell runs pipefail, and grep -q's early exit EPIPEs the producer
  (a metrics curl once failed CI with exit 23 on a MATCHING payload), and
  under pipefail the negated form `! producer | grep -q` can phantom-green.
  Dump to /tmp, then grep the file. Mechanized in CI (the "Ban piped
  grep/tail/head" awk step; `| tail`/`| head` are the same exit-code-eating
  class and are banned too). Word boundaries in that awk are
  `([^[:alnum:]]|$)`, NOT `\b` - gawk 5.x regex constants treat `\b` as
  backspace, which made the first version of the lint a never-firing
  false green (caught by local negative test).
- Extract cross-file identifiers mechanically (`grep -o`, `od`, `git diff`
  read-back after multi-line edits) rather than trusting eyes or memory;
  from-memory identifiers have produced corrupted store paths and wrong
  option names.
- Before creating a file at the repo root, `ls` the WHOLE repo including
  `docs/` - a duplicate `THREAT_MODEL.md` was once created beside
  `docs/THREAT_MODEL.md` by checking only the root.
- 0.16-upgrade loop rules: (a) PROBE BEFORE RERUN - on ANY VM-test
  failure, boot the demo/debug VM with the FIFO console BEFORE rerunning
  the expensive test (failures are diagnosed cheaper on the console than
  by a rerun); (b) NEVER trust a sibling report's "green" - read the
  stored run log / `registrationTime` first; (c) NO SCHEMA CLAIM without
  an apply transcript - Rust struct doc comments have been wrong once
  (`User.name`); (d) long-running debug commands under `machine.execute`
  die silently (status 28/-1, empty log) - use succeed-wrapped capture
  (`cmd || true` + file) or packaged probe scripts, and let provisioning
  settle BEFORE probing (port-open != server-ready, the ExecStartPost
  restart window eats connections); (e) every logged artifact in VM tests
  dumps on failure by default, never only on success; (f) VM-test dnsmasq
  must FORWARD upstream (10.0.2.3) - 0.16's reload validation resolves the
  SpamPyzor address through the system resolver, and a black-hole upstream
  aborts the apply before listeners spawn; (g) serialize heavy VM builds
  ACROSS repos - concurrent builds (this repo + siblings) OOM-killed a
  run mid-flight.
- Session-start baseline ritual: `git status --short`, `pgrep -af crush`,
  and a scan of `ls docs/status` for same-day reports BEFORE the first
  edit;
  attribute gate reds via the baseline + `registrationTime` dating, never
  by blaming your own diff; never edit a file another session is
  mid-iterating on - if a file is hot (mtime moving, same-day report
  names it), write to a non-colliding location and hand off via TODO_LIST
  rows. Register reads with `view` (bash sed/grep does NOT arm the edit
  tool's modified-since-read guard).
- Annotated status reports are formatter-fragile: dprint REWRAPS struck
  table rows and EATS the overflow cells (a pass once had to rebuild 120
  rows from git blobs). Rules: strike table rows in the PER-CELL canonical
  form (`| ~~N~~ | ~~cell~~ verdict | ...`), run `annotate.go check-rows`
  AFTER every formatter pass over an annotated file (it proves uniformity
  AND shape), and never hand-roll row repairs - the verdict text must come
  from the preserved spec, never from memory.
- Known gate noise: the full-gate log's "running N flake checks" count
  line has disagreed with the defined set - trust the attrNames eval, not
  the log's count line (reconciliation is a TODO_LIST row).

## Documentation map

- `README.md` - architecture, module docs, go-live runbook, VERIFIED-FACTS
  LEDGER (fact + method + date; do not re-derive config keys from memory),
  and the canonical check-set list ("What is built and verified").
- `FEATURES.md` - honest feature inventory by status.
- `TODO_LIST.md` - open bounded work. `ROADMAP.md` - long-term themes,
  non-goals, and the open user decisions (D1/D2, spam->Junk) that gate
  them.
- `CHANGELOG.md` - what changed. `docs/{status,planning,reviews}/` -
  point-in-time session snapshots; `archived/` subdirectories hold the
  snapshots whose items are fully resolved or routed into the living docs.
- Archive policy: a snapshot is ARCHIVED (`git mv` to `<dir>/archived/`)
  once every forward-looking item (sections b/c/f/g) is closed OR
  canonically routed - the verdict cites the TODO_LIST row, decision-batch
  entry, or ROADMAP idea that now owns it; a user-gated decision counts as
  routed once it sits in `decision-batch.md` with a [rec]. Sections a/d/e
  stay historical records (unstruck by design). Bulk archives carry a
  manifest (`docs/status/archived/README.md`). FORMAT BEFORE ARCHIVE:
  dprint (`buildflow -s dprint-format --fix`) before the `git mv` -
  post-archive reformat commits churn history. Sub-bullets: strike each
  with its own verdict marker; a struck parent with clean children reads
  as open and fails check-rows.
- `docs/TELEMETRY.md` - Stalwart telemetry best-practices guide (written
  against the 0.15.5-era upstream docs; carries a version-skew caveat -
  verify keys against the pinned binary before wiring).
  `docs/THREAT_MODEL.md` - threat model. `SECURITY.md` - security policy
  (supported-versions table).
- `docs/INBOXCLEAN.md` - the InboxClean JMAP integration contract
  (pinned-version facts, auth/host-rewrite rules, label mapping,
  re-verification procedure); raw probe transcripts live under
  `docs/probes/<date-topic>/` with their own README manifests - and BOTH
  are docs-health sweep targets (a pass audits probe-dir manifests for
  staleness too, not just status/planning docs).
- `docs/MONITORING.md` - monitoring/alerting taxonomy + coverage matrix;
  owner split: wrapper-side sources here, alert routing/Gatus/scrape on
  the CONSUMER host. Standing rules: alerts never ride the mail stack they
  watch; every checker is itself monitored (dead-man switch).
- `CONTRIBUTING.md` - verified-facts ledger rules (adding/correcting
  bullets), wrapper-change rules, the gate, the release procedure, the
  pre-push formatting hook, and the architecture-diagram regen command.
