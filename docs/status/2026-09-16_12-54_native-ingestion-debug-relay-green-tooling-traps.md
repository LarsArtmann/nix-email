# Status 2026-09-16 12:54 — Native-ingestion deep-debug, relay-SASL green, three tooling traps verified

Session start ~09:00, report 12:54 CEST. Continuation of session 4's "GET
SHIT DONE" residue: the two unverified VM tests were the headline work.
One went green; the other turned into a forensic debugging session that is
STILL OPEN — four real bugs found and fixed, one mystery remaining.

## a) FULLY DONE (this session)

1. **Recon**: git states re-verified before acting (project rule). Found
   nix-email ahead 1 (docs-only), SystemNix ahead 57→75 (parallel sessions
   VERY active, incl. a queued "broken pre-commit gitleaks gate" report —
   their lane, untouched).
2. **stalwart-relay-e2e VM test: GREEN (EXIT:0, verified via
   `nix build .#checks...` log)** — three fixes were needed:
   - `import "${pkgs.path}/nixos"` rejects `modules` on pinned nixpkgs →
     switched to `nixos/lib/eval-config.nix` (tests/stalwart-relay-e2e.nix:36)
   - `machine.log(...)` eval-forcing line referenced nonexistent `machine`
     node in the two-node test (type-check failure) → `smtp.log(...` (:141)
   - mailpit freeform keys pass through `lib.cli.toCommandLineGNU` VERBATIM:
     `smtpAuthFile` rendered literal `--smtpAuthFile` (unknown flag, exit 1)
     → dashed quoted keys `"smtp-auth-file"` / `"smtp-auth-allow-insecure"`
     (:122-135), binary-probed on mailpit 1.31.0 before editing.
3. **Dependabot PR #1 root-caused**: its failing run 35062650429 died on the
   SAME `unexpected argument 'modules'` eval bug — i.e. master was broken
   when the PR ran; my in-tree fix resolves it. Triage conclusion: push
   master green → `@dependabot rebase` (rebase NOT yet sent).
4. **README verified-facts ledger: 4 new/extended entries** (all with
   method + date): Stalwart TOML fully-quoted dotted header rejection;
   mailpit freeform dashed-flag verbatim pass-through + plaintext-auth
   requires allow-insecure without TLS; `nixos/default.nix` vs
   `eval-config.nix` import trap; swaks `--attach` @-prefix trap (extended
   the existing swaks entry).
5. **SystemNix AGENTS.md**: deploy-key recipe (5-step proven procedure +
   narHash-verify + GH013 caveat) written into "Private Go Repos" section.
6. **Upstream filings re-checked**: nixpkgs #563651/#563652/#563777,
   mjs/imapclient #662 — all OPEN, zero maintainer responses. Nothing to
   action.
7. **Commits**: all session edits are committed (daemon heuristic commits
   — 43ab2f1 latest; earlier fixes were PUSHED to origin by a parallel
   session up to 1bea3b4 09:27, unasked but harmless: the tree was fix-only
   at that point).

## b) PARTIALLY DONE

1. ~~**stalwart-e2e native-ingestion subtest — 4 fixes in, 1 mystery open.**~~
   ~~Progression of the session (5 full VM runs + 3 debug-VM runs + host
   probes):~~ done (mystery SOLVED in 15-21 §a/1: `/api/queue/reports` is the OUTBOUND queue - incoming reports live at `/api/reports/dmarc`; green in `bc7e954`)
   - Run 1: Stalwart crash-looped at boot → `["report.analysis"]`
     fully-quoted TOML header rejected by Stalwart's parser (binary a/b
     probe: bare `[report.analysis]` parses). Fixed: real-attr nesting.
   - Run 2: `jq: command not found` in VM → added `pkgs.jq` to
     systemPackages.
   - Run 3: my poll `jq -e 'length >= 1'` passed VACUOUSLY (response is an
     OBJECT; length=1 even with zero items), detail GET then failed. Fixed:
     `.data.total >= 1` + `.data.items[0].id` (timeout 60→120).
   - Debug-VM run 1: settings API 404 killed script early (informational
     call made non-fatal).
   - Debug-VM run 2: **"Relay not allowed" at MAIL FROM** — my debug script
     had skipped the DOMAIN principal provisioning; fixed script.
   - Debug-VM run 3 (EXIT:0, decisive): message CONSUMED (absent-probe:
     "needle never delivered") proving `is_report`=true + analyze branch
     runs; store stays empty; ZERO IncomingReport journal events → the
     part-matcher found no report part.
   - Host forensics (python SMTP sink + swaks 20240103.0): **`--attach
     <path>` attaches the path STRING as literal data, no `filename=`
     header**; files need `@`-prefix. This silently defeats Stalwart's
     detector (matches '!' / '.xml' in the attachment NAME).
   - Run 4 (probe5): `filename="estadocuenta1...2940.xml.zip"` now sent,
     journal shows **`DMARC report received with warnings`** — parse
     SUCCEEDED. But `/api/queue/reports` STILL returns
     `{"data":{"items":[],"total":0}}` for the full 120 s poll. Subtest
     failed on poll timeout only; the 19 subtests before it green.
   - **Open thread**: write path requires
     `if let Some(expires_in) = report.analysis.store`
     (analysis.rs:272, default "30d") and writes
     `ValueClass::Report(ReportClass::Dmarc{id, expires})`; readout is the
     SAME endpoint the CLI uses (verified cli/src/modules/report.rs:97).
     Next inspection point (was mid-read when interrupted):
     `crates/http/src/management/report.rs` (list handler — suspected
     filter/mismatch between write key and list read) and whether
     "with warnings" (DmarcReportWithWarnings, analysis.rs:396) changes the
     stored format or skips the write.
