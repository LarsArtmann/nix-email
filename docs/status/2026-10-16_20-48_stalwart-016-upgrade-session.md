# Status Report: Stalwart 0.16 Upgrade Session (0.15.5 -> 0.16.22)

- **Date:** 2026-10-16 20:48 CEST
- **Session:** vendored nixpkgs PR #552103 module + full wrapper/test rework onto the
  0.16 JMAP-provision object model
- **HEAD at writing:** ca12af6 (auto-commit daemon active mid-session)
- **Verdict in one line:** the 0.16 object-model port is WRITTEN and eval-green;
  live-VM debugging root-caused four upstream/0.16.22 blockers (two fixed,
  two patched in the vendored module) but the repo is NOT green yet - relay-e2e
  needs a rerun with the fixes, stalwart-e2e has never run, docs are stale.

## a) FULLY DONE

1. **Upstream research** - PR #552103 (nixos/stalwart 0.16+ module) analyzed at
   rev 9b15e1f: module files downloaded, provision mechanism (stalwart-cli
   apply + Lua schema typecheck/topo-sort) understood, UPGRADING/v0.16.md read.
   Evidence: files in /tmp/pr552103, greps in session log.
2. **Pin verification** - nixpkgs 6774f7bc has `stalwart_0_16` 0.16.22 +
   `stalwart-cli` 1.0.12 (>= 1.0.2 requirement) + the OLD 0.15 module; no
   nixpkgs bump needed. Evidence: `nix eval` version outputs.
3. **0.16 object schema extracted** - schema.json + source tarball of 0.16.22
   unpacked; exact field shapes/enum names for every object the wrapper emits
   (NetworkListener, Domain, Account/User, DkimSignature variants, MtaRoute
   Relay, MtaInboundThrottle, SpamDnsblServer variants, ReportSettings,
   Cache, Metrics, SystemSettings, AcmeProvider, Certificate, Expression,
   SecretText/SecretKey variants, duration = integer ms). Evidence:
   /tmp/schema-0.16.22.json + crates greps.
4. **Vendored module** - `modules/stalwart-module/` (default.nix,
   provision.nix, provision-check-sort.lua, stalwart.md) at PR rev with
   provenance headers + TWO documented vendor patches: (a) `meta.doc` removed
   (anchors need nixpkgs-side redirects.json -> manual build failed without
   the patch), (b) provision unit: `partOf` dropped + `ExecStartPost`
   try-restart stalwart (listener sockets do not re-spawn on reload,
   transcript-verified). Evidence: nixos-manual build green after (a);
   guest `ss` before/after restart for (b).
5. **Wrapper rework** - `modules/mail-server.nix` fully remapped onto 0.16:
   settings = config.json datastore descriptor; wrapper options render into
   `services.stalwart.provision` plans (5 listeners incl. kept 587 STARTTLS,
   wrapper Domain `#domain`, SystemSettings w/ required defaultDomainId,
   Cache ms, Metrics, MtaInboundThrottle with key translation + ms rate,
   SpamDnsblServer variants, MtaRoute Relay + MtaOutboundStrategy
   expression, AcmeProvider, Certificate File-secrets); admin (fallback) via
   systemd-creds required; new publicUrl option; firewall contract
   unchanged; disabledModules swap of nixpkgs 0.15 module.
   Evidence: eval smoke green; Lua plan typecheck green for default AND
   rich (relay+throttle+dnsbl+metrics+cache) configs.
6. **Demo VM rework** - `flake-modules/demo-vm.nix`: curl-provision oneshot
   DELETED, declarative plan (demo + catchall accounts, Domain.catchAllAddress,
   SpamPyzor off), admin secret via /etc/demo-admin-secret credential,
   banner updated; domain renamed `mail.demo.invalid` -> `mail.demo.test`
   (0.16 hostname validation REJECTS `.invalid` - guest transcript
   "Invalid hostname or IP address ... defaultHostname"). VM closure builds.
