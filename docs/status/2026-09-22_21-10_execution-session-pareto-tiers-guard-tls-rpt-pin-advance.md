# Status Report: Pareto Execution Session (Tiers 1%→20% + partial 100%)

| Field | Value |
| ----- | ----- |
| Date | 2026-09-22 21:10 CEST |
| Session type | EXECUTION of `docs/planning/2026-09-22_19-23_pareto-master-plan` (plan-only was the PREVIOUS session; this one wrote code) |
| Tasks executed | M1, M2, M3 (+pin advance), M4, M5, M6, M7, M8, M9, M10, M11, M12 (wiring found pre-done; transcript added), M13, M15, M16 (doc part), M18 (spec), M20, M21 (local), M27 (already-tracked verdicts) |
| Task interrupted mid-flight | **M14** (rate-limit + DNSBL wrapper options) - design decided, code NOT written |
| Gate state | ALL 5 checks built green individually (incl. both new ones); aggregated `nix flake check` NOT yet run this session; `nix fmt -- . --check` green at every yield point |
| Git | origin/master = `a2b6c2f` (auto-daemon pushed EVERYTHING incl. all guard/VM work); SystemNix has UNPUSHED local changes (dedupe + lock) |
| Judgment call to flag | I executed the plan's non-gated tiers autonomously; all 19 decision-gated todos untouched and batched in `docs/planning/decision-batch.md` (M2 deliverable) |

## a) FULLY DONE (implemented + verified, not just attempted)

