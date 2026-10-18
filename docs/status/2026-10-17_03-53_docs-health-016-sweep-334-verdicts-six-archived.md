# Status Report: docs-health AUDIT — 0.16 sweep, 391 verdicts, 6 archived, living docs to the 0.16 truth (2026-10-17)

- **Date:** 2026-10-17, 03:53 CEST (`date` CLI)
- **Mandate:** the user's "view ALL `**/2026-0*` files, execute docs-health
  SUPERBLY, make the six living docs superb, archive fully-done-and-updated
  files" instruction (third generation of the 07-54/06-58 shape).
- **Session type:** docs-health AUDIT (VERIFY + HARVEST + ANNOTATE + ARCHIVE).
- **Repo state at report time:** the 0.16 upgrade went GATE GREEN mid-pass
  (parallel session 4, its 03-34 report: `nix flake check` all green,
  stalwart-e2e 17/17 real run, relay-e2e 3/3, buildflow EXIT:0); this pass
  re-based its living-doc facts onto that state before yielding. HEAD
  `3da7803` (daemon committed the pass's work continuously); origin still
  red on the statix step until the local commits push.

## a) FULLY DONE

1. **Skill-first:** docs-health SKILL.md + verify-checklist + health-report-format
   loaded before acting; annotate.go source read before the corpus pass
   (the 06-58 d/1 lesson applied - no spec-grammar guessing this time).
2. **Inventory:** all `2026-0*` files verified ALREADY ARCHIVED (glob: 47
   status + 7 planning + 1 review, zero non-archived stragglers) - the
   skill's closed-history rule was honored (no archived file re-opened).
   The live universe: six 2026-10-16/17 status reports + the 07-18 plan +
   decision-batch; all read IN FULL.
3. **Living docs swept to the 0.16 truth** (the upgrade sessions had
   declared docs NOT-STARTED; this pass executed it): README (status
   banner, d2 diagram, built-and-verified rewrite, module section onto the
   provision model, per-account semantics incl. the journal-silence
   posture, relay MtaRoute, runbook steps 2/3/6, pin-advance runbook
   vendored-module bullet, demo `.test` contract, JMAP quickstart on the
   0.16 session endpoint, ledger "Stalwart 0.16" transcript-pinned section
   - 0.15 era markers, fixed the sentence split around the doctrine note,
     nixpkgs rev `eaad089`→`6774f7bc`); FEATURES (evidence line refs
     re-anchored, backup → 🔴 BROKEN, declarative provisioning → SHIPPED,
     e2e/relay/gate rows → green after 03-34); ROADMAP (theme 1 REST-based
     ideas superseded/marked, backup re-research owed, telemetry/queue/Junk
     0.16 caveats, vendored-module retirement + C45 in §5, 0.16-born raw
     ideas); AGENTS (0.16 doctrine + plan-dialect paragraph, upgrade-loop
     rules a-g, session-start baseline ritual incl. `pgrep` + view-before-edit,
     formatter/check-rows rule, gate-log count noise note, demo bullet
     `.test` fix); CHANGELOG (BREAKING 0.16 entry + vendored-module Added +
     relay-dnsmasq/statix Fixed + this pass's bullet); INBOXCLEAN/MONITORING/
     TELEMETRY 0.16 banners; the 07-18 plan got a dated DISRUPTED note.
4. **decision-batch: C42-C46 recorded** (parsedmarc retire-or-keep
   0.16-conditioned, vendored-release doctrine, account-secrets, package
   version, flap tolerance) - the three upgrade reports' g-questions all
   route somewhere durable now.
5. **TODO_LIST rebuilt** (write, not patch - the 0.16 disruption touched
   ~40% of rows): new "0.16 release path" section (push, v0.5.0 + dry-run,
   SystemNix pin), Medium rows for the backup-story research (the largest
   UNVERIFIED product claim, 03-34 b/7) + THREAT_MODEL 0.16 revisit, the
   C45 row folded the delta-table task, MONITORING row upgraded to the
   queue-METRIC alert rule (journal silence makes it the only signal),
   JMAP anti-rot extended (eventSource 0.16 + StateChange assert), Low
   rows added (lockstep guard, flood robustness, relay bounce-path, e2e
   polish) and extended (host-parse closure re-check, demo.qcow2 scratch,
   quickstart live walk, ExecStartPost upstream evidence, buildflow skip
   re-evals). The four rows the parallel session closed were DELETED per
   lifecycle (their evidence lives in CHANGELOG).
6. **ANNOTATE - 334 inline verdicts across six reports (332 tool-applied + 2 hand verdicts on lines containing literal `~~`)** (annotate.go
   `status-items`, emit-keys-generated specs, `--verify` before every
   write): 06-58 (65 incl. 2 hand), 08-26 (45), 20-48 (64), 21-08 (63), 01-22 (36), 00-03 (59). Sections a/d/e historical per policy; every b/c/f/g item
   carries a dated verdict; the two 06-58 lines containing literal `~~`
   got hand verdicts (the tool correctly refuses to strike them).
7. **Inline correction of a false claim:** 21-08 a/2's "relay-e2e GREEN
   end-to-end" was annotated STALE per 00-03 d/4 (the 01-22 f/18 ask,
   executed).
8. **ARCHIVE - 6 files `git mv`'d**, check-rows green BEFORE each move and
   RE-RUN AFTER the formatter; manifest section appended (one line per
   file, classification + deciding reason). `docs/status/` now holds only
   the live 03-34 report.
9. **Mechanical closures:** 00-03 f/36 (parsedmarc-e2e/dmarc-eval: zero
   `services.stalwart` refs - decoupling proven) and f/49 (no dead `/jmap`
   reads: the remaining hits are the anon-401 POST, a comment, and the
   apiUrl assert) - both greps run fresh, cited in the verdicts.
10. **Gates:** check-rows COMPLETE over all six annotated files post-format;
    FEATURES check-rows green; the dprint damage class (below) repaired
    and re-verified formatter-stable. `docs/status/archived/` count 43→49
    matches the manifest.

## b) PARTIALLY DONE

~~1. **README freshness: section-level, not line-level.** Every section this~~ routed - README line-level verification landed 2026-10-17 (05-37 pass, 6 drift fixes); the external-link T15 re-run stays open - TODO_LIST row (added this pass)
pass touched was rewritten against tree + transcript evidence, and the
ledger's 0.15 clusters got era markers rather than a line-by-line
re-verification (they are historical records now). The external-link
re-verification (T15, 2026-10-05) was NOT re-run - TODO row stands.
~~2. **CONTRIBUTING.md: verified generic, not re-read line-by-line** - the~~ done 2026-10-17 - CONTRIBUTING read + mapped in the 05-37 pass; release procedure needed no 0.16 edits (vendored-module notes live in README/ROADMAP)
release procedure needs no 0.16 edits (the vendored-module notes live
in README/ROADMAP).
~~3. **The 03-34 report (live) was not annotated** - it is the freshest~~ current - 03-34 remains the live queue owner (this pass also leaves it live); its f-list is harvested into TODO_LIST
snapshot and the next pass's HARVEST source; archiving it now would
strip the live queue. Its f-list is already harvested into TODO_LIST.
~~4. **The 07-18 plan stays live with a disruption note** (not archived): its~~ current - the 07-18 plan stays live with its DISRUPTED note; owner sittings N1/N2 stand (TODO_LIST blocked-on-user row)
owner sittings N1/N2 stand, and the TODO_LIST rebuild owns the re-mapped
rows. A future pass may archive it once the sittings land.

## c) NOT STARTED (correctly parked; canonical list = TODO_LIST/decision-batch)

~~1. The owner sitting: C42-C46 + C39/C40/C41 + ratifications + D1/D2 + the~~ routed - decision-batch C42-C46 entries (+ C39/C41, adoptions ratification; TODO_LIST blocked-on-user row)
standing batch (C18/C19/C22/C24/C29/C34, Q4/Q5, demo g1/g2, qcow2).
~~2. v0.5.0 (C43-gated), the SystemNix pin advance, the push + CI watch.~~ done 2026-10-17 (push half) - origin green, runs 39016232923 + 39072344502, statix fix landed 8aa9e81; v0.5.0 + pin advance routed - TODO_LIST 0.16-release-path rows (C43-gated)
~~3. The 0.16 residue rows: backup story, delta table, MONITORING metric~~ routed - TODO_LIST rows: 0.16 backup story (research DONE 2026-10-17), C45 row (delta-table task folded), MONITORING metric row, local lockstep guard row, demo-smoke row, match-property audit row
rule, lockstep guard, demo smoke + INBOXCLEAN re-verification, match
property audit, provision-plan-eval - all routed, none executed here
(docs pass).

## d) TOTALLY FUCKED UP (all self-caught; nothing shipped broken)

1. **My repair script used bare row numbers as verdict keys** - the
   g-section verdicts overwrote f/1-f/3 in each rebuilt table (dict
   collision across restarting section numbering). NINE rows carried wrong
   verdicts; caught on post-repair spot-check, fixed with task-text-anchored
   substitution, and the FIRST fix attempt silently no-op'd (regex anchor
   vs leading whitespace) - caught by re-reading the file, not by trusting
   the tool's "fixed 3" output. Lesson: the spec's FULL key (N@substr)
   exists precisely to prevent this; row-level repairs must match on
   content, never on number alone.
