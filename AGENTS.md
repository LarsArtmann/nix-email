# nix-email: Agent Guide

Upstream NixOS flake for the LarsArtmann mail stack. Consumed by SystemNix
(InboxClean/DiscordSync upstream-flake pattern). Full architecture, runbook,
and the verified-facts ledger live in README.md - READ THE LEDGER before
touching Stalwart/parsedmarc config keys; several "obvious" keys are wrong
(see `certificate.self-signed`, `[imap]` vs `[mailbox]`, and the whole
"Stalwart 0.16" ledger section - the 0.16 object model broke most 0.15
intuitions: REST recipes, provision-plan dialect, JMAP session path; the
0.15.5 clusters are era-marked historical).

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
- `nix flake check` - the full gate: eval contract tests (dmarc-eval,
  module-import-eval, demo-eval) + the three VM E2E tests
  (~2-4 min; the SMTP subtest intentionally waits out ~60 s of resolver
  timeouts in the DNS-less VM). NOTE: failed check results are CACHED - a
  rerun without an input change replays the old verdict. `--no-build`
  emits the eval warnings fast (cheap triage instrument for eval noise).
  The gate also forces the `nixosConfigurations.demo` toplevel incl. its
  assertions (probe-verified 2026-10-06); `demo-eval` additionally pins
  the demo's human contract (quickstart port pairs, provision
  roles/catch-all/absolute-curl, fallback admin, pyzor off).
- Host binary spike = DEAD END for Stalwart (2026-09-16): the pinned binary
  boots and parses config on the host but listeners never bind (futex-wait
  after external-resource downloads); the same binary boots fine in the VM.
  Use the VM debug loop below instead. Host loops remain fine for pure
  client-side forensics (swaks/SMTP sink, see below).
