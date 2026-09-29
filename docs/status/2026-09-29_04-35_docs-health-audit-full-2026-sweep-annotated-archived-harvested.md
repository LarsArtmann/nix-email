# Status Report — docs-health AUDIT over all 2026-0* files (annotation, archive, harvest)

- **Date:** 2026-09-29 04:35 CEST (`date` CLI)
- **Session type:** docs-health AUDIT under the user's "view ALL \*\*/2026-0\* files, annotate inline,
  archive fully-done" mandate: skill + 8 references loaded first → read all 37 `2026-0*` matches
  (12 active status reports, 2 active planning docs, archived set gate-checked, `.d2`/`.svg` noted)
  - all six living docs → VERIFY against code/git → HARVEST → ANNOTATE → ARCHIVE → living-doc
    rebuild → gates → inline health report (delivered in-session: Accuracy 8.25 → 9.5, Fitness
    7.75 → 10, math shown there).
- **Session verdict:** every active 2026-0* doc now carries per-item resolution verdicts
  (~350 new inline strikethroughs across 10 files), the flake-parts migration report is
  ARCHIVED (completeness gate green), eight unharvested report items were routed into
  TODO_LIST, the stale ergonomics row is gone, the 19-23 plan's two false pin claims are
  corrected inline, and the six living docs are rebuilt. All gates green modulo the 4
  documented nix-checker FPs.
- **Repo state:** `master` **ahead 9** of origin (daemon auto-commits of this session's work;
  nothing manually pushed by me). Working tree clean at report time except this file.
- **Gate state:** `buildflow` EXIT:69 = ONLY the 4 documented port-collision FPs (zero new
  findings; lychee 7 warnings = documented non-fixes); `nix fmt -- . --check` EXIT:0 (twice);
  archive gate `grep -rLn '~~' docs/status/archived/ docs/planning/archived/` silent;
  `check-rows.py` COMPLETE on all 11 touched files (after one fix, see d/5).

---

## a) FULLY DONE

1. **Skill-first compliance:** docs-health SKILL.md + harvest-guide, verify-checklist,
   health-report-format, annotation-placement, resolving-items, agents-quality-guide,
   doc-ownership read BEFORE acting; the annotate-status-items/check-rows assets used as
   tooling instead of hand-rolled sweeps (per the SKILL's tooling mandate).
2. **All 37 `**/2026-0*` matches viewed:** 12 active status reports + 2 active plans read in
   full; archived set verified via the completeness gate rather than re-read; the four
   `docs/architecture-understanding/2026-09-15_*` d2/svg renders classified LEAVE-ALONE
   (no items; content-freshness audit already an ROADMAP §5 idea).
3. **VERIFY pass with fresh evidence:** master in sync + CI green (incl. a 2026-09-28
   Dependabot run); `flake.nix` at **356 lines** — ROADMAP's ~300-line split trigger FIRED;
   README grep-clean of stale versions, pin `6774f7bc` current, "Rate-limit sizing" section
   present (kills the stale ergonomics TODO row); CI has the pipe-lint but NO md-table-pipe
   lint (05-55 f/7 genuinely open); decision-batch C17 section confirmed fresh (v0.4.0 update
   present).
4. **HARVEST — TODO_LIST rebuilt:** stale `rateLimits`/DNSBL ergonomics row DELETED
   (deliverable landed 2026-09-22; the 05-55 d/3 debt paid); 9 rows added with evidence
   columns (CI pipe-table lint, pre-push lockstep mirror, host-parse-fixture helper,
   parsedmarc sample breadth + `arrival_date_utc`, CI statix step, v0.4.0 tag smoke,
   docs-freshness audits, parsedmarc Restart decision, flake.nix split as a new Medium row);
   sweep header compressed from 25 lines of dated prose to one current pass + pointer to git
   history. 23 open rows, zero DONE rows, no trophy sections.
5. **ANNOTATE — ~350 inline verdicts across 10 files** (annotate-status-items.py with
   `--verify` before every write, `--emit-keys` never hand-typed): 16_18-41 (34+2), 19-07
   (63), 21-10 (37 — completing the 02-58 M14 pass), 22-50 (66), 23-15 (28), 02-58 (18),
   03-21 (47), 05-55 (48), 17_17-28 (1), plus manual c-bullet/g-item strikes. Every verdict
   cites commit, report §, CHANGELOG 0.4.0, or the TODO_LIST/decision-batch home; open items
   left bare per the skill (absence of marker = open signal); house-style routed pointers
   where an item moved to a canonical home.
6. **ARCHIVE:** 17_17-28 (flake-parts migration) — last open item f/22 struck as
   verified-pre-existing (21-10 a/5), `git mv` to `docs/status/archived/`, completeness gate
   green. `docs/status/` now holds 11 active reports.
7. **Planning-doc truth:** 19-23 master plan — the two provably-false "SystemNix pin bump
   v0.2.0 → v0.3.1" claims (C15 row, M21 21.1) corrected inline (plain corrections, NOT
   strikes — see d/5) + a per-task Resolution appendix (M1-M27 verdicts with evidence);
   23-25 backlog-burn plan — Resolution appendix with T01-T23 verdicts (12 done, 2
   partial/standing, 9 open/user-gated).
