# Status Report: Upstream-Watch Re-check and the #566282 Persistence Finding

_2026-10-19 03:59 CEST. Scope: THIS session only (user-directed upstream-watch
re-check of the five external issues in the README ledger). Per instruction,
no unrelated project research was performed; items noticed in passing are
labeled by source. Format `.md` at explicit user demand (HTML is normally
canonical for status reports)._

## What this session did (one paragraph)

User pasted the README "External upstream issues" section and asked to
"check all for updates". I re-checked all five filings via the GitHub API
(state, comments, events, timelines), re-evaluated the version surface
(`nix eval`: our pin `6774f7bc` vs nixpkgs master), fetched and grepped the
reworked master `parsedmarc.nix` and parsedmarc's `cli.py`, proved the
#563651 bug shape SURVIVES the upstream rework (host-less `[opensearch]`),
and refreshed the four local doc surfaces that had drifted (README ledger,
module comment, TODO watch row, CHANGELOG). All gates green.

## The one material finding

**The merged #566282 rework (2026-10-13) did NOT fix #563651 - it renamed
it.** Master dropped `provision.elasticsearch` (`mkRemovedOptionModule`, so
the filed repro no longer evals) in favor of `provision.opensearch`
(default TRUE). But with `provision.opensearch = false` the module still
materializes a host-less `[opensearch]` section (unconditional `ssl=false`
and `cert_path` defaults survive the null filter) and parsedmarc still
exits 255 ("hosts setting missing from the opensearch config section",
`cli.py:1175-1183` on parsedmarc master, verified 2026-10-19). Our wrapper
breaks at the FIRST pin past `22579286`: `provision.elasticsearch =
mkDefault false` (modules/dmarc-monitor.nix:106) becomes an eval throw and
the strip guard reads the dead option. Port procedure: README runbook step
2 (already written by the 2026-10-16 session).

## Issue-by-issue verdict (all re-checked today)

| Filing                              | State                           | Movement since last ledger entry                                                                                     |
| ----------------------------------- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| nixpkgs#563651 host-less ES section | OPEN, 0 comments, no linked PRs | MATERIAL: option removed on master by #566282; bug persists as `[opensearch]`                                        |
| nixpkgs#563652 imapclient py3.14    | OPEN, 4 comments                | Only a title rename (2026-10-01); retirement ARMED: master ships imapclient 4.1.0, pin still 4.0.1 (`nix eval` both) |
| nixpkgs#563777 no Restart policy    | OPEN, 0 comments, no linked PRs | None; reworked master module still greps 0 for `Restart`                                                             |
| mjs/imapclient#662                  | CLOSED (2026-09-18)             | None, as expected                                                                                                    |
| mailsuite#65 auto-STARTTLS          | OPEN, 0 comments                | None; no maintainer response in 14 days                                                                              |

Version surface: pin `6774f7bc` = imapclient 4.0.1 + parsedmarc 11.0.1;
master = imapclient 4.1.0 + parsedmarc 11.0.2. Stalwart surface untouched
this session (no research per scope).

## a) FULLY DONE

1. Session-start baseline ritual (git status clean - daemon had committed
   `b598703` before my edits; five concurrent crush sessions noted; same-day
   reports 02-16 and 02-35 identified and left alone).
2. All five filings re-checked mechanically: `gh api` for state, comments,
   events, and timelines (timeline sweep proved zero linked PRs on
   563651/563777; the 563652 "movement" was a title rename, not substance).
3. Version claims re-proven with `nix eval` (imapclient and parsedmarc on
   pin and master; imapclient latest release 4.1.0 confirmed via releases
   API - no 4.1.1).
4. Master module fetched and grepped, not eyeballed: `mkRemovedOptionModule`
   present, `provision.opensearch` default TRUE, `ssl`/`cert_path` still
   unconditional, `grep -c Restart` = 0.
5. The persistence proof chain closed end-to-end: module shape (nixpkgs
   master) + parsedmarc rejection (`cli.py` opensearch branch, fetched from
   domainaware/parsedmarc) + our wrapper's exposure point (exact lines).
6. Discovered the 2026-10-16 session had ALREADY updated runbook step 2 and
   the TODO watch row for the #566282 merge - so my updates layered on top
   instead of duplicating (the ledger bullets were the stale surfaces).