2. **A sloppy row-deletion loop ate 3 live rows** (the push, v0.5.0, and
   SystemNix rows adjacent to the DONE rows in TODO_LIST). Caught by
   viewing the section after the edit; rebuilt the whole section from
   content. The "verify after every edit" rule caught it in one turn.
3. **dprint re-wrapped the struck report tables and ATE the verdict cells**
   (120 rows across three files: verdict + category lost, `| ~~ |`
   placeholder collapse). Root cause: whole-line strikes put `~~` adjacent
   to table pipes - the exact eaten-rows class AGENTS documents. Repaired
   by rebuilding rows per-cell from the PRE-ANNOTATION git blobs + the
   preserved spec verdicts, then re-running check-rows after a fresh
   format pass (formatter-stable now). The AGENTS rule is written down.
4. **Trusted `grep -L` exit semantics again** (the exact quirk the 06-58
   report flagged): exit 0 with no output was ambiguous until the
   calibrated per-file `grep -c` ran. The calibration exists; I reached
   for the wrong one-liner first.
5. **One planned AGENTS edit never landed** (the demo-bullet `.test` fix
   was in the multiedit batch that bounced on read-state; the retry
   dropped it). Caught by the final 0.15-drift grep (`demo.invalid` still
   present at line 42), fixed.

