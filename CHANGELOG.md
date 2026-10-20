# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `check-set-lockstep` check + `tests/check-expected.json` canonical
  check list (2026-10-19): the declared check set must equal the JSON
  list on BOTH arches or `nix flake check` throws with both sets
  spelled out. ci.yml's lockstep/shape steps and the pre-push
  `scripts/check-inventory.sh` now read the SAME file, collapsing the
  four restated copies of the list to one machine source plus the
  README prose row (the 2026-09-23 missing-entry class now fails
  locally regardless of pre-push hook state). Negative-tested (drifted
  name throws; restore passes).
- `provision-plan-eval` check (2026-10-18, the paid-for plan-dialect bug
  classes caught at eval speed): hostname == provisioned-Domain
  coherence, match-property posture (reconcile sets MUST carry an
  explicit match; no-match sets only on the documented implicit-key
  allowlist Domain/MtaRoute/AcmeProvider; Account sets match
  `["name"]`), the fallback listener port set pin (smtp 25 / submission
  587 / submissions 465 / imaps 993 / http httpBind), a systemd Exec*
  multi-line lint (the "Unbalanced quoting" class), and the
  MtaInboundThrottle description identity. Pure eval, arch-independent
  (the aarch64 shape grew to three checks; all three guard sites
  updated in the same change).
- `stalwart-migrate-e2e` re-registered with the TWO-NODE redesign
  (2026-10-18): the 0.15.5 phase-A node seeds a real store, the store
  travels as a tar through the testers framework's writable `/tmp/shared`
  virtfs dir, and the 0.16 consumer node swaps it in, trips the store
  guard, simulates the poison + `--backup-dir` recovery, and asserts
  the 0.15 password authenticating on 0.16 - no in-VM
  switch-to-configuration ever runs (the 2026-10-17 single-node wedge).
  Six real runs debugged the harness (read-only share, virtfs chown,
  oneshot wait race, python quoting, unrealistic 0.15 listener set);
  subtests 1-6 are green. The then-open post-migration boot bug was
  fixed the next day (see Fixed below; the runs 6-10 transcript chain).
- Guard-tooling batch (2026-10-19, W11): prose-wrap list-marker lint
  (`scripts/check-md-list-markers.sh`, empirically scoped against real
  dprint behavior - the one list-adjacency shape dprint normalizes is
  flagged, stable wrapped/sibling/nested shapes are not), check-set
  drift alarm (`scripts/check-check-set-drift.sh`: numeric check-set
  claims in AGENTS/README fail - counts rot within hours), a README
  completeness step (every live check name must appear in README -
  caught `provision-plan-eval` missing on first run), argless mode +
  indented-fence coverage for the pipes lint, a `nix-health`
  contention-vs-failure bisect in the devShell, and pre-push parity
  for all of it incl. the PINNED statix (the 4x-red W20 class).
  Every new CI step self-tests on planted fixtures first (the
  never-firing-lint-is-a-false-green doctrine).
- `migrate-convert-eval` check (2026-10-19, W10.1): the vendored
  migrate_v016.py's first FUNCTIONAL test - the real `convert`
  subcommand against a minimal 0.15 dump fixture at build time,
  pinning the DataStore descriptor, the Domain/Account/SystemSettings
  plan shape (local-part names, restore-<id> account ids, #id
  references), and the `--patch-paths` rewrite the migration script
  now depends on. Arch-independent; the check set is 10 (all four
  guard sites updated in the same change).
- Test-hygiene decisions (2026-10-19, W10): the host-parse-fixture
  flake app dry-ran end-to-end (`nix run .#host-parse-fixture --
  <fixture> --check parsedmarc-e2e` - note the `--` separator); the
  apps.vm store-closure eval guard is RESOLVED-AS-REDUNDANT (a runtime
  VM smoke proves the closure by construction - boot failure); fixture
  dedup is DECIDED AGAINST (per-test fetchurl pins localize the
  upstream-samples-rot blast radius - a shared fixtures.nix couples
  every bump).
- Refactor-identity proof as a script (2026-10-19, W18.2):
  `scripts/check-refactor-identity.sh` prints outPath +
  registrationTime + narHash per attr; run before/after a refactor and
  diff - identical outPath is the bit-identity proof (the 3-command
  hand-rolled recipe mechanized).
- Demo VM runtime smoke re-verified post disk-relocation (2026-10-19,
  W10.5): HTTP 200 on the forwarded 18080 within seconds of boot, the
  disk lives at `~/.cache/nix-email-demo/demo.qcow2`, and a STALE
  pre-relocation `demo.qcow2` left in the repo root from an old boot
  was trashed (the CWD-pollution class the relocation closed).
- Upstream evidence comment filed on nixpkgs PR #552103 (2026-10-19,
  W12.2, after the verify-before-filing + github-voice gates): the
  restart-after-apply requirement and the virgin-store built-in-8080
  bootstrap fallback, both 0.16.22-VM-proven here
  (docs/drafts/552103-evidence-comment.md; the comment is
  <https://github.com/NixOS/nixpkgs/pull/552103#issuecomment-6258512488>).
- `dmarc-eval` unit-hardening pins (2026-10-19, W9): the pinned
  nixpkgs parsedmarc module's sandbox shape is now DROP-detected at
  eval (DynamicUser, SystemCallFilter, RestrictAddressFamilies -
  additions pass, drops fail loudly naming the dropped key) with a
  build-time negative self-test proving the matcher discriminates.
  IFD cleanup: the strip script and options doc are grepped at BUILD
  time instead of `builtins.readFile`/passAsFile forcing at eval.
- Demo-VM disk relocation (2026-10-18): `apps.vm` pins `NIX_DISK_IMAGE`
  to `~/.cache/nix-email-demo/demo.qcow2` (HOME-unset fallback kept) -
  the demo disk is no longer CWD-relative and can never pollute the
  working tree again (the write-lock footgun now also documented
  accurately in the quickstart).
- `apps.host-parse-fixture` (2026-10-18): the pinned-parser dry-run is
  now a flake app (interpreter supplied, nix CLI from the caller's
  PATH).
- Fail-closed Python lint in CI (2026-10-18, the ruff-red incident
  mechanized): error-class ruff findings shipped to master through three
  gate runs because daemon pushes bypass the pre-push hook and CI had
  NO Python linting at all. New ci.yml step: locked-rev nixpkgs ruff
  over tracked `.py` files, `--select E4,E7,E9,F` (version-drift-proof
  error floor; buildflow keeps owning the deeper PERF/FURB/BLE classes),
  with a negative self-test (an unused import must fail) so the step can
  never silently stop firing.
- 0.16 backup story VM-proven on the pin (2026-10-18): offline `cp -a`
  full copy, `stalwart-cli snapshot` config plans (secrets stripped by
  default; referential closure enforced, cycles via
  `--allow-unresolved`), MAIN-binary `--export/--import` (present on
  0.16.22; import needs a never-started wiped store + the
  `v016-store-migrated` marker touch), and a full restore drill
  (listeners, logins, mail counts, post-restore delivery). Vandelay is
  NOT in the pinned nixpkgs. README go-live backup step rewritten from
  the verified procedure; FEATURES backup row updated; probe
  transcripts + reproducible host scripts under
  `docs/probes/2026-10-18-demo-smoke-backup/`.
- JMAP contract re-verified on 0.16.22 (2026-10-18,
  `docs/INBOXCLEAN.md`): discovery 307→`/jmap/session` unchanged,
  auth identity = synthesized address, EventSource `StateChange` push
  works and now ACCEPTS `closeafter` (0.15.5 rejected it), accountId
  `c`, `urn:stalwart:jmap` + `emailpush` capabilities new, and the
  Junk-filing automation path (`Email/set` mailboxIds move) verified
  end-to-end.
- 0.15 -> 0.16 store migration machinery (2026-10-17, the pbx-artmann
  outage train): the 0.16 binary PANICS (exit 101,
  `migration/lib.rs:95`) on a pre-0.16 store and every attempted boot
  POISONS the settings subspace for 0.15.5 before panicking - a
  restart-looping unit destroys its own recovery path (the sanctioned
  dump runs through a live 0.15.x). Two pieces:
  - Unit guard (`modules/stalwart-module/default.nix`, 0.16 packages
    only): `ExecStartPre` fails with migration instructions when a
    non-empty store lacks `<dataDir>/v016-store-migrated`; virgin
    stores self-mark, pre-guard 0.16 stores self-mark once via the
    printed escape hatch.
  - `stalwart-migrate-from-015` (`modules/stalwart-module/migration.nix`
    + the vendored upstream `migrate_v016.py`): owner-run root script -
    poison preflight, `cp -a` backup, 0.15.x dump probe on a dedicated
    port, dump+convert, recovery-mode 0.16 on port 18080 (never the
    built-in 8080), `stalwart-cli apply` (accounts keep their 0.15 ids
    via `restore-<id>`), marker. `--backup-dir` dumps from a pre-0.16
    copy when the live store is already poisoned and still recovers it.
  - `stalwart-migrate-e2e` check: phase-A 0.15.5 VM with a real
    principal, the 0.16 switch trips the guard (journal instructions,
    zero panics), the poison refusal, the `--backup-dir` migration, and
    the 0.15 password authenticating on 0.16 + restart persistence.
    CORRECTED 2026-10-17 (same-day, before any release): the check is
    UNREGISTERED again - two full local runs proved the in-VM
    switch-to-configuration to the foreign-eval toplevel stops
    backdoor.service and wedges the test driver at the guard subtest.
    The test file stays with the diagnosis + repair shape in its header;
    TODO row "migrate-e2e repair" owns the two-node redesign. The guard,
    the script, and the registration bookkeeping (ci.yml lockstep,
    check-inventory.sh) are unaffected by the unregistration.
- `stalwart-bind-e2e` check (2026-10-17): dedicated non-default `httpBind`
  (`127.0.0.1:8082`, the pbx-artmann shape) against a virgin store - the
  bootstrap class `stalwart-e2e` cannot cover (its bind coincides with the
  built-in 8080, so the deadlock was untestable there by construction).
  Pins the full fallback path: the apply journal names the built-in
  endpoint, the plan's listener set replaces the built-ins (8080 gone,
  8082 + 25 bound), the dedicated bind serves the admin JMAP session, and
  a plain `systemctl restart` restores it without the provision unit
  re-running.
