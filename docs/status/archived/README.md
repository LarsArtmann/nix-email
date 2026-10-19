# Archived status snapshots

Closed history. Every file here carries per-item inline resolution verdicts
(`~~item~~ done/routed/won't-implement`); sections a/d/e stay historical
records by design. Do not reopen — the living docs
(TODO_LIST/ROADMAP/decision-batch/CHANGELOG) own everything forward-looking.

Archive policy: `AGENTS.md` → Documentation map.

## Manifest — 2026-10-05 docs-health bulk archive (13 files)

All classified ANNOTATE→ARCHIVE (every forward-looking item closed or
canonically routed; routed user-gated decisions live in
`docs/planning/decision-batch.md` with recommendations).

| File (date prefix)                                      | Classification | Deciding reason                                                                                                           |
| ------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-16_18-41_docs-health-pass2…                     | ARCHIVE        | b/c items closed (v0.3.0 shipped, assertions/hooks in 0.3.0, pushes flushed) or routed (TODO user-gated rows)             |
| 2026-09-16_19-16_medium-rows-swept…                     | ARCHIVE        | 18 opens all routed: TODO standing/watch rows, decision-batch C17-C20/C22/D1, ROADMAP §5 + pin-advance runbook            |
| 2026-09-17_15-11_v030-release-session-status            | ARCHIVE        | signed-tags DONE (v0.4.0 ED25519 signature verified), PROXY answered (README ledger), rest routed to C17/C18-C20/D1/D2/Q6 |
| 2026-09-17_21-07_v031-release-and-demo-vm-hostfwd-hang  | ARCHIVE        | hostfwd hang fixed 2026-09-22; sole open (demo g2) routed to decision-batch Demo-VM residue                               |
| 2026-09-22_19-07_capability-gap-advisory-session        | ARCHIVE        | drift repairs done (23-15 pass); f-table items struck 2026-09-29; c-group rows routed (TODO/decision-batch/ROADMAP)       |
| 2026-09-22_21-10_execution-session-pareto-tiers…        | ARCHIVE        | 12 opens all decision-batch pointers (D1/D2, C17-C20, C24/C29, demo g2); tag-cadence part resolved by v0.4.0              |
| 2026-09-22_22-50_m14-closeout-gate-green…               | ARCHIVE        | 2 opens (D1+D2, C24+C29) routed to decision-batch                                                                         |
| 2026-09-22_23-15_docs-health-audit-harvest-routing…     | ARCHIVE        | was already fully struck (zero forward opens) — moved this pass                                                           |
| 2026-09-23_02-58_pareto-execution-demo-fix…mid-t12      | ARCHIVE        | was already fully struck — moved this pass; marker-column rows uniformized cell-wise (check-rows green)                   |
| 2026-09-23_03-21_pareto-resume-t12-forensic-fixture-red | ARCHIVE        | T12 red root-caused + green same day (repaired fixture ae1e5adb, shipped v0.4.0)                                          |
| 2026-09-23_05-55_t12-green-v040-released-self-review    | ARCHIVE        | was already fully struck — moved this pass                                                                                |
| 2026-09-29_04-35_docs-health-audit-full-2026-sweep…     | ARCHIVE        | 49 opens: routed (TODO rows/decision-batch/ROADMAP), done (AGENTS policy line, archive execution, push verified) or moot  |
| 2026-09-30_12-53_cross-repo-integration-design-session  | ARCHIVE        | HARVESTed same pass: 4 JMAP-seam TODO rows + C35-C37; InboxClean-side items stay theirs (rows 172-176, #156)              |

Earlier archives (2026-09-14 → 2026-09-17, 25 files): single-file moves whose
manifests live in the moving session's commit messages.

## Check-rows verdict — 2026-10-05 (T23)

The three pre-gate files below failed the cell-uniformity gate (rows left
unstruck that are today canonically routed). FIXED same day: cell-wise
strikes completed with dated `routed/resolved` markers pointing at the
canonical home (decision-batch/TODO_LIST/ROADMAP); `2026-09-14_17-05`
f-row 2 had lost its Impact/Effort/Cat cells to the 2026-09-23 dprint
pipe-eating drop - cells restored; `2026-09-16_08-08` b-table separator
had a single-dash cell that the `-{2,}` separator rule could not recognize

- normalized. Both files now pass `check-rows.py`; the fourth early file
  (2026-09-15_04-42) needed only 3 resolved-markers. Verdict: fix, not
  leave - the gate now reads the whole archived corpus green.

## Manifest — 2026-10-16 docs-health bulk archive (4 files)

The four 2026-10-05 session reports. All classified ANNOTATE→ARCHIVE:
every b/c/f/g item struck inline with a dated verdict (207 markers across
the four files; sections a/d/e historical by policy), check-rows green,
dprint-formatted BEFORE the `git mv`. The same pass harvested their
forward items into TODO_LIST/decision-batch (C39-C41) and refreshed the
upstream watch (#566282 MERGED 2026-10-13).

| File (date prefix)                               | Classification | Deciding reason                                                                                                              |
| ------------------------------------------------ | -------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-05_07-54_docs-health-audit-jmap-harvest… | ARCHIVE        | 37 verdicts: f/c items executed same day (JMAP seam, split, CI hardening) or routed; g/3 answered (plans archived this pass) |
| 2026-10-05_10-29_pareto-execution-jmap-seam…     | ARCHIVE        | 64 verdicts: a/1-a/19 executed, f/1-f/50 done/routed (T13 upstream af5eb80, CHANGELOG b1deb35, Q6 099ba9d), g/1-g/3 closed   |
| 2026-10-05_11-14_pareto-continuation…            | ARCHIVE        | 66 verdicts: session debts paid same day; gated residue routed (TODO rows, C40, SystemNix row, BuildFlow rows)               |
| 2026-10-05_11-53_nix-superbly-review…            | ARCHIVE        | 40 verdicts: findings remediated or routed (C39, TODO rows), b-section caveats verified absorbed, g/1-g/3 answered           |

## Manifest — 2026-10-17 docs-health bulk archive (6 files)

Five reports from the 0.16-upgrade corridor (2026-10-16/17) plus the
00-03 quota-fix report. All classified ANNOTATE→ARCHIVE: every b/c/f/g
item struck inline with a dated verdict (332 markers across the six
files; sections a/d/e historical by policy), check-rows green over every
file, dprint-formatted BEFORE the `git mv` (and check-rows re-run AFTER
the formatter - the pass caught and repaired dprint re-wraps of struck
table rows). Forward items were routed into the 2026-10-17 TODO_LIST
rebuild, decision-batch C42-C46, and ROADMAP; the 03-34 report (gate
green) supersedes the upgrade-state facts and stays live.

| File (date prefix)                                        | Classification | Deciding reason                                                                                                                    |
| --------------------------------------------------------- | -------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-16_06-58_docs-health-full-archive-exit69-retired… | ARCHIVE        | 65 verdicts: f/1-21 routed into the 07-18 plan, f/22-32 closed in-pass or routed, watches superseded by the 0.16 landing; g routed |
| 2026-10-16_08-26_pareto-plan-and-stalwart-016-research…   | ARCHIVE        | 45 verdicts: N-rows live in the (disruption-noted) 07-18 plan; C42 recorded; residue closed in-pass                                |
| 2026-10-16_20-48_stalwart-016-upgrade-session…            | ARCHIVE        | 64 verdicts: b/c closed by 21-08→00-03→03-34; f-table done-in-pass (docs sweep) or routed (TODO rows, C43-C46); g routed           |
| 2026-10-16_21-08_stalwart-016-vm-tests-going-green…       | ARCHIVE        | 63 verdicts incl. the inline CORRECTION of the stale relay "green" (a/2); rest done-in-pass or routed                              |
| 2026-10-17_01-22_statix-w20-fix-and-gate-triage…          | ARCHIVE        | 36 verdicts: statix fix landed, catch-all fixed in-tree, gate green; process items routed (TODO rows + AGENTS ritual)              |
| 2026-10-17_00-03_stalwart-016-quota-signature-and-schema… | ARCHIVE        | 59 verdicts: quota = journal silence (03-34 a/1-2), gate green (a/5), all f-items done/routed; g/3 closed as MOOT                  |

## Manifest — 2026-10-19 late docs-health pass (5 files + specs)

All ANNOTATE→ARCHIVE: every b/c/f/g item carries an inline verdict (174
tool-applied + 8 hand for literal-`~~`/bullet lines = 182 total); tables in per-cell
form with `check-rows:ledger` exemptions where routed rows are the point;
a/d/e historical by policy. The daemon's mid-pass dprint run mangled
whole-line table strikes twice — rebuilt per-cell from the preserved specs
(next to this manifest: `2026-10-17-late-pass-annotate-specs/`). The
06-12 report's f27 verdict (lost in a pre-pass annotate rebuild, routed
here by the 2026-10-19 06-05 resumed-thread report) is restored in the
stable form. Forward items route to TODO_LIST (10-check-set state),
decision-batch (C38/C41 addenda, new C52/C53), and ROADMAP.

| File (date prefix)                                   | Classification | Deciding reason                                                                                                                       |
| ---------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-17_03-53_docs-health-016-sweep-334-verdicts… | ARCHIVE        | 16 verdicts: push/CI done (green runs 39016232923/39072344502), residue routed (backup/monitoring/lockstep/demo-smoke rows), g routed |
| 2026-10-17_04-09_docs-health-self-review…            | ARCHIVE        | 63 verdicts: b/c closed by later passes (05-37, 06-05), f/1-50 routed to TODO rows (all verified present), g done (push) or routed    |
| 2026-10-17_05-37_readme-agents-superb-pass…          | ARCHIVE        | 25 verdicts: accuracy work done-in-pass (05-37), structure calls routed (C52, C41 addendum), CI-watch + harvest done by this pass     |
| 2026-10-17_06-05_agents-md-drift-fix-prune…          | ARCHIVE        | 25 verdicts: prune executed 06-05, duration claim fixed (CI-timed), tooling rows routed then executed by W11 (2026-10-19)             |
| 2026-10-17_06-12_issue-4-bootstrap-fix-and-p3-close… | ARCHIVE        | 53 verdicts: f27 done (pbx gate on d7e1334), f28/f29/f32 done (AGENTS + grep), rest routed per P-numbers; g routed (C38/C52/C53)      |