- `nix run .#vm` (x86_64) - throwaway demo VM (`nixosConfigurations.demo`,
  reworked for 0.16: declarative plan, `mail.demo.test`, password
  `demo-nixemail-2026`, admin `demo-admin` via /etc credential; a fresh
  0.16 host-side smoke is pending - TODO_LIST): web/API host :18080,
  SMTP :2525, submission :2587, IMAPS :2593. Debug pattern that worked:
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
  are ephemeral and flakehub-cache owns persistence there. DEBUG-SCRIPT
  INSTRUMENT RULES (2026-10-17, three drivers' worth of evidence): (a)
  long commands inside `machine.execute` return status -1/28 or die on a
  guest-shell BrokenPipeError - wrap the payload in `machine.succeed(`
  `"... > /tmp/f.log 2>&1; echo EXIT:$? >> /tmp/f.log")` and cat the
  file; (b) NEVER `systemctl start stalwart-provision.service` manually
  in a debug script - the boot apply already ran (oneshot completes ~10 s
  after stalwart activates) and a manual RE-run's try-restart races the
  probe: driver6 got a 535 on VALID credentials from exactly this; wait
  for `stalwart.service` + `wait_for_open_port` instead; (c) journal
  signature greps must exclude systemd noise words - `over` alone
  matches every `Consumed ... over Ns wall clock` line (driver7 false
  positive); quote concrete phrases (`over quota`, `rescheduled`) or
  grep the queue id; (d) the driver can die mid-poll-loop
  (BrokenPipeError at iteration ~7 of 16, driver8) - a rerun is the fix,
  not a redesign.
- Gate commands never wear pipes (`cmd | tail` can print PASSED on a failing
  run) - full redirect+echo-exit procedure in Working rules below; test
  assertions are transcribed from observed transcripts, not from
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
- A working-tree gate red may belong to ANOTHER session's UNCOMMITTED
  in-flight fix, not your edits (2026-10-17: stalwart-e2e's catch-all apply
  failed in a gate run whose tree carried a foreign, uncommitted
  Account-before-Domain plan reorder whose own comment documents that exact
  failure). Before attributing a red to your diff: `git status`/`git diff`
  for files you didn't touch, and date the check output via
  `nix path-info --json <outPath>` registrationTime - an output registered
  BEFORE your edit window but hashing to the SAME path your post-edit tree
  evals to is content-addressing proof the refactor changed nothing (the
  2026-10-17 attrpath collapses reproduced the byte-identical relay-e2e VM
  closure this way). Never edit the foreign in-flight file; report it.
- After editing ONE check, build THAT check first
  (`nix build .#checks.x86_64-linux.<name> -L`), then the full gate - a
  full-gate run just to discover a single subtest's typo costs ~9 min.
- Adding/removing a flake check requires updating BOTH ci.yml guard lists
  (the x86_64 lockstep `expected=` list AND the aarch64 shape-guard
  `test ... = ...`) in the same change - the local `nix flake check`
  does NOT run these CI-side guards, so a miss ships red CI (2026-09-23:
  module-import-eval missing there caused three red master runs before
  anyone noticed).
- A red CI run is NEVER "the known one" without reading the failing STEP
  name from `gh run view --log-failed` - two distinct causes stacked once
  (2026-09-23: the T12 red masked a lockstep-guard red that had already
  shipped three unnoticed master runs).
- Markdown tables in this repo are dprint-formatted: a cell containing a
  literal `|` (journal transcripts, grep patterns) MUST escape it as
  `\|` - dprint re-splits unescaped pipes into phantom columns and DROPS
  the overflow content (two status-report rows were eaten and had to be
  restored from git, 2026-09-23).
- VM-test fixture traps (2026-09-15, both live-observed):
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
  python service (2026-09-23, paid for itself same day; mechanized
  2026-10-05): `python3 scripts/host-parse-fixture.py <fixture> --check
  parsedmarc-e2e` runs the PINNED parser on the fixture in ~30 s (walks
  the check closure, PYTHONPATH = pinned minor's site-packages,
  `parse_report_file(offline=True)`; realize the check first if the
  closure is missing). This
  reproduced a VM red (upstream's forensic sample had space-only blank
  lines that fold into headers, defeating payload-walk detection) in
  seconds instead of a ~5 min VM build - and proved fixture vs
  harness blame before the IMAP path was ever suspected. Related trap:
  upstream "sample" artifacts can be malformed and later repaired
  (upstream repaired theirs in commit ae1e5adb/PR #659) - when a fixture
  fails to parse, diff the newest upstream copy before blaming the parser
  or hand-building a replacement.

## Conventions

- nixpkgs pinned to SystemNix's lock rev (compat doctrine). Bump both
  together. The full bump + consumer-pin + workaround-retirement procedure
  is the README "Pin-advance runbook". EXECUTED 2026-10-05: SystemNix
  HARD-PINNED this flake `?ref=v0.4.0` (C17a adopted; the earlier
  "floats `?ref=master`" and "pins v0.2.0" claims are both obsolete) -
  the consumer pin rides each release tag from here (README PIN
  DISCIPLINE). STALWART SURFACE (2026-10-17): the wrapper NO LONGER uses
  nixpkgs' `services.stalwart` module - the 0.16 module is VENDORED
  (`modules/stalwart-module/`, PR #552103) and the binary is the pin's
  `stalwart_0_16` (0.16.22); the nixpkgs watch item is now "PR #552103
  merging into the pinned rev" (retire the vendored dir then - checklist
  in the module header), plus the C45 0.16.26-overlay question.
- Wrapper hardening options (2026-09-22, M14): `rateLimits` and
  `spamFilter.dnsbl.servers` default OFF by design - 0.15.5 shipped two
  conservative inbound limiters via DEFAULT_SETTINGS (README ledger (i))
  and DNSBL has no master switch + needs real DNS (ledger (j)). Do NOT
  "fix" the defaults to ON. 0.16 update: the DNSBL plan section ALWAYS
  carries an (empty-by-default) reconcile set that DESTROYS 0.16.22's 18
  shipped-broken default rows (fixed upstream 0.16.23; the
  `defaultDnsblEmpty` posture is contracted in module-import-eval) - do
  not simplify it away. Limiter identity on 0.16: `MtaInboundThrottle`
  matches on `description` (no `name`); key vocabulary `authenticated_as`
  (NOT auth_as); dnsbl zone/tag are emitted as QUOTED expression
  constants.
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
- STALWART 0.16 DOCTRINE (2026-10-16/17 upgrade): the wrapper vendors
  nixpkgs PR #552103's module (`modules/stalwart-module/`, provenance +
  retirement trigger in-file) and renders `services.stalwart.provision`
  plans; `services.stalwart.settings` is ONLY the config.json datastore
  descriptor; the admin is a REQUIRED systemd credential. Plan dialect
  (ALL transcript-pinned, README ledger "Stalwart 0.16"):
  `User.name`/`EmailAlias.name` = LOCAL PART only (a full address fails
  apply); ops apply sequentially, `#id` refs resolve ONLY against earlier
  ops in the SAME plan; an upsert patching an existing object MUST carry
  its match property (`name` for Domain); `credentials` must be the
  indexed-map form `{"0":{...}}`; `MtaInboundThrottle` matches on
  `description`; Account sets need explicit `match = ["name"]` (value
  matching breaks once the server hashes secrets); durations are integer
  ms; passwords are zxcvbn-enforced; `.invalid` hostnames are rejected.
  JMAP session: `/.well-known/jmap` 307 -> `/jmap/session` (`GET /jmap` is
  404); anon session = 200 `primaryAccounts: {}`, anon API POST = 401.
  IMAP LOGIN keys on the synthesized EMAIL ADDRESS (the 0.15
  login-by-principal-name trap is gone); `hostname` = the provisioned
  Domain value (keep them equal or addresses land outside the local
  namespace: auth 535, MAIL FROM 501).
- E2E ordering matters: provision domain/accounts BEFORE any SMTP probe -
  a probe touching an unprovisioned domain poisons the directory negative
  cache (1 h TTL) and the domain then routes to MX instead of local; a
  catch-all (`Domain.catchAllAddress` on 0.16) makes every local part
  deliverable, so it is applied AFTER any unknown-recipient-rejection
  probe (the e2e uses a second runtime plan). Over-quota mail is ACCEPTED
  at RCPT and retried - assert IMAP absence, never SMTP refusal (the 0.15
  journal signature `Message rescheduled for delivery` has NO confirmed
  0.16 equivalent; the quota subtest re-pin is open).
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
  edit mode). The ellipsis is the only shape that survives both. Since the
  2026-10-05 module split, `flake.nix` is a thin shell (inputs + guards +
  mkFlake `imports`) and the outputs live in `flake-modules/*.nix`
  (flake-parts modules: nixos-modules, demo-vm, checks, devshells,
  lock-guards); module files take `inputs`/`self` as module args, and only
  `flake-parts` stays in the outputs destructure (named-but-unused
  patterns trip deadnix + statix - the ellipsis still carries self).
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
  style). nix-checker port-collision ERRORS (4 findings, 2 pairs, surfaced
  2026-09-23 when buildflow first ran over the demo-VM changes) WERE
  cross-context false positives: demo-VM hostfwd GUEST ports (587/993
  inside a throwaway QEMU VM; flake-modules/demo-vm.nix since the
  2026-10-05 split, flake.nix before it) vs tests/stalwart-relay-e2e.nix
  relay.port 587 (a DIFFERENT VM test's client connect target) vs
  modules/dmarc-monitor.nix example-block port 993 (docs prose inside
  literalExpression) - no shared runtime exists. ROOT-FIXED upstream
  2026-10-05 (BuildFlow commit 15ea141d2): the checker now masks
  strings/comments before extraction (the docs-prose FP class) and
  downgrades privileged-port (<1024) collisions to warnings, so a full
  buildflow run exits 0 again - VERIFIED with a locally built binary
  against this repo (EXIT:0, zero error findings; the 587 pair survives
  as an annotated warning). RESOLVED 2026-10-16: the home-manager profile
  flipped to a build >= 15ea141d2 (binary 83db580) and a FULL gate run here
  verified EXIT:0 (the nix-checker step reports 12 warning-severity
  findings, 0 errors - the summary-vs-detail 12-vs-2 count gap is a
  BuildFlow-repo TODO). Do NOT "fix" this repo's Nix for the surviving
  warning pairs and do NOT skip the nix-checker step (it also owns
  stale-hash/input drift checks with real signal). The hardcoded-hash
  findings on the parsedmarc-e2e fetchurl pins are
  WARNINGS and documented wrong-about-fixtures (see above).
- Workflow edits need a LOCAL actionlint run WITH shellcheck on PATH:
  CI's actionlint runs WITH shellcheck (preinstalled on runners), but a
  shellcheck-less local machine is blind to shellcheck findings
  (2026-10-05: a trap handler + a backtick-bearing printf shipped as
  SC2016/SC2064 reds). ROOT-FIXED 2026-10-05: the devShell carries
  actionlint + shellcheck (buildflow runs tools inside it, so its
  actionlint step is no longer blind), and the pre-push hook runs
  actionlint with a `nix shell nixpkgs#shellcheck nixpkgs#actionlint`
  fallback. Outside the devShell, bare `nix run nixpkgs#actionlint`
  alone is STILL blind (it pulls actionlint without shellcheck).
  Quoting fixes there have a
  crab-walk quality - SC2016 wants deferred, SC2064 wants immediate,
  SC1012 bans `\n` in double quotes - heredocs with quoted delimiters
  dissolve all three.
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
  Also never run `buildflow` and `nix flake check` CONCURRENTLY - the
  timing analytics become contention noise and get reported as phantom
  regressions (2026-10-05: a +581% nix-build timing was self-inflicted).
- An EMPTY `nix build` log means CACHE HIT, not a run (2026-09-16: EXIT 0
  on three VM checks whose outputs pre-existed 88 min earlier - caught only
  by grepping the log for execution lines). When execution itself is the
  claim, force it (`nix build --rebuild`) or grep the log for driver
  output. Dating store outputs: `nix path-info --json registrationTime`
  (mtimes are epoch-normalized). BuildFlow's nix-flake-check step is
  EVAL-ONLY (observed 0 ms, 2026-09-16) - real VM execution is owned by
  `nix flake check` / CI, never by the buildflow gate.
- Release procedure (cut CHANGELOG -> gates -> annotated tag -> push ->
  tag-CI verify -> gh release): CONTRIBUTING "Release procedure" section
  owns the checklist. The daemon races explicit commits on release-critical
  files - edit and commit in the SAME tool call.
- `core.hooksPath` can dangle silently: it pointed at `.githooks/` for the
  hook's whole lifetime while the directory did not exist (2026-09-16) -
  zero symptoms until invoked. When touching hook config, check `git
  config core.hooksPath && ls "$(git config core.hooksPath)"`. It is
  repo-LOCAL config (verified 2026-09-22): fresh clones must re-set it -
  CI's fail-closed alejandra step is the real gate.
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
- 0.16-upgrade loop rules (all paid for 2026-10-16/17): (a) PROBE BEFORE
  RERUN - on ANY VM-test failure, boot the demo/debug VM with the FIFO
  console BEFORE rerunning the expensive test (every failure that session
  was diagnosed cheaper on the console than by a rerun); (b) NEVER trust a
  sibling report's "green" - read the stored run log / `registrationTime`
  first (relay-e2e's "green" was stale for hours); (c) NO SCHEMA CLAIM
  without an apply transcript - Rust struct doc comments have been wrong
  once (`User.name`); (d) long-running debug commands under
  `machine.execute` die silently (status 28/-1, empty log) - use
  succeed-wrapped capture (`cmd || true` + file) or packaged probe
  scripts; `systemctl start stalwart-provision` + settle BEFORE probing
  (port-open != server-ready, the ExecStartPost restart window eats
  connections); (e) every logged artifact in VM tests dumps on failure by
  default, never only on success; (f) VM-test dnsmasq must FORWARD
  upstream (10.0.2.3) - 0.16's reload validation resolves the SpamPyzor
  address through the system resolver, and a black-hole upstream aborts
  the apply before listeners spawn; (g) serialize heavy VM builds ACROSS
  repos - three concurrent builds (this repo + pbx-artmann + SystemNix)
  OOM-killed one run mid-flight.
- Session-start baseline ritual (2026-10-17, after a near-clobber on a
  foreign in-flight file): `git status --short` + `pgrep -af crush` +
  scan `ls docs/status` for same-day reports BEFORE the first edit;
  attribute gate reds via the baseline + `registrationTime` dating, never
  by blaming your own diff; never edit a file another session is
  mid-iterating on - if a file is hot (mtime moving, same-day report
  names it), write to a non-colliding location and hand off via
  TODO_LIST rows. Register reads with `view` (bash sed/grep does NOT
  arm the edit tool's modified-since-read guard).
- Annotated status reports are formatter-fragile: dprint REWRAPS struck
  table rows and EATS the overflow cells (verdict + category lost - the
  2026-10-17 pass had to rebuild 120 rows from git blobs). Rules:
  strike table rows in the PER-CELL canonical form
  (`| ~~N~~ | ~~cell~~ verdict | ...`), run `annotate.go check-rows`
  AFTER every formatter pass over an annotated file (it proves
  uniformity AND shape), and never hand-roll row repairs - the verdict
  text must come from the preserved spec, never from memory.
- Known gate noise (2026-10-17): the full-gate log printed "running 4
  flake checks" while SIX are defined (`nix eval
  .#checks.x86_64-linux --apply builtins.attrNames` = 6 = ci.yml's
  lockstep list, verified same day); trust the attrNames eval, not the
  log's count line - reconciliation is a TODO_LIST row.

## Documentation map

- `README.md` - architecture, module docs, go-live runbook, VERIFIED-FACTS
  LEDGER (fact + method + date; do not re-derive config keys from memory).
- `FEATURES.md` - honest feature inventory by status.
- `TODO_LIST.md` - open bounded work. `ROADMAP.md` - long-term themes,
  non-goals, and the open user decisions (D1/D2, spam→Junk) that gate them.
- `CHANGELOG.md` - what changed. `docs/{status,planning,reviews}/` -
  point-in-time session snapshots; `archived/` subdirectories hold the
  snapshots whose items are fully resolved or routed into the living docs.
- Archive policy (2026-10-05): a snapshot is ARCHIVED (`git mv` to
  `<dir>/archived/`) once every forward-looking item (sections b/c/f/g) is
  closed OR canonically routed - the verdict cites the TODO_LIST row,
  decision-batch entry, or ROADMAP idea that now owns it; a user-gated
  decision counts as routed once it sits in `decision-batch.md` with a
  [rec]. Sections a/d/e stay historical records (unstruck by design).
  Bulk archives carry a manifest (`docs/status/archived/README.md`).
  FORMAT BEFORE ARCHIVE: dprint (`buildflow -s dprint-format --fix`)
  before the `git mv` - post-archive reformat commits churn history.
  Sub-bullets: strike each with its own verdict marker; a struck parent
  with clean children reads as open and fails check-rows (2026-10-05).
- `docs/TELEMETRY.md` - Stalwart telemetry best-practices guide (from
  stalw.art docs fetched 2026-09-15; carries an upstream-object-model vs
  pinned-0.15.5 version-skew caveat - verify keys against the binary
  before wiring). `docs/THREAT_MODEL.md` - threat model.
- `docs/INBOXCLEAN.md` - the InboxClean JMAP integration contract
  (pinned-version facts, auth/host-rewrite rules, label mapping,
  re-verification procedure); raw probe transcripts live under
  `docs/probes/<date-topic>/` with their own README manifests - and BOTH
  are docs-health sweep targets (a pass audits probe-dir manifests for
  staleness too, not just status/planning docs).
