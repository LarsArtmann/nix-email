<!-- Status snapshot 2026-10-30 20:29 CET. Scope: THIS session only
     (18:33 -> 20:29), a docs-health AUDIT pass (skill loaded first).
     Baseline ritual ran at 18:33: tree clean except ONE STAGED foreign
     file (the 18:26 deliverability report, mtime 4 minutes old - its
     owning session was LIVE, so the file was never touched); 20+
     concurrent crush processes; corridor scan found no other same-day
     reports. Gate state at yield: eval-level `nix flake check --no-build`
     EXIT 0, ruff floor (CI's exact pinned-rev command) PASS, alejandra +
     dprint --check green, md pipe lint green, annotate check-rows green
     on every touched file. Working tree clean at write. -->

# Status: docs-health corridor pass - 12 archived, CI red fixed, living docs truth-up (2026-10-30 20:29)

## 0. TL;DR

| Area              | Verdict                                                                                                                                             |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| CI                | Found origin RED on master (run 40991974714), root-caused to the failing STEP (ruff F841 x2, 10-29 CalDAV probe), fixed (14934ac), floor re-run green |
| ANNOTATE          | ~370 inline verdicts across 13 corridor files (status-items / repair / house prose grammar), check-rows green per file                                 |
| ARCHIVE           | 12 files moved with manifests (11 status reports 2026-10-23 -> 10-28 + the exhausted Y-plan); completeness gate silent; 4 reports kept live BY DESIGN  |
| Living docs       | TODO_LIST: 4 dead rows deleted + structural repairs; FEATURES: 4 rows corrected; ROADMAP: +1 open question, +1 backlog line; CHANGELOG: pass entry      |
| Gates             | All green at yield (see header)                                                                                                                        |

## a) FULLY DONE (verified this session, evidence cited)

1. **Red CI triaged and fixed** (the pass's only code change): `gh run
   view --log-failed` on 40991974714 (2026-10-30 02:29, a daemon-swept
   commit) named the failing STEP - the fail-closed ruff floor, two F841s
   in `docs/probes/2026-10-29-caldav-01626/caldav_probe.py:309,364`
   (`etag2`, `etag1b`, assigned but never read). The owning session had
   landed 2026-10-29 22:30 (no live caldav processes), so the
   error-class cross-session fix was per doctrine: two dead lines
   removed, committed same-call (`14934ac`), then the CI ruff floor
   re-run LOCALLY with the exact CI command (`nix run
   github:NixOS/nixpkgs/fe132422#ruff -- check --select E4,E7,E9,F` over
   `git ls-files '*.py'`): "All checks passed". Origin stays red until
   the next push (assistants never push).
2. **Full corridor re-read before any verdict** (the 10-23 pass's keep):
   all 15 live status reports (2026-10-19 -> 10-30) + 4 planning files +
   decision-batch spot-checks + the 3 drafts, each `view`-registered
   (the mtime guard armed). The two X-generation parents (12-17 + 14-19)
   were read in full and confirmed as the pbx owners (their own arrows
   defer their archive to the blessing).
3. **Living-docs truth-up, every claim verified against code/git/CI
   before the edit**:
   - TODO_LIST: deleted the four DONE/STALE rows (v0.5.0 cut row -
     RELEASED 2026-10-28 per tag `v0.5.0` + release commit `06ab701`;
     SystemNix pin-advance row - premise superseded 2026-10-28; C45 row -
     superseded, the pin ships stalwart_0_16 0.16.26; gh-auth row - LIVE
     again, re-verified with `gh auth status` this session). Folded the
     two orphaned table rows back into the Medium Impact table; removed
     the emptied "0.16 release path" section; repaired the `>`-split
     blockquote that broke the 2026-10-30 note mid-sentence; updated the
     owner-sitting row (C43 answered, C45 gone); re-dated the sweep
     banner to this pass.
   - FEATURES: SystemNix consumer row rewritten (floats master,
     `nixpkgs.follows` contract, v0.5.0 shipped); gate row 11-check ->
     12-check set (deliverability-e2e, verified against
     `tests/check-expected.json`); CI currency (green through run
     40861706874 of 2026-10-29, then the red + this fix); the mail-server
     "Native DMARC report ingestion" row now names native ARF ingest
     (runtime-verified 2026-10-26, subtest 16b).
   - ROADMAP: NEW open question 9 (the 2026-10-25 store-doctrine trio:
     cluster horizon / backup-doctrine ownership / durability - routed
     where three owner questions had lived unrouted for five days); NEW
     theme-6 line (the 2026-10-24 exporter-hardening backlog, harvested
     from the archived 19-03 report's f-list).
   - Z-plan O2 row: the seven 2026-10-26 coverage additions (C36/C37/Q5,
     flood, rename, cadence, AGENTS cap) folded into the task line -
     the exact drift the 21-40 report confessed (its d/2) and left open.
   - CHANGELOG: `[Unreleased]` Added entry for this pass (ridden into a
     daemon commit - see d/3).
4. **ANNOTATE over the resolved corridor** (~370 verdicts): every
   b/c/f/g item in the 2026-10-23 -> 10-28 reports carries a dated
   `~~done~~` / `~~routed~~` / `~~NOT-DO~~` verdict; a/d/e sections stay
   bare (house precedent, 03-34 archive shape); the tool pipeline was
   emit-keys -> spec -> `status-items --verify` -> apply -> check-rows
   per file, dry-run-first where the tool supported it. The 10-28
   pin-advance report got inline strikes for the closure its own Appendix
   1+2 had only recorded as an appendix (the skill's #1 failure mode,
   appendix-only, now closed). The kept-live 10-23 docs-health report
   got strikes for its 19 CLOSED f-items only - its open items stay bare
   as the open signal.
5. **ARCHIVE (12 files, gates before the move)**: 11 status reports
   (2026-10-23_16-10, 10-24 x2, 10-25, 10-26 x6, 10-28) -> `docs/status/
   archived/`; the Y-generation plan -> `docs/planning/archived/` with a
   per-task Appendix R (46 rows: 24 DONE, rest SPLIT/ROUTED). Bulk
   check-rows 12/12 green BEFORE `git mv`; manifests appended to both
   archive READMEs; `grep -L '~~'` over the moved files silent (one
   prose-annotated file initially failed the gate - fixed by converting
   its append-verdict to the struck form, then amended).
6. **Gates at yield**: eval-level `nix flake check --no-build` EXIT 0 on
   the final docs tree; `nix fmt -- . --check` green (alejandra +
   dprint); `scripts/check-md-table-pipes.sh` green; check-rows green on
   every annotated file; the CI ruff floor green (a/1).
7. **2026-0\* glob honored at the level the skill allows**: the literal
   `*2026-0*` pattern matches 45 files, ALL already archived (closed
   history) or architecture diagrams (routed to the standing ROADMAP
   audit row) - verified mechanically (`grep -L '~~'` over the archived
   subset + `ls`), not re-read (skill rule: no reopening closed
   archives). The one ~~-less archived file is a 2026-09-22 plan-class
   document (planning corridor precedent: Appendix dispositions, not
   strikes). The live October corridor was read in full (a/2).

## b) PARTIALLY DONE

1. **The kept-live reports' arrows are now partially stale**: 12-17 and
   14-19 route several f-items at rows that have since LANDED and been
   deleted (ping x2, relay bounce, TLS breadth, runtime-trim, the v0.5.0
   row). Their dispositions live in CHANGELOG (dated 2026-10-26/28), but
   a reader following the arrow hits a missing row first. I deliberately
   did NOT re-annotate live files a second time this pass (archive is
   deferred anyway) - recorded as an open question (g/1).
2. **README verification was spot-wise, not line-by-line** (the standing
   F6 residue): banner, check list (12 names), ARF ledger cluster, and
   the sections this pass touched were verified; the 10-23 pass's "never
   read end-to-end" caveat still stands, now with three consecutive
   spot-passes (10-23/28/30) on the drift-prone surfaces.
3. **The TODO standing rows were kept on last-known evidence**: I
   verified every kept row against recorded state, but did NOT re-check
   the upstream watch freshness today (#552103/#563651/#563777/
   mailsuite#65 last re-dated 2026-10-26/28; the ~11-05 nudge decision
   is four days out).
4. **The 21-40 "two stale documents" fix is 2-of-2 only after this
   pass**: TODO's sweep note was already updated 2026-10-26 21:07; the
   Z-plan O2 line was fixed here. The sheet's OWN header still says
   "answer with IDs only" for a decision set that shrank twice
   (C43/C45) - the sheet carries its own audit trail, so I left the
   instrument itself untouched (owner-facing file).
5. **Daemon narrative recovery**: the 11-26 annotations, the Y-plan
   Appendix R, and the CHANGELOG entry landed via daemon heuristic
   commits (a31a8a2 and neighbors) after the daemon outran my explicit
   commit - content verified byte-intact, messages generic (d/3).

## c) NOT STARTED (all routed, none forgotten)

1. Every owner-gated row (C42/C44/C39/C41/C46, pbx blessing, D1/D2,
   Resend, Renovate, branch protection, Discussions, qcow2 purge,
   REPORT-RENAME, REPORT-CADENCE, AGENTS cap) - the sitting sheet owns
   them; this session deliberately consumed no owner decision.
2. Their-repo lanes (BuildFlow upstream batch incl. the jscpd exclude
   question, SystemNix CI debt, SystemNix deliverability wiring) -
   TODO rows, their cadence.
3. The filings queue (#552103 webui comment owner-review-gated;
   #563651 follow-up ON HOLD per owner; mailsuite nudge ~11-05;
   dnsmasq venue + transcript) - TODO rows.
4. TELEMETRY.md full key re-verify (standing caveat; header re-pinned
   0.16.26 on 10-28, keys not re-verified).
5. The 21-23/21-40 test-idea fleet (traced-verbosity ARF event,
   aggregate control, combined report subtest) - routed as parked
   ideas, not built.
6. Arch-diagram content-freshness audit (the 2026-09-15 d2/svg renders
   again went unviewed - standing ROADMAP row).
7. A drift-alarm arm for the TODO sweep-banner date (10-23 f/27, routed
   again, still not built).

## d) TOTALLY FUCKED UP (all caught; the regex bug recurred - own it)

1. **The single-digit item filter bug shipped THREE times.** The
   TODO_LIST/21-40/11-26 driver scripts used
   `l[:2].rstrip('.').isdigit() and l[2:4]=='. '` which silently drops
   items 1-9 (`l[2:4]` is `" x"`, not `". "`). I fixed it once (21-40),
   then RE-COPIED the broken filter into the 11-26 script and hit the
   same assert. The assert caught it every time (atomic writes - zero
   corruption), but the same bug class recurring inside one session
   after being diagnosed once is the real failure: the filter should
   have been written once, correctly, and reused (`re.match(r'^\d+\.\s',
   l)`).
2. **zip() truncation in the 20-48 spec**: 29 table rows matched, 28
   verdicts supplied - `dict(zip(...))` silently dropped the wrapped
   continuation row. Caught only because I audited the strike count
   against the table afterwards; the `len` equality assert existed in
   every OTHER file's script but was omitted in that one. check-rows
   passed even with the continuation line bare (it groups continuations
   with the parent row) - so the gate alone would NOT have caught it;
   the manual audit was load-bearing.
3. **The daemon outran me on release-critical files AGAIN**: CHANGELOG
   was edited in one tool call and the commit attempted in the next;
   the daemon swept it into `a31a8a2` ("chore: auto-commit"). The repo's
   same-tool-call rule exists precisely for CHANGELOG, I knew it, and I
   still split the calls across a status check. Content is byte-intact
   and verified in HEAD; the narrative message is lost.
4. **Modified-since-read guard fired once (FEATURES)**: my own python
   edit updated the mtime, then `edit` refused; I re-registered the read
   and re-applied. One wasted round trip - but the correct reflex is to
   route all multi-hunk doc edits through ONE mechanism per file.
5. **Two verdict strings encoded before their claim was verified**: the
   21-40 f/17 verdict called the README coverage "the stalwart-e2e check
   row" before grepping (the ARF documentation lives in the ledger
   cluster, not that row); the 19-00 f/11 verdict was written with the
   CI-run claim attached before pulling `gh run list`. Both verified
   TRUE after the fact, but the ORDER was backwards - that is exactly
   the claim-before-transcript class this repo keeps burning people for.
6. Minor: three TODO_LIST script iterations died on pre-write asserts
   (section-shape, window-width) before the third landed - atomic, but
   three cycles to learn the file's exact shape I had already viewed.

## e) WHAT WE SHOULD IMPROVE

1. **Extract the annotate driver into a repo-persistent script** (or
   upstream it): the emit-keys -> verdict-map -> spec -> verify ->
   apply -> check-rows pipeline was re-implemented eight times in bash
   heredocs, each copy re-learning the same lessons (d/1, d/2). One
   `scripts/annotate-corridor.py` with the correct item regex and the
   len asserts would have halved the effort and zeroed the recurrence.
2. **Verify-then-encode, mechanically**: grep the README/FEATURES
   claim BEFORE composing the verdict string that cites it (d/5). The
   corridor verdicts are evidence claims and deserve the repo's own
   transcript discipline.
3. **Same-call commit reflex for CHANGELOG**: edit + commit must share
   the tool call, every time, including when a status check sits
   between (d/3).
4. **check-rows has a blind spot for wrapped continuation rows** (they
   group with the parent, so a bare continuation passes) - the 20-48
   catch was manual. Worth a check-rows upstream note or a `--strict`
   flag; until then, audit row counts, not just the gate exit.
5. **Kept-live reports need an arrow-freshness rule**: routes pointing
   at deleted TODO rows should be refreshed at each pass OR the archive
   deference should be re-affirmed with a dated note (g/1 asks which).
6. **The sitting sheet's decision set shrinks faster than the
   sheet**: C43/C45 are answered/dissolved but the sheet still presents
   them as open calls (with inline banners). A one-line "ANSWERED
   2026-10-28" prefix per settled row would prevent a future sitting
   from re-answering them.

## f) Up to 50 things to get done next (ranked; residues first)

1. Owner: **hold the sitting** (sheet Batches 1-7; C42/C44/C39/C41/C46,
   pbx blessing, D1/D2, Resend, policy batch, REPORT-RENAME/CADENCE,
   AGENTS cap) - it still gates >half the board.
2. Owner: **bless the pbx hermetic override** (TODO pbx row; sheet
   Batch 2) - the single highest-leverage open gate.
3. On the blessing: land the override in pbx, green their gate, then
   close the corridor tail (convert the two kept-live reports' open
   arrows, archive all three deferred reports incl. the 10-23
   docs-health one, whose f/50 pre-commits exactly this).
4. Push master (owner/daemon): the ruff-floor fix `14934ac` + the
   archive commits are local; origin CI is red until they land (24+
   commits ahead).
5. EventCatalog publish (TODO row): watch the hub demo-flagging
   workstream, push hub master, live-verify catalog.home.lan (T8).
6. mailsuite#65 nudge at ~2026-11-05 after re-reading their `imap.py`.
7. #552103 webui-resource comment once the owner reviews the draft
   (admin-bundle TODO row).
8. #563651 follow-up comment (ON HOLD per owner 2026-10-28 - draft
   review first).
9. dnsmasq forward-vs-blackhole transcript, then venue + filing (TODO
   upstream-filings row).
10. Re-date the upstream watch row (#552103/#563651/#563777/
    mailsuite#65) at the next session - last evidence 2026-10-26/28.
11. Full README line-by-line verify (F6 residue; three spot-passes
    done, the end-to-end read still never happened).
12. TELEMETRY.md full key re-verify against the pin (standing caveat).
13. Flood posture verdict execution (TODO flood row; owner taste).
14. C42 retire-or-keep execution (pure owner call; evidence complete).
15. C44 account-secrets doctrine implementation (sheet Batch 1).
16. C39 MemoryMax verdict landing (sheet).
17. C41/C46 verdicts landing (sheet).
18. D1-unlock prep pack (rotation runbook, vandelay compare plan,
    dmarc poll checklist, Resend smoke) - D1-gated.
19. qcow2 purge-or-accept verdict (TODO row; history rewrite, owner
    call).
20. Branch-protection verdict execution (C18; bypass vs strict).
21. Renovate install-or-drop (C19; config dead since 2026-09-16).
22. Discussions enable-or-keep (C22).
23. AGENTS.md cap verdict (sheet Batch 7; file at 279 lines).
24. REPORT-RENAME verdict (the mis-timestamped 20-15 report is now in
    the archive with the name kept; renaming an archived file is
    trivial if the owner says so).
25. REPORT-CADENCE verdict (one combined report per session vs two).
26. BuildFlow upstream batch (TODO row; their repo - count gaps, ruff
    identity parsing in BOTH modes, detect-only, vulture policy).
27. BuildFlow binary rebuild + delta review + rev-stamping cadence
    (TODO row).
28. BuildFlow state-DB purge (0.63 GB; their tool, their repo).
29. SystemNix CI-debt lanes (credential, canary allowlist, pin flips,
    divergence doc - TODO row).
30. SystemNix deliverability-alert wiring (their half of the 10-30
    machinery; MONITORING section 8 copy-paste specs).
31. SystemNix description-sync refresh at the next material wrapper
    change (TODO row).
32.contacts probe re-run at the NEXT stalwart bump (row re-armed
    2026-10-28).
33. Watch nixpkgs `stalwart` rename past 0.16 (standing TODO row).
34. Vendored-module retirement when #552103 merges into the pin
    (checklist in the module header).
35. Extract the annotate driver into `scripts/` (e/1) or upstream the
    bullet grammar into annotate.go.
36. check-rows continuation-row strictness (e/4; upstream note or
    `--strict`).
37. Sheet hygiene: prefix ANSWERED rows (e/6) so a sitting cannot
    re-answer settled calls.
38. Arrow-freshness rule for kept-live reports (e/5; g/1 decides).
39. Drift-alarm arm for the TODO sweep-banner date (10-23 f/27,
    re-routed this pass, still unbuilt).
40. Sheet-vs-decision-batch ID diff script (21-23 f/4; "not worth a
    check yet" - revisit if a sitting slip ever repeats).
41. Exporter hardening backlog (ROADMAP theme 6: absolute-URL selftest,
    `--plain` parity, `--check` drift guard, ADR cross-links).
42. Catalog content refresh at the next catalog session (exporter
    bodies predate the v0.5.0 cut; Consumers section).
43. EventCatalog publisher receipt loop: live URL verifies + screenshots
    appended to the 18-40 report (rides item 5).
44. Traced-verbosity ARF variant (pins `incoming-report.*` event names;
    parked test idea).
45. Aggregate-subtest delivery control (parked idea, defense in depth).
46. Combined report-ingestion subtest (parked runtime optimization).
47. Arch-diagram content-freshness audit (standing ROADMAP row; the
    2026-09-15 renders were not re-viewed again).
48. vulnix replacement once BuildFlow ships a working scanner (standing
    ROADMAP row).
49. DOMAIN_LANGUAGE.md authoring post-v0.5.0 (standing ROADMAP row; the
    release has now shipped, so the "terms stabilize" precondition is
    met - first candidate to graduate).
50. THIS report: annotate + archive when the pbx blessing lands
    (f/2-3 close every open thread in it except the standing rows).

## g) Questions I cannot figure out myself

1. **Arrow freshness in the kept-live reports**: the 12-17 + 14-19
   reports route f-items at rows that have since landed and been
   deleted from TODO_LIST (ping, relay bounce, TLS breadth, the v0.5.0
   row). Refresh those arrows now (a second annotation pass over live
   files), or leave them frozen and archive as-is when the pbx blessing
   lands? I lean refresh-at-archive-time only.
2. **Glob semantics for future sweeps**: the literal `2026-0*` pattern
   matched zero live files this pass - I treated it as
   intent-to-sweep-the-live-corridor (October files) and verified the
   2026-0\* archives mechanically instead. Is that the standing
   interpretation, or do you want literal-glob reports (listing every
   archived file as "viewed") even when it burns context on closed
   history?
3. **Push posture**: master is ~24 commits ahead of origin and origin
   CI is RED (the ruff-floor fix `14934ac` that greens it is local).
   Assistants never push unasked - do you want the fix pushed now, or
   does the daemon's push cadence own it?

---

_Point-in-time snapshot 2026-10-30 20:29 CET. Every claim above is this
session's own tool output or a citation to the artifact that settled it
(gh run log, git tags/releases, flake.lock pin, gate logs, annotate.go
verify output). Waiting for instructions._
