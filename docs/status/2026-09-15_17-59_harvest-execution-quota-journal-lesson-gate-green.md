# Execution session: §f harvest + tightening sweep, the quota-journal lesson, gate re-green

**Date:** 2026-09-15, session ran ~17:10 → 17:59 CEST (report written 17:59)
**Directive:** "READ, UNDERSTAND, RESEARCH, REFLECT ... Execute and Verify them one step at a time. Repeat until done."
**Scope:** THIS session only - the continuation after the 17:05 handoff report
(`docs/status/2026-09-15_17-05_gate-green-parsedmarc-e2e-recovery-c1-systemnix-wiring.md`).
That report's §f (50 items) was the worklist; its §g questions remain open and
are restated in §g below.
**Method:** every claim re-verified against tree/eval/VM this session; gate
verdicts read from `FLAKECHECK_EXIT` markers in redirected logs (no pipes).

## Headline

The 17:05 report's §f backlog was executed and harvested: TODO_LIST/ROADMAP/
CHANGELOG/FEATURES/ledger are synced, 8 §f items were DONE in-tree, the
aarch64 posture became build-verified (not just documented), SystemNix's
contract test was hardened — and the session shipped one honest failure worth
more than the rest: a new test assertion written from SOURCE instead of a
TRANSCRIPT failed the full gate, was root-caused in a debug VM run, and the
transcript-backed fix is what's green now. **Final gate: `nix flake check`
exit 0, all 4 checks, unmasked.** Nothing pushed (not authorized).

---

## a) FULLY DONE

1. **Gate green at session end, honestly.** `nix flake check` →
   `FLAKECHECK_EXIT:0`, "all checks passed!" (redirected log, exit echoed into
   the file, no pipe anywhere). First run of this session was RED (§d-1);
   the rerun after the transcript fix is the verdict reported here.
2. **docs-health HARVEST of the 17:05 report's §f (its item 50).** All 50
   items classified against the tree: 8 done in-tree this session (below), 4
   already done before this session (CONTRIBUTING pipe rule existed; the
   catch-all subtest already logs in by NAME; stale-spam-claim grep clean;
   the aarch64 TODO-row rewording resolved by keeping+sharpening it), 15
   routed into TODO_LIST (now 15 open rows, every row verified+evidence-
   stamped), 6 routed into ROADMAP, 3 user questions kept in §g.
3. **parsedmarc-e2e tightened (§f-9, §f-10).** The runtime ini is now
   asserted free of `^\[elasticsearch\]` directly (parsedmarc merely starting
   was necessary-but-not-sufficient evidence), and the aggregate-report wait
   dropped 300 s → 120 s (~9 s healthy parse). PASSED in this session's first
   gate run.
4. **dmarc-eval ExecStartPre ORDER assertions (§f-13).** `lib.isList` +
   `>= 2` entries guards, so `lib.last` remains a real ordering proof (on a
   single string entry it would return a CHARACTER). Verified against the
   actual eval: exactly 2 entries — module ini-writer first, strip script
   last. Built green standalone; evaluated in the gate.
5. **aarch64 made real (§f-22 + TODO row).** `nix build
   .#checks.aarch64-linux.dmarc-eval` → **exit 0** (first aarch64 build ever
   in this repo; `nix eval .#checks.aarch64-linux --json` green too), and CI
   gained a fail-closed step that EVALUATES the aarch64 check set (VM checks
   stay deliberately x86_64-gated; building aarch64 in CI would need
   emulation the hosted runner lacks).
6. **Architecture SVGs re-rendered (§f-11).** The stale "files Junk" flow is
   gone: d2 line corrected to the README wording, `nix-email-current.svg`
   re-rendered (`X-Spam-Status (GTUBE/rules)` verified IN the SVG). The
   "improved" SVG was content-diffed against a fresh render of its source:
   36/36 labels identical — only geometry differs (different d2 layout run),
   so it was left untouched.
