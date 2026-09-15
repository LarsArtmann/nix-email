# Execution session: gate-green recovery, parsedmarc-e2e never-green chain, SystemNix C1 wiring

**Date:** 2026-09-15, session ran ~15:00 → 17:00 CEST (report written 17:05)
**Directive:** "READ, UNDERSTAND, RESEARCH, REFLECT ... Execute and Verify them one step at the time. Repeat until done."
**Scope of this report:** THIS session only (the 15:00–17:00 continuation after the 10:20 handoff). Prior sessions' work is referenced only where this session verified or changed it.
**Method:** every claim below was re-verified against the tree/eval/VM this session (git status, nix eval/build, VM debug runs, byte-level greps). The two fake-greens in §d are owned, not hidden.

## Headline

`nix flake check` is **fully GREEN (exit 0, unmasked)** — all four checks: `dmarc-eval`, `stalwart-e2e`, `stalwart-relay-e2e`, `parsedmarc-e2e`. SystemNix's C1 consumer wrapper is wired, locked, sops-seeded, and contract-tested. Both repos fsck-clean, everything committed by the auto-daemon. Nothing pushed.

parsedmarc-e2e had **never been green** before this session — three stacked root causes (one nixpkgs module bug, one nixpkgs packaging bug, one test-design bug) plus two assertion bugs, all found by experiment, all fixed with workarounds/regression-guards inside this repo.

---

## a) FULLY DONE