- `demo-eval` check (2026-10-06): pure-eval contract for the demo host
  (`nixosConfigurations.demo`). `nix flake check` already forces the demo
  toplevel (probe-verified), but the demo's human contract - the README
  quickstart QEMU port forwards (18080/2525/2587/2593), the provisioning
  unit's `roles:["user"]`, the fallback-admin login, the pyzor-off
  posture, the absolute-curl provisioning path - could regress while
  still evaluating clean. Negative-tested: a drifted forward port fails
  the check with a named error. x86_64-only (the demo host is); the
  aarch64 check shape is unchanged, CI's lockstep expected-list updated
  in the same change.
- JMAP seam (2026-10-05 execution session): `stalwart-e2e` gains a JMAP
  subtest (session document as a `roles:["user"]` principal, Mailbox
  query/get asserting `inbox`+`junk` roles, the delivered e2e needle
  visible via `Email/query`+`Email/get`; file-based `jq -e` assertions).
  Pin facts verified on the way: `/.well-known/jmap` answers 307 (curl
  needs `-L`), the account id must come from the session's
  `primaryAccounts`, and EventSource push works LIVE (`StateChange` ~5 s
  after a real SMTP delivery; `{closeafter}`/`{ping}` are rejected by
  0.15.5).
- `docs/INBOXCLEAN.md`, the InboxClean integration contract (pinned
  version, endpoint + auth model, capability URNs, label mapping,
  host-rewrite rules, re-verification procedure), plus six probe
  transcripts under `docs/probes/2026-10-05-jmap-demo-vm/` and the README
  JMAP quickstart.
- parsedmarc-e2e breadth: Netease + LinkedIn `.crlf` failure fixtures
  (pinned at the repaired rev `ae1e5adb`) with `arrival_date_utc`
  timezone conversions (+0200/+0800/+0000) and breadth-field assertions
  (CSV >= 4 records).
- `scripts/host-parse-fixture.py`: the host-side parser dry-run
  mechanized to one command (closure walk, pinned-minor PYTHONPATH,
  `parse_report_file(offline=True)`); verified on both pinned fixtures.
- CI hardening: `scripts/check-md-table-pipes.sh` (unescaped-pipe-in-table
  lint with four in-CI self-tests) and a lock-pinned statix CI step;
  `.githooks/pre-push` now mirrors the CI check-inventory guards via
  `scripts/check-inventory.sh`.
- `SECURITY.md` security policy (2026-10-09): supported-versions table,
  private GitHub Security Advisory reporting path, response-commitment
  timeline.
- Vendored Stalwart 0.16 NixOS module (`modules/stalwart-module/`, vendored
  from nixpkgs PR #552103 at rev `9b15e1f`, provenance header + retirement
  trigger in-file): `services.stalwart.provision` applies declarative
  JMAP-object plans via `stalwart-cli apply` with Lua schema typecheck and
  dependency-sorted ops. Two documented vendor patches: `meta.doc` removed
  (anchors need nixpkgs-side redirects.json) and the provision unit restarts
  stalwart via `ExecStartPost` (0.16 reload does not re-bind listener
  sockets - transcript-verified). Plus the wrapper's new `publicUrl` option
  (0.16 renders absolute URLs from it) and `services.stalwart.provision
  .singletons/.objects` merge points for consumer plans.

### Changed

