# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