1. **Full gate green, honestly verified.** `nix flake check` → `FLAKECHECK_EXIT:0` (redirect-to-file, no pipe). Previous runs had failed on stalwart-e2e (E501 build break) and parsedmarc-e2e (crash chain, §d/§a-3).
2. **stalwart-e2e green** with all 17 subtests, including the delivery behaviors this session debugged to passing: unknown-recipient 550 rejection, alias, catch-all, over-quota (accepted at SMTP, never delivered), GTUBE → `X-Spam-Status` tagging, negative-cache poisoning + low-TTL recovery, restart, backup drill.
3. **parsedmarc-e2e green for the first time ever** (9.00 s parse subtest once healthy). Three stacked root causes eliminated — two with shipped workarounds + regression guards, one with a fixture fix (§a-4..6, details in §d).
4. **Workaround 1 shipped + guarded** (nixpkgs bug): with `provision.elasticsearch = false`, nixpkgs' parsedmarc module still materializes `elasticsearch.cert_path` (`types.path`, CA bundle) and `.ssl` (`types.bool`) — both survive the module's null/[]/{} filter → rendered ini carries `[elasticsearch]` without `hosts` → parsedmarc 11 exits 255 ("hosts setting missing"). Fix: guarded `ExecStartPre` awk-strip of the section from the rendered ini (only while ES is off); byte-verified the generated script; offline-tested the awk against the real ini. Neither key can be nulled through its option type — this is the only local fix shape.
5. **Workaround 2 shipped + guarded** (nixpkgs packaging): the NixOS python scope on this pin resolves imapclient 3.1.0 for parsedmarc; 3.1.0 assigns `imaplib.IMAP4.file`, read-only since python 3.14 → AttributeError at first IMAP connect. The same rev ships parsedmarc 11.0.1 on python 3.13 where 3.1.0 works; the wrapper pins the unit's `ExecStart` to the py3.13 build (same version/CLI/ini contract). `dmarc-eval` asserts both workarounds (strip-script presence + content, py3.13 pin).
6. **SystemNix C1 complete**: `flake.nix` input `nix-email` pinned to the verified pushed rev `1f8bb52` with `nixpkgs.follows` + compat-doctrine comment; `flake.lock` updated; consumer module repaired (sops path `../../../secrets/` → `../../../platforms/nixos/secrets/` — a real latent break; option-existence guard around the relay wiring since the pin predates the relay option); `platforms/nixos/secrets/nix-email.yaml` created and sops-encrypted in place (3 placeholder keys, matches module references byte-verified); `tests/test-nix-email.nix` eval-contract test (13 assertions, green) registered in `tests/default.nix`; flake attrNames eval confirms `nix-email-contract` present.
7. **README verified-facts ledger +4 entries** (fact + method + date): per-account quota behavior; catch-all vs unknown-recipient ordering trap; IMAP LOGIN resolves by principal NAME (curl-imaps experiment); nixpkgs `[elasticsearch]` emission bug; imapclient/py3.14 bug. Plus the d2 flow line corrected: "files Junk via GTUBE/rules" → "tags X-Spam-Status … no auto-Junk filing" (the old line was an unverified claim).
8. **docs/THREAT_MODEL.md extended** with the attacker-scenario table and the out-of-scope/consumer-responsibilities list; the spam row corrected from "files to Junk" to "tagged, not auto-filed" — every claim in it now points at a shipped mechanism or test.
9. **AGENTS.md gotchas updated**: quota (assert IMAP absence, not SMTP refusal), catch-all ordering, IMAP-login-by-name — replacing an earlier, wrong conclusion of mine (§d-3).
10. **TODO_LIST.md rewritten to reality**: 29 rows deleted (all verified present in tree: relay option/test, CI, DKIM/restart/metrics/backup/journal subtests, negative-cache option, certificate tier, metrics option, httpBind warning, alejandra, aarch64 documentation, THREAT_MODEL, topics, mkDefault root cause, CONTRIBUTING/renovate/git-town, LICENSE, d2 diagram, and more). Surviving rows carry `verified 2026-09-15` stamps (the "verified stamps" TODO row is thereby done).
11. **CHANGELOG.md restructured**: the orphaned pre-`[Unreleased]` body (old session's work, headerless) is now `## [0.1.0] - 2026-09-14` with `### Added`; new bullets added for the delivery-behavior subtests, the parsedmarc-e2e fixes, the two wrapper workarounds, LICENSE, THREAT_MODEL extension.
12. **FEATURES.md synced**: test-suite rows for `parsedmarc-e2e` (was missing entirely) and the new stalwart-e2e subtests; LICENSE row ⚪→🟢; SystemNix consumer wrapper ⚪→🟡 with precise scope.
13. **ROADMAP.md Q3 (license) annotated RESOLVED** (MIT shipped, flip is one file).
14. **Both repos healthy**: `git fsck --no-dangling` clean on nix-email and SystemNix; nix-email master ahead of origin by the session's daemon commits; SystemNix tree fully committed. No pushes (not authorized).

## b) PARTIALLY DONE

1. **SystemNix pin advance**: C1 is functionally complete, but the pin (`1f8bb52`) predates the upstream relay option — the wrapper carries an option-existence guard (commented dead-code) and the contract test carries a PIN NOTE with a tryEval absence-proof instead of the real relay-credential assertions. All of this is one bounded task after the next nix-email push.
2. **parsedmarc-e2e green via workarounds**: the gate depends on two in-repo workarounds for nixpkgs bugs. Both are guarded and ledgered, but the honest end-state is upstream fixes + workaround removal. Also: the test does not yet directly assert the stripped ini (it infers success from parsedmarc starting) — a one-line in-test grep of `/run/parsedmarc/parsedmarc.ini` for `^\[elasticsearch\]` would tighten it.
3. **Docs consistency after the spam-line correction**: the README d2 source was corrected, but the rendered SVGs under `docs/architecture-understanding/` still show the old "files Junk" flow — they were not re-rendered this session.
4. **TODO_LIST aarch64 row**: I re-added "actually run the VM test under qemu-aarch64 once" as TODO. The original row's OR-clause ("or document x86_64-only loudly") was already satisfied, so this row is my reinterpretation — defensible, but it is scope re-inflation and should be consciously confirmed or deleted at the next docs pass.
5. **Upstream filings**: both nixpkgs issues are fully diagnosed with repro (settings-tree eval, generated ini, VM transcript) but NOT filed — needs your authorization per the verify-before-filing gate. Nothing was drafted beyond the ledger text.

## c) NOT STARTED

1. **dmarc-monitor live validation** on evo-x2 (needs the D1 rua-mailbox decision; wrapper + secrets + test are ready for it).
2. **Migration tooling compare** (stalwart-vandelay vs imapsync; D1-gated, needs live mailboxes).
3. **aarch64 actual VM run** (qemu TCG; documented-only posture today).
4. **LICENSE confirmation** (MIT shipped under the earlier mandate; user confirmation pending).
5. **Upstream issue filings** (two nixpkgs issues, diagnosed — see §b-5).
6. **Junk-filing product decision** (§g-3): 0.15.5 tags but does not file; whether the wrapper should own a declarative sieve is an open product question.
7. Everything ROADMAP D1/D2-gated (VPS, Terraform DNS, migration, MX cutover) — untouched, correctly.

## d) TOTALLY FUCKED UP

1. **Two pipe-masked exit codes — including one fake GREEN I reported as verified.** At session start I ran `nix build .#checks.x86_64-linux.parsedmarc-e2e -L | tail; echo EXIT:$?` and reported the dovecot fix "verified green" — `$?` was `tail`'s status, not nix's. The test was red (elasticsearch crash chain) and this session spent hours discovering what an honest exit code would have said immediately. Later the first `nix flake check` background launch piped `| tail -15` the same way. This is the EXACT trap AGENTS.md documents ("gate commands never wear pipes") and that I had already violated in a prior session. Twice in one day, after writing the rule down. The fake green is the single worst failure of the session.
2. **Identifier-perception loop.** Repeatedly "saw" byte differences in identical identifiers (`nix-email.yaml`, `stalwart-fallback-admin`, `relay`), burned multiple verification cycles on phantoms, and — worse — at least once drafted NEW content with corrupted identifiers from memory (the write was rejected, but only the daemon's rejection saved me). The working method that finally held: byte-level `od`/`grep -o` extraction, `test -f` resolution, and git-diff as the final arbiter.
3. **Banked a wrong conclusion as fact.** My first AGENTS.md gotcha said the catch-all account "needs its own real address to authenticate with." The curl-imaps experiment proved login resolves by principal NAME (by-email fails for a name≠email principal). I had to walk the wrong claim back out of AGENTS.md, the test comment, and almost the ledger. Lesson: experiments first, then bank — the reverse order shipped a falsehood into memory files for ~20 minutes.
4. **THREAT_MODEL duplicate.** Created root `THREAT_MODEL.md` while `docs/THREAT_MODEL.md` existed (my handoff summary claimed it didn't exist; I checked root only). The duplicate also asserted the quota/GTUBE subtests in present tense before they were proven. Resolved by merging unique sections into the canonical `docs/` file and trashing my root copy — but the file-existence check cost one write and one trash.
5. **Debug-script churn: three wasted VM runs** before the decisive one. Run 1: nested-quoting traceback (python -c inside succeed). Run 2: sequencing bug — header-checked message B without sending it. Run 3 (spam): probed :25 before the listener was warm. The comprehensive script (wait_for_open_port per listener, one send + per-variant probes, journal dump) answered everything in one run.
6. **Wrong-registry eval.** `nix eval nixpkgs#python314Packages.imapclient.version` resolved the REGISTRY nixpkgs (moving), not the pin → false "4.0.1 available in-pin" conclusion → one wasted build attempt before I caught that `flake.inputs.nixpkgs` was the correct handle. Pinned-rev evaluations must go through the consuming flake's locked input, always.
7. **SystemNix test churn**: first write had a broken runCommand tail (shell-echoing Nix assertions), then a dropped `];` (syntax), then the wrong module shape (flake-parts wrapper imported raw into nixosSystem — needed `.flake.nixosModules.X` extraction + specialArgs), then relay-configured cases that cannot eval against the pin. Five build iterations that a slower first draft would have avoided.
8. **Whitespace-normalization nested a subtest.** One multiedit's old_string matched only whitespace-equivalently and the tool re-indented my replacement, nesting `with subtest("SMTP: full dialogue…")` inside the previous subtest. Caught by reviewing the diff — the tool's "verify the result" note is not optional.
9. **Stale-handoff trust, partially repeated.** The 10:20 handoff was stale in ≥4 places (dovecot fix already applied; delivery subtests already in tree; THREAT_MODEL already in docs/; git already recovered). I verified most of it up front, but still slipped on THREAT_MODEL existence and initially trusted the "subtests genuinely undone" claim until the tree grep said otherwise.

## e) WHAT WE SHOULD IMPROVE

1. **Make the no-pipes rule mechanical.** Gates redirect to a file (`> /tmp/x.log 2>&1; echo EXIT:$?`), never pipe. Every "let me just tail it" is how both fake verdicts happened. A checked shell function or pre-echoed marker (echo the exit INTO the log, then read the log) is the only reliable pattern — this session's honest runs all used it.
2. **Never draft identifiers from memory.** All new code's cross-file identifiers get grepped from source before writing; `git diff` read-back after every multi-line edit; `od` when eyes disagree.
3. **Experiment → then bank.** No claim enters AGENTS.md/README until a reproduction exists (the catch-all auth claim shipped wrong for 20 minutes because reasoning ran ahead of the VM).
4. **Existence checks before creation**: `ls` the whole repo (docs/ included), not the path you assume; the handoff summary is a hypothesis, not a fact.
5. **One comprehensive debug script beats three partial ones**: enumerate the decision points first (what would each variant prove?), then instrument all of them in a single VM run with proper `wait_for_open_port` per listener.
6. **When an experiment overturns a banked claim, sweep for every landing site** (AGENTS, test comments, ledger, threat model) — done correctly for the auth-by-name correction; make it the standard.
7. **Correction ownership**: fake greens and wrong banked claims go into the status report's §d the day they're found, not silently fixed. (This report does that; the 08:40 fake green was only owned here, hours later.)
8. **Eval discipline**: pinned-rev questions evaluate through the consuming flake's locked inputs (`builtins.getFlake` of the local path → `.inputs.nixpkgs`), never through the registry.

## f) Top 50 things to get done next

Sorted by impact; items 1–12 are concrete and unblocked-or-decision-gated, 13–50 are harvested ideas (ROADMAP fuel, not commitments).

1. Push nix-email `master` (24+ commits) — unblocks the SystemNix pin advance and the upstream-fix cycle. **Needs your authorization.**
2. Push SystemNix's local commits (same authorization question — the daemon pushed before, but that state is yours to confirm).
3. Advance the SystemNix `nix-email` pin past the relay-landing rev; restore the relay-credential assertions in `tests/test-nix-email.nix`; delete the wrapper's option-existence guard.
4. File nixpkgs issue: parsedmarc module emits host-less `[elasticsearch]` with `provision.elasticsearch = false` (repro: settings-tree eval + generated ini + VM exit 255; workaround shipped).
5. File nixpkgs issue: parsedmarc broken on python 3.14 via imapclient 3.1.0 (`imaplib.IMAP4.file` read-only; workaround shipped).
6. Decide Junk-filing ownership (see §g-3); if wrapper-owned: declarative sieve (spamtest → fileinto Junk) + upgrade the GTUBE subtest to assert actual Junk filing.
7. Confirm MIT (one word flips TODO_LIST's last BLOCKED row to done).
8. Actually run `stalwart-e2e` once under qemu-aarch64 (or consciously delete the TODO row and keep documentation-only posture).
9. parsedmarc-e2e: add in-test assertion that the runtime ini no longer contains `^\[elasticsearch\]` (tightens workaround coverage from "parsedmarc starts" to "section provably gone").
10. parsedmarc-e2e: tighten the 300 s wait_until for aggregate.json (healthy parse took 9 s — a 120 s bound fails faster and still has 13× headroom).
11. Re-render `docs/architecture-understanding/` SVGs so they match the corrected spam-flow line in README (currently stale vs the corrected d2 source).
12. Add `no-pipes-on-gates` to CONTRIBUTING.md (AGENTS.md has it; the contributor-facing doc should too).
13. dmarc-eval: also assert ExecStartPre ORDER (strip runs after the module's secret-replacement script — today only "last entry" is asserted).
14. stalwart-e2e: assert the over-quota retry journal line (`Mailbox over quota.`) so the `delivery.rs:223` claim is transcript-backed, not comment-only.
15. Ledger entry: mailsuite STARTTLS auto-activation is DONE (§a-7); add the same trap to the parsedmarc module comment in nixpkgs-issue draft (shared root with #5).
16. Pin-advance runbook: one docs/planning note describing the bump procedure (bump both locks together, restore relay assertions, delete guard, `nix flake check` both repos).
17. Add "imapclient upstream release" to that runbook's revert-condition checklist (renovate does not watch python deps inside nixpkgs).
18. THREAT_MODEL: add the catch-all-probing scenario (unknown-local-part enumeration becomes impossible once a catch-all exists — a real anti-enumeration tradeoff worth documenting).
19. sops-key-audit: confirm the three placeholder keys in `nix-email.yaml` surface as rotation-due (expected behavior — verify it actually flags them).
20. Rotate the three placeholder secrets before any live enablement (blocked on D1 anyway).
21. Keep CI's expected-checks list and `flake.nix` checks in lockstep (add a tiny audit test so a new check cannot ship unguarded).
22. Run dmarc-eval on aarch64 in CI (pure eval, cheap) — makes the aarch64 posture more than documentation.
23. stalwart-e2e: consider `directoryCacheTtlNegative` already 5 s — verify the 65 s poisoning subtest cost is purely SPF timeouts (documented) and leave it.
24. Consider a `mail-server` assertion or warning when a catch-all and strict-rejection intent coexist (product-shape question, low priority).
25. Module docs: document quota semantics (accepted-at-SMTP, retried forever) in the wrapper option description, not just the test comment.
26. CHANGELOG: `[Unreleased]` → cut a real version tag when the consumer pin advances (release discipline per go-release skill).
27. GitHub release for v0.1.0 (changelog exists; no release yet) — user decision.
28. CI on push will ingest the entire local backlog at once; consider whether a split push (docs first, then code) is wanted for CI sanity.
29. parsedmarc-e2e: assert the report CSV row count or at least non-trivial size (currently `test -s` only).
30. parsedmarc-e2e: cover a TLS-capable localMail variant eventually (cert fixture) so the production-shaped path (TLS IMAP) is exercised, not just plaintext.
31. docs-health ANNOTATE pass over `docs/status/` — the 10:20 report and this one both go stale fast.
32. TODO_LIST: resolve the aarch64 row ambiguity (confirm re-add or delete).
33. AGENTS.md: add "extract identifiers mechanically" to the gotchas (this session's recurring failure mode).
34. AGENTS.md: add "no new files at repo root without checking docs/ first" (THREAT_MODEL duplicate class).
35. Ledger: cite the mailsuite imap.py line for the STARTTLS auto-activation (currently named file only).
36. Consider a follow-up parsedmarc/mailsuite upstream note: a config knob to disable auto-STARTTLS (the trap generalizes to any cert-less IMAP server).
37. Verify the strip workaround survives a future `services.parsedmarc.settings` shape change — dmarc-eval covers presence; add a "section actually absent from filteredConfig" assertion (eval-level mirror of the awk).
38. `tests/test-nix-email.nix`: assert the integration-registry entry's backup directory equals the wrapper's `outputDirectory` DEFAULT VALUE explicitly (currently compares two eval results — same-bug-shields-both).
39. SystemNix: `services.dmarc-monitor` enable is still NOWHERE — keep it that way until D1; consider a host-comment marking the exact enablement diff.
40. Check whether nixpkgs' parsedmarc module upstream already fixed the `[elasticsearch]` emission on newer revs (informs how loud the upstream issue should be).
41. Same check for imapclient: newer nixpkgs may already carry a py3.14-compatible imapclient (the accidental registry eval suggested 4.0.1 exists) — cite it in the issue.
42. Consider `ref`-less pinning discipline note for `nix-email` input (InboxClean uses `?ref=master`; nix-email uses a hard rev — document why rev-pin won here).
43. README runbook: add the "evo-x2 parsedmarc enablement" checklist pointer to the SystemNix wrapper (the runbook targets raw consumers today).
44. dmarc-eval: assert `provision.localMail` interplay once the live path exists (today's eval config is remote-IMAP-shaped).
45. stalwart-e2e: the alias/catch-all subtests log in via `emails[0]`-style addresses — add one by-NAME login assertion to lock the ledger fact.
46. Feature idea (ROADMAP): parsedmarc reports-dir freshness is monitored, but no Gatus check reads aggregate.json staleness directly (registry backup.maxAgeHours covers it — confirm duplication is avoided).
47. Consider a `system.stateVersion`-style migration note for `mail-server.stateVersion` consumers (unit-name coupling is documented in three places — consolidate).
48. Sweep for remaining "session.data.spam-filter = true"-style stale claims anywhere in docs (grep-driven; the subtest header was fixed, others may linger).
49. `/tmp` debug artifacts (`/tmp/pm-*`, `/tmp/vmdebug*`, `/tmp/strip-scr`) — ephemeral, but the debug SCRIPTS were useful; consider preserving the good one (`/tmp/debug-spam3.py` pattern) as a tests/fixtures debug template.
50. Next session: run docs-health HARVEST on this report's §f (the skill contract — §f belongs in TODO_LIST/ROADMAP, not entombed here).

## g) Questions I cannot figure out myself

1. **Push authorization.** nix-email `master` is 24+ commits ahead of origin and SystemNix carries local commits too; the auto-daemon pushed during prior incidents, but I will not push. The SystemNix pin advance (TODO #1 high-impact row), the upstream-issue cycle, and CI's first real run all key off a push: **do you want me to push (both repos), and if yes, plain or split (docs-then-code)?**
2. **MIT confirmed?** The LICENSE shipped MIT under the earlier blanket mandate; ROADMAP Q3 is annotated resolved-pending-your-word. Confirm, or name the license you actually want (flip is one file + re-push).
3. **Who owns Junk filing?** Verified: 0.15.5 tags spam (`X-Spam-Status`) but never files to Junk. Options: (a) this wrapper ships a declarative sieve for all accounts and the GTUBE subtest upgrades to assert real Junk filing; (b) consumer-side sieve (SystemNix layer); (c) status quo (tag-only, documented). This decides a product behavior and whether the mailsuite/dovecot STARTTLS upstream note should propose a knob alongside it.

---

**Report format note:** the status-report skill's canonical output is a styled HTML dashboard; you explicitly requested `.md`, so this file is Markdown — the override is intentional and not propagated back into the skill.

**Then per the skill: WAITING FOR INSTRUCTIONS.**