7. Four doc surfaces refreshed in one pass: README ledger (all five
   bullets), `modules/dmarc-monitor.nix` UPSTREAM comment block (code-side
   retirement condition), TODO_LIST watch row (evidence cell, 2026-10-19
   facts), CHANGELOG `[Unreleased]` Changed entry.
8. Quality gates all green: `buildflow format` (exit 0, 21 steps success),
   `scripts/check-md-table-pipes.sh` (exit 0), `nix fmt -- . --check`
   (alejandra, exit 0), `git diff` read-back after the formatter pass, and
   a table cell-count check on TODO_LIST (43 rows, all 5 cells - no dropped
   cells).

## b) PARTIALLY DONE

1. **The upstream-watch loop is half-closed**: local truth is fully **→ TODO_LIST watch row (pending #563651 follow-up comment, owner go-ahead)**
   updated, but upstream is not informed. nixpkgs#563651 is now misleading
   to any reader (its repro eval-throws on master) and WE hold the
   correction (the opensearch persistence proof). Posting needs your
   go-ahead (outbound filing rules: verify-before-filing + github-voice).
2. **dmarc-monitor.nix**: comment updated, code deliberately NOT ported **→ port decision rides the pin advance (README runbook step 2); gates eval-prove the comment-only edit every run**
   (the current pin still needs the elasticsearch shape - porting now would
   break the pin). The forward-compatible option (dual-strip both section
   names) was identified but not decided or built.
3. **mailsuite#65**: issue state re-checked, but the underlying **→ TODO_LIST watch row (pre-bump re-verify added 2026-10-23)**
   "master `imap.py` byte-identical at the quoted lines" claim (verified at
   filing, 2026-10-05) was NOT re-verified today. Trusted the filing-date
   verification; acceptable, but it is a residual un-re-checked fact.

## c) NOT STARTED (noticed this session, zero work done)

1. Follow-up comment / retitle on nixpkgs#563651 (the persistence finding). **→ TODO_LIST watch row (owner go-ahead + filing gates first)**
~~2. Mechanical eval-safety proof for the touched module file: I reasoned~~ done — dmarc-eval green in every gate since (incl. CI 2026-10-22)
   "comment-only cannot affect eval" instead of running the ~10s
   `dmarc-eval` check. Doctrine prefers mechanical proof.
~~3. `annotate.go check-rows`: not located this session (not in~~ done — AGENTS records the invocation (formatter rule)
   `scripts/`, not on PATH). The dprint pass DID touch the other session's
   02-35 report (cosmetic-only: blank lines after list intros, `*x*` to
   `_x_`; verified benign by diff read, no struck rows involved).
4. The actual pin advance carrying #566282 (bump-gated; owned by the **→ README runbook step 2 (bump-gated; TODO_LIST SystemNix row)**
   runbook, not this session).
~~5. HARVEST of this report's section (f) into TODO_LIST - deliberately~~ done (docs-health pass 2026-10-23)
   deferred because you instructed WAIT FOR INSTRUCTIONS.

## d) TOTALLY FUCKED UP

1. **I broke the TODO_LIST table mid-edit.** My first multiedit spliced a
   NEW cell into the watch row (6 cells instead of 5) instead of editing
   the evidence cell. Caught it on the very next read-back and fixed it
   within one minute - but for that window the table was malformed, and the
   auto-commit daemon could have snapped it up mid-window (it did not).
   Root cause: I composed the replacement cell string without counting the
   row's columns. Inexcusable in a repo where dprint EATS overflow cells.
2. **A draft remnant shipped in a real command.** One bash call contained a
   vestigial draft shim (`fetch() { :; }`) plus a grep of a /tmp file that
   did not exist. Pure noise, a wasted round-trip, and sloppy tool
   discipline.
3. **Wrong-path fetch by assumption.** First parsedmarc source fetch used
   `src/parsedmarc/config.py` (404 - wrong layout guess). The code-search
   call I ran IN PARALLEL found `cli.py` instantly; the 404 contributed
   nothing.
4. **Reasoning where a check was cheap.** Touched a `.nix` file and proved
   eval-safety by argument ("comments only") + alejandra instead of
   building `dmarc-eval`. The repo's own doctrine is transcript-over-
   reasoning. Low risk this time, wrong habit.