8. **Living docs:** AGENTS.md gained the red-CI cause-attribution working rule (05-55 e/2)
   and the fixture-traps bullet restructured into sub-bullets (05-55 f/28); FEATURES.md
   Renovate+Dependabot row split honestly (Dependabot FULLY_FUNCTIONAL with the 09-28 run;
   Renovate PARTIALLY_FUNCTIONAL — app never installed, C19); ROADMAP flake-split idea marked
   FIRED/GRADUATED; CHANGELOG `[Unreleased]` gained the docs-pass entry (count stated as
   "~350" after grep re-derivation, not the first-guess 378).
9. **Inline health report delivered** (Accuracy 8.25 → 9.5, Fitness 7.75 → 10, per-doc table,
   visible math, "could not verify" section — README's 26 ledger claims carried forward on
   the unchanged pin).

## b) PARTIALLY DONE

1. **Push verification** — the daemon committed everything (9 ahead) but the push happens on
   its own cadence; CI-green on the pushed head is inherited evidence, not a check of these
   9 commits. Docs-only delta, same posture the 05-55 session accepted.
2. **Archive queue** — 16_19-16, 17_15-11, 17_21-07 deliberately remain unarchived: they
   carry genuinely-live user-gated items (C17 SystemNix set, demo g2, standing watch rows).
   Annotated (by prior passes) and re-verified this session, but "fully done" they are not.
3. **README ledger re-verification** — the 26 Stalwart-0.15.5 claims were NOT re-grepped
   against the binary this pass; carried forward on the unchanged pin (`6774f7bc` since
   2026-09-22). Stated in the health report rather than silently assumed.
4. **AGENTS.md hash-anchor deviation** — the file keeps 4 commit-hash evidence anchors and
   dated lessons (house style: lesson provenance); the generic verify-checklist flags hashes.
   Deliberate, but it IS a standing deviation from the generic rubric.
5. **This report's own annotation depth** — sections (a)-(c) of the OLDER reports (FULLY DONE
   records) were left as historical records per house precedent; only forward-looking items
   (b/c/f/g + open bullets) got verdicts. A maximalist pass would also re-verify every §a
   evidence cell; the 18-41 pass explicitly did not either.

## c) NOT STARTED (correctly parked; canonical list = TODO_LIST)

1. The nine newly routed TODO rows (pipe lint, pre-push mirror, host-parse-fixture,
   parsedmarc breadth, CI statix step, tag smoke, docs-freshness audits, parsedmarc Restart
   decision, flake.nix split) — routed this session, executed by none.
2. The entire user-gated set, unchanged: decision batch (D1/D2, C24/C29, C18/C19/C20/C22/
   C34, Q4-Q6, demo g1/g2), C17 SystemNix push + C17a pin choice, Resend API-key smoke,
   qcow2 history purge, mailsuite/Junk/Renovate/Discussions filings.
3. BuildFlow upstream fixes (port-collision context-blindness; dprint pipe-truncation) —
   TODO row exists, not started.
4. The remaining archive moves (17_15-11/17_21-07/16_19-16) — gated on their live items.
5. Monitoring encoding (C24/C29-gated), D1 build-out slices (M22-M26), TELEMETRY
   webhooks/alert-objects key verification, CONTRIBUTING per-claim audit — all routed rows,
   none executed here.

## d) TOTALLY FUCKED UP (all self-caught this session; none reached a gate red)

1. **TODO_LIST multiedit collision — the worst one.** Six dependent edits in one batch:
   edit 4 consumed the buildflow port-collision row (its text was my old_string), which made
   edit 5 fail; edit 6 matched a PREFIX of the qcow2 row instead of the full line and spliced
   the new Restart row into the middle of it, orphaning the qcow2 cells onto the new row's
   line. Detected on re-read, repaired with two exact edits + byte verification. Root cause:
   composed overlapping anchors from memory and used a prefix match — against the repo's own
   exact-match discipline. Cost: ~3 tool calls of rework, zero data loss (diff reviewed).
