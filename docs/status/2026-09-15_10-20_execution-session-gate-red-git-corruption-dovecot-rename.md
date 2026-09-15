# Status: Execution Mode — Session 1 (gate found RED, prior session's work discovered, C1 wiring, git corruption)

- **Date:** 2026-09-15 ~10:20 CEST (verified via `date`)
- **Mode:** "GET SHIT DONE — the WHOLE TODO list" (user mandate)
- **Scope:** nix-email TODO_LIST.md execution + SystemNix C1-C4 consumer wrapper
- **Interrupted twice** mid-edit by user (each interruption killed in-flight background jobs; one coincided with an auto-commit write → git damage, see d)

## a) FULLY DONE (verified this session)

| #  | Item                                                                                                                                                                                     | Verification                                                                    |
| -- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| 1  | **Stale-handoff detection**: 14 daemon commits after `1f8bb52` carried a complete unreported execution session (relay option, metrics/cache/certificate options, relay+parsedmarc tests, DKIM/restart/backup/journal/metrics subtests, CI, CONTRIBUTING, THREAT_MODEL, renovate, git-town, alejandra+fmt pass, GitHub topics). TODO_LIST.md was never synced against it | file greps + `flake.nix` exports + `gh repo view` (topics: 7 set, license null)  |
| 2  | **mkDefault-list mystery ROOT-CAUSED** (prior session banked symptom only, d/1): reproduced (`mkDefault [25 587]` alone → `[]`), bisected (priority 100 survives / 101 drops), culprit FOUND via `options.<opt>.definitionsWithLocations` — podman `network-socket.nix:95` (`lib.optional`, unconditional `[]` def at priority 100 from a DISABLED module) + `udp-over-tcp.nix:276` (`getFirewallPorts`); mechanism = `lib/modules.nix filterOverrides'` keeps only lowest-priority defs, lists concat never crosses tiers. `lib.optional`-instead-of-`mkIf` is the upstream anti-pattern | 3 eval probes + definitionsWithLocations output + module source read                 |
| 3  | Root cause documented in all 3 carrier locations: `modules/mail-server.nix` (firewall comment), `AGENTS.md` (convention), `README.md` ledger (new bullet incl. the `definitionsWithLocations` debugging tool) | greps: 1/1/1 hits                                                                  |
| 4  | **parsedmarc-e2e eval failure FIXED**: Dovecot 2.4 on this pin asserts on `dovecot_config_version`/`dovecot_storage_version`; nixpkgs' parsedmarc `localMail` provision enables dovecot2 WITHOUT them (upstream gap, source-verified in the pinned module). Test now pins both to `config.services.dovecot2.package.version` | `nix eval .#checks.x86_64-linux.parsedmarc-e2e.drvPath` → green (drv resolves)     |
| 5  | Dovecot-2.4/localMail gap banked in README ledger (with the dovecot rename warning note)                                                                                                 | README grep                                                                        |
| 6  | **CI fail-closed guard gap FIXED**: guard enumerated 3 checks; flake exports 4 — `parsedmarc-e2e` added to the expected list (`.github/workflows/ci.yml`)                                  | file grep = 1                                                                       |
| 7  | **dmarc-monitor unit hardening**: ProtectSystem=strict, PrivateTmp, NoNewPrivileges, RestrictNamespaces/Realtime/SUIDSGID, SystemCallArchitectures — deliberately ONLY the keys the nixpkgs DynamicUser unit does NOT already set (upstream's existing set read from the pinned module; my first draft's dead mkDefault duplicates + a `ProtectKernelTunes` typo caught and removed before commit) | module edit + nixpkgs unit source read                                              |
| 8  | **LICENSE added (MIT, 2026 Lars Artmann)** — sibling-repo convention (go-output/gogenfilter/go-atomic-write all identical). Decision executed under the GET-SHIT-DONE mandate from the standing MIT recommendation; ROADMAP open question #3 not yet annotated (report g/3) | `ls LICENSE`, convention check                                                     |
| 9  | **Stalwart 0.15.5 key verification for pending test work** (binary `strings` on `/nix/store/...-stalwart-0.15.5`): spam namespace is `spam-filter.*` (NOT `spam.*`) — `spam-filter.rule`, `spam-filter.score.spam`, `spam-filter.enable` all present; quota is a per-principal directory column (`columns.quota`). Ledger entries NOT yet written (tests not yet built) | binary strings                                                                     |
| 10 | **SystemNix C1.2 WRITTEN**: `modules/nixos/services/nix-email.nix` consumer wrapper — imports `inputs.nix-email.nixosModules.default`; dmarc-monitor layer (sops secret → `_secret` path contract, onFailure + startLimit, integration-registry entry: `monitored = true`, reports-dir freshness 72h, no vHost/checks); mail-server layer (sops → `services.stalwart.credentials` LoadCredential for fallback-admin + conditional relay password, `%{file:...}%` macro, unit-name computed for stateVersion < 26.05, onFailure). 3 self-caught bugs fixed pre-verify (relay-null crash on `msCfg.relay.username`, hardcoded unit name, split credentials merge) | file on disk (5781 B); NOT yet eval-verified (see b/2)                              |
| 11 | **SystemNix patterns fully researched** (prereq for C1-C4): flake-parts filename discovery, cv.nix upstream-consumer reference, integration.nix registry options, `onFailure = ["notify-failure@%n.service"]`, ports.nix doctrine (no port registration needed: dmarc has no listener; mail ports are upstream-owned IANA standards), mock-sops.nix + test-cv.nix test shapes, SystemNix AGENTS.md 5 prevention layers + gatus `pat()` trap rules | file reads, all cited in-session                                                    |
| 12 | **Dovecot unit-rename ROOT CAUSE (runtime test failure)** — debug VM loop (driver realized, `-o` existing-dir trap hit once, fixed): `Unit dovecot2.service could not be found` while the renamed `dovecot.service` runs healthy (pid 766, 143+993 listening). Fix identified (one line: wait for `dovecot.service`) but NOT applied — reporting was demanded first | debug transcript `/tmp/pd-debug/full.log`                                          |

