# Archived planning plans

Closed history. Plans land here only when every task in them is closed OR
canonically routed (the routed-bar policy: a user-gated decision counts as
routed once it sits in `docs/planning/decision-batch.md` with a [rec]).
The living docs (TODO_LIST/ROADMAP/decision-batch/CHANGELOG) own
everything forward-looking. Archive policy: `AGENTS.md` → Documentation map.

## Manifest — 2026-10-16 docs-health bulk archive (3 files)

All classified UPDATE→ARCHIVE: stale Resolution verdicts corrected inline
first (the 2026-10-05 execution session had overtaken several rows), an
archive banner added, check-rows green, dprint-formatted BEFORE the
`git mv`.

| File (date prefix)                                         | Classification | Deciding reason                                                                                                                           |
| ---------------------------------------------------------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-22_19-23_pareto-master-plan-super-email-monitoring | ARCHIVE        | Resolution appendix maps M1-M27 to verdicts + homes; stale M21/M27 rows updated inline (C17/C17a EXECUTED 2026-10-05, mailsuite FILED)    |
| 2026-09-22_23-25_pareto-backlog-burn-master-plan           | ARCHIVE        | T01/T16/T18/T22/T23 Resolution rows updated inline (push+pin EXECUTED, filings closed at the gates); residue routed to TODO_LIST          |
| 2026-10-05_08-01_SUPERB-pareto-backlog-burn-plan           | ARCHIVE        | SUPERSEDED banner (2026-10-05) updated: T13 completed upstream (15ea141d2), archive note added; 15/23 tasks executed per the 10-29 report |

Decision-batch references to these plans point at their archived paths.

## Manifest — 2026-10-23 planning-plans corridor (5 files)

The P/V/W/X chain plus the 10-16 ancestor. Every task is closed or canonically
routed: each file carries an `## Appendix R — Resolution` table whose rows
point at a DONE artifact (with its path) or at a Y-generation task / living
doc. The Y plan's Appendix C proves full TODO coverage, which is what makes
the routed-bar policy satisfiable for four generations at once. dprint ran
BEFORE the `git mv`.

| File (date prefix)                                                       | Classification | Deciding reason                                                                                                               |
| ------------------------------------------------------------------------ | -------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| 2026-10-16_07-18_SUPERB-pareto-backlog-burn-plan                         | ARCHIVE        | N-generation ancestor; Appendix R maps N1-N27 (5 DONE with artifacts, rest routed to Y/decision-batch)                        |
| 2026-10-17_04-18_SUPERB-pareto-backlog-burn-plan-p-gen                   | ARCHIVE        | P-generation; 1:1 chain mapping already in its banner, Appendix R records the terminal hand-off to Y                          |
| 2026-10-18_22-20_SUPERB-pareto-v-generation-backlog-burn                 | ARCHIVE        | Per-task dispositions already written by W15.1 (2026-10-19); Appendix R records the archive verdict                           |
| 2026-10-19_02-34_SUPERB-pareto-w-generation-migration-fix-release-unlock | ARCHIVE        | Appendix R reads all 19 rows: 5 DONE (migration e2e, gate, dmarc-eval pins, guard tooling, docs corridor), rest split/routed  |
| 2026-10-19_07-35_SUPERB-pareto-x-generation-release-ship-residue-burn    | ARCHIVE        | Appendix R reads all 20 rows: 5 DONE (delta table, local guards, ruff debt, skip set, vm-debug.sh), rest routed to the Y plan |