- buildflow local-noise batch (2026-10-19): `interrogate` skipped
  with rationale (procedural probe scripts, minimal devShell is
  deliberate); the stale mypy rationale ("only Python is the
  test-driver template") replaced with the honest accepted-noise
  verdict; `BUILDFLOW_TELEMETRY_DISABLED` opt-out note added
  (verified in the binary env surface). Verified no-ops: jest
  self-skips on missing package.json (a skip_steps entry would
  restate a default), `buildflow timings --regressions` reports
  clean, the nix-hash-fix preflight WARN only fires in the
  self-heal path after a nix-build failure.
- `scripts/vm-debug.sh` - the VM debug-driver dance mechanized
  (2026-10-19): GC root, per-test driver discovery (extracted from the
  check derivation's buildCommand - the `runNixOSTest` output is an
  empty dir, so the old `<output>/bin/nixos-test-driver` recipe never
  matched), starter test-script with the capture/settle/no-manual-provision
  rules baked in. Smoke-verified through driver invocation.
- External-link sweep re-run over the living docs (2026-10-19,
  first full pass since the 0.16 rewrite): 30 unique targets,
  ZERO dead links - the single lychee red is the known private-repo
  404 false positive (`LarsArtmann/InboxClean` exists, PRIVATE).
- Match-property audit CLOSED (2026-10-19): the wrapper option-surface
  review found ZERO dead/no-op options - all 34 `services.mail-server`
  options verified consumed (plan emission, settings, credentials,
  assertions, or warnings; the wrapper is a fresh 0.16 rewrite, so no
  0.15-era carry-overs exist). The snapshot-vs-wrapper Account matchOn
  divergence line was already in the README ledger (VM-proven
  2026-10-18); the dkim-survival e2e subtest it rode on is green in the
  full gate.
- DNS-arrival race module verdict (2026-10-19, W14): the
  provision-vs-resolv.conf race is CLOSED as DOCUMENTED DOCTRINE, not a
  unit reorder - `network-online.target` is a no-op under dhcpcd
  (exactly the late-DNS case), so ordering guarantees nothing; the
  required pattern for late-DNS hosts is the DnsResolver singleton
  (README module section: probe transcript pointer + deliberate
  no-default rationale - DNS policy belongs to the consumer).
- THREAT_MODEL.md 0.16 revisit (2026-10-18): new "0.16 exposure delta"
  section (REST removal shrinks the attack surface; provision-plan
  secrets in the world-readable Nix store GROW it - C44-gated, real
  hosts must not ship passwords in plans until answered; migration
  artifacts and `--include-secrets` snapshots are secrets-on-disk;
  MemoryMax stays C39-gated), the "secrets prevented by construction"
  row split into an honest 0.16 verdict, the spam row re-scored
  ("Scored; filing varies" - filing is not a fixed INBOX rule on 0.16),
  and the catch-all row moved to `Domain.catchAllAddress`.
- AGENTS.md diet (2026-10-18): 451 -> 229 lines (-49%) - every distinct
  concept either compressed in place or pointed at its owning doc
  (README quickstart, archived-README archive policy, flake.nix
  mechanism comments); demo ports, the DNS-race fix, and
  provision-plan-eval refreshed while in there. The last 9 lines vs
  the BuildFlow 220 cap are decision C41's call.
- README status banner corrected (2026-10-18): only the CLI/REST export
  variants died in 0.16 - the MAIN-binary `--export`/`--import` exists
  and is VM-proven (the living 0.15-reference sweep found exactly one
  stale claim; everything else was already era-marked).
- Docs-truth corrections (2026-10-18): the archived 06-58 report's
  "CHANGELOG vs git-log diffed" verdict overstated a subjects-only skim -
  a theme-coverage audit of every non-daemon commit since 2026-10-05 now
  backs the `[Unreleased]` set (no missing major theme; correction
  recorded here per the append-only rule). The 19-23 plan strike-marker
  reconcile is moot (the plan is archived; no living doc restates the
  ~350-markers claim). `.config/metadata.yaml` (a local tool artifact
  the auto-commit daemon had swallowed into history, referenced nowhere)
  is untracked and gitignored.
- **BREAKING - Stalwart 0.15.5 -> 0.16.22** (2026-10-16/17 upgrade; the
  release vehicle is the pending v0.5.0 - SystemNix pins ride tags):
  the wrapper now maps its options onto the 0.16 JMAP object model and
  renders `services.stalwart.provision` plans; `services.stalwart.settings`
  is only the config.json datastore descriptor (everything else lives in
  the datastore as objects). Consumer-visible breaks: REST `/api`
  management recipes are gone (`/api/principal`, `/api/dkim`,
  `/api/reports/dmarc`) - provisioning is declarative plans and the JMAP
  session endpoint moved (`GET /jmap` is 404; `/.well-known/jmap` 307 ->
  `/jmap/session`); offline backup/restore via `--export`/`--import` is
  removed upstream (no replacement shipped yet); the admin account is a
  REQUIRED systemd-credential (`services.mail-server.admin.secretFile`);
  `hostname` now equals the provisioned Domain value and must pass 0.16
  hostname validation (`.invalid` TLDs are rejected - the demo renamed
  `mail.demo.invalid` -> `mail.demo.test`, password `demo` ->
  `demo-nixemail-2026`); durations are integer milliseconds; account
  passwords are zxcvbn-strength-enforced; the `acme.default`-era option
  shape and the throttle key `mx` are gone; firewall/port contract
  unchanged. Full fact set in the README ledger "Stalwart 0.16" section
  and the 2026-10-16/17 status reports (transcript-pinned).
  Upgrade state as of 2026-10-17 03:34: GATE GREEN - `nix flake check`
  passes all checks on the 0.16 tree (stalwart-e2e 17/17 subtests in a
  real run incl. the four never-exercised ones, relay-e2e 3/3, buildflow
  EXIT:0). The 0.15 quota journal signature is DEAD on 0.16
  (transcript-pinned JOURNAL SILENCE, `docs/probes/2026-10-17-quota-
  journal-silence/`): the subtest now asserts SMTP acceptance
  (`250 Message queued with id`), IMAP absence, and a negative journal
  assertion. Remaining: release doctrine (C43), the 0.16 backup-story
  gap, and the consumer pin advance - TODO_LIST owns the queue.

- Docs-health AUDIT pass (2026-10-17): the six 2026-10-16/17 upgrade-corridor
  reports annotated inline (332 dated verdicts via annotate.go status-items;
  check-rows green per file) and ARCHIVED with a manifest; decision-batch
  gained C42-C46 (parsedmarc retire-or-keep, vendored-release doctrine,
  account-secrets, package version, flap tolerance); TODO_LIST rebuilt
  (0.16 release path + the 03-34 harvest: backup-story research,
  MONITORING queue-metric rule, lockstep guard, flood robustness, relay
  bounce-path, e2e polish); README/AGENTS/FEATURES/ROADMAP/INBOXCLEAN/
  MONITORING/TELEMETRY swept to the 0.16 truth (provision model, JMAP
  session move, ledger "Stalwart 0.16" section + 0.15 era markers, demo
  `.test` rename, backup BROKEN status); the pass also repaired the
  dprint re-wrap damage its own first format pass inflicted on the struck
  report tables (rows rebuilt from git blobs + preserved specs; the
  AGENTS formatter rule now mandates per-cell strikes + post-format
  check-rows).
- Docs-health audit pass (2026-09-29) over every `docs/status` and
  `docs/planning` 2026-0* file: the seven unannotated reports plus both
  Pareto plans got inline strikethrough verdicts (~350 new resolution
  markers; per-item evidence cited against commits, CHANGELOG 0.4.0, and
  the living docs), the flake-parts migration report was archived (last
  open item verified pre-existing), unharvested report items were routed
  into TODO_LIST (CI pipe-table lint, pre-push lockstep mirror,
  host-parse-fixture helper, parsedmarc sample breadth, CI statix step,
  v0.4.0 tag smoke, docs freshness audits, parsedmarc unit Restart
  decision), the flake.nix split graduated from ROADMAP to TODO_LIST
  (the ~300-line trigger fired at 356 lines), the stale rateLimits/DNSBL
  ergonomics TODO row was deleted (deliverable landed), the 19-23 plan's
  two false "SystemNix pin bump v0.2.0 -> v0.3.1" claims were corrected
  inline, AGENTS.md gained the red-CI cause-attribution rule and a
  fixture-traps restructure, and FEATURES.md split the Renovate+Dependabot
  row honestly (Dependabot works; the Renovate app was never installed).
- ROADMAP records the decided InboxClean integration direction (2026-09-30:
  JMAP-first per InboxClean ADR-023, this stack is the adapter target).
- Docs-health AUDIT pass (2026-10-05): the 2026-09-30 cross-repo session
  HARVESTed (four JMAP-seam TODO rows - demo-VM probe transcript,
  EventSource/push test, contract doc, e2e subtest; decisions C35-C37
  batched with recommendations; C38 daemon-flush added), all 13 active
  docs/status reports resolved inline (~185 new verdicts plus ~80
  marker-column table rows uniformized cell-wise; 262 strikethrough lines,
  grep-derived) and ARCHIVED under the new archive policy (AGENTS.md
  Documentation map; manifest in docs/status/archived/README.md; the
  signed-tags and PROXY-protocol opens verified resolved - v0.4.0 carries a
  good ED25519 tag signature, the PROXY verdict lives in the README
  ledger), TODO_LIST defects fixed (broken header emphasis, a blank line
  splitting the Low-impact table), and decision-batch reorganized with a
  cross-repo-integration section.
- flake.nix split into `flake-modules/{lock-guards,nixos-modules,demo-vm,
  checks,devshells}.nix` flake-parts modules; flake.nix reduced to inputs
  + eager guards (`nix flake show` surface byte-identical pre/post; both
  eval guards + full `nix flake check` green).
- README runbook step 2 rewritten as a re-verify presence list (nixpkgs
  PR #566282 renames `provision.elasticsearch` to `provision.opensearch`,
  which breaks the `mkDefault` + `ExecStartPre` guard at the first pin
  past it); upstream watch updated (imapclient fix released in 4.1.0;
  mailsuite STARTTLS issue filed upstream as seanthegeek/mailsuite#65;
  the parsedmarc-Restart and Stalwart-Junk asks DROPPED at the verify
  gates with recorded verdicts).
- Docs freshness pass: TELEMETRY webhook/alert caveat binary-verified
  against the pinned 0.15.5; CONTRIBUTING fresh-clone `core.hooksPath`
  caveat + three-VM-test fix; FEATURES stalwart-e2e row; AGENTS
  format-before-archive + sub-bullet strike rules and post-split
  known-noise locations; the three early-archive files repaired to pass
  check-rows (25 cell-wise strikes, one dprint-eaten row restored).
- SystemNix consumption (cross-repo): the nix-email input hard-pinned
  `?ref=v0.4.0` (contract check green against the tag) plus a full-tree
  statix sweep.
- Docs-health AUDIT pass (2026-10-16) over every `docs/status` and
  `docs/planning` 2026-0*/2026-1* file: the four 2026-10-05 session
  reports got 207 inline verdicts (b/c/f/g resolved or routed; a/d/e
  historical by policy) and were ARCHIVED (manifest in
  `docs/status/archived/README.md`), the three planning plans got their
  stale Resolution verdicts corrected inline (C17/C17a push+pin EXECUTED
  2026-10-05, mailsuite FILED, T13 completed upstream) plus archive
  banners and were ARCHIVED (new manifest
  `docs/planning/archived/README.md`; decision-batch reference updated to
  the archived path), the harvest routed ~20 new TODO_LIST rows and
  deleted 19 done/stale ones, decision-batch gained C39 (MemoryMax
  ownership), C40 (v0.5.0 release timing) and C41 (AGENTS ~21 KB floor),
  ROADMAP closed Q6 to its source-verified residue resolution and dropped
  the executed flake-split idea, AGENTS fixed the obsolete "SystemNix
  floats ?ref=master" claim (hard-pinned v0.4.0 since 2026-10-05), gained
  the concurrent-gates rule and the arrival_date_utc fixture-trap class,
  FEATURES corrected the devShell row (actionlint + shellcheck are
  CI-parity members) and the CI row (md-table-pipe lint + statix +
  pre-push inventory mirror), README fixed the same pin-claim drift,
  marked nixpkgs PR #566282 MERGED (2026-10-13, `22579286` - the
  provision.opensearch port procedure is now mandatory at the first pin
  past it) and added the one-VM-per-qcow2 demo write-lock note, and the
  upstream watch row was re-verified (filings all still OPEN,
  #566282 MERGED).
- Upstream-watch re-verification (2026-10-19): the merged #566282 module
  rework removed `provision.elasticsearch` on nixpkgs master but the
  #563651 bug shape PERSISTS - with `provision.opensearch = false` the
  module still materializes a host-less `[opensearch]` section and
  parsedmarc still exits 255 ("hosts setting missing from the opensearch
  config section", cli.py re-verified on parsedmarc master). nixpkgs
  master now ships imapclient 4.1.0 (the #563652 py3.13-pin retirement is
  armed; our pin still 4.0.1), the #563777 module still ships no
  `Restart`, and mailsuite#65 remains unanswered (zero comments). README
  ledger bullets, the dmarc-monitor workaround comment, and the TODO
  watch row updated to the new truth.

### Fixed

- stalwart-bind-e2e red class (2026-10-20): the store-cached `runCommand`
  test cert carried `-days 2` and expired 2026-10-19 (yesterday's green
  gate finished ~13 minutes before expiry); stalwart then silently fell
  back to its rcgen runtime self-signed and the imaps-cert probe failed
  on the served-vs-pinned mismatch (`CN=rcgen self signed cert` vs
  `CN=bind.test`, debug transcript). Now `-days 3650` with the
  load-bearing rationale in-file: nix never rebuilds a cached
  runCommand output, so short validity only ever detonates. vm-debug.sh
  also survives a RED check now - its GC-root build RUNS the test and
  used to abort under `set -e` before the debug script could run.

- VM-test failure-forensics gaps (W18.3/W18.4 residue, 2026-10-20):
  seventeen redirect sites across the five VM tests wrote evidence to
  VM-local files whose only consumer was a `grep -q` - a failing
  assertion lost the artifact. Every capture now dumps to the driver
  transcript on/before its failure path (shell brace-group `cat >&2`
  chains; assertion strength unchanged, no new pipes). The
  dump-on-failure claim itself is fault-injection-proven (vm-debug.sh
  debug run: a failing `stalwart-cli apply` - `unknown object:
  NoSuchObjectType`, exit 1 - still delivered the log dump;
  /tmp/x17-run.log). TODO row removed.

- CI ruff floor red since 2026-10-19 (first red run on master 2026-10-20
  08:46 UTC): F541 `carddav_diag.py:165`, F841 unused `token0` + RUF059
  unused `headers2` in `carddav_probe.py`, SIM115 x2 in the archived
  `gen-repair-spec.py`. The owning CardDAV session landed 2026-10-20
  08:40 without them, so the cross-session hold expired and the four
  floor fixes landed; every push until now failed at the ruff step and
  skipped the lockstep/shape steps downstream. TODO row removed.

- `stalwart-migrate-from-015` post-migration exit-101 panic (2026-10-19,
  migrate-e2e runs 6-10, each root cause transcript-pinned): THREE
  stacked causes. (1) convert's `config.json` DataStore path carried
  the DUMP store - the 0.15 management API serves the probe's EFFECTIVE
  settings, so the probe toml's `store.db.path` (the `--backup-dir`
  COPY) leaked into the converted plan and recovery mode migrated the
  copy while the live store stayed pre-0.16; the script now rewrites
  dump-store paths (`--patch-paths` plus a forced
  DataStore-at-live-store pass, `rewrite-datastore-path.py`). (2) The
  0.15 probe and the 0.16 recovery boot now run as the SERVICE USER
  (setpriv) with ownership normalization before the boot - root-run
  boots litter root-owned RocksDB files (MANIFEST/WAL) that block
  writes mid-apply (jmap 503 serverUnavailable, run 8). (3) Recovery
  mode's one-shot wipe only triggers on a CLEAN pre-0.16 store: a
  poisoned live store skips the wipe, the built-in Role objects are
  never re-seeded, and the apply dies on `x:Account/set` "Role not
  found" (run 9); the script now RESTORES the clean dump copy into the
  live store path before recovery (upstream doctrine - the poison
  refusal says exactly this; the freshest poisoned-live mail survives
  in the `.v015-premigrate` backup). The script also VERIFIES the end
  state before claiming it - stable `stalwart.service` boot (settle
  window + zero restarts) plus the provision apply, `[DONE]` only after
  both, and a failed verification removes the marker so the guard
  refuses further boots. `stalwart-migrate-e2e` GREEN end-to-end (9/9
  subtests, run 10).
- Statix findings in `provision-plan-eval.nix` (2026-10-19, the CI red
  on `b598703`): four assignment-instead-of-inherit warnings and one
  redundant-parentheses finding shipped via daemon pushes past the
  pre-push hook; fixed with CI's exact pinned statix locally (the
  pre-push hook now runs it too).
