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

| File (date prefix)                                             | Classification | Deciding reason                                                                                                            |
| -------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------- |
| 2026-09-16_18-41_docs-health-pass2…                            | ARCHIVE        | b/c items closed (v0.3.0 shipped, assertions/hooks in 0.3.0, pushes flushed) or routed (TODO user-gated rows)               |
| 2026-09-16_19-16_medium-rows-swept…                            | ARCHIVE        | 18 opens all routed: TODO standing/watch rows, decision-batch C17-C20/C22/D1, ROADMAP §5 + pin-advance runbook             |
| 2026-09-17_15-11_v030-release-session-status                   | ARCHIVE        | signed-tags DONE (v0.4.0 ED25519 signature verified), PROXY answered (README ledger), rest routed to C17/C18-C20/D1/D2/Q6   |
| 2026-09-17_21-07_v031-release-and-demo-vm-hostfwd-hang         | ARCHIVE        | hostfwd hang fixed 2026-09-22; sole open (demo g2) routed to decision-batch Demo-VM residue                                 |
| 2026-09-22_19-07_capability-gap-advisory-session               | ARCHIVE        | drift repairs done (23-15 pass); f-table items struck 2026-09-29; c-group rows routed (TODO/decision-batch/ROADMAP)         |
| 2026-09-22_21-10_execution-session-pareto-tiers…               | ARCHIVE        | 12 opens all decision-batch pointers (D1/D2, C17-C20, C24/C29, demo g2); tag-cadence part resolved by v0.4.0               |
| 2026-09-22_22-50_m14-closeout-gate-green…                      | ARCHIVE        | 2 opens (D1+D2, C24+C29) routed to decision-batch                                                                          |
| 2026-09-22_23-15_docs-health-audit-harvest-routing…            | ARCHIVE        | was already fully struck (zero forward opens) — moved this pass                                                            |
| 2026-09-23_02-58_pareto-execution-demo-fix…mid-t12             | ARCHIVE        | was already fully struck — moved this pass; marker-column rows uniformized cell-wise (check-rows green)                    |
| 2026-09-23_03-21_pareto-resume-t12-forensic-fixture-red        | ARCHIVE        | T12 red root-caused + green same day (repaired fixture ae1e5adb, shipped v0.4.0)                                           |
| 2026-09-23_05-55_t12-green-v040-released-self-review           | ARCHIVE        | was already fully struck — moved this pass                                                                                 |
| 2026-09-29_04-35_docs-health-audit-full-2026-sweep…            | ARCHIVE        | 49 opens: routed (TODO rows/decision-batch/ROADMAP), done (AGENTS policy line, archive execution, push verified) or moot    |
| 2026-09-30_12-53_cross-repo-integration-design-session         | ARCHIVE        | HARVESTed same pass: 4 JMAP-seam TODO rows + C35-C37; InboxClean-side items stay theirs (rows 172-176, #156)                |

Earlier archives (2026-09-14 → 2026-09-17, 25 files): single-file moves whose
manifests live in the moving session's commit messages.