1. **Fleet eval guards (M3, C01+C02)** - `flake.nix` now parses `flake.lock` at eval time and asserts: (a) nixpkgs `original.type == "github"` (registry tarball trap, 1:1 from SystemNix's `allEvalGuards`), (b) `locked.rev == fleetNixpkgsPin` constant (compat doctrine mechanized), (c) `flake-parts.inputs.nixpkgs-lib == ["nixpkgs"]` (the dropped-follow smuggle guard). All three chained via `builtins.seq`. NEGATIVE-TESTED: pin-guard fires ("nixpkgs pin drift vs the SystemNix fleet pin", exit 1), follows-guard fires after a real drop+re-lock ("flake-parts input regression"; the failed test run smuggled `nix-community/nixpkgs.lib 5bdaa90a` into the lock live - the threat is real, the guard catches it). Positive evals green on both arches.
2. **nixpkgs PIN ADVANCE (discovered live, not planned)** - SystemNix floats `nixos-unstable`; its lock moved to `6774f7bc` TODAY (auto-daemon commit, pushed) while nix-email sat at `eaad0894` - the compat doctrine was already broken when I started. Advanced nix-email to `6774f7bc` (lock + URL + comment). Presence list re-verified against the NEW pin via `nix eval`: stalwart 0.15.5 (module-compatible; 0.16 still module-incompatible), parsedmarc 11.0.1, mailpit 1.31.1, swaks 20240103.0, imapsync 2.314.
3. **Workaround retirement (C55 ritual)** - the demo-VM `qemu.enableSharedMemory = true` pin-skew workaround DROPPED: the new pin's `qemu-vm.nix:756` defaults `enableSharedMemory = useVirtiofs` (= true on linux), verified by grep of the pinned source. Replaced with a comment explaining the history.
4. **Module-import check (M4, C03)** - new `tests/module-import-eval.nix`: `nixosSystem` eval importing BOTH wrappers in ONE toplevel (co-existence proof), asserts `services.mail-server` + `services.dmarc-monitor` option surfaces and both wrapped services flip. Runs on BOTH arches (pure eval). Built green x86_64 + aarch64.
5. **Loopback relay assertion (M5 residue, C04)** - the one unmechanized ledger fact now eval-time enforced: `relay.address` matching localhost/127.0.0.1/::1/0.0.0.0 throws (Stalwart refuses loopback relay targets - SSRF guard). NEGATIVE-tested (`localhost` → exact throw message) and positive-tested (`smtp.resend.com` evals clean). C04/C06 confirmed otherwise pre-done (indexed IfBlock keys + hostname assertion + catch-all ledger note all existed) - rows were stale.
6. **Lock-mystery SOLVED (M7, C07)** - the 2026-09-17 open question "why did `nix flake lock` surface the broken checks" is ANSWERED with experiments: (a) a `throw` inside checks leaves `nix flake lock` GREEN (lock never forces output leaves), (b) an UNDEFINED VARIABLE anywhere in flake.nix fails lock (exit 1) - it is a PARSE-time scope error, not output evaluation; control test placed the undefined variable outside `checks` and lock still failed. The mystery was never lock evaluating outputs. The guard comment's original "ANY flake command (eval, lock, check, build)" claim was WRONG and is corrected in-file (measured, with the experiment summary).
7. **M9 verify pass → README ledger (foundations for 6 wire-or-skip verdicts)** - pinned v0.15.5 tarball + pinned parsedmarc 11.0.1 package grepped (store paths, not web docs): metrics keys, tracing keys, rate-limiter shape (`queue.limiter.inbound.<id>` with enable/key/match/REQUIRED rate), spam-filter DNSBL keys (content-analysis, NOT connection-level), auto-expunge defaults (30d/3d, no per-mailbox Junk knob), AUDIT = NOT AVAILABLE in 0.15.5, autoconfig = HTTP routes present (`config-v1.1.xml`), TLS-RPT = `parse_smtp_tls_report_json` + shared-poll routing. One consolidated ledger entry (a)-(h) with file:line citations, dated 2026-09-22.
8. **TLS-RPT consumption (M10, C23) - wired AND e2e-verified** - `parsedmarc-e2e` now sends an RFC 8460 report (`application/tlsrpt+json` attachment, inline deterministic fixture mirroring the parser's required fields) alongside the DMARC aggregate, and asserts `smtp_tls.json` exists with the right org/policy/failure-details (snake_case verified against the pinned parser) + `smtp_tls.csv` rows. **BUILD + RUN GREEN on first attempt.** No wrapper code needed - the verdict was "rides the existing poll" and the e2e now proves it.
9. **docs/MONITORING.md (M11 + M9.4 + M13 + M15 + M18 + M20.1 + M20.3)** - new doc: severity taxonomy (CRITICAL/WARNING/INFO), 14-row signal inventory with verified sources and honest statuses, coverage matrix (today/planned/gap), routing table, consumer Gatus + dead-man specs, failed-auth alert spec (threshold/window/dedupe), queue IR levers table (`GET/PATCH/DELETE /api/queue/messages`, `PATCH /api/queue/status/stop` - all source-verified in the pinned queue.rs), round-trip canary design (vantage options, SLO, failure-alarm split), threat-model cross-check table (every attacker scenario → signal), non-mail-channel rule.
10. **Metrics transcript (M12.1/M12.4 residue)** - `stalwart-e2e` now dumps the full `/metrics/prometheus` body into the build log (transcript-first doctrine). GREEN run captured 40 series names (auth_success, smtp_spf_ehlo_fail, smtp_dkim_fail, delivery_*, store_*, server_memory, queue_queue_message_authenticated...). KEY FINDING: **0.15.5 exposes NO queue-depth gauge and NO queue-age series** - the M12 "queue-depth/queue-age alerts off /metrics" idea is NOT implementable off stock metrics; the honest alternative is a consumer-side management-API poll (`GET /api/queue/messages`). MONITORING.md row 2 must be corrected accordingly (noted, not yet edited).
11. **ROADMAP theme-4 reorg (M20.2)** - detect → alert → respond → verify, with this session's verified facts folded in and the stale "verify keys against the binary" telemetry item resolved to its post-verification state.
12. **TELEMETRY.md caveat update** - the "verify keys against the pinned binary" caveat is now half-answered in place (core keys source-verified 2026-09-22; webhooks/alert-objects/series names remain unverified).
13. **docs-truth sweep (M1, C56+C57+C11)** - ROADMAP Q7 closed inline (demo VM in this repo, answered 09-17; hostfwd residue linked) and Q8 closed (`v0.3.1` exists); TODO_LIST: the unrecorded demo-VM hostfwd-hang bug is now a High row (with repro command + report link), the SystemNix pin-bump row unblocked, the archive-sweep row CORRECTED (its "several 2026-09-16 files eligible" claim was FALSE - marker check shows all 5 candidates carry zero `~~` resolution markers; the real task is annotate-then-move). Eval surfaces smoked.
14. **Decision batch (M2)** - `docs/planning/decision-batch.md`: D1, D2, C24 (channel), C29 (vantage), C18 (bypass), C19 (Renovate), C20 (mailsuite), C22 (Discussions), C34 (webmail), Q4, Q5, Q6, demo-VM residue (g1 port, g2 dmarc-in-demo), C17 (push approval), C14 (secrets, no decision needed) - each with a recommendation, what it unblocks, cost of delay. Linked from ROADMAP open-questions header.
15. **Upstream filings re-check (M8.1)** - nixpkgs #563651/#563652/#563777 all still OPEN/unmerged (workarounds stay); **mjs/imapclient #663 MERGED 2026-09-18** (was open at the last sweep) - the py3.14 starttls fix is upstream; #662 (issue) closed as answered. TODO evidence needs this update (harvest phase).
16. **IMAP-LOGIN-by-NAME documentation (M8.2, C09)** - added to BOTH the `dmarc-monitor` settings example and the option description (Stalwart resolves LOGIN by principal NAME, not email addresses). dmarc-eval rebuilt green (its optionsCommonMark render forces the new text through the docs pipeline).
17. **SystemNix pin/dedupe (M21, C15 - local part)** - the TODO row itself was DRIFTED: SystemNix no longer pins v0.2.0, it floats `?ref=master` (lock was at b54f5c3). Applied the real remaining work: `inputs.nix-email.inputs.flake-parts.follows = "flake-parts"` dedupe + `nix flake lock --update-input nix-email` → nix-email node now `2659abb`, the second `flake-parts` node (`flake-parts_17`) collapsed FOR NIX-EMAIL (it legitimately remains for `papdashboard` - separate consumer, noted for SystemNix hygiene). Consumer `checks.nix-email-contract` built GREEN ("all eval assertions passed"). **NOT pushed** (gated on C17 approval).
18. **Over-quota surface (M6, C05)** - verdict: README already documents the decision ("no wrapper option because it is per-account data"; queue-depth is the operator signal); the module owes nothing new. Row sweepable.

## b) PARTIALLY DONE

1. **M14 rate-limit + DNSBL wrapper options** - verdicts locked (rate limiter shape verified safe-to-default: no DNS dependency; DNSBL keys verified but must default OFF - the DNS-less E2E lesson, same class as pyzor). Design decided: `rateLimits` submodule option with one conservative per-remote-ip default + `spamFilter.dnsbl.enable = false` default + eval assertions. **Code NOT written** - I was reading the module's option surface when the report was requested.
2. **Full gate** - every check built green INDIVIDUALLY this session (dmarc-eval ×2, module-import-eval both arches, stalwart-relay-e2e, parsedmarc-e2e with the new TLS-RPT subtest, stalwart-e2e with the metrics dump), but the aggregated `nix flake check` was never executed - it is the next command, and it also re-evals the demo toplevel on the new pin.
3. **MONITORING.md row 2 correction** - the transcript now proves stock metrics have no queue-depth/age series; the row still describes the aspired rule and must be rewritten to the management-API-poll alternative. Transcript exists; edit pending.
4. **Harvest into living docs** - TODO_LIST row sweeps (C03/C04/C05/C06/C07/C09/C10/C23/C24-spec/C28-spec/C31-33/C36/C37/C56/C57 done; C15 partial; C16 doc-verified) + CHANGELOG [Unreleased] entries for: guards, pin advance, workaround retirement, module-import check, loopback assertion, TLS-RPT e2e, MONITORING.md, SystemNix dedupe. NOT yet written - the session ran out of road before the closing harvest.
5. **M17/M19** - resolved at the VERDICT level (expiry: defaults already active, doc-only; audit: knob does not exist, tracing is the surface; autoconfig: rides the HTTP listener, doc-only) and captured in the ledger + MONITORING rows, but no CHANGELOG/TODO sweep yet, and M17's "capacity metrics" row still needs the management-API-based spec once row 2 is corrected.
6. **TODO evidence updates** - imapclient #663 merge (M8 finding) and the SystemNix-row rewrite (it no longer describes reality: no v0.2.0 pin exists) are known-needed TODO_LIST edits, not yet applied.

## c) NOT STARTED

1. **The demo-VM hostfwd/API hang** (now a TODO_LIST High row) - root-cause work needs the VM debug loop (GC root, custom test script, guest-side curl first). Zero progress this session beyond recording it properly.
2. **docs-status ANNOTATE passes** (C11 real task) - five reports need inline `~~item~~ done at <hash>` resolution before any `git mv` to archived/; not begun (only the eligibility check ran).
3. **D1-gated cluster M22-M26** (provisioning+DKIM, backup/DR, Terraform DNS, migration+cutover, DMARC-live+OIDC) - untouched by design; hard-gated on the user's D1/D2 answers.
4. **User-gated filings** - mailsuite issue (C20, draft ready), Stalwart upstream Junk-filing request (C21, gated on Q6), Renovate (C19), Discussions (C22), webmail (C34).
5. **Resend live smoke (C16)** - SASL shape doc-verified; the real :587 probe still needs an API key from Lars. Outbound webhook telemetry (C25) similarly gated.
6. **Secret rotation (C14)** - gated on D1 by design.
7. **Release tag** - nothing cut this session; guards + TLS-RPT + pin advance are sitting in CHANGELOG-less [Unreleased] purgatory until the harvest.
8. **Fleet eval-guard PROPOGATION** - SystemNix/telephony do not yet benefit from THIS repo's pin-guard learnings (SystemNix has its own tarball/URL guards; the nixpkgs-pin-identity constant idea could be adopted there - cross-repo suggestion, not started).

## d) TOTALLY FUCKED UP (own failures, root-caused)

1. **`git restore flake.nix` wiped my own uncommitted guard implementation mid-negative-test.** I used file-level `git restore` to undo a targeted test mutation while the file ALSO carried the entire guard block (daemon hadn't committed yet) - restore reverted to the pre-guard commit and silently disarmed everything. Three subsequent negative tests (NEG2/NEG2B/NEG3/NEG4) ran against a file WITHOUT guards and produced INVALID "the guard didn't fire" conclusions, which I briefly trusted and nearly documented as a guard defect. Diagnosed via a `sed` probe that printed NOTHING (the symbol was gone), then rebuilt the guards and re-ran BOTH negatives properly (they fire). Root cause: file-granularity restore on a dirty file. Rule I owe AGENTS.md: never `git restore` a file with unrelated uncommitted work of mine - revert test mutations with targeted edits, or commit before negative-testing.
2. **`toString /.` vs `./.` typo** - one character sent `builtins.getFlake` to the FILESYSTEM ROOT ("/.crush: Permission denied"), invalidating both loopback-assertion test runs before I noticed. Two wasted eval cycles; caught only because the positive run's error looked wrong.
3. **A fabricated commit hash shipped briefly** - I wrote "pushed, 2659606-era iterations" into the new demo-VM TODO row from memory. It was NOT a real hash. Caught on self-review, replaced with the real one (`cffc332`, found via `git log -S`). The class of error the repo's AGENTS.md warns about ("extract cross-file identifiers mechanically, never trust memory") - I re-proved the rule the hard way, inside the session that codified it.
4. **The first guard comment contained a false claim** - "ANY flake command (eval, lock, check, build)" fails on regression. The M7 experiments proved `nix flake lock` forces NEITHER the guards NOR check leaves. Shipped (locally), then corrected in the same session with the measured verdict written in. The intermediate commits are on origin (daemon) - the wrong claim exists in git history; the tip is truthful.
5. **Archive-sweep row trusted instead of verified for three sessions** - the TODO row claimed "several 2026-09-16 files eligible" for archiving; a 30-second marker check disproved it (all candidates: 0 resolution markers). Nobody had run it since 09-17. Small, but it is exactly the "status is verified, not assumed" violation the docs-health skill exists to prevent.

## e) WHAT WE SHOULD IMPROVE

1. **Standing session opener: fleet-drift probe.** The SystemNix pin drift (6774f7bc vs eaad0894) was discovered by ACCIDENT during guard design. A 60-second `python3 json.load(flake.lock)` diff of nix-email vs SystemNix at session start would have caught it immediately. Now that the guard exists, CI catches it - but only AFTER push; the opener catches it before work begins on a stale base.
2. **Commit-before-negative-test.** All destructive test mutations on files carrying real work should happen only after a commit checkpoint (or via reversible targeted edits). Today's 20-minute guard-rebuild outage was self-inflicted.
3. **VM debug loop for the demo hang needs a scheduled block.** It is now the highest-value REMAINING technical item in-repo (blocks: withheld README/FEATURES demo docs, dmarc-in-demo (g2), and the "Try it in a VM" story), and it needs the GC-root + `--test-script` discipline from AGENTS.md - a distracted tail-end-of-session attempt would Verschlimmbessern it. Budget a fresh session for it.
4. **MONITORING.md needs its row-2 correction + a standing "series names transcribed from build log `stalwart-e2e` <date>" annotation** so future readers know the transcript's authority and date.
5. **The daemon pushes mid-session** - today that was FINE (work was green at each daemon cycle, eval guards ran after every flake write per AGENTS.md), but the M14 half-implemented option must NOT be left dirty across a yield: either finish it or stash it before ending any session segment.
6. **The plan's M12 "queue alerts off /metrics" was written before the transcript existed** - the plan itself carried an unverified assumption. Improvement: any plan row that says "off /metrics" should carry a verify-series-first checkbox. The transcript-first doctrine caught it; the planning stage could adopt the same gate.
7. **CHECKS.md-style gate proof for docs claims**: the MONITORING/Gatus/IR specs cite source line numbers - a future session should spot-verify 2-3 of them against the tarball before consumer implementation (they are grep results from today, transcribed carefully, but not independently reviewed).
8. **SystemNix TODO_LIST needs its own drift row** (nix-email row rewritten to reality + papdashboard flake-parts dedupe idea + push approval) - I can only write it when working IN that repo per the consumer-layer doctrine; noting it here for the next SystemNix session.

## f) NEXT 50 (sorted by leverage; Tier-1 items unblock the rest)

**Decisions (the 1% - unblocks 19 gated todos):**

1. D1 verdict (Workspace fork) - gates M22-M26, C12, C14, C43-C51.
2. D2 verdict (VPS placement/budget) - gates M23/M24 sizing.
3. C24 alert channel + C29 canary vantage - unblocks M11 routing table + M18 implementation.
4. C17 SystemNix push approval - ships today's dedupe + lock advance (local work is DONE and green).
5. C18 branch-protection bypass: keep or strict.
6. C19 Renovate: install or drop (note: Dependabot opened its first branch `dependabot/github_actions/actions-b7aede57ad` this week).
7. C20 mailsuite issue: file the verified draft or skip.
8. C22 Discussions; 9. C34 webmail goal/non-goal; 10. Q4 README detail level; 11. Q5 declarative provisioning; 12. Q6 spam ownership (recommends c-now+d-upstream); 13. demo-VM g1 port call; 14. demo-VM g2 dmarc-in-demo call; 15. cut a tag (`v0.3.2`?) checkpointing guards+TLS-RPT+pin-advance for the fleet.

**In-repo technical (next session):**

16. Finish M14: `rateLimits` + `spamFilter.dnsbl` options with the decided defaults + module-import-eval assertions + relay-e2e re-run.
17. Fix MONITORING.md row 2 (no queue-depth gauge in 0.15.5 - spec the `GET /api/queue/messages` consumer poll instead).
18. Run the aggregated `nix flake check` (all checks at once, demo toplevel on the new pin) - the one gate not yet executed this session.
19. Harvest: TODO_LIST sweeps + CHANGELOG [Unreleased] entries (guards, pin advance, workaround retirement, module-import check, loopback assertion, TLS-RPT e2e, MONITORING.md).
20. Update TODO evidence: imapclient #663 merged (upstream-watch row), SystemNix pin row rewrite (no v0.2.0 pin exists - it floats master).
21. Demo-VM hostfwd hang: guest-side `curl -v 127.0.0.1:8080` first, read the 6 "Configuration build warning" lines, check the "Downloading external resource" loop (fresh-session budget).
22. Then the layered demo re-smoke (guest loopback → host 18080 → swaks catch-all → IMAPS login) with transcripts.
23. Then land the withheld demo docs (README "Try it in a VM", FEATURES row, AGENTS `nix run .#vm`).
24. Optional after demo is green: dmarc-monitor in the demo against a local Mailpit sink (g2).
25. Investigate the demo journal's "Configuration build warning" content even if benign.
26. Decide the demo's external-resource download posture (identify URLs; disable-or-allow; ledger the E2E-vs-demo delta).
27. docs-status ANNOTATE pass #1 (report 16_19-16) then `git mv` if fully resolved.
28. ANNOTATE pass #2 (16_20-49) + archive move.
29. ANNOTATE pass #3 (17_15-11 v0.3.0 release report) + archive move.
30. ANNOTATE pass #4 (17_17-28 flake-parts migration) + archive move (its open items are already harvested/routed).
31. ANNOTATE pass #5 (17_21-07) LAST (hostfwd items still open - only after task 21-23 close it).
32. `nix flake lock` mechanism note: add the parse-time-scope finding to AGENTS.md working rules (one line; prevents future sessions from re-deriving).
33. Extend parsedmarc-e2e failure-report coverage? (forensic/failure reports currently untested - only aggregate + smtp_tls are) - check parsedmarc's failure-report sample and decide.
34. Add a freshness Gatus spec refinement to MONITORING (dedupe note vs consumer `backup.maxAgeHours` - already flagged, needs the final wording).
35. Capacity spec (row 11): transcribe store_/server_memory series from today's build log into concrete thresholds.
36. Canary design: turn MONITORING §6 into an actionable TODO row (post-C29).
37. Rate-limiter tuning note: document how consumers should size `queue.limiter.inbound` (after M14 lands).
38. Threat-model: add the new loopback eval-assertion to the SSRF row (it strengthens the existing entry).
39. FEATURES.md: add rows for the eval guards, module-import check, TLS-RPT collection (FULLY_FUNCTIONAL), monitoring taxonomy (PARTIALLY - specs vs consumer wiring).
40. Cross-check dmarc-eval's rendered-settings greps still pass after M14 (they will - mkDefault additions don't move existing keys - but the check is the proof).

**Consumer/cross-repo (post-approval):**

41. SystemNix: push the dedupe + lock (C17) + triage its CI debt list.
42. SystemNix: consider adopting the fleet-pin-constant guard (its nixpkgs floats - the constant+ritual pattern from M3 ports directly).
43. SystemNix: papdashboard flake-parts dedupe (same pattern as nix-email's).
44. Rotate the 3 placeholder secrets (C14) - only when D1 lands.
45. Resend: API key from Lars → live :587 smoke (C16) → close the last unverifiable relay claim.
46. Resend: webhook endpoint for bounce/complaint telemetry (C25) - consumer-side, post-D1.
47. File mailsuite draft (C20) if approved - the draft is voice-checked and 5-gates-passed.
48. Stalwart upstream feature request (C21) if Q6 lands on (d).
49. InboxClean JMAP/IMAP spike ticket (cross-repo, post-migration).
50. Paperless app-passwords + smartd decoupling plan (cross-repo, ROADMAP theme 4).

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

1. **D1 + D2 (the fork and the budget):** retire Google Workspace mailboxes for the Stalwart VPS, and if yes - which Hetzner project/location, CX22-class?, backup target (evo-x2 btrfs pool now, StorageBox later)? Everything in tiers "D1-gated production" (M22-M26, 15+ todos) waits on this single answer; my recommendation and the full option set are in `docs/planning/decision-batch.md`.
2. **Alert channel + canary vantage (C24 + C29):** do alerts go to Discord via the existing SystemNix layer (my recommendation, non-mail rule satisfied), or ntfy/something else? And does the round-trip canary run from evo-x2 (my recommendation - independent residential path), or do you want a different vantage? I cannot know whether evo-x2 is guaranteed-resident or whether Discord is actually monitored by you at 3 a.m.
3. **Push + bypass + tag cadence (C17 + C18 + new-tag):** may I push SystemNix's local dedupe + lock advance (the work is green there: contract check passed)? Keep the branch-protection bypass for daemon velocity, or go strict? And do you want a `v0.3.2` tag cut NOW to checkpoint today's guards + pin advance + TLS-RPT for the fleet, or batch into the next feature release?

---
*Point-in-time snapshot (2026-09-22 21:10 CEST). Session artifacts: `docs/planning/decision-batch.md`, `docs/MONITORING.md`, `tests/module-import-eval.nix`, `tests/parsedmarc-e2e.nix` (TLS-RPT), `tests/stalwart-e2e.nix` (metrics dump), `flake.nix` (guards + pin 6774f7bc + workaround retirement), `modules/mail-server.nix` (loopback assertion), `modules/dmarc-monitor.nix` (LOGIN doc), `README.md` (ledger (a)-(h)), `ROADMAP.md` (Q7/Q8 closed, theme-4 reorg), `TELEMETRY.md` (verification update), `TODO_LIST.md` (hostfwd row, truth fixes). SystemNix (unpushed): flake.nix nix-email dedupe + flake.lock at nix-email `2659abb`.*