- Demo VM boot race: provision apply vs resolvconf (2026-10-18, found by
  the fresh host-side runtime smoke the demo contract owed): on a fresh
  boot the 0.16 reload-validation read the not-yet-written
  `/etc/resolv.conf` ("no nameservers found in config"), the apply
  failed at its trailing reload op, and the apply script aborted BEFORE
  its restart step - stalwart stayed on the built-in listener set (no
  587/465) with a failed `stalwart-provision.service`. The demo now pins
  `DnsResolver."@type" = "Cloudflare"` (the e2e pattern); after the fix
  the unit is Result=success and all five listeners bind. The demo
  banner's "unauthenticated inbound lands in Junk Mail" claim was also
  wrong for 0.16 (score-based: both INBOX and Junk landings observed) -
  now says "may land". TODO row tracks the module-level ordering
  question for real late-DNS hosts. Transcripts:
  `docs/probes/2026-10-18-demo-smoke-backup/`.
- Provision bootstrap deadlock on non-default `httpBind` (nix-email#4,
  2026-10-17): 0.16 silently ignores static `server.listener` keys, so a
  virgin store binds only the built-in set (smtp 25 + http 8080) while the
  provision unit's probe waited for the consumer's `httpBind` - a
  self-deadlock for every port other than 8080 (pbx-artmann's
  `127.0.0.1:8082` wedged a real host switch for 43 minutes; a 3-min
  bounded failure since 2026-10-17 morning). The unit now probes `cfg.url`
  and then the built-in `127.0.0.1:8080`, applies against whichever
  answered, restarts stalwart, and VERIFIES `cfg.url` came up - so
  "provisioned listeners never activate" (the apply-succeeded
  reload-validation class) fails the unit loudly instead of passing
  silently. Multi-line unit scripts moved to `writeShellScript` store
  paths: embedded newlines in `ExecStart` are rejected by systemd
  ("Unbalanced quoting ... unit will not be started" - first bind-e2e
  run).
