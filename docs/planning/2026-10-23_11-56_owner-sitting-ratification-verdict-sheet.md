<!-- Owner-sitting package (Y-plan task O1). Every entry here is an OPEN owner
     call harvested fresh from docs/planning/decision-batch.md on 2026-10-23
     (C38-C53 + the older policy/ratification batch). Recommendations were
     re-read against the current tree, not copied blind: entries whose [rec]
     is now stale are marked STALE with the correction inline. Nothing here
     is executed by the agent sitting - the executor records verdicts
     verbatim (Y-plan O3) and never defaults an unanswered row.

     2026-10-26 COVERAGE RE-PROOF (Z-plan O1 audit): the "every open call"
     claim above was FALSE. C36, C37, and Q5 sit OPEN in decision-batch.md
     and appeared on no sheet; the three 2026-10-26 session g-questions
     (flood posture, report rename, report cadence) and the AGENTS.md
     line-cap lint were answered nowhere either. All seven are ADDED below
     (Batch 5 + Batch 7) so ONE sitting can still clear the board. -->

# Owner sitting - ratification + verdict sheet (2026-10-23)

> **Time budget:** ~70 min (60 as drafted + the 2026-10-26 coverage
> additions in Batch 5 and Batch 7). Answer with IDs only
> (`C43: cut`, `C19: drop`).
> **Unanswered = still BLOCKED** (no silent defaults, Y-plan kill-switch).
> Verdicts get written into `docs/planning/decision-batch.md` and the
> TODO_LIST re-rowed in the same session (O3).

## Batch 1 - release train (blocks v0.5.0 and the whole fleet)

| ID  | The call                                                                                         | Recommendation                                                                                     | Alternatives                                            | Cost of delay                                                           |
| --- | ------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------- | ----------------------------------------------------------------------- |
| C43 | Ship v0.5.0 WITH the vendored 0.16 module, or wait for nixpkgs PR #552103 to merge?              | **Cut with the vendored module**                                                                   | Wait for the PR (fleet stays 0.15.5)                    | Every consumer stuck on v0.4.0 = the 0.15 world while the tree is green |
| C45 | Stalwart package: stay on the pin's 0.16.22, or overlay 0.16.26?                                 | **Stay on 0.16.22**                                                                                | Overlay 0.16.26 (needs x86-64-v2 + VM cpu change)       | None today: both known .22 bugs are neutralized in-tree                 |
| C44 | Account-secrets pattern for real hosts (0.16 plan passwords land in the world-readable store)    | **(b) admin-created for interactive + (a) sops-rendered for automation; build (c) only on demand** | (a) only, (b) only, (c) credential-file type            | No blessed pattern exists at the v0.5.0 pin advance                     |
| C46 | Deploy-time restart flap on the vendored unit (every plan change bounces the mail ports seconds) | **Accept for v0.5.0**                                                                              | Plan-hash gate (stateful)                               | Cosmetic                                                                |
| C39 | MemoryMax ownership: wrapper `mkDefault` or consumer layer?                                      | **Consumer layer, wrapper ships none; record in THREAT_MODEL + module headers**                    | wrapper mkDefault                                       | Every nix-review re-flags it; unbounded stalwart on the VPS             |
| C41 | AGENTS.md size floor (~29 KB, under the 30 KB flag)                                              | **Accept as the floor** (no budget, no gate)                                                       | Force a diet to <20 KB by relocating VM-debug mechanics | Recurring F22.3 line in every docs pass                                 |
| C42 | `services.dmarc-monitor`: retire or keep on 0.16?                                                | **Keep through 0.16 stabilization**; re-decide after the live webadmin exists                      | Retire now (0.16 parses aggregates AND ARF)             | Wrapper may be partly redundant; README carries the caveat              |
| C52 | README-as-ledger permanent, or move the ledger to `docs/LEDGER.md`?                              | **Accept README-as-ledger**                                                                        | Move (rewrites many pointers)                           | Coupling deepens with every session                                     |
| C53 | Bootstrap degradation doctrine (bind-e2e falls back to `127.0.0.1:8080`)                         | **Accept degrade-visible**                                                                         | Add the eval-time port-set pin                          | None (failure is loud and bounded)                                      |

**STALE flag:** C42's [rec] was written before the 2026-10-18 re-verification
settled the ARF unknown. **RESOLVED 2026-10-26: the last evidence gap is
CLOSED** - stalwart-e2e subtest 16b runtime-verifies ARF ingest on the pin
(report-specific consumption + a delivered report-less control), so C42 is a
pure owner call now: retire immediately, or keep through stabilization and
re-decide once the live webadmin exists. See `decision-batch.md` C42.

## Batch 2 - pbx-artmann hermetic blessing (unblocks B1-B3 and the last two kept-live reports)