7. **Docs: THREAT_MODEL catch-all enumeration-tradeoff row (§f-18); AGENTS
   "Working rules" section (mechanical no-pipes pattern, identifier
   extraction, root-file existence check); CONTRIBUTING got the same
   mechanical `> log 2>&1; echo EXIT:$?` pattern.**
8. **Ledger upkeep:** mailsuite STARTTLS cite now carries the line
   (`imap.py:284`); the quota citation corrected `:223` → `:225` (the line
   the reason string actually lives on); BOTH nixpkgs-bug entries now carry
   upstream status verified against CURRENT master: (a) `[elasticsearch]`
   emission still unfixed (same filter, same defaults), (b) imapclient 4.0.1
   (master) dropped the `imap4.py` `open()` override that assigned
   `self.file`, but `imapclient.py:starttls()` STILL assigns it — so 4.x on
   python 3.14 still breaks the STARTTLS-upgrade path
   (`lib/python3.14/imaplib.py:337` is the read-only property). Filing is now
   mechanical.
9. **SystemNix test hardened (§f-38).** The backup-directory contract is
   pinned to the LITERAL `/var/lib/parsedmarc/reports` instead of comparing
   two eval results that one bug could move in lockstep. Contract test
   rebuilt green (`SYSNIX_CONTRACT_EXIT:0`).
10. **Both repos healthy:** everything committed by the auto-daemon (nix-email
    master 46 ahead of origin, SystemNix 2 ahead); `git status` shows only
    the last AGENTS.md touch pending pickup. No pushes.

## b) PARTIALLY DONE

1. ~~**The §f sweep itself:** 8 items done, but 3 consciously deferred: the CI~~ **Won't implement — all three deferred items landed later: lockstep guard (v0.2.0), filings (done), ANNOTATE (2026-09-16 pass).**
   ~~lockstep audit test (TODO_LIST), the upstream issue DRAFTS (diagnosis~~
   ~~complete; drafting gated on filing authorization), and the docs-health~~
   ~~ANNOTATE pass over `docs/status/` (needs user scoping per the skill).~~
2. ~~**aarch64:** the EVAL contract builds for aarch64 and CI evaluates the~~ done (posture decided 2026-09-15 (emulated run attempted; documented-manual))
   ~~check set, but the stalwart VM tests have still never run on ARM~~
   ~~(TODO_LIST row kept, sharpened).~~
3. ~~**The debug-VM tooling:** worked end-to-end (see §d-3 for the fumble), and~~ done (preserved as tests/fixtures/debug-template.py)
   ~~the AGENTS VM-debug-loop command was amended with the correct binary path~~
   ~~(`<output>/bin/nixos-test-driver`) — but the good debug script still lives~~
   ~~in `/tmp` only (TODO_LIST row: preserve as a fixtures template).~~

## c) NOT STARTED (all gated - correctly untouched)

1. ~~Push of either repo (not authorized; nix-email 46 commits ahead now).~~ done (pushed 2026-09-15)
2. ~~SystemNix pin advance + relay-assertion restore + guard delete (blocked on~~ done (done (evening session: pin v0.2.0))
   ~~that push).~~
