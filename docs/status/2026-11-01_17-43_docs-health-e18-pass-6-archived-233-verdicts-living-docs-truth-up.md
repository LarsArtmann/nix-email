<!-- Status snapshot 2026-11-01 17:43 CET. Scope: THIS session only
     (~16:50 -> 17:43), a docs-health AUDIT pass (skill loaded first;
     the user instruction: view ALL 2026-0* files, execute the skill,
     superb living docs, archive the fully-done). Baseline ritual ran:
     tree clean, 4 live crush -y PIDs, one same-day corridor pair
     (02-29 + 06-03) read before any edit. A concurrent session's
     17:18 commit (f12ed24, ruff-wrap reformat of the probe +
     annotate-corridor py) was investigated before touching anything -
     neither file is this pass's surface. Gate state at yield: dprint
     --check green, pipe lint green, annotate check-rows green on every
     touched file, eval-level flake check EXIT 0. -->

# Status: docs-health E18 pass - 6 archived, 233 verdicts, living docs truth-up (2026-11-01 17:43)

## 0. TL;DR

| Area        | Verdict                                                                                                                                                                                                                                                                                                                                    |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-0\*    | The literal glob matches 4 non-archived files - the architecture-understanding d2/svg set, regenerated 2026-10-31 and already carrying the 0.16.26 + probe surface (E7's re-baseline). Fresh; the 45 archived matches stay closed (mechanical gate only)                                                                                   |
| ANNOTATE    | 233 verdicts across the 10-30 -> 11-01 corridor + the Z-plan + the mailsuite draft (217 tool-applied via annotate-corridor.py, 16 house-grammar bullet strikes, Z-plan Appendix R)                                                                                                                                                         |
| ARCHIVE     | 6 files moved with manifests in both archive READMEs; bulk check-rows green BEFORE the git mv and re-verified at the archived paths; `grep -L '~~'` silent                                                                                                                                                                                 |
| Living docs | TODO_LIST: 1 DONE row deleted + 6 rows added + banners re-dated; AGENTS +2 clauses; CONTRIBUTING +2 rules (errexit, A4 shape split); MONITORING row-2 lazy note; FEATURES CI currency + parsedmarc wait claim; ROADMAP +parked-ideas line +drift-alarm line +open question 10; decision-batch C20 resolved by events; CHANGELOG pass entry |
| Kept live   | 12-17 + 14-19 (pbx owners, Omega B3), 10-23_11-26 (pbx-deferred), the sitting sheet, the EventCatalog publish plan, decision-batch, the Omega plan                                                                                                                                                                                         |
| Gates       | All green at yield (see header)                                                                                                                                                                                                                                                                                                            |

## a) FULLY DONE (verified this session, evidence cited)

1. **The 06-03 closeout's own residual list executed**: the
   loaded-runner timeout-audit TODO row + CI cache-throttle row ADDED
   (owner questions g/2-g/3 now have durable homes), the final green
   run id 41265954894 STAMPED into the 02-29 h) addendum, both AGENTS.md
   clauses landed (rerun-triage: grep the whole failed log before
   rerunning; the alejandra-only `nix fmt` caution), and the dprint
   coverage gap rowed.
2. **Fix-on-sight doc repairs**: CONTRIBUTING rule (f) rewritten to the
   A4 scope split (it still carried the superseded pbx run-16 framing
   while both test headers tell the 2026-10-31 truth) + the NEW
   test-driver errexit rule ((f) in the first rules list); MONITORING
   row 2 gained the `queue_rescheduled` LAZY-registration note (a fresh
   boot shows no HELP line - rules must expect a missing series).
3. **ANNOTATE + ARCHIVE (E18, the pre-committed pass)**: 18-26 (63
   verdicts; header Verdict cell corrected to the RESOLVED form - a
   partial cell strike trips check-rows uniformity), 20-29 (64),
   02-29 (51 + 8 bullets), 06-03 (39 + 6 bullets + 2 range lines), the
   Z-plan (closure banner + 25-row Appendix R; routed rows use the
   `**→ routed**` arrow so check-rows counts them resolved), and the
   mailsuite draft (CLOSED-upstream header note + the moot PR-offer
   line struck). Three dprint-rewrap hazards caught by the post-pass
   gates: one dash-lead continuation in the struck 02-29 bullet
   (reflowed, dprint-stable), the header-cell partial-strike class
   (converted), and the manifests (dprint-excluded as archived dirs -
   formatted before the move where live).
4. **Dangling-pointer sweep after the move** (the B3.3 discipline):
   the Omega-plan's source pointer repointed at the archived 20-29
   path; decision-batch C20 resolved-by-events (draft FILED 2026-10-05,
   upstream FIXED via their PR #67 2026-10-27 - the [rec] executed as
   recommended); TODO rows cite archived paths from the start.