- Docs drift sweep (2026-10-17, post-03-34-report): README's check-set list
  was missing `module-import-eval` and `demo-eval` (the flake exports six
  checks - ci.yml lockstep is the authority); the dmarc-monitor status row
  still said "eval contract-tested" though `parsedmarc-e2e` VM-tests it; the
  demo port table carried a truncated "What it" header; the devShell list
  omitted actionlint + shellcheck. AGENTS.md claimed the quota subtest
  re-pin was "open" (it is re-pinned and green - journal-silence posture)
  and said "web/API" for the 0.16 demo (REST is gone upstream); its
  documentation map gained `docs/MONITORING.md` + CONTRIBUTING.md.
- AGENTS.md accuracy fix + prune (2026-10-17): the check-set restatement
  said "three VM E2E tests" / "SIX defined" while the live set is seven
  (`stalwart-bind-e2e` landed 05:34; `nix eval` attrNames verified) - the
  set is now SINGLE-SOURCED from the ci.yml lockstep / README list instead
  of restated in AGENTS (closing the split brain the 05-37 report's f/8
  flagged); the duplicated Stalwart 0.16 plan-dialect paragraph now points
  at the README ledger; provenance narration (commit hashes, incident
  storytelling with verified homes in README/flake comments/status
  reports) was stripped to standing rules + pointers (31.5 KB -> ~28 KB);
  documentation map gained SECURITY.md and the README canonical check-set
  note. TODO_LIST's gate-noise row updated 6 -> 7 to match.
  FEATURES.md rows (native ingestion, rate limiting, provisioning, relay)
  still described pre-gate-green state and contradicted the gate row in the
  same file - all updated to the 2026-10-17 green-run truth.