3. ~~Upstream nixpkgs issue FILING (authorization; diagnosis is current).~~ done (filed (#563651, #563652))
4. Junk-filing ownership implementation (product decision; now ROADMAP open
   question 6 with the three options spelled out).
5. ~~v0.1.0 tag + GitHub release (TODO_LIST row, blocked on push).~~ done (cut: v0.1.0 retroactive + v0.2.0, both released)
6. All D1-gated work: live dmarc validation, migration compare, secret
   rotation + sops-key-audit check, VPS/DNS themes.
7. ~~MIT LICENSE confirmation (user).~~ done (MIT CONFIRMED 2026-09-15)

## d) TOTALLY FUCKED UP

1. **Wrote a test assertion from SOURCE, not from a TRANSCRIPT — the exact
   documented anti-pattern.** I read `delivery.rs:225`, saw the reason string
   `"Mailbox over quota."`, and asserted it in the journal. It is NEVER
   logged at default verbosity; the observable retry signature is
   `Message rescheduled for delivery`. The full gate caught it (exit 1,
   timeout in the quota subtest), a debug VM run produced the real journal
   (`grep -i quota` → nothing), and the fix was transcribed verbatim. This is
   the repo's own rule ("assertions are transcribed from observed transcripts,
   not from expected output — the swaks `<**` vs `<-` lesson") violated by the
   person who had just re-copied it into two docs. Cost: one wasted gate run
   (~9 min) + one debug run. Rule now added to AGENTS working rules.
2. **Documented the assertion as a win BEFORE the gate verified it.** The
   CHANGELOG/FEATURES bullets praising the journal assertion were written
   pre-verification and had to be rewritten after the catch. Docs should
   trail a green gate, not lead it.
3. **Debug-driver invocation fumble:** `nix-store -q --references` on the VM
   test drv yields the driver's `.drv`; I invoked `<drv>/nixos-test-driver`
   (no such file) with errors silenced, then used the realized output path
   but missed the `bin/` prefix. Two dead invocations before the run worked.
   AGENTS now spells out the full path.
4. **Host-side comparison loop wrote an artifact INTO the repo:** the SVG
   text-diff loop used a relative `"$f.txt"`, creating
   `docs/architecture-understanding/...improved.svg.txt` (untracked).
   Trashed immediately. Host-side scratch belongs in /tmp, always.

## e) WHAT WE SHOULD IMPROVE

1. **Transcript-first, mechanically.** No new test assertion without an
   existing log line or a debug run (now an AGENTS working rule; consider a
   CONTRIBUTING line too).
2. **Docs trail the gate.** CHANGELOG/FEATURES entries describing test
   behavior get written (or at least re-read) AFTER the gate is green.
3. **The §f→TODO_LIST/ROADMAP harvest discipline worked exactly as designed**
   — verification-first routing, dedupe against existing rows, evidence
   stamps. Keep it as the default loop for every status report.
4. **Gate-failure triage was fast because the gate was honest:** unmasked
   exit + the failing subtest name + `nix log` pointer in the error. No
   change needed — this entry exists to say the redirect-no-pipes pattern is
   now paying for itself.
5. **Upstream status checks belong in the ledger from day one** (§a-8): a
   workaround without a "still broken on master as of DATE" note invites
   stale filings and stale workarounds.

## f) Up to 50 things to get done next

The 17:05 §f was fully harvested THIS session — most items now live in
`TODO_LIST.md` / `ROADMAP.md` (do not re-harvest this file into duplicates;
dedupe against those first). The genuinely NEW items this session produced:

1. ~~Answer §g (3 questions) — gates 8+ TODO_LIST rows by itself.~~ done (MIT confirmed; pushes executed; Q6 re-posed (ROADMAP))
2. ~~Push both repos once authorized → run CI's first real pass on 46 commits.~~ done (pushed; CI green)
3. ~~After push: advance the SystemNix pin, restore relay assertions, delete~~ done (done (pin v0.2.0 + assertions + guard))
   ~~the wrapper guard, gate both repos (TODO_LIST high-impact row).~~
4. ~~After push: cut `v0.1.0` tag + GitHub release (TODO_LIST row).~~ done (cut + released (both tags))
5. ~~File the two nixpkgs issues once authorized (diagnosis verified vs master~~ done (filed (both))
   ~~2026-09-15; cite imapclient 4.0.1's partial fix + the starttls() gap).~~
6. ~~Junk-filing decision → if wrapper-owned: declarative sieve + GTUBE subtest~~ **Won't implement — re-posed - wrapper-owned impossible (sieve wall); ROADMAP Q6 options a-d, rec c+d.**
   ~~upgrade (ROADMAP open question 6).~~
7. ~~Run `stalwart-e2e` once under qemu-aarch64 (TODO_LIST; eval build already~~ done (attempted; decided documented-manual)
   ~~green — the VM run is the remaining unknown).~~
8. ~~parsedmarc-e2e TLS-capable localMail variant (TODO_LIST).~~ done (TLS node shipped in v0.2.0)
9. ~~Pin-advance runbook note incl. imapclient revert-condition checklist~~ done (README Pin-advance runbook shipped)
   ~~(TODO_LIST).~~
10. ~~CI lockstep audit test: flake asserts CI's expected-checks list matches~~ done (strict lockstep guard shipped (both directions negative-tested 2026-09-16))
    ~~`attrNames checks` (TODO_LIST).~~
11. ~~parsedmarc CSV row-count assertion; negative-cache 65 s cost proof;~~ done (row-count + 65s proof + runbook pointer + fixture shipped; stateVersion verified already-consolidated; pin-discipline note shipped; ANNOTATE = this 2026-09-16 pass)
    ~~README runbook SystemNix pointer; stateVersion-coupling consolidation;~~
    ~~pin-discipline note; debug-script fixture template; docs-health ANNOTATE~~
    ~~pass (all TODO_LIST rows).~~
12. ~~CONTRIBUTING: consider mirroring the transcript-first rule (e-1).~~ done (CONTRIBUTING transcript-first rule shipped (18-17 session))
13. ~~Ledger: note that `nix flake check` reports "omitted incompatible~~ **Won't implement — pairing documented in the CI aarch64 step comment; no ledger bullet needed.**
    ~~systems: aarch64-linux" — the CI aarch64 EVAL step covers exactly that~~
    ~~gap; keep them paired if the flake ever grows more systems.~~
14. ~~Consider making the over-quota subtest ALSO assert the retry keeps~~ done (shipped (SECOND reschedule line proves the loop))
    ~~rescheduling (two `Message rescheduled` lines after a sleep) — today one~~
    ~~line proves "retried at least once", not "forever" (the IMAP-absent probe~~
    ~~carries the rest).~~
15. ~~The 17:05 report's remaining §f items that are ROADMAP fuel (viewer,~~ done (ROADMAP carries them (viewer DEFERRED, freshness dedup noted))
    ~~Gatus freshness, DMARC ladder, etc.) — see ROADMAP; nothing new to add.~~

## g) Questions I cannot figure out myself

1. ~~**Push authorization** (unchanged from 17:05, now more urgent): nix-email~~ done (pushes executed (plain))
   ~~`master` is 46 commits ahead of origin; SystemNix 2 ahead. Push both?~~
   ~~Plain or split (docs-then-code) for CI's first run?~~
2. **Junk-filing ownership** (now ROADMAP open question 6): 0.15.5 tags
   `X-Spam-Status` but never files to Junk. (a) wrapper-owned declarative
   sieve (GTUBE subtest upgrades to assert real Junk filing), (b) consumer-
   side sieve in SystemNix, or (c) tag-only as the documented end state?
3. ~~**MIT confirmed?** LICENSE shipped MIT under the earlier mandate; one word~~ done (MIT CONFIRMED 2026-09-15)
   ~~flips the TODO_LIST row to done (or names the license you actually want).~~

---

**Report format note:** the status-report skill's canonical output is a styled
HTML dashboard; you explicitly requested `.md`, so this file is Markdown — the
override is intentional and not propagated back into the skill.

**Then per the skill: WAITING FOR INSTRUCTIONS.**

---

## Resolution addendum (2026-09-16, docs-health pass)

All items resolved inline except the standing user decisions: g/2
(spam→Junk - ROADMAP Q6) and the D1/D2-gated block (c/6, ROADMAP themes).
Archived.