5. **Living-docs truth-up**: TODO banners re-dated to this pass; the
   DONE reconcile-destroy row DELETED (doctrine: done rows live in
   CHANGELOG); 6 new rows (timeout audit, cache-throttle, dprint gap,
   VM/debug tooling batch, deliverability probe backlog lane,
   TELEMETRY compression); the filings row re-statused (gh auth LIVE -
   the gate is the owner review); the BuildFlow row carries the jscpd
   native-config skill note. FEATURES: gate + CI rows' currency through
   run 41265954894 with both 11-01 flake classes; the parsedmarc-e2e
   row's "120 s parse bound" replaced by the 300 s reality (grep-backed
   against the test). ROADMAP: theme-4 parked probe follow-ons line
   (absorbs the 18-26 f/36-50 raw ideas), theme-6 drift-alarm parked
   line, open question 10 (A4 residuals - gives the 02-29 g/2-3 owner
   questions their durable home).
6. **Gates at yield**: `nix develop -c dprint fmt` idempotent on the
   live tree, pipe lint EXIT 0, check-rows green on every touched file
   (live AND archived), eval-level `nix flake check` EXIT 0.

## b) PARTIALLY DONE

1. **README verification was spot-wise again** (banner, check list,
   fast-movers) - the D7 line-by-line banner (2026-10-31) remains the
   authoritative pass; nothing this session changed contradicts it.
2. **The probe + annotate-corridor reformat commit (f12ed24)** belongs
   to a concurrent session; its narrative (why a ruff-wrap pass ran at
   17:18) is theirs to write. Not investigated beyond confirming no
   overlap with this pass's surface.
3. **The three kept-live status reports still carry open arrows** by
   design (Omega B3 converts them at the pbx blessing; the lean
   refresh-at-archive-time verdict was applied: frozen, not re-annotated).

## c) NOT STARTED (all routed)

1. Every owner-gated row (the sitting: C42/C44/C39-C41/C46, pbx
   blessing, D1/D2, Resend, policy batch, REPORT-RENAME/CADENCE, AGENTS
   cap, C36/C37/Q5) - the sheet owns them; nothing consumed.
2. The new rows themselves (timeout audit needs the g/3 verdict; dprint
   gap needs a lane decision; VM/debug tooling batch; probe backlog
   lane; TELEMETRY compression).
3. Their-repo lanes (SystemNix wiring + CI debt, BuildFlow batch) and
   the filings queue (A1 owner review, A2 ON HOLD) - unchanged rows.

## d) TOTALLY FUCKED UP (all caught in-session, zero damage)

1. **Three multiedit round-trips lost to dprint rewraps** (TODO banner,
   FEATURES gate row, ROADMAP drift-alarm line): I reconstructed
   old_strings from a session-start read instead of re-viewing the
   exact lines - the 06-03 lesson (grep-count anchors, read before
   asserting) applies to edit anchors too. All recovered on retry.
2. **A verdict-map transcription error caught on the dry-run read-back**:
   18-26 lines 134-136 got the WRONG verdicts (I mapped the 20-29
   report's f/43-45 item text onto 18-26's line numbers). The driver's
   `--verify` print-every-line output is what caught it - verify-first
   is load-bearing, not ceremony.
3. **The header-cell partial strike tripped the uniformity gate** - a
   metadata table row with one struck fragment is PARTIAL by check-rows
   math (struck rows must cover the table or ride the ledger
   exemption). Converted to the non-strike RESOLVED append; strikes
   stay in the b/c/f/g sections where they belong.
4. Minor: the first dprint pass over the manifests reported "no files
   found" - the archived/ excludes were ALREADY doing their job; the
   manifests were formatted pre-move in the earlier repo-wide pass.

## e) WHAT WE SHOULD IMPROVE

1. **Line-number-based verdict maps should be built FROM the verify
   output, not from session-start reads** - emit-keys print-line
   pairing exists precisely so verdicts bind to lines read-back, not
   remembered (d/2).
2. **The metadata-header-table class deserves one house line** in the
   skill: header Field/Value tables take the RESOLVED-append form, not
   strikes (uniformity gate makes strikes there a guaranteed rework).
3. The Omega-plan's L1 do-now rows all carry DONE verdicts but the plan
   itself will need its own Appendix R at ITS archive time - worth
   writing the dispositions as verdicts land, not at archive time.

## f) NEXT

1. O1 the owner sitting (unchanged; gates >51% of everything).
2. The new TODO rows in priority order: timeout-audit verdict (g/3) ->
   sweep; dprint coverage gap; VM/debug tooling batch; probe backlog
   lane; TELEMETRY compression.
3. A1/A2 filings, B1-B3 pbx chain, C/D/E Omega lanes - unchanged rows.
4. Next docs-health pass: the 10-23_11-26 report + the two pbx owners
   ride B3; THIS report archives at the next corridor pass (f/50
   pre-commits nothing - it IS the corridor close).

## g) QUESTIONS FOR THE OWNER

1. The sitting (sheet Batches 1-7) - unchanged, still gates >51%.
2. ROADMAP open question 10 (A4 residuals) is NEW - the two small
   taste calls the 02-29 session left in its g/2-3 now live there.
3. The two new TODO owner rows (timeout sweep vs per-flake; CI
   cache-throttle mitigation vs manual rerun) - both from the 06-03
   closeout's g-list, now rowed for the sitting.