2. ~~**Host stalwart binary spike** (attempted local debug loop for the same
   question): server boots, config parses (report.analysis warnings seen),
   but listeners never bind (main thread futex-wait after external-resource
   downloads) — abandoned as environment-specific (VM boots fine); store
   dir + config kept at /tmp/st-spike for a later attempt if wanted.~~ **Won't implement — dead end confirmed; AGENTS.md now carries the host-spike DEAD END verdict (debug-VM loop is the premier tool).**
3. ~~**Push/CI**: origin was advanced by a parallel session through 1bea3b4
   (includes relay fixes); my latest commit 43ab2f1 (attach @-fix, poll
   fix, README entries) is UNPUSHED — deliberately: stalwart-e2e is red
   locally, pushing would redden CI (branch protection requires the check).~~ done (pushed as `bc7e954` once green, 15-21 §a/5; CI success)

## c) NOT STARTED (from the session plan)

- ~~Full `nix flake check` (all four checks, unpiped) — blocked on (b).1.~~ done (15-21 §a/4: EXIT:0)
- ~~`git push origin master` + CI watch + `@dependabot rebase` on PR #1.~~ done (15-21 §a/5-6; PR #1 later MERGED 2026-09-16 16:08 UTC)
- ~~CHANGELOG entries for both sessions' work.~~ done (15-21 §a/9 + `2b7257e`)
- ~~HARVEST of plan §10 + 08:16 report + this report into TODO_LIST/ROADMAP
  (docs-health skill to be loaded first).~~ done (`43cd0b4` + `e18758f` + the evening AUDIT)
- ~~Consider removing the debug `cat ... >&2` dumps from the native-ingestion
  subtest once green.~~ **Won't implement — the transcript cats earned their keep across four debugging sessions (12:54/15:21/16:33/18:03); they cost nothing at runtime and pay in debuggability.**

## d) TOTALLY FUCKED UP (honest failures this session)

1. **Two vacuous-assertion bugs I authored myself** in the space of one
   subtest: `jq 'length >= 1'` on an object (burned a full VM run) — same
   FALSE-GREEN class as the gawk `\b` lesson already in AGENTS.md. I
   re-committed the sin the ledger warns about: assert the OBSERVED shape,
   not the assumed one.
2. **rg `-r` footgun**: ran `rg -rln "queue/reports"` — `-r` is REPLACE,
   silently rewrote matches to "ln" and sent me briefly chasing a
   nonexistent `/api/ln` path.
3. **Host spike config thrash**: three restarts (duplicate storage.data,
   empty duplicate [storage] table, missing `storage.directory`) before
   realizing the host-boot hang made the whole spike a dead end. Should
   have gone to the debug-VM loop immediately — it reproduced everything
   with the REAL module config.
4. **One daemon-commit race lost** (tried to commit both test fixes,
   daemon had already taken them as 48e0b8a/bdb300a — content fine,
   message generic). Known hazard, cost only history quality.

## e) WHAT WE SHOULD IMPROVE

1. **Never yield with unverified test code again** — last session shipped
   two "written but never run" tests; this session paid ~3.5 h debugging
   them (5 VM runs). A test that hasn't run is RED, not done.
2. **Negative-test every new assertion pattern against the REAL response
   once** (`.data.total` vs `length`) — same discipline as the pipe-lint
   negative test, not yet mechanized for jq-in-VM.
3. **Debug-VM loop is the premier tool** (custom `--test-script`, ~90 s to
   decisive evidence incl. journal + IMAP probes); host binary spikes of
   Stalwart have a different failure surface (boot hang) — prefer the VM.
4. **python stdlib SMTP sink + base64 decode of swaks's own echo** nailed
   the attach bug in minutes on the host — cheap, keep the recipe (python
   sink script pattern in this session's transcript; NOT yet written into
   AGENTS.md/ledger — the swaks @-lesson IS in the ledger).
5. Parallel-session density is now high (SystemNix +75, pushes of my
   commits by others): re-read file state before EVERY edit held so far,
   but pushing should be coordinated — my unpushed 43ab2f1 is intentional.

## f) NEXT (bounded, roughly ordered)

1. ~~Read `crates/http/src/management/report.rs` list handler; compare with
   `ValueClass::Report(ReportClass::Dmarc{id,expires})` write key
   (analysis.rs:272-335, store/src/write/key.rs).~~ done (15-21 §a/1: handler + openapi.yml read - the endpoints differ, the write path was never broken)