| ID  | The call                                                                                                                                                                                                                         | Recommendation                                                                                  | Cost of delay                                                     |
| --- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| PBX | Land the hermetic Directory override in their `stalwart-host-wiring` test (whole-key `mkVMOverride` of the `pocketid` object to a non-remote `@type` + Authentication ref), or keep the test red until a different shape exists? | **Land it** - their gate is red on a proven-impossible live OIDC fetch, not on a product defect | pbx master stays red; the last two kept-live reports cannot close |

**Evidence pack (runs 15/16):** driver VMs have NO outbound at all (valid DHCP
route + populated `resolv.conf`, yet slirp DNS AND direct TCP fail instantly).
Full transcript: `docs/status/2026-10-19_12-17_*` and
`docs/status/2026-10-20_14-19_*` (g/1); the spec lives in their test header
plus CONTRIBUTING "VM debug loops" (f).

## Batch 3 - the two D-lane questions (gate all live enablement)

| ID  | The call                                                                                 | Recommendation                                                                               | Cost of delay                             |
| --- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------- |
| D1  | Retire Google Workspace for the Stalwart VPS, or keep Workspace and run monitoring only? | **Retire** (the whole build-out assumes it)                                                  | The "super system" stays a test fleet     |
| D2  | VPS placement + budget: Hetzner project/location, size ceiling, backup target            | **CX22 alongside the domains project; backup to evo-x2 btrfs, StorageBox second copy later** | Blocks M22-M26 even after D1              |
| C14 | Rotate the 3 placeholder secrets in SystemNix `nix-email.yaml` (execution, not a choice) | Executes as part of M22/M26 when D1 lands                                                    | Rotation-due drift before live enablement |

## Batch 4 - Resend (needs an account/API key, not a doctrine call)

| ID | The call                                                                           | What is needed                                                                          |
| -- | ---------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| R1 | One real SASL smoke: username `resend`, API-key-as-password, `smtp.resend.com:587` | An API key (and the FROM domain). Shape is doc-verified; only the live smoke is missing |

## Batch 5 - policy batch (2-minute answers)