5. **One clunky prose wrap survived into the README.** The 563652 bullet's
   reworded middle ("...still ships 4.0.1 on / py3.13 AND py3.14
   (`nix eval`), so the / py3.13 pin retires...") is dprint-legal but
   reads badly. dprint fixes geometry, not sentence flow; I should have
   re-read my own sentence after the formatter pass.

## e) WHAT WE SHOULD IMPROVE

~~1. **Count table columns BEFORE composing edits** - or edit only the inner~~ **NOT-DO — process note, consumed.**
   text of the target cell, never splice cell boundaries. (Direct fix for
   d1.)
~~2. **Mechanical proof over argument, even for trivial diffs**: after ANY~~ **NOT-DO — process note, consumed.**
   `.nix` touch, build the cheapest affected check. (d4.)
~~3. **List layout before fetching by assumption**: `gh api .../contents` or~~ **NOT-DO — process note, consumed.**
   code search first, raw-file fetch second. (d3.)
~~4. **The upstream watch must refresh ALL surfaces in one pass.** The~~ done — watch row + ledger + module comment updated together (2026-10-19 and 2026-10-23 passes)
   10-16 session updated the runbook + TODO row but left the README ledger
   bullets stale for three days - a runbook/ledger split-brain. New rule
   candidate for AGENTS working rules: a watch re-check updates ledger,
   row, and module comment together or not at all.
~~5. **The rework fact now lives in FOUR places** (README ledger, runbook,~~ done — all four surfaces carry it; the runbook owns the retire-together port
   TODO row, module comment). AGENTS designates the ledger as owner and
   the module comments + runbook as retirement sites, so this is
   sanctioned - but when the pin advances, all four need the retirement
   edit in the same change. Consider a `grep -rn '566282'` pre-flight
   before the bump (mirrors the existing check-inventory pre-flight).
~~6. **Locate `annotate.go check-rows` now**, not during a future formatter~~ done — AGENTS records the invocation
   fire; record the command in AGENTS.md if it is devShell-only.
7. **Upstream silence handling**: two filings (563651: 34 days, mailsuite#65: **→ TODO_LIST watch row (nudge policy rides the row)**
   14 days) have zero maintainer response. Define a bump policy (e.g. after
   N days, post the nudge with new evidence) instead of deciding it fresh
   each time.
~~8. **No ghost systems created** (no code added) and **no split brains~~ **NOT-DO — confirmation note.**
   introduced** - this session actually closed one (runbook knew, ledger
   did not). No useful code removed. Scope stayed inside the user's bounds
   (no unrelated research).

## f) Things we should get done next (up to 50; brainstorm, not commitments)

Source tags: `[S]` = direct follow-up from THIS session; `[T]` = existing
TODO_LIST row read during this session (not re-verified today); `[N]` =
noticed in passing. Impact-sorted within groups.

### Session-direct (the upstream-watch thread)

1. `[S]` Post the nixpkgs#563651 follow-up: #566282 removed the filed **→ TODO_LIST watch row (owner go-ahead + verify-before-filing + github-voice)**
   repro, but the host-less shape persists via `provision.opensearch =
   false` (quote cli.py + the module defaults); propose guarding
   `ssl`/`cert_path` behind `mkIf cfg.provision.opensearch` or filtering
   the section in `filteredConfig`. Gates: verify-before-filing,
   github-voice. (~15m)
2. `[S]` If 1 is approved, retitle/re-scope #563651 in the same comment **→ TODO_LIST watch row (rides the follow-up comment)**
   (the elasticsearch repro is dead on master; the issue survives as the
   opensearch shape).
3. `[S]` Decide the wrapper port strategy NOW so bump day is small: **→ owner call at bump planning (README runbook step 2 owns the port)**
   (a) strict runbook port at bump time (no dead code, bigger blast
   radius), or (b) forward-compatible dual-strip (strip `[elasticsearch]`
   AND `[opensearch]`, option-shape-aware condition) landing before the
   bump (smaller bump, small YAGNI cost). Owner call.
~~4. `[S]` Add a dmarc-eval assertion pinning the strip's CONTRACT: rendered~~ done — parsedmarc-e2e asserts the rendered ini [elasticsearch]-free; dmarc-eval pins the strip-script content
   ini contains NEITHER `[elasticsearch]` NOR `[opensearch]` when
   provisioning is off (today only the VM e2e sees the rendered ini).
   (~30-45m)
~~5. `[S]` Build `dmarc-eval` once to mechanically confirm the comment-only~~ done — green in every gate since
   module edit is eval-clean (~10s; closes c2/d4).
~~6. `[S]` Locate `annotate.go check-rows` (devShell?) and record the~~ done — AGENTS records the invocation
   invocation in AGENTS.md. (~10m)
~~7. `[S]` AGENTS.md working-rules candidate: "a watch re-check refreshes~~ done — folded into the TODO watch row text (2026-10-23; AGENTS is at its 220-line cap)
   ledger + TODO row + module comment in the same pass" (2-line edit,
   prevents the next runbook/ledger split-brain).