## b) PARTIALLY DONE

| # | Item                                | Works now                                                                                                                                                | Missing                                                                                                                                                                              |
| - | ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1 | **parsedmarc-e2e green**            | Eval passes (dovecot 2.4 version pins)                                                                                                                    | Runtime still red for a ONE-LINE reason now known: `wait_for_unit("dovecot2.service")` → must be `dovecot.service` (a/12). Then re-run + full `nix flake check` gate (cached-verdict trap: input changed, will re-eval) |
| 2 | **SystemNix C1-C4 consumer wiring** | Wrapper module written (a/10); lock-rev parity verified (`eaad089` both repos); deployment-state documented (plumbing-only, enabled nowhere)                 | flake.nix input NOT added (interrupted at exactly this edit twice); sops placeholder secrets file NOT created; `tests/test-nix-email.nix` NOT written; SystemNix eval gate NOT run; SystemNix git repo BROKEN (see d/1)    |
| 3 | **Docs sync (docs-health debt)**    | —                                                                                                                                                         | TODO_LIST.md still shows ~19 rows as TODO that are DONE in code+CHANGELOG; CHANGELOG.md structurally mangled (old `[Unreleased]` section orphaned below the new one — duplicate Added/Changed/Fixed tails); ROADMAP license question #3 needs the MIT-executed annotation; TODO rows lack `verified <date>` stamps (TODO row) |
| 4 | VM debug loop                       | Driver realized + debug script ran to completion twice                                                                                                    | Third run's full output unanalyzed beyond the dovecot finding; `/tmp` artifacts fragile across interruptions (lost once already)                                                            |

## c) NOT STARTED (deliberate — interrupted, or sequenced after the gate)