- `stalwart-relay-e2e` boot starvation on 0.16: dnsmasq's black-hole
  upstream (192.0.2.1) made the SpamPyzor reload validation fail ("Invalid
  address: failed to lookup address information"), aborting the apply
  before listeners spawned - dnsmasq now forwards upstream to 10.0.2.3
  (the same resolution path as every other node).
- Master CI red x4 (2026-10-16 14:29-22:56): four statix W20 findings
  (repeated attrpath prefixes) shipped via daemon pushes and tripped the
  fail-closed statix step - collapsed into nested attrsets across three
  files (`8f8ced8`), semantic identity proven three ways (pinned-statix
  exit 0, byte-identical eval captures, content-addressed VM output
  identity). HEALED 2026-10-17: the set pushed as `7fda2c0`, runs
  38991468642 + 38994707702 green on master. Follow-up: pinned-statix in
  the pre-push hook (TODO_LIST).
- The standing EXIT:69 gate posture is RETIRED (2026-10-16): the
  home-manager buildflow profile has flipped to a build >= 15ea141d2
  (binary 83db580) and a FULL gate run verified EXIT:0 - the AGENTS
  known-noise caveat is now a history line, and the vulture finding it
  surfaced (unused `REPO` in `scripts/host-parse-fixture.py`) is fixed.
- CI red (run 37281593175): shellcheck findings (SC2016 backtick-printf,
  trap quoting) in the pipe-lint step were invisible to a
  shellcheck-less local machine - fixed via a quoted-delimiter heredoc
  fixture + explicit disable; AGENTS records the gate-parity lesson (run
  `nix run nixpkgs#actionlint` before pushing workflow edits).
- Cross-repo upstream fix: the BuildFlow nix-checker port-collision noise
  class is retired (strings/comments masked before extraction;
  privileged-port <1024 collisions downgraded to warnings, unprivileged
  stay errors - BuildFlow commit 15ea141d2). Verified against this repo
  with a locally built binary (nix-checker step EXIT:0, zero error
  findings); the standing EXIT:69 posture here ends once the
  home-manager profile buildflow flips to a build >= 15ea141d2.

## [0.4.0] - 2026-09-23

### Added

- Wrapper hardening options (M14): `services.mail-server.rateLimits`
  (opt-in sustained inbound limiter, default OFF - v0.15.5 already ships
  two conservative limiters, README ledger (i)) and
  `services.mail-server.spamFilter.dnsbl.servers` (typed DNSBL entries:
  scope enum ip|domain|email|url, zone/tag emitted as quoted expression
  constants; default `{}` = DNSBL inert - no master switch exists upstream,
  README ledger (j)). Eval-time assertions validate throttle keys and
  non-empty zones. RUNTIME EVIDENCE 2026-09-22: stalwart-e2e gains a
  `flood` node whose wrapper limiter (3/1m per remote_ip) is asserted to
  TRIP at runtime (exactly 3 banners + 7 pre-banner hangups + still gated
  after the 1s window - a tripped limiter is connection-gating, ledger
  (m)); DNSBL runtime evidence deliberately stays eval-only until the D1
  live host (verdict recorded in ledger (j)).
- `checks.module-import-eval` on both arches: `nixosSystem` import of the
  full wrapper surface (mail-server + dmarc-monitor in ONE toplevel),
  option-surface contract, M14 default-absence + rendered-shape +
  assertion-trip proofs.
- Eval guards in `flake.nix` (fleet-compat doctrine mechanized):
  nixpkgs-pin equality with the documented fleet pin,
  `flake-parts/nixpkgs-lib` follow presence, and the lock-file sanity
  checks run via `builtins.seq` at output construction.
- TLS-RPT end-to-end: the parsedmarc E2E now sends an inline RFC 8460
  report (`application/tlsrpt+json`) and asserts `smtp_tls.json`/`csv`
  land in the output dir (parser routing verified against parsedmarc
  11.0.1 source, README ledger (h)).
- Forensic/failure end-to-end: the parsedmarc E2E now mails upstream's
  repaired RFC 6591 sample (pinned at `ae1e5adb`, PR #659) and asserts
  `failure.json`/`csv` plus `samples/Subject.eml` land in the output
  dir, including the `smg-policy-action`→`policy` delivery-result
  normalization. The original upstream sample
  (`samples/forensic/subject.eml` at the aggregate fixture's rev) is
  malformed - space-only blank lines fold into headers and defeat
  pinned-11.0.1 payload-walk detection; reproduced host-side against
  the store package before any VM run (AGENTS.md lesson).
- Relay loopback assertion: `relay.address` pointing at
  localhost/127.0.0.1/::1/0.0.0.0 is rejected at eval time (Stalwart's
  SSRF guard would refuse it at first submission).
- `docs/MONITORING.md`: severity taxonomy, 14-row signal inventory,
  coverage matrix, Gatus/dead-man/failed-auth specs, queue-IR levers,
  canary design, threat-model cross-check.
- README "Try it in a VM" section + verified-facts ledger (k)-(n):
  host-side end-to-end smoke of `nix run .#vm` (API 200 via hostfwd,
  catch-all SMTP accept, AUTH submission -> INBOX, IMAPS login+fetch,
  external mail -> Junk with `X-Spam-Status: Yes`), the firewall/hangup
  + systemd-PATH root causes, limiter-trip behavior, and the demo
  spam-filter/ASN-download posture. FEATURES gains the demo-VM row and
  the conditional-firewall correction.
- `docs/planning/decision-batch.md`: every open user decision on one page
  (D1/D2, C24/C29, C18/C19/C20/C22/C34, Q4-Q6, demo-VM g1/g2, C17).
- README verified-facts ledger entries (a)-(j): metrics/tracing keys,
  queue-management API routes, auto-expunge default, absent audit stream,
  autoconfig routes, TLS-RPT consumption, upstream default rate limiters
  (boot.rs DEFAULT_SETTINGS), DNSBL config shape.

### Changed

- statix W20 (repeated keys) fixed in the VM-test node configs (2026-09-16
  session): fully-collapsed `services`/`parsedmarc` attrsets in all four
  flagged nodes - W20 recurses after each collapse, so partial collapses
  were landmines; AGENTS.md policy reversed from deliberate-non-fix to
  always-collapse (all three VM suites force-rebuilt green on fresh
  execution).
- nixpkgs pin advanced `eaad0894` -> `6774f7bc` (fleet lock rev); the
  qemu `enableSharedMemory` workaround is RETIRED - the new pin's
  `qemu-vm.nix` defaults `useVirtiofs = true`, the 9p pairing that made
  shared memory impossible is gone.
- MONITORING row 2 corrected against the transcribed metrics dump:
  0.15.5 exposes NO queue-depth/age gauge - the queue alert spec now
  uses a consumer poll of `GET /api/queue/messages` (§5.4).
- Pin-discipline docs updated to observed reality: SystemNix consumes
  this flake via `?ref=master` (verified 2026-09-22), not a tag pin -
  the runbook/decision docs now say so instead of asserting compliance.
- Docs-audit fixes (2026-09-22): ROADMAP queue-alerting bullets corrected
  to the management-API poll (0.15.5 exposes NO queue Prometheus series -
  transcript-proven), THREAT_MODEL relay-SSRF posture gains the eval-time
  loopback assertion, FEATURES gains the `module-import-eval` row + the
  parsedmarc-e2e TLS-RPT subtest note, TODO_LIST line anchors re-verified
  (`:516-518`->`:529-532`, `:528`->`:542`), the over-quota row swept by
  verdict (README documents it; no wrapper option owed), unrouted
  21-10/22-50 harvest rows routed (M14 runtime evidence, consumer
  ergonomics, failure-report coverage, v0.4.0 tag call, Dependabot
  branch), and `demo.qcow2` untracked (28 MB VM disk image the
  auto-commit daemon had committed five times; `*.qcow2` gitignored).
- Dependabot PR #2 merged (squash, 2026-09-22): flakehub-cache-action
  3.22.3 -> 3.22.5 in the actions group - bump verified against the
  upstream `v3.22.5` tag SHA, all PR checks green incl. the full
  `nix flake check`; the TODO_LIST "first Dependabot PR" row closed by
  the merge.
- dprint md-table alignment pass over the 2026-09-22/23 table edits
  (buildflow full pass). The pass exposed a destructive edge: rows whose
  cells carry literal `|` characters (journal transcripts, grep
  patterns) are re-split at those pipes and the overflow DROPPED - two
  such rows restored from git with GFM `\|` escaping; table cells that
  contain pipes must escape them (`\|`) or dprint will eat the row.

### Fixed

- CI red on master since 2026-09-22 (three runs): the lockstep guard and
  the aarch64 shape guard in ci.yml still expected the pre-M14
  four-check set - `module-import-eval` (added with M14, both arches)
  was never registered in the CI lists. Both expected lists updated and
  verified locally with the exact CI assertions (the local full gate
  does not run these CI-side guards - that is why three pushes shipped
  red unnoticed).
- The 2026-09-17 "lock evaluates outputs" mystery SOLVED: `nix flake
  lock` does NOT evaluate outputs (throw-in-checks repro), but any
  UNDEFINED VARIABLE in flake.nix fails lock as a parse-time scope
  error. Mechanism documented in the flake.nix guard comment.
- Demo-VM hostfwd/API hang (open since 2026-09-17) root-caused and fixed:
  a NON-loopback `httpBind` (`0.0.0.0:8080`) was silently firewalled -
  connections through the port-forward opened and then starved forever
  ("connects but never answers"), while in-guest loopback answered in
  ~1.5 ms and SMTP ports flowed. The module now opens the httpBind port
  exactly when the bind is non-loopback (README ledger (k)).
- Demo-VM provisioning silently no-op'd: the oneshot's bare `curl` is
  "command not found" under systemd's minimal PATH (unit scripts do not
  inherit `environment.systemPackages`), and `|| true` masked it into a
  green unit that provisioned nothing. Now absolute store paths +
  `--max-time`, and the unit FAILS when the API readiness gate exhausts
  (README ledger (l)). Demo re-smoked end-to-end from the host after both
  fixes.

## [0.3.1] - 2026-09-17

### Added

- Docs: AGENTS.md records the flake-parts decisions (floating input +
  lock-pin policy, treefmt/`systems`/git-hooks rejections, reference-first
  migration rule with immediate eval guards); the README Pin-advance
  runbook gained the `flake-parts` dedupe step for the next SystemNix
  bump and the `dovecot2.protocols` expected-noise note

### Changed

- flake.nix migrated to flake-parts (hercules-ci), following the
  nix-international-telephony / SystemNix pattern. Exported surface is
  unchanged - `nixosModules.{default,mail-server,dmarc-monitor}`, the
  four checks (CI lockstep + shape guards hold verbatim), devShells,
  alejandra `nix fmt`. One new input: `flake-parts` with
  `nixpkgs-lib.follows = "nixpkgs"`, so the compat-doctrine nixpkgs rev
  stays the only nixpkgs in the lock. Release-tag consumers are
  unaffected; on the next bump they can dedupe the new input with
  `inputs.nix-email.inputs.flake-parts.follows = "flake-parts"`.

### Fixed

- Nothing yet.

## [0.3.0] - 2026-09-17

### Added

- Local `pre-push` hook (`.githooks/pre-push`, wired via the existing
  `core.hooksPath`) running `nix fmt -- . --check` so an unformatted tree
  fails the push locally instead of going red on master; CONTRIBUTING
  gained a "Formatting gate (pre-push)" section
- `stalwart-e2e`: direct `jq -e '.data.errors | length == 0'` assertion on
  the DKIM dual-sign `/api/reload` response - a re-broken reload now fails
  on the precondition itself, not one step later via "DKIM signer not
  found" (response shape source-verified against stalwart v0.15.5)

- CI pipe-lint step (fail-closed): bans `producer | grep/tail/head`
  assertions inside `tests/*.nix` testScripts - under the test shell's
  pipefail, `grep -q`'s early exit EPIPEs the producer (observed in CI as
  curl exit 23 on a MATCHING payload) and the negated form can
  phantom-green. The gawk 5.x `\b`-is-backspace trap (a never-firing false
  green) was caught by a local negative test and fixed to a character-class
  boundary (`.github/workflows/ci.yml`)
- All remaining piped in-VM curl assertions converted to dump-to-file +
  grep-the-file (the pipe-lint found its own offenders)
- Flake `devShells.default` (alejandra + python3) for `nix develop` and
  tool runners; the `outputs` signature fixed to an open pattern (a closed
  pattern without `self` broke evaluation - Nix always passes `self`)
- `.github/dependabot.yml`: weekly grouped github-actions bumps (Renovate
  keeps the nix side, approval-gated); `.gitignore` python tooling
  artifacts; d2 edge-label rewrap so labels parse as single strings
- README: CI badge, `parsedmarc-e2e` listed in the verified-checks section
  (was missing), POP3 + FTS-offload non-goal notes, and an "External
  upstream issues" ledger block (#563651, #563652 with status)
- CI: tag-push trigger (`on.push.tags: ["v*"]` - releases now run CI) and
  branch protection on master (`nix flake check` required, linear history)
  (`.github/workflows/ci.yml`)
- `parsedmarc-e2e`: POSITIVE TLS-handshake assertion (dovecot journal
  `imap-login: Logged in: ... TLS, session=` line, transcript-derived),
  replacing absence-of-failure checking (`tests/parsedmarc-e2e.nix`)
- Upstream filings (2026-09-16): NixOS/nixpkgs#563777 (parsedmarc unit has
  no Restart policy), mjs/imapclient#662 (`starttls()` assigns read-only
  `IMAP4.file` on Python 3.14; supersedes the earlier "file it" TODOs);
  cross-link comment on nixpkgs#563652; README external-issues ledger
  extended with both
- `stalwart-e2e` DKIM dual-sign subtest: `POST /api/dkim` (Ed25519
  keygen, default id `ed25519-<domain>`), public-key readout shape
  asserted, then one submission carrying BOTH `a=rsa-sha256` and
  `a=ed25519-sha256` DKIM-Signature headers (declarative rsa block +
  API-created ed25519 key) (`tests/stalwart-e2e.nix`)