8. `[S]` AGENTS.md pre-flight candidate for the bump: `grep -rn '566282' **→ README runbook step 2 owns the retire-together port**
   .` before a pin advance - four surfaces must retire together.
9. `[S]` Re-verify the mailsuite#65 quoted lines against mailsuite master **→ TODO_LIST watch row (added 2026-10-23)**
   before any bump that advances parsedmarc/mailsuite (the auto-STARTTLS
   trap gates future plaintext-hop consumers). (~10m)
10. `[S]` mailsuite#65 nudge policy: if still silent by ~2026-11-05, post **→ TODO_LIST watch row**
    a one-paragraph bump with any new evidence (your call, your voice).
11. `[S]` Next scheduled watch re-check: fold into every pin advance + **→ TODO_LIST watch row (cadence + evidence-cell dating)**
    a monthly cadence, and log each re-check date in the watch row's
    evidence cell (the row now carries the 2026-10-19 set).

### The mandatory bump work (existing plan, sharpened by this session)

12. `[T]` Pin advance past `22579286` (when nixpkgs moves): MANDATORY port **→ TODO_LIST SystemNix pin row + README runbook step 2**
    - rename `provision.elasticsearch` to `provision.opensearch = mkDefault
    false`, re-point the strip guard, verify the shipped section name,
      re-verify imapclient >= 4.1.0 and revert the py3.13 pin (ExecStart
      mkForce + dmarc-eval pin assertion), rerun dmarc-eval + parsedmarc-e2e.
13. `[T]` Same bump: re-check the dovecot2.protocols rename warning **→ rides the bump; triaged upstream-not-actionable (2026-10-19 07-18 session)**
    disappeared (runbook predicts it dies with the rework).
14. `[T]` Same bump: Stalwart surface re-check per runbook step 2 bullet 3 **→ README runbook step 2 bullet 3**
    (vendored module retirement when #552103 lands in the pin; 0.16 object
    shapes if `stalwart_0_16` moves; C45 overlay question).
15. `[T]` Cut v0.5.0 (C43-gated): annotated tag, tag-CI, gh release; **→ TODO_LIST v0.5.0 row**
    sequenced dry-run of the release procedure on a scratch tag first;
    Unreleased date/link pass.
16. `[T]` SystemNix consumer pin advance to v0.5.0 (runbook step 3; their **→ TODO_LIST SystemNix pin row**
    repo, their cadence; flake-parts dedupe decision rides along).

### Existing TODO rows noticed this session (not re-verified today)

~~17. `[T]` migrate-e2e run 7: instrumented artifact dumps~~ done — fixed + green 9/9 (W1, 2026-10-19)
    (`migration-v016/config.json`, `recovery.log`), root-cause the
    post-migration exit-101 "multi-step process" panic, fix
    `stalwart-migrate-from-015`, run to green. (IN_PROGRESS, High, the one
    open product bug.)
18. `[T]` C42: dmarc-monitor retire-or-keep - one stalw.art docs fetch **→ decision-batch C42 (evidence complete)**
    (0.16 inbound failure parsing) settles the last unknown. (~15m)
19. `[T]` C44: real-host account-secrets doctrine (sops-rendered apply vs **→ decision-batch C44**
    admin-created vs credential-file secret type). (~1h)
20. `[T]` C45: 0.16.22 vs 0.16.26 overlay decision + the delta table next **→ decision-batch C45 (delta table written)**
    to it. (~1h)
21. `[T]` C39: MemoryMax ownership decision, then document. (~30m) **→ decision-batch C39**
~~22. `[T]` Provision vs resolv.conf boot race: real-host verdict before any~~ done — DECIDED as doctrine (W14: DnsResolver singleton, not ordering)
    unit reorder (demo already pins the Cloudflare resolver).