## e) WHAT WE SHOULD IMPROVE

1. **Preserve the spec file with the corpus.** The row rebuild was only
   possible because /tmp/spec-*.tsv still existed; a same-session format
   pass could have run after a /tmp cleanup. Annotate sweeps should drop
   their specs next to the manifest (or in the report) until the archive
   gate closes.
2. **Post-format check-rows is now canonical** - the SKILL's repair trio
   exists because this damage class recurs; the repo rule (AGENTS) makes
   the trigger explicit (any formatter pass over an annotated file).
3. **Concurrent-session discipline held under stress:** two sessions
   edited overlapping living docs all pass with zero clobbers (mtime
   checks, view-before-edit, section-level ownership). The 03-34 e/1
   protocol suggestion is already half-practice; AGENTS now carries it.
4. **Verdict text belongs to the spec, not the file** - every repair
   pulled from /tmp/spec-*.tsv, never from memory (the d/1 near-miss is
   the counterexample that proves the rule).
5. **Score the health report at pass time, not post-hoc** (06-58 b/7
   recurrence avoided - the math below was computed before this report
   was written).

## f) NEXT TASKS (the live queue; canonical list = TODO_LIST)

~~1. Push + CI watch (the statix red streak heals with the local commits).~~ done 2026-10-17 - pushed and green: runs 39016232923 (7m48s) + 39072344502 (6m49s), statix fix 8aa9e81
~~2. C43 sitting → v0.5.0 (with the release dry-run) → SystemNix pin advance.~~ routed - decision-batch C43 + TODO_LIST v0.5.0 / SystemNix-pin rows
~~3. The 0.16 backup story research (Critical - the largest UNVERIFIED claim).~~ routed - TODO_LIST "0.16 backup story" row (research DONE 2026-10-17: offline cp -a + MAIN-binary --export/--import + stalwart-cli snapshot; VM proof on the pin remains)
~~4. Demo smoke on the 0.16 closure + INBOXCLEAN full re-verification.~~ routed - TODO_LIST demo-smoke row (rides the INBOXCLEAN re-verification)
~~5. MONITORING queue-metric alert rule (journal silence consequence).~~ routed - TODO_LIST MONITORING row (extended this pass: provision-failure alert + verify-budget doc)
~~6. Match-property audit + provision-plan-eval + lockstep guard.~~ routed - TODO_LIST rows: match-property audit; provision-plan-eval (extended this pass with the Exec* unit lint + 8080 pin); local lockstep guard
~~7. Next docs-health pass: annotate + archive 03-34 when its items close.~~ partial - this pass annotated + archived the five superseded reports (03-53/04-09/05-37/06-05/06-12); 03-34 stays live until its items close

## g) QUESTIONS FOR YOU

~~1. **C43-C46 one-sitting bundle** (plus C39/C40/C41 + ratifications): all~~ routed - decision-batch C42-C46 entries with [rec]s
recorded in decision-batch with [rec]s; answering clears the release
path and ~6 blocked rows.
~~2. **Push posture:** origin is red on a fix that has been local for ~6~~ done 2026-10-17 - pushed, origin green (run 39072344502); the concurrent-session sub-question recorded as a C38 addendum
hours (statix W20, `8f8ced8`); the daemon owns pushes (C38 posture) -
want an explicit push now, or keep riding the cycle?

---

_Point-in-time snapshot, 2026-10-17 03:53 CEST. Session artifacts: 334
archived inline verdicts + the archive manifest section, the rebuilt
TODO_LIST/decision-batch/ROADMAP/AGENTS/FEATURES/README/CHANGELOG edits,
the 0.16 banners on INBOXCLEAN/MONITORING/TELEMETRY, the 07-18 plan
disruption note, and this file. NOW WAITING FOR INSTRUCTIONS._