- dmarc-eval contract extensions: `settings.general.offline` passthrough
  grep and `pkgs.nixosOptionsDoc` rendering assertions
  (`dmarc-monitor`/`RETENTION`/`parsedmarc.ini` survive option-docs
  rendering) (`tests/dmarc-eval.nix`)
- CI actionlint step (`nix run nixpkgs#actionlint` after the YAML parse;
  registry pin deliberate) (`.github/workflows/ci.yml`)
- README: "Per-account semantics" section (quota = integer bytes on the
  principal, accepted-at-SMTP/retried-forever; catch-all `"@domain"`
  literal disables strict 5xx rejection and cannot coexist with it;
  negative-cache ordering) and the nixos-mailserver thin-wrapper lessons
  note; CONTRIBUTING: d2 `--layout=elk` SVG regen command
- mailsuite auto-STARTTLS opt-out issue draft, all 5
  verify-before-filing gates passed (no knob on master - `imap.py`
  byte-identical to 2.3.1; parsedmarc#534 is the same trap); filing
  user-gated (`docs/planning/mailsuite-starttls-issue-draft.md`)

### Changed

- Refreshed the committed `current` architecture SVG after a full
  label-level d2↔SVG re-diff (50/50 text nodes identical; the byte drift
  was elk-geometry only from d2 version churn)
- docs-health AUDIT (2026-09-16): all 21 `2026-0*` historical snapshots
  annotated inline (done-at hashes / verified-evidence / won't-implement
  verdicts) and archived under `docs/{status,planning,reviews}/archived/`;
  every open item re-verified against the tree and harvested into
  TODO_LIST/ROADMAP; TODO_LIST rebuilt from the harvest
- README verified-facts ledger: five new source/binary-verified traps
  (Stalwart TOML quoted-dotted-header rejection; mailpit freeform dashed
  flag names + `smtp-auth-allow-insecure` for plaintext auth;
  `eval-config.nix` vs `nixos/default.nix` import contract; swaks
  `--attach` @-prefix for real file attachments; incoming
  `/api/reports/dmarc` vs outbound `/api/queue/reports` endpoints)
- Release notes v0.1.0/v0.2.0 pinned with the exact nixpkgs lock
  `rev`/`narHash` both releases shipped with (GitHub releases, 2026-09-16)
- Renovate verdict: the app NEVER ran on this repo (no
  Dependency-Dashboard issue, zero branches/PRs); install-or-drop is a
  user decision, TODO_LIST row converted to user-blocked (2026-09-16)
- AGENTS.md: host-spike DEAD END note (replaces the stale "much faster
  than the VM" claim), swaks python-sink forensics recipe, `rg -rn`
  footgun, and the local GC-root debug recipe
  (`nix build -o /tmp/st-e2e-root .#checks...stalwart-e2e`; CI-side
  gc-roots pointless - CI keeps check paths alive for the log window)
- docs-health AUDIT, second pass (2026-09-16 evening): the seven
  2026-09-16 status reports annotated inline (per-item done /
  won't-implement / routed verdicts citing commits and evidence) and
  archived under `docs/status/archived/` - `docs/status/` now holds only
  the archive. Every open item re-verified against the tree
  (PR #1 MERGED 16:08 UTC; CI green on HEAD; `data.errors` assertion
  confirmed still absent; dmarc-eval assertions confirmed present) and
  harvested: TODO_LIST rebuilt to 17 open rows (0.3.0 release now
  UNBLOCKED, reload-precondition assertion, pre-push fmt hook,
  branch-protection policy decision, SystemNix row extended with cache
  hygiene, a 3-row Low hygiene tier), README gained a "Development"
  section (devShell, gate hierarchy, no-pipes rule) plus the #563652
  dotlambda/#663 watch note, ROADMAP pruned of shipped items (CI,
  formatter, upstream filings, aarch64 decision) and extended (reload
  -smoke ops idea, treefmt-vs-alejandra tradeoff, aarch64 `--all-systems`
  residue), FEATURES `dmarc-eval` row now carries the offline +
  option-docs assertions, and the AGENTS deadnix wording was corrected
  (report-only default; BuildFlow's auto-fix is the removal path)

### Fixed

- `stalwart-relay-e2e` green (was eval-broken, never CI-red): null-relay
  config eval now uses `nixos/lib/eval-config.nix` (the pinned nixpkgs'
  `import "${pkgs.path}/nixos"` rejects a `modules` argument), the
  eval-forcing log line targets the smtp node (two-node test has no
  `machine`), and the relay-side Mailpit gets a plaintext SMTP auth file
  with dashed freeform flags (`tests/stalwart-relay-e2e.nix`)
- `stalwart-e2e` native-ingestion subtest green: `report.analysis`
  settings nest as real attrs (dotted-string keys render a quoted TOML
  header Stalwart rejects), swaks attaches the DMARC sample with the
  @-prefix, and the store poll reads `/api/reports/dmarc` (incoming
  reports) instead of `/api/queue/reports` (the outbound queue - same
  response shape, permanently `total:0`; items are `<id>_<expires>`
  strings) (`tests/stalwart-e2e.nix`)
- `stalwart-e2e` DKIM dual-sign leg red→green: `POST /api/dkim` writes
  `signature.<id>.*` store-only (`config.set` does no broadcast/rebuild),
  and `GET /api/reload` silently no-ops without swapping the core while
  ANY config error exists - the DNS-less VM's pyzor build error pinned
  that. Fix: test-side `spam-filter.pyzor.enable = false` (pyzor was never
  functional without DNS) + explicit `/api/reload` before submission;
  journal-hygiene count 2→1 accordingly (both traps source-verified
  2026-09-16, ledgered) (`tests/stalwart-e2e.nix`)

## [0.2.0] - 2026-09-15

### Added

- `services.mail-server.relay` option: outbound smarthost relaying via
  verified `queue.route.<id>` + `queue.strategy.route` generation (v0.15.5
  source-verified key set, IfBlock indexed-key shape, eval assertions for
  IP-literal and half-configured auth), `modules/mail-server.nix`
- `stalwart-relay-e2e` two-node VM test: Stalwart + Mailpit smarthost -
  non-local submission transits the relay, local routing never leaks to it,
  relay hostname resolved via dnsmasq (Stalwart's resolver ignores
  /etc/hosts) (`tests/stalwart-relay-e2e.nix`)
- `metrics.enable` wrapper option wiring `metrics.prometheus.*`, with a
  `/metrics/prometheus` format assertion in the E2E
- `directoryCacheTtlNegative` wrapper option
  (`directory."internal".cache.ttl.negative`)
- `certificate` option tier (`self-signed | acme | manual`) with
  completeness assertions and ignore-warnings; manual mode registers the
  cert as the SNI catch-all via `certificate.<id>.default` (v0.15.5
  source-verified)
- NixOS warning when `httpBind` is non-loopback (README listener doctrine)
- `stalwart-e2e` subtests: DKIM signing (declarative `signature.<id>`,
  header asserted on the stored message), journal hygiene (exactly the 2
  known-benign config-build errors), restart persistence, offline
  backup/restore drill (`--export` → wipe → `--import`)
- `dmarc-eval`: parsedmarc >= 11 version floor guard and forced rendering of
  the real unit config (the ini generation with secret replacement is now
  actually exercised); `StateDirectory` wiring asserted
- CI: `.github/workflows/ci.yml` - fail-closed `nix flake check` with an
  expected-checks guard (asserts every check exists before the gate runs)
- `CONTRIBUTING.md` (verified-facts ledger rules), `docs/THREAT_MODEL.md`
  (loopback-guard boundaries, admin exposure policy, secret inventory),
  `renovate.json` (nix manager, approval-gated, SystemNix pairing note),
  `git-town.toml`
- `nix fmt` support: flake `formatter` output (alejandra) + one full
  formatting pass over all `.nix` files
- GitHub repo topics (mail, nixos, nixos-module, stalwart, dmarc,
  email-server, nix-flake)
- `stalwart-e2e` delivery-behavior subtests: alias (second `emails` entry)
  and catch-all delivery, over-quota message accepted at SMTP but never
  delivered, GTUBE spam detection (X-Spam-Status tagging; v0.15.5 files NO
  Junk folder by default - ledger entry), and the
  negative-cache poisoning + low-TTL recovery regression pair
  (`directoryCacheTtlNegative = 5` in the test)
- `parsedmarc-e2e` VM test fixes for the Dovecot 2.4 pin: explicit
  `dovecot_config_version`/`dovecot_storage_version` (nixpkgs localMail
  omits them), the renamed `dovecot.service` unit (was `dovecot2.service`),
  a plaintext dovecot fixture (mailsuite auto-activates advertised
  STARTTLS; no cert material in the VM - WRONG_VERSION_NUMBER), and
  corrected sample-report assertions (parsed org_name is "XYZ
  Corporation"; `jq -e` without slurp)
- `LICENSE` (MIT); `docs/THREAT_MODEL.md` extended with the attacker-scenario
  table and the out-of-scope/consumer-responsibilities list
- `stalwart-e2e` over-quota subtest asserts the queue's retry in the journal
  (`Message rescheduled for delivery`, the observed signature - the
  code-level reason `Mailbox over quota.` at `delivery.rs:225` is NOT logged
  at default verbosity; the first attempt to assert it failed the gate and
  the transcript fixed it)
- `parsedmarc-e2e` asserts the runtime ini is provably free of the inert
  `[elasticsearch]` section (parsedmarc merely starting was necessary but not
  sufficient evidence), and the aggregate-report wait tightened 300 s → 120 s
  (a healthy parse takes ~9 s)
- `dmarc-eval` asserts `ExecStartPre` ORDER - the module's ini-writing step
  plus the wrapper's strip script (>= 2 entries, strip last) - so `lib.last`
  remains a real ordering proof rather than a string's last character
- CI asserts the aarch64 check-set SHAPE (`attrNames`, genuinely
  arch-independent - forcing the outPath needs to BUILD the aarch64 strip
  script, which fails without emulation, as the first CI run proved); the
  deep aarch64 build of `dmarc-eval` was verified green locally with
  emulation, so the aarch64 posture is no longer documentation-only. CI also
  gained fail-closed action-SHA validation by fire: the workflow's pinned
  action SHAs never existed (one digit off on checkout v4.2.2) and were
  repinned from the real tag refs after the first-ever run failed at Set up
  job
- `docs/THREAT_MODEL.md` gained the catch-all enumeration-tradeoff row;
  AGENTS.md gained a working-rules section (mechanical gate pattern,
  identifier extraction, root-file existence check)
- CI enforces alejandra formatting (`nix fmt -- . --check`, fail-closed) -
  the gate previously parsed Nix but let style drift ship; a pre-existing
  `(sendEmail)` paren slip in `tests/parsedmarc-e2e.nix` was the proof it
  could. NOTE: bare `nix fmt` dies on alejandra 4.0.0 (stdin mode) - the
  invocation is `nix fmt .` (AGENTS documents it)
- Verified-facts ledger: the 0.15.5 sieve/Junk-filing architecture entry
  (settings scripts cannot `fileinto`; delivery runs only the per-account
  active script from the store) - source-verified while implementing the
  wrapper-owned Junk filing the user had chosen; the finding overturned the
  settings-based plan and the decision is re-posed in ROADMAP open question 6
- License CONFIRMED as MIT by the user (2026-09-15, after an intermediate
  rejection); `LICENSE` stands as shipped
- `parsedmarc-e2e` TLS node: the production-shaped IMAPS collection path
  (port 993, `ssl=True`, mailsuite DEFAULT certificate verification via
  `create_default_context` against a machine-trusted self-signed fixture
  CA with proper SANs - not a skip-verification shortcut); the ini shape
  (`ssl=True`, `port=993`, no `skip_certificate_verification`) is asserted
  and the report round-trips over the TLS path (`tests/parsedmarc-e2e.nix`)
- `parsedmarc-e2e` CSV sink row-count assertion (header + >= 1 data row)
  instead of bare `test -s`
- `stalwart-e2e` over-quota subtest now proves the RETRY LOOP (a SECOND
  `Message rescheduled for delivery` line, observed ~120 s after the
  first), not a one-off requeue; the two RCPT probes' resolver-timeout
  cost is measured per run (~65 s each) so the runtime budget is
  documented, not assumed
- CI: strict lockstep guard - the flake's declared check set and CI's
  expected-checks list must match EXACTLY (a vanished check AND an
  unregistered new check both fail the gate); local negative-test proof
  recorded
- `tests/fixtures/debug-template.py`: the proven VM debug-loop script
  pattern (per-listener port waits, provision-before-SMTP, file-based
  greps, journal dump) preserved in-tree
- README: "Pin-advance runbook" (both-locks-together bump procedure +
  workaround-retirement re-check checklist: imapclient py3.14 starttls,
  host-less `[elasticsearch]` emission, 0.15.5 key-set re-verification),
  cross-linked from the module comments; SystemNix wrapper pointer in the
  go-live runbook; pin-discipline rationale (hard rev vs `?ref=master`);
  capability-audit ledger entry (v0.15.5 git-tag source grep: DKIM
  rotation/automated DNS are 0.16-only; native report ingestion, OIDC,
  TOTP, encryption-at-rest, autoconfig, POP3, JMAP-WS present; PROXY
  protocol absent) with verdicts in the Pareto plan §10

### Changed

- aarch64 posture: one emulated `stalwart-e2e` run attempted (qemu
  binfmt + TCG) - the aarch64 guest builds and boots, but boot alone
  (~6 min) exceeds the test driver's shell-connect timeout and a full
  E2E would run over an hour; decision documented in the flake trap
  comment: manual-only, not CI-worthy
- parsedmarc wrapper now sets `StateDirectory` + `ReadWritePaths`: the
  nixpkgs unit runs as a DynamicUser with no writable state, so the default
  `/var/lib/parsedmarc/reports` output could never have worked (found by
  forcing the unit; parsedmarc 11.0.1 makedirs()es the output dir as the
  dynamic user) - `modules/dmarc-monitor.nix`

### Fixed

- The two diagnosed nixpkgs bugs are now filed upstream and linked from
  the README ledger entries: NixOS/nixpkgs#563651 (host-less
  `[elasticsearch]` section with `provision.elasticsearch = false`) and
  NixOS/nixpkgs#563652 (imapclient 4.0.1 `starttls()` assigns the
  read-only `imaplib.IMAP4.file` on python 3.14)
- parsedmarc dies at its first IMAP connect on this nixpkgs pin
  (imapclient 3.1.0 assigns `imaplib.IMAP4.file`, read-only since python
  3.14; AttributeError, exit 255). The wrapper pins the unit's binary to
  the same parsedmarc 11.0.1 built on python 3.13 (same rev, same
  contract); `dmarc-eval` asserts the pin (README ledger entry;
  upstream-able)
- parsedmarc unit fails to start with parsedmarc 11 ("hosts setting
  missing from the elasticsearch config section"): nixpkgs' module
  materializes a host-less `[elasticsearch]` section (cert_path + ssl
  survive the empty filter) even with `provision.elasticsearch = false`.
  The wrapper now strips that section from the rendered ini (guarded:
  only while ES is off), and `dmarc-eval` asserts the workaround
  (README ledger entry; upstream-able)
- `dmarc-eval` encoded the wrong `_secret` contract: the nixpkgs ini
  generator requires an absolute path STRING (`isString` gate) and throws on
  path values - a real host unit would have failed to build its config. The
  ledger entry was corrected accordingly (README)
- Relay E2E transcript assertion now accepts the observed `<~*` swaks marker
  (550 RCPT refusal arrives with the timeout-receive variant, not `<-` /
  `<**`); lesson recorded in the README ledger
- The over-quota citation was corrected to `delivery.rs:225` (the quoted
  reason line) in the README ledger and the test comments - the earlier
  `:223` pointed one statement short of the string it claimed

## [0.1.0] - 2026-09-14

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