~~23. `[T]` Match-property audit REMAINING: wrapper option-surface review~~ done — X6 closed 2026-10-19 (zero dead options; ledger line existed)
    (which 0.15-era wrapper options are dead under 0.16) + the
    snapshot-vs-wrapper matchOn divergence ledger line.
24. `[T]` dmarc-monitor live validation against a real IMAP mailbox **→ TODO_LIST (D1-gated row)**
    (D1-gated; first poll, JSON/CSV output lands). (~1h)
~~25. `[T]` dmarc-eval: unit-hardening shape assertions (DynamicUser,~~ done — W9 drop-detectors + negative self-test
    SystemCallFilter, RestrictAddressFamilies) so a pin advance that drops
    them fails loudly at eval speed. (~45m)
26. `[T]` CI python-lint gate residue: bandit/vulture scope doctrine + **→ TODO_LIST CI python-lint row (owner blessing)**
    whether buildflow's deeper ruff ruleset (PERF/FURB/BLE) joins the CI
    floor (owner blessing).
~~27. `[T]` PR #552103 watch: when it merges into the pinned rev, retire~~ done — TODO_LIST watch row carries the retirement checklist
    `modules/stalwart-module/` (restore `meta.doc` + `partOf`, drop the
    ExecStartPost patch; header checklist).
~~28. `[T]` Consider posting our ExecStartPost-restart + bootstrap-fallback~~ done — filed 2026-10-19 (comment 6258512488, W12.2)
    transcripts as PR #552103 evidence comments (verify-before-filing
    first).

### Noticed in passing

~~29. `[N]` The 02-35 session's contacts-assessment follow-ups (0.16.22 vs~~ done — that thread closed 2026-10-19 (probes + FEATURES rows + AGENTS pointer)
    0.16.26 crates diff; CardDAV demo transcript probe; the SOCIALPROFILE
    edge) - owned by that session's thread; harvest only if orphaned.
~~30. `[N]` Honesty note: I read TODO_LIST only to line 60 - the "Low Impact~~ **NOT-DO — point-in-time note; later passes inventoried the full file.**
    (hygiene)" rows BELOW the watch row were NOT inventoried this session.
~~31. `[N]` HARVEST this report's f-list into TODO_LIST/ROADMAP once you~~ done (docs-health pass 2026-10-23)
    answer g1-g3 (skill-mandated close-out; deliberately deferred per your
    WAIT instruction).

(31 items: the honest, grounded set. Padding to 50 with unverified filler
would violate the no-new-research scope and the ledger's no-fabrication
rule - the remaining ~19 candidate slots are ROADMAP fuel only if you ask
for a sweep.)

## g) Questions I can NOT figure out myself

1. **Upstream engagement**: Do you approve posting the #563651 follow-up **→ TODO_LIST watch row (pending owner go-ahead)**
   comment (the opensearch persistence proof + the mkIf fix proposal), and
   if yes, do you want the issue retitled/re-scoped in the same comment?
   This is outbound under your name and gated on your two filing skills -
   I will not post without your explicit go.
2. **Port strategy**: dual-strip forward-compat in the wrapper BEFORE the **→ owner call at bump planning (runbook step 2)**
   bump (smaller bump day, tiny YAGNI cost), or strict runbook port AT the
   bump (zero dead code, bigger blast radius on a day that already carries
   the imapclient un-pin)? Both are defensible; the answer changes what I
   would build next.
3. **Scheduling**: when is the next nixpkgs pin advance planned, and **→ owner call (TODO_LIST v0.5.0 + SystemNix pin rows)**
   should the mandatory #566282 port ride the v0.5.0 release (C43) or land
   as a separate pre-release bump commit? I cannot infer your release
   appetite or SystemNix's cadence.

---

_Verification trail for every claim above: gh api outputs (issues,
comments, events, timelines, releases), `nix eval` runs (imapclient +
parsedmarc on pin and master), fetched-and-grepped sources (master
`parsedmarc.nix`, parsedmarc `cli.py`), and the local diff/gate read-backs.
No claim in this report comes from memory alone. Report written 2026-10-19
03:59 CEST; session work ran ~02:16-02:50 CEST._