| ID     | The call                                                                                                                 | Recommendation                                                                                                     | Cost of delay                                                                                   |
| ------ | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| C18    | Branch protection: keep the push bypass for the auto-commit daemon, or go strict?                                        | **Keep the bypass on master**, require the check on any future protected branch                                    | The 4x-red statix streak is the observed cost                                                   |
| C19    | Renovate: install the GitHub app or drop `renovate.json`?                                                                | **Drop the config** (Dependabot covers Actions)                                                                    | Dead config stays drift                                                                         |
| C22    | GitHub Discussions, or issues-only?                                                                                      | **Keep issues-only**                                                                                               | Another inbox for a single maintainer                                                           |
| C24    | Alert channel (alerts must NOT ride the mail stack they watch)                                                           | **Discord via the existing DiscordSync layer**, ntfy as fallback                                                   | Blocks the monitoring taxonomy + dead-man switch                                                |
| C29    | Round-trip canary vantage (send to receive SLO probe)                                                                    | **evo-x2** (independent network + DNS path)                                                                        | Blocks the canary implementation                                                                |
| C34    | Webmail: wrapper goal or non-goal?                                                                                       | **Non-goal** - already executed as Bulwark on the consumer host (2026-10-19)                                       | Ratification only                                                                               |
| Q4     | README ops-detail level (public runbook detail has recon value)                                                          | **Keep as-is** until D1 lands, then re-decide                                                                      | None                                                                                            |
| CI     | CI python-lint scope: keep the ruff error floor, or move bandit/vulture (and BuildFlow's deeper ruleset) into CI too?    | **Keep the error floor in CI** (`--select E4,E7,E9,F`); bandit/vulture stay BuildFlow detect-only                  | Move them into CI (204 bandit + 436 ruff-format findings today - a gate nobody can go green on) |
| Q6     | Spam/Junk ownership                                                                                                      | **Tag-only now** - the auto-move half is MOOT (upstream hard-codes INBOX-spam to JUNK; no wrapper setting exists)  | Ratification only                                                                               |
| C36    | InboxClean + corpus topology: evo-x2 at home, or the VPS beside Stalwart? (decides DR, backup failure domain, auth path) | **evo-x2** (corpus-as-backup wants a failure domain independent of the VPS)                                        | Blocks row-175 deployment + the Gatus split                                                     |
| C37    | InboxClean build order: adapter-first (row 173) or corpus-first (row 174)?                                               | **Corpus-first**, JMAP spike in parallel (corpus needs no JMAP; ADR-023's order is a choice)                       | Orders the next two InboxClean sessions                                                         |
| Q5     | Declarative provisioning: grow `domains`/`accounts` options, or keep account state imperative/webadmin?                  | **Add the options** - the e2e already provisions mechanically; declarative is the NixOS contract                   | Same verdict powers M22; without it the demo/canary stays hand-built                            |
| AGENTS | AGENTS.md line cap: the doctor flags 247 lines against a 220 cap (pre-existing, every session) - trim to cap, or accept? | **Accept the overage** (the 30 KB flag is the real ceiling and AGENTS is under it; line count is the wrong metric) | The warning rides every session's doctor output until answered                                  |

## Batch 7 - the 2026-10-26 session g-questions (Z-plan O2.4)

Harvested from `docs/status/2026-10-26_19-00_*` (g/1-g/3; the 20-15 report
repeats g/1) and the Z-plan's O2.4 agenda; none of these had a home on this
sheet before the 2026-10-26 audit.

| ID               | The call                                                                                                                                                   | Recommendation                                                                                                                   | Cost of delay                                                         |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| FLOOD (D5 taste) | Flood subtest posture: keep the strict final probe (now capture-first, so a recurrence self-captures), or relax it to a soft warning?                      | **Keep strict** - the M14 probe is the only runtime proof the limiter trips; the capture block already removed the diagnosis tax | One recurring judgement call per stalwart-e2e red; no live impact     |
| REPORT-RENAME    | The line-mis-timestamped report `docs/status/2026-10-26_20-15_y-plan-ef-lanes-execution-bounce-ping-tls-dprint.md` - rename to its real hour, or leave it? | **Rename** - the filename is a citation key in TODO rows and CHANGELOG; a wrong hour is a real (if small) split brain            | Every future citation repeats the wrong hour                          |
| REPORT-CADENCE   | Status-report cadence: keep the per-session full status + brutal self-review default, or move to on-demand only?                                           | **Keep per-session** - the two kept-live reports and the TODO harvest both depend on it                                          | Ad-hoc reporting loses the harvest trail that made these sweeps cheap |

## Batch 6 - ratify the agent-executed adoptions (reversible, 2026-10-05)

| ID       | Adoption                                              | Status                                                                                                   |
| -------- | ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| C35      | JMAP spike start-now (executed; probes + e2e subtest) | Ratification only                                                                                        |
| C17/C17a | SystemNix push + input hard-pinned `?ref=v0.4.0`      | Ratification only; the pin advances to v0.5.0 after A4                                                   |
| C20      | mailsuite#65 filed                                    | Ratification only                                                                                        |
| C38      | Daemon flush: ride the cycle                          | Ratification only; the sub-question (hold pushes over a concurrent session's in-flight files) stays OPEN |
| Q6       | Spam-to-Junk "upstream ask" retired on source facts   | Ratification only                                                                                        |

## Appendix A - C45 delta table (decision input, already written)

`README.md` "Stalwart 0.16.22 -> 0.16.26 delta" (line ~259). Summary:
0.16.23 fixes the `bit_and` DNSBL class (our always-reconcile already
neutralizes it), 0.16.24-25 fix spam-rule/JMAP-VAPID/queue-quota bugs,
0.16.26 BREAKS x86_64 startup below x86-64-v2 and needs a VM cpu-type change.
No CVEs in the window; the pin's 0.16.22 is past the one that mattered.

## Appendix B - C44 options in one line each

- **(a) sops-rendered runtime `stalwart-cli apply`** - secrets never enter the
  Nix store; adds a runtime apply step + sops coupling on the consumer host.
- **(b) admin-created interactive accounts** - zero wrapper surface, zero
  declared account state; interactive onboarding only.
- **(c) wrapper credential-file secret type** - declarative + secret-safe;
  new option surface, built only on real consumer demand.

## Appendix C - what each verdict unlocks (Y-plan mapping)

| Verdict       | Unlocks                                                            |
| ------------- | ------------------------------------------------------------------ |
| C43 = cut     | A1-A5 (CHANGELOG pass, gate proof, dry-run, tag, banner)           |
| C45           | C2.2 (overlay execution or stand-verdict)                          |
| C44           | C5 (implementation + THREAT_MODEL)                                 |
| C39           | C6 (MemoryMax landing)                                             |
| C42           | C7 (retire execution or keep-plus-docs-fetch)                      |
| PBX blessing  | B1-B3 (their gate + the corridor closeout)                         |
| D1/D2         | C8 (rotation runbook, vandelay-vs-imapsync, dmarc live poll) + G7  |
| Resend key    | C8.3 (the one live smoke)                                          |
| CI lint scope | D4 (ci.yml/.buildflow.yml scope landing + negative test)           |
| C36/C37/Q5    | the InboxClean/M22 lanes (topology, build order, declarative plan) |
| C18/C19/C22   | settings micros (branch protection, app install/drop, Discussions) |
| C24/C29       | G7 monitoring encoding (taxonomy, canary)                          |
| C34/Q4/Q6     | ratifications; ROADMAP non-goals pass (G7)                         |
| FLOOD         | D5 (close the row as-is, or soften + rerun stalwart-e2e)           |
| REPORT-*      | the corridor rename + the cadence line in AGENTS/docs policy       |
| AGENTS        | retires the doctor line from every session's output                |