2. **Stale-read guard trips (×2)** — hand-edited 21-10 and 22-50 right after the annotate
   script rewrote them; "modified since last read" bounced both. The 02-58 report's own e/5
   documents this exact pattern ("always re-view immediately before editing a file the tools
   touched") and I repeated it anyway. Cost: two wasted round trips.
3. **Spec-key guesswork** — 9 `--verify` failures across four files (substrings reconstructed
   from the view instead of grep'd: em-dash vs hyphen, line-wrapped items, a `~~`-containing
   line the script refuses, and one duplicate-49 confusion between the 21-10 and 22-50
   f-lists). Each caught by --verify as designed, but the failures were all preventable by
   grepping the exact line first.
4. **A stray verdict fragment shipped into 19-07** — my f/3 spec line contained
   `imports<TAB>done - SHIPPED...`, so the script faithfully wrote a stray "imports" word
   into the struck row. Caught only by spot-reading the applied output (the --verify output
   would have shown it; I skimmed it). Fixed with a python one-liner — ironically the exact
   "bypass the edit tools" class earlier sessions flag; justified there by the tab character
   being impractical in edit-tool old_strings, but it should have been an edit with
   surrounding context.
5. **Planted the PARTIAL-table miss pattern** — my two 17_17-28-style strikes inside the
   19-23 plan's big tables made check-rows FAIL (1/57 and 1/4 rows struck = the exact
   mixed-strike shape the gate exists to catch). Converted both to plain inline corrections
   (tables back to UNTOUCHED, corrections preserved); check-rows then green. Also:
   my first 17_17-28 strike wrapped table pipes inside `~~` (GFM cannot render that across
   cells) — redone cell-wise per the house pattern before archiving.
6. **Count-first almost-failure** — wrote "378 new resolution markers" into CHANGELOG from
   arithmetic on script-reported counts; re-derived from greps (364 current total minus
   pre-existing, plus the manual strikes) and corrected to "~350" before yield. The 18-41
   session's d/1 sin, caught this time — but only because the count-first reflex fired AFTER
   the wrong number was already written.
7. Minor: ROADMAP first edit produced broken grammar (mangled continuation) — fixed
   immediately; ROADMAP flake-split wording needed two attempts.

## e) WHAT WE SHOULD IMPROVE

1. **Full-line anchors only, and never batch dependent edits.** The d/1 collision class dies
   if (a) old_string is always a complete line/row, (b) edits whose anchors overlap run in
   separate calls with a re-read between. The repo rule says "include 3-5 lines of context" —
   the stronger form is "include the WHOLE unit you are replacing".
2. **Grep the exact line before composing any annotate spec** — substrings from memory of a
   view produced 9 verify failures; substrings from grep produce zero. `grep -n <fragment>`
   costs seconds and pins dashes, wrapping, and duplicates.
3. **Re-View is mandatory after ANY script write, before ANY hand edit** — it is already
   written down (02-58 e/5); the failure was treating it as optional when "just one small
   edit". Mechanically: never hand-edit a file a tool touched in the same session segment
   without a fresh View first.
4. **Run check-rows on any file where strikes were hand-placed inside large clean tables**
   before yielding — the PARTIAL class only surfaces through the tool; my eyes read both
   versions as fine.
5. **Count discipline: grep into a variable, then write the prose.** The corrected count
   came from `grep -c`; the wrong one came from adding script outputs. The rule is not
   "verify your count before yielding" — it is "never compose a number from anything but a
   single command's output".
6. **The annotate script could refuse verdicts containing tabs** (the d/4 leak) — a one-line
   hardening in the skill asset; same class as its existing dup-key refusal.
7. **Archive-policy clarity** — this pass applied "archive when every item is closed or
   canonically routed" (17_17-28 precedent). 17_15-11/17_21-07/16_19-16 carry routed-open
   user-gated items and stayed. The line between the two groups is a judgment call that
   deserves an explicit policy line in AGENTS.md's Documentation map (candidate, not filed).

## f) Up to 50 things we should get done next (ranked; routed, not re-researched)

**This session's direct residue (small, self-serve):**

1. Verify the daemon pushed the 9-commit docs batch and CI stays green on the true head.
2. Execute the flake.nix split (`flake-modules/*.nix`) — TODO Medium row; trigger already
   fired at 356 lines. Highest-value in-repo engineering item.
3. CI: unescaped-pipe-in-table-cell lint (odd pipe-count vs header, fail-closed).
4. Pre-push hook: mirror the CI check-inventory guards (lockstep list + aarch64 shape).
5. `scripts/host-parse-fixture.py` (PYTHONPATH from the check drv closure) — makes the AGENTS
   dry-run rule a one-liner.
6. parsedmarc-e2e breadth: Netease + LinkedIn `.crlf` failure samples (host-dry-run first)
   - `arrival_date_utc` assertion.