1. **E2E subtests: quota, alias/catch-all, Junk-delivery** (TODO row; keys verified a/9, incl. the `spam-filter.*` namespace correction — the TODO's assumed mechanism ("spam.header") does not exist in 0.15.5)
2. **Negative-cache regression VM test** (plan: poison → provision → short `directoryCacheTtlNegative` → assert local delivery after TTL expiry; doubles as coverage for the new option)
3. **d2 architecture diagram in README** (hosts, flows, decisions — TODO row)
4. **TODO_LIST verified-date stamps** (TODO row, folds into b/3)
5. **SystemNix sops secrets** (`platforms/nixos/secrets/nix-email.yaml`: `dmarc-imap-password`, `stalwart-fallback-admin`, `stalwart-relay-password` placeholders, age-encrypted per `.sops.yaml` creation rule)
6. **SystemNix test** (mock-sops pattern, co-import integration.nix per the mkIf/options-guard trap note; eval-contract level — upstream already VM-tests product behavior)
7. **Renovate pairing note** (nix-email input must move with SystemNix's nixpkgs — noted in the planned input comment, config not touched)
8. Upstream-issue candidates verified-but-not-filed: nixpkgs parsedmarc localMail dovecot 2.4 gap (eval-breaking), podman/udp-over-tcp `lib.optional` firewall defs (mkDefault-killer), dovecot2.service rename (breaks wait_for_unit callers). verify-before-filing + github-voice apply before any filing.

## d) TOTALLY FUCKED UP

1. **SystemNix `.git` is corrupted — truncated object write at the interruption.** `.git/objects/4f/0b9081…` is 0 bytes (timestamped 09:32 = the exact second of the second user interruption, while the auto-commit daemon was committing my `nix-email.nix`). `git log`/`reflog` fail (`fatal: bad object HEAD`) locally. KEY FACT: `git ls-remote origin master` returns **that same hash** — the daemon PUSHED the commit; only the LOCAL object file is truncated. Likely fix: delete the 0-byte object file + `git fetch` (recovers the object from origin). Unverified — deliberately not executed (report-first mandate; repo surgery needs a green light).
2. **nix-email local history was REWOUND.** Local master: `ce35500 → 6dade65 → 4d5143d` (two daemon commits of my session's edits — one captured a mid-edit partial of parsedmarc-e2e, hence the file still shows `M`). Remote `origin/master` = `1f8bb52` (the prior session's pushed state, 16 commits ahead of ce35500). The prior session's commits are therefore NOT in local master — only on origin. Working tree = the UNION of everything (verified by greps: relay option, hardening, LICENSE, CI guard, root-cause docs all on disk). fsck shows dangling blobs (interrupted-commit debris). Recovery needs care + authorization (no-reset rule): e.g. `git fetch origin` → `git switch -c recover origin/master` → commit the working-tree delta there.
3. **I piped a gate command — my own repo's #1 documented rule.** The background parsedmarc-e2e build ran `nix build … -L \| tail -30; echo EXIT: $?` — the pipeline reported `EXIT: 0` on a FAILED VM test (the driver traceback was visible in the log, the exit code was not). The mask was caught only because I read the transcript. The rule exists in AGENTS.md verbatim and I violated it in the same session I re-cited it.
4. **I trusted the handoff's "everything done, tree clean" without re-verifying git state first.** First tool call of the session showed 14 unknown daemon commits — every subsequent decision had to be re-derived. A 5-second `git log` at session start was the missing step (the global lesson "status reports are point-in-time" applies to my own handoff).
5. **Two interruptions each killed in-flight background state silently** (debug VM logs, the flake-check job) — /tmp debug artifacts vanished once (recreated). Long-running VM/debug work in background shells is fragile across user interruptions; the AGENTS driver-loop notes don't mention this failure mode.

## e) WHAT WE SHOULD IMPROVE

1. **`git log`/`git status` FIRST in any "continue" session, before reading any doc** — the handoff's git facts age in minutes (daemon races).
2. **Gate commands never wear pipes — even in background jobs** (d/3): background + pipe is the worst combo (masks exit code AND the transcript is the only witness).
3. **Persist debug-loop artifacts under the repo's gitignored scratch or /var/tmp**, not /tmp, if interruptions keep eating them; or print findings inline before shutting the VM down.
4. **Auto-commit daemon + user interruptions = truncated git objects** (d/1). A `git fsck` after any interrupted session should be reflexive before further commits. Consider flagging the daemon's non-atomic write to its owner.
5. **The docs-health skill's "TODO rows get verified stamps" change should land WITH the sync commit** (b/3) — otherwise the next audit re-invents it.
6. **Upstream-gap findings (c/8) should go from "verified" to "filed" same-session** — the verification work is the expensive half and it decays.

## f) Up to 50 things to get done next

**Recovery first (blocks honest git state):**
1. Authorize + execute SystemNix object repair (delete 0-byte object, `git fetch`, verify `git log`/`status` — a/d/1, ~5 min)
2. Authorize + execute nix-email history recovery (fetch, `git switch -c recover origin/master`, commit working-tree delta, then fast-forward master without reset-class commands — a/d/2, ~10 min)
3. Re-run `git fsck` both repos post-repair; confirm zero missing objects

**Gate back to green (nix-email):**
4. Apply the one-line dovecot rename fix (`wait_for_unit("dovecot.service")`, a/12) — also re-check `postfix.service`/unit names in that script for other 26.11 renames while there
5. Re-run parsedmarc-e2e alone → green
6. Full `nix flake check` (no pipes, background, read raw output) → all 4 checks green
7. Commit gate-green state explicitly (per-task message, not daemon heuristic)

**TODO_LIST execution (remaining rows, ranked):**
8. Quota subtest (per-principal `quota` column, a/9 — unit needs empirical verification, likely bytes; assert via rejection or GETQUOTA)
9. Alias/catch-all subtest (multi-email principal + `@example.test` catch-all; generalize the imap probe for per-account logins)
10. Junk-delivery subtest (`spam-filter.rule.<id>` header rule + `spam-filter.score.spam`; keys binary-verified a/9; rule field names need one empirical probe — docs fetch 404'd)
11. Negative-cache regression subtest (short `directoryCacheTtlNegative`, poison→provision→wait-TTL→assert local)
12. Ledger entries for quota/alias/junk/spam-filter keys once observed in VM (fact+method+date)
13. d2 architecture diagram in README (hosts, flows, decisions — keep it small, dprint-stable)
14. TODO_LIST sync: delete ~19 done rows, add `verified 2026-09-15` stamps to the rest (schema per docs-health e/5)
15. CHANGELOG restructure (merge orphaned old `[Unreleased]` Added/Changed/Fixed into the current sections; keep Keep-a-Changelog shape)
16. ROADMAP: annotate open question #3 as executed-MIT (2026-09-15, mandate + standing recommendation, revisit-before-first-external-contribution)
17. FEATURES.md: add hardening/LICENSE/CI/topics rows to inventory
18. Renovate config: add nix-email pairing note if not adequately covered by the input comment (check existing renovate.json)
19. aarch64 posture row: README now documents x86_64-only loudly — verify the row's "or document" arm is satisfied and delete the row

**SystemNix C1-C4 completion:**
20. Add the nix-email flake input (exact edit prepared twice, both interrupted — comment text in session transcript)
21. `nix flake lock --update-input nix-email` (or `nix flake update nix-email`) + parity check (rev == eaad089-pin doctrine)
22. Create `platforms/nixos/secrets/nix-email.yaml` (sops -e to evo-x2 age key per `.sops.yaml`; placeholder values documented as rotate-at-go-live)
23. Write `tests/test-nix-email.nix` (mock-sops + integration.nix co-import; assert: `_secret` path wiring, credentials → LoadCredential macro, registry entry fan-out, unit onFailure)
24. Register test in `tests/default.nix`
25. SystemNix eval gate (their `nix flake check` equivalent / pre-commit suite) → green
26. SystemNix explicit commit (per-task message; daemon races — check status first)
27. Note in nix-email README "SystemNix integration" section: consumer wrapper landed, shape link

**Cross-repo hygiene:**
28. Push nix-email recover branch / master (needs authorization — push was authorized last session for that push only)
29. SystemNix push (if the daemon's 4f0b90 push was partial — verify remote integrity post-repair)
30. Consider filing the 3 upstream issues (c/8) — verify-before-filing gate, then github-voice drafting
31. Git-town/config alignment check if sibling-repo workflow expects it (git-town.toml exists nix-email side)

**Blocked (user decisions — see g):**
32. dmarc-monitor live validation (D1)
33. Migration tooling compare stalwart-vandelay vs imapsync (D1)
34. Everything VPS/Terraform/migration (D1/D2) — ~20 plan tasks stay parked

## g) Questions I cannot answer myself

1. **Git recovery authorization (d/1+d/2):** May I repair both repos (delete SystemNix's 0-byte object + fetch; nix-email fetch + recover-branch + working-tree commit + master fast-forward)? It touches ref state — the no-reset rule makes this explicitly yours to authorize. Remote backups exist for both (origin verified reachable).
2. **D1 — Google Workspace fork:** retire Workspace for the Stalwart VPS, or keep Workspace and run only the parsedmarc/monitoring half? Gates ~20 TODO/plan tasks (VPS, Terraform, migration, dmarc-live).
3. **LICENSE confirmation:** I executed MIT under the mandate (standing recommendation, sibling convention). Confirm, or name your preferred alternative while it is still trivially changeable (no external contributors yet).