2. ~~Check whether `DmarcReportWithWarnings` path stores a different
   class/skips write (analysis.rs:396 area).~~ done (15-21 §a/1: it stores like any other; the `store` default "30d" holds)
3. ~~If key mismatch is real → likely upstream 0.15.5 bug or a needed
   settings knob (e.g. explicit `report.analysis.store = "30d"`); try the
   explicit setting in the VM test first.~~ **NOT-DO/DUPLICATE — there is no key mismatch; the poll URL was wrong. Ledger entry carries the endpoint truth.**
4. ~~Re-run stalwart-e2e; on green: strip debug dumps, re-run again.~~ done (green `bc7e954`; dumps deliberately KEPT - see c/5)
5. ~~Full `nix flake check` (unpiped, log to file, EXIT recorded).~~ done (15-21 §a/4)
6. ~~Push master, watch CI to green (branch protection on).~~ done (15-21 §a/5, run 35092101106 success)
7. ~~`@dependabot rebase` PR #1; verify its CI goes green; merge or leave
   for user.~~ done (15-21 §a/6; user merged it 16:08 UTC)
8. ~~CHANGELOG entries: pipe-lint + gawk lesson, pins + deploy keys,
   gitleaks allowlists, statix/deadnix sweep, #563777/#662 filings, TLS
   assertion, branch protection, tag trigger, THIS session's four traps.~~ done (CHANGELOG [Unreleased] via 15-21 §a/9 + `2b7257e`)
9. ~~HARVEST: plan §10 + 08:16 report + this file → TODO_LIST.md/ROADMAP.md
   (docs-health skill first).~~ done (`43cd0b4` + `e18758f` + evening AUDIT)
10. ~~Re-check maintainer responses on the 4 filings (next session).~~ done (16-33 §a/1)
11. ~~Write the python-sink swaks forensics recipe next to the debug-VM loop
    in AGENTS.md.~~ done (15-21 §a/10)
12. ~~Consider asserting the benign-journal line count change ("DMARC report
    received with warnings" adds a line — the journal subtest asserts
    EXACTLY 2 config-build errors; verify it does not conflict).~~ done (resolved during the DKIM work: journal-hygiene expectation now 1, `891fa44`)
13. ~~Ledger entry for the host-boot-hang spike finding (if it recurs, it is
    a real trap; one occurrence = note only).~~ **NOT-DO — one occurrence only; the AGENTS DEAD END note covers it per its own condition.**
14. ~~SystemNix: after GH013 unblock → push ~75 commits, watch CI, then the
    deploy-key recipe proves itself in anger.~~ _(routed: TODO_LIST SystemNix row - still user-gated)_
15. ~~User-gated queue: GH013 click, Q6 junk-filing verdict, D1/D2 license
    one-liners, ANNOTATE scope, `syn_` secret-scan policy.~~ ANNOTATE scope: done (evening pass); the rest are standing user decisions / routed rows
16. ~~(If key-mystery turns out to be an upstream bug) file it via
    verify-before-filing + github-voice, cross-link from README ledger.~~ **NOT-DO — it was our endpoint error, not an upstream bug.**

## g) QUESTIONS (cannot resolve myself)

1. ~~**GH013**: will you click the unblock (SystemNix push, ~75 commits
   behind origin now)?
   https://github.com/LarsArtmann/SystemNix/security/secret-scanning/unblock-secret/3JNEaUWN2z6QQokKh8kJ5JbjOXh~~ _(routed: TODO_LIST SystemNix row)_
2. ~~**Native-ingestion budget**: keep debugging to the bottom of the
   store-write/read mismatch (I estimate 1-3 h more), or park the subtest
   (revert it out of stalwart-e2e, keep the ledger findings) until
   upstream clarifies? It is the LAST red item; everything else in the
   repo is green-path.~~ done (solved within the hour: wrong endpoint, 15-21 §a/1 - no budget call needed)
3. ~~**Q6 verdict** (standing from earlier): junk-filing — accept
   per-account sieve (webmail/JMAP) as the answer, or draft the Stalwart
   feature request from the README ledger first?~~ standing user decision (ROADMAP Q6)

## Session artifacts

- Logs: /tmp/stalwart-{e2e,relay-e2e}-probe{,2,3,4,5}.log,
  /tmp/debug-native{,2,3}.log, /tmp/st-spike/* (host spike),
  /tmp/sw-t*.log + /tmp/swaks-host.log (swaks forensics).
- Debug VM scripts: /tmp/debug-native.py (reusable template).
- Failed-run drvs (transcripts via `nix log`): probe5 =
  xm95az1g70qfiib35ynq78i6lgalhmia-vm-test-run-stalwart-e2e.drv.

**WAITING FOR INSTRUCTIONS.**

---

## Resolution addendum (2026-09-16, docs-health pass)

The open mystery this report carried was solved the same day (wrong
endpoint, `bc7e954`); every actionable §f item resolved by sessions 6-8.
Kept deliberately: the debug `cat >&2` transcript dumps (four sessions of
evidence they pay for themselves). Remaining open: SystemNix push row and
the standing user decisions. Archived.