7. CI statix step (fresh-file W20 drift class).
8. v0.4.0 tag smoke: `nix flake show` + one `nix run .#vm` boot on a tag worktree.
9. Docs freshness audits: TELEMETRY webhooks/alert-objects keys + CONTRIBUTING per-claim.
10. Add the archive-policy line to AGENTS Documentation map (e/7) — 5 minutes, prevents the
    next judgment call.
11. Decided-against candidates to sweep with verdicts: none new — but re-check 16_19-16's 15
    open items at the next decision batch (archive sweep row).

**User decisions (minutes each; the standing batch, unchanged):**

12. D1 (Workspace fork) — gates the entire production build-out.
13. D2 (VPS placement/budget) — gates sizing.
14. C24 alert channel + C29 canary vantage — gates all MONITORING encoding rows.
15. C17 SystemNix push approval + C17a pin choice (hard-pin `?ref=v0.4.0` vs float master) —
    the fleet-pin gate; unblocked since the v0.4.0 tag exists.
16. C18 branch-protection bypass policy.
17. C19 Renovate install-or-drop (app never ran; its actions scope duplicates Dependabot).
18. C20 mailsuite STARTTLS issue file-or-skip (draft ready, 5 gates passed).
19. C22 Discussions; C34 webmail; Q4 README detail level; Q5 provisioning philosophy.
20. Q6 spam→Junk ownership verdict (rec: tag-only now + upstream path) — gates the Stalwart
    upstream filing.
21. Demo g1/g2 (dmarc-in-demo) — g2 gates the 17_21-07 archive.
22. qcow2 history-purge verdict (~140 MB, force-push window) vs accept-clone-weight.
23. Daemon flush policy at session end (wait-for-push block vs ride-the-cycle).

**In-repo, gated on the above or standing:**

24. Resend live :587 SASL smoke (needs API key) — closes the last unverifiable relay claim.
25. SystemNix push + CI-debt triage + cache sweep (C17 payload).
26. parsedmarc unit Restart-policy upstream proposal (file-or-skip; new TODO row).
27. Watch nixpkgs #563651/#563777; the imapclient 4.1.0 bump retires the py3.13 pin at the
    next pin advance carrying >= 4.1.0.
28. Next-pin-bump presence-list re-verify (standing row; fires on the NEXT bump).
29. Archive moves for 17_15-11/17_21-07/16_19-16 once their gated opens close
    (+ completeness gate re-run).
30. Monitoring encoding rows 2-14 per MONITORING.md the moment C24/C29 land (queue poll,
    failed-auth, dead-man, Gatus templates, capacity, canary).
31. D1-gated build-out slices M22-M26 / C12 / C14 (re-slice at unlock).
32. BuildFlow upstream session: port-collision context-awareness/suppression + markdown-table
    pipe handling; then retire the AGENTS known-noise entry and the exit-69 posture.

**Improvement candidates (from e/, cheap, unfiled where noted):**

33. Annotate-script hardening: refuse tabs in verdicts (skill-asset change; out of repo).
34. Check-rows as a yield-time reflex after any hand-strike inside big tables (process; could
    ride the docs-health skill notes).
35. Consider a `docs/status/README.md` index (status live-index rot is a VERIFY checklist row;
    currently checked by diffing `ls` vs nothing — 11 files is manageable, 15+ would not be).
36. Host-side dry-run tool work (see 5) doubles as the first flake `apps.` candidate if a flake
    app is preferred over `scripts/`.

**Deliberately NOT re-listed (already canonical elsewhere):** the D1 production theme ideas,
ROADMAP §5 raw ideas, monitoring taxonomy work — they live in ROADMAP/decision-batch; listing
them here again would be the entombment this skill exists to kill.

## g) Questions I can NOT figure out myself

1. **The decision batch itself** — D1/D2, C24/C29, C17+C17a, C18/C19/C20/C22/C34, Q4-Q6,
   g1/g2 have been pending since 2026-09-22 with recommendations staged in
   `docs/planning/decision-batch.md`. Is a single 30-minute sitting realistic this week, or
   should I stop surfacing it in every report until you initiate?
2. **Archive policy** — is "every item closed OR canonically routed" an acceptable archive
   bar (the 17_17-28 precedent I followed), or must every item be CLOSED with routed-open
   reports staying active? It changes whether ~4 more reports move now or wait.
3. **BuildFlow upstream session** — should the port-collision + dprint-pipe fixes be a
   dedicated BuildFlow-repo session soon (I can author both; the gate keeps exiting 69 until
   then), or stay routed-as-TODO until BuildFlow's own cycle picks them up?

---

_Point-in-time snapshot, 2026-09-29 04:35 CEST. Session artifacts: this file, the 10 annotated
docs, 17_17-28's archive move, TODO_LIST/AGENTS/FEATURES/ROADMAP/CHANGELOG edits, and the
in-session health report. NOW WAITING FOR INSTRUCTIONS._