7. **Eval contract tests rewritten + GREEN** - `tests/module-import-eval.nix`
   (vendored-module-active check, plan absence/hardening postures, ms throttle
   rate, quoted DNSBL expressions, bad-key + empty-zone trips),
   `tests/demo-eval.nix` (0.16 accounts, stalwart-cli apply unit, credential
   file, catch-all, pyzor off), `tests/dmarc-eval.nix` untouched-still-green.
   Evidence: `nix build .#checks.x86_64-linux.{demo-eval,module-import-eval,dmarc-eval}`
   exit 0.
8. **flake.nix pin comment** updated to the 0.16/vendored-module reality.
9. **Live debug loop** - AGENTS.md FIFO-console pattern used on the demo VM to
   root-cause all four runtime blockers with in-guest transcripts; the
   broken-default-DNSBL workaround was VERIFIED LIVE in the guest (reconcile
   destroyed 18 rows, next apply's reload passed, restart bound 587).

## b) PARTIALLY DONE

1. **relay-e2e** - node config + eval asserts reworked (0.16 route shapes,
   declarative sender account, SpamPyzor off). Works: plan typecheck green,
   apply reached "Done ... 0 failed" by run 3. Open: still RED overall - last
   run failed `wait_for_open_port(587)` BEFORE the DNSBL-reconcile +
   ExecStartPost-restart fixes existed; the fixes are in-tree UNVERIFIED by a
   rerun. Effort to finish: S (one VM run + triage).
2. **stalwart-e2e** - fully rewritten (declarative accounts incl. quota +
   alias, DUAL declarative DKIM rsa+ed25519, ReportSettings singleton,
   /jmap auth probes replacing /api/principal, runtime catch-all via a
   second `stalwart-cli apply`, REST-only subtests dropped: negative-cache,
   webadmin keygen -> declarative dual-sign, backup/restore removed
   [0.16 has no --export/--import]). Open: ZERO VM runs in 0.16 form;
   journal assertions (config-error count, reschedule wording), metrics
   path/format, GTUBE header, flood-limiter gating, DkimSignature
   publicKey acceptance are all unverified. Effort: M (1-3 VM iterations).
3. **Wrapper DNSBL default-rows fix** - root cause proven live (18 shipped
   SpamDnsblServer rows carry `bit_and` tag expressions that fail 0.16.22
   reload validation, silently killing the core swap); live-verified fix
   (empty reconcile set). Open: the wrapper does NOT yet ALWAYS emit that
   set (currently only when consumers configure servers) - one edit away.
   Effort: S.
4. **Docs phase** - NOT STARTED except flake.nix comment. README quickstart
   still prints the dead domain (`demo.invalid`) + old password (`demo`);
   README ledger's REST-API recipes and --export/--import backup facts are
   now WRONG for 0.16; AGENTS.md/CHANGELOG/FEATURES/TODO_LIST need the 0.16
   doctrine. Effort: M.

## c) NOT STARTED

1. **Full `nix flake check`** - blocked on relay/stalwart-e2e going green
   (failed results are CACHED; a red check replays until inputs change).
2. **buildflow gate + `nix fmt -- . --check`** - after tests green.
3. **README/AGENTS/CHANGELOG/FEATURES/TODO_LIST 0.16 sweep** - see b4.
4. **Upstream reporting** - two candidate reports (reload does not spawn
   listeners on 0.16.22; shipped default DNSBL rows fail reload validation)
   must first be checked against 0.16.26 (master) via verify-before-filing.
5. **Consumer coordination** - SystemNix pins this flake at v0.4.0; this is a
   BREAKING wrapper release (settings->provision, REST gone, demo domain
   rename, acme.default option removed, throttle key "mx" removed). Needs a
   release decision + pin-advance run.
6. **0.16.26 consideration** - master packages 0.16.26; if the two 0.16.22
   bugs are fixed there, a version overlay (or early nixpkgs bump) beats
   carrying the ExecStartPost vendor patch.
7. **Host-side demo smoke + probe transcripts** - `nix run .#vm` host probes
   and docs/probes/ manifest update for 0.16 (INBOXCLEAN re-verification).

## d) TOTALLY FUCKED UP

1. **Repo head is not releasable** - relay-e2e RED (fixes unverified),
   stalwart-e2e never run, full gate not run. Severity: blocks everything.
   Mitigation: in flight (b1-b3).
2. **README verified-facts ledger is now actively wrong for 0.16** - REST
   /api/principal recipes, export/import backup procedure, `demo` password,
   `mail.demo.invalid` quickstart all describe a dead world. Severity:
   misleads any consumer upgrading now. Mitigation: docs phase (b4), gated
   on green tests.
3. **0.16.22 shipped-broken defaults** - 18 default SpamDnsblServer rows
   (e.g. id jjzu732sbpqa) carry tag expressions 0.16.22's own parser rejects
   ("Invalid variable or constant \"bit_and\""), which fails EVERY reload
   validation and silently prevents provisioned config from activating.
   Severity: breaks any fresh 0.16.22 deployment that provisions via apply
   with reloadSettings=true (i.e. the vendored module's default posture).
   Mitigation: wrapper will always reconcile the set empty (b3); report
   upstream after checking 0.16.26.
4. **Session self-inflicted:** (a) I retyped the test RSA key from memory
   into a draft and corrupted it - caught, draft deleted, rule "extract
   identifiers mechanically" re-learned; (b) two wrapper edits failed
   stale-read because the auto-commit daemon reformatted mid-session;
   (c) two relay-e2e VM runs were burned BEFORE starting the FIFO debug VM -
   the debug loop should have been step one. No data loss anywhere.

## e) WHAT WE SHOULD IMPROVE

1. **Debug-VM-first triage** - on ANY VM-test failure, boot the demo/test VM
   with the FIFO console BEFORE rerunning the expensive test. Cost of not
   doing it this session: ~15 min of blind rebuilds. Candidate: a skill note
   in AGENTS.md (working rules), which is planned anyway.
2. **Fast plan typecheck surface** - the Lua provision typecheck only runs
   when forcing the unit/VM closure; IFD via readFile lost path context.
   Exposing the sorted plan as a flake check (or `.#packages.provision-plan`)
   would give a ~10 s "did my plan break the schema" signal instead of a
   full VM build. Concrete: add `checks.provision-plan-eval` in
   flake-modules/checks.nix (needs ci.yml lockstep list update too).
3. **Batch-then-test** - fix ALL transcript-known issues before the next VM
   run (one run validates many fixes; each run costs minutes).
4. **Test-secret dedup** - `testPass` is duplicated in stalwart-e2e and
   relay-e2e (split brain waiting to drift). Extract to a shared
   tests/lib.nix when touching tests next.
5. **Vendor-patch bookkeeping** - the two patches live as comments in
   vendored files; a single "VENDOR PATCHES vs PR #552103" README section
   (with upstream-filed status) prevents them rotting silently.
6. **Secret-in-store story for account passwords** - 0.16 plans carry
   account passwords in world-readable store paths (0.15 used sha512-crypt
   strings, equally public but hash-only). Real hosts need a blessed
   pattern (runtime apply from sops-rendered file vs admin-created
   accounts) - needs user doctrine, see (g).

## f) TOP 50 NEXT TASKS (ranked by impact; HARVEST fodder for docs-health)

| #  | Task                                                                                                                                                     | Impact   | Effort | Category      |
| -- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------ | ------------- |
| 1  | Wrapper: ALWAYS emit SpamDnsblServer reconcile set (empty ok) to destroy broken default rows                                                             | Critical | S      | Bug           |
| 2  | Re-run stalwart-relay-e2e until green with the two landed fixes                                                                                          | Critical | S-M    | Bug           |
| 3  | First stalwart-e2e VM run; triage every transcript surprise                                                                                              | Critical | M      | Bug           |
| 4  | If apply rejects DkimSignature without publicKey, emit derived pubkeys or drop to single-sign                                                            | Critical | S      | Bug           |
| 5  | Fix journal assertions from transcript (config-error count, quota reschedule wording)                                                                    | High     | S      | Bug           |
| 6  | Full `nix flake check` green (redirect + echo-exit procedure)                                                                                            | Critical | M      | Quality       |
| 7  | `nix fmt -- . --check` before yielding (daemon race discipline)                                                                                          | High     | S      | Quality       |
| 8  | Run buildflow gate                                                                                                                                       | High     | S      | Quality       |
| 9  | Verify ci.yml lockstep lists still match (no checks added/removed - confirm mechanically)                                                                | High     | S      | Quality       |
| 10 | README quickstart: demo.test domain + demo-nixemail-2026 password + stalwart-provision wording                                                           | High     | S      | Documentation |
| 11 | README ledger: 0.16 facts (REST gone, export/import gone, .invalid rejected, ms durations, zxcvbn passwords, reload-listener caveat, DNSBL default rows) | High     | M      | Documentation |
| 12 | README pin-advance note: breaking v0.5.0, SystemNix coordination                                                                                         | High     | S      | Documentation |
| 13 | AGENTS.md: 0.16 doctrine, vendored-module retirement plan, FIFO-debug-first lesson, new traps                                                            | High     | M      | Documentation |
| 14 | CHANGELOG entry for the 0.16 breaking upgrade                                                                                                            | High     | S      | Documentation |
| 15 | FEATURES.md status flips (0.16, declarative provisioning, dropped backup flags)                                                                          | High     | S      | Documentation |
| 16 | TODO_LIST.md refresh post-gate                                                                                                                           | Medium   | S      | Documentation |
| 17 | INBOXCLEAN.md: flag JMAP contract for 0.16 re-verification (history stays historical)                                                                    | High     | S      | Documentation |
| 18 | Check 0.16.26 (master) for the two 0.16.22 bugs; if fixed, overlay/bump version                                                                          | High     | M      | Bug           |
| 19 | Upstream reports (reload-listener gap; broken default DNSBL rows) via verify-before-filing                                                               | Medium   | M      | Quality       |
| 20 | Host-side demo smoke (`nix run .#vm` + probes) once tests green                                                                                          | High     | M      | Quality       |
| 21 | docs/probes/ 0.16 manifest for debug transcripts                                                                                                         | Medium   | S      | Documentation |
| 22 | Account-secrets pattern for real hosts (sops-rendered runtime apply vs admin-created)                                                                    | High     | M      | Feature       |
| 23 | Expose provision plan as a fast check (provision-plan-eval + ci.yml lists)                                                                               | Medium   | S      | Quality       |
| 24 | Confirm /metrics/prometheus path/format on 0.16 from transcript; fix docs/MONITORING.md                                                                  | High     | S      | Bug           |
| 25 | Confirm GTUBE X-Spam-Status behavior on 0.16 (e2e subtest 15)                                                                                            | High     | S      | Bug           |
| 26 | Confirm over-quota retry loop + journal wording on 0.16 (subtest 14)                                                                                     | High     | S      | Bug           |
| 27 | Confirm inbound-limiter connection gating on 0.16 (flood subtest 19)                                                                                     | High     | S      | Bug           |
| 28 | Confirm EmailAlias delivery + catch-all runtime apply patch (subtests 12-13)                                                                             | High     | S      | Bug           |
| 29 | Re-verify JMAP session/mailbox shape for INBOXCLEAN contract on 0.16                                                                                     | High     | M      | Quality       |
| 30 | Dedup testPass constants into tests/lib.nix                                                                                                              | Low      | S      | Cleanup       |
| 31 | Clean repo-root result symlinks from ad-hoc builds                                                                                                       | Low      | S      | Cleanup       |
| 32 | Kill stale /tmp debug VMs + GC-root hygiene                                                                                                              | Low      | S      | Cleanup       |
| 33 | Document vendor patches vs PR #552103 in one README section                                                                                              | Medium   | S      | Documentation |
| 34 | VENDOR retirement checklist when PR merges (restore meta.doc + partOf, drop ExecStartPost)                                                               | Medium   | S      | Documentation |
| 35 | Mechanize stalwart-cli >= 1.0.2 assertion (eval-time version check)                                                                                      | Low      | S      | Quality       |
| 36 | Document password-strength (zxcvbn) requirement for consumer provisioning                                                                                | Medium   | S      | Documentation |
| 37 | Sweep docs for /api/principal references; mark 0.15-historical                                                                                           | Medium   | S      | Documentation |
| 38 | docs/TELEMETRY.md: retire 0.15 version-skew caveat or re-verify keys on 0.16                                                                             | Medium   | S      | Documentation |
| 39 | ROADMAP D1/D2 notes: .invalid rename implications for prod domains                                                                                       | Medium   | S      | Documentation |
| 40 | THREAT_MODEL: File-secret filePath paths + plan-in-store exposure note                                                                                   | Medium   | S      | Documentation |
| 41 | Add GC-root discipline note for local debug runs (AGENTS.md working rules)                                                                               | Low      | S      | Documentation |
| 42 | Verify aarch64 module-import-eval still green (pure eval runs on both arches)                                                                            | Medium   | S      | Quality       |
| 43 | Consider `publicUrl` warning when scheme is https but no ACME/manual cert configured                                                                     | Low      | S      | Quality       |
| 44 | Decide: track upstream PR branch vs vendored copy as the intermediate support surface                                                                    | Medium   | S      | Cleanup       |
| 45 | Add eval assertion wrapper Domain id `#domain` stability contract (consumers reference it)                                                               | Medium   | S      | Quality       |
| 46 | Confirm flood node's stateVersion asymmetry (machine node lacks system.stateVersion) is inert                                                            | Low      | S      | Cleanup       |
| 47 | Update docs/DOMAIN_LANGUAGE.md if it exists with 0.16 object nouns (MtaRoute, provision plan)                                                            | Low      | S      | Documentation |
| 48 | Harvest this report into TODO_LIST.md (docs-health HARVEST) after green                                                                                  | High     | S      | Documentation |
| 49 | Cut v0.5.0 release (CHANGELOG -> gates -> tag -> release) once gates green + user approves                                                               | Critical | M      | Release       |
| 50 | SystemNix consumer pin advance to the new tag (runbook)                                                                                                  | Critical | S      | Release       |

## g) QUESTIONS (cannot answer myself)

1. **Release doctrine:** ship this as v0.5.0 with the VENDORED module once
   gates are green, or hold the release until nixpkgs PR #552103 merges and
   we can un-vendor? (SystemNix hard-pins our tags, so this decides when the
   consumer fleet can move.)
2. **Real-host account secrets:** 0.16 provision plans put account passwords
   in the (world-readable) Nix store; 0.15 only ever exposed salted hashes.
   Which blessed pattern should the wrapper document/support for SystemNix
   hosts - sops-rendered runtime `stalwart-cli apply`, admin-created
   accounts via WebUI/CLI, or a credential-file secret type wired through
   wrapper options?
3. **Demo/quickstart domain:** `mail.demo.invalid` is dead under 0.16
   (hostname validation rejects the special-use TLD; `.test` passes). Keep
   the `.test` rename (my choice), or do you want a real subdomain of a
   domain you own in the demo/quickstart?

---

_Report is a point-in-time snapshot (2026-10-16 20:48 CEST). Section (f) is
HARVEST input for TODO_LIST.md/ROADMAP.md per docs-health. Format note: this
report is `.md` at the operator's explicit request (skill default is HTML -
flagged, not propagated)._
