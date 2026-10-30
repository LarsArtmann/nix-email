# Z-corridor completeness + ARF runtime proof (2026-10-26 21:23 CET)

> Scope: THIS session only. Baseline at `765970f` (clean tree), 20+ concurrent
> crush processes (multi-session machine), no foreign same-day report in the
> corridors. Predecessor: `2026-10-26_20-48_z-d-lane-session-full-status-*`
> (D-lane execution + self-review). Two opener claims were RE-VERIFIED rather
> than assumed, and both still hold: `gh auth status` HANGS (20 s timeout,
> exit 124 - invalid/expired token, the O1 blocker), and the hub's
> demo-flagging workstream has NO commits yet (G5 stays external-blocked).

## a) FULLY DONE (all verified)

1. **Owner-sitting sheet - COVERAGE RE-PROOF (the 51% bottleneck).** The sheet
   claimed to hold "every open owner call". It did not: **C36** (InboxClean
   topology), **C37** (build order), and **Q5** (declarative provisioning)
   were OPEN in `decision-batch.md` and appeared on NO sheet, so the owner
   could have answered every row and still left three calls open. Three
   2026-10-26 session g-questions (flood posture, report rename, report
   cadence - the Z-plan's own O2.4 agenda) and the AGENTS.md line-cap lint
   were also unanswered anywhere. All seven added (Batch 5 + new Batch 7),
   header comment amended with the audit trail, time budget 60 -> 70 min,
   and Appendix C's stale task IDs corrected (Resend C7.4 -> C8.3, CI lint
   scope D3 -> D4, D1/D2 C7 -> C8, C42 row added).
2. **C42's LAST evidence gap CLOSED at runtime** - `stalwart-e2e` subtest
   16b. An RFC 5965 `message/feedback-report` with
   `Feedback-Type: auth-failure` mailed from an unauthenticated session to
   `reports@example.test` (forwarding off) is CONSUMED: 30 s non-delivery
   window, exit 0. The delivery CONTROL - a report-less message to the SAME
   address - IS delivered (probe exit 0 in 0.13 s), so the absence is
   report-specific, not address-wide.
   Detection shape pinned from upstream source first (`arf/parse.rs`): ARF
   is MIME-typed (`message/feedback-report` + recognised `Feedback-Type`);
   the aggregate detector instead keys on the attachment NAME. That
   asymmetry is why the filename-shaped aggregate probe proves nothing
   about ARF - the probe had to be shaped differently.
   Cost measured: +45 s script time (302 s -> 342 s); both swaks uploads
   spend ~45 s on real RCPT policy lookups in the DNS-less VM.
3. **Evidence trail updated everywhere it was claimed stale**: README ledger
   "0.16 report features" (docs-verified -> runtime-verified + the
   MIME-vs-name asymmetry), `decision-batch.md` C42 (runtime gap closed
   block), the sitting sheet's C42 STALE flag (now RESOLVED, pure owner
   verdict), the TODO C42 row (no evidence gap left), CHANGELOG (Added +
   Fixed).
4. **Two unharvested self-review items folded** (both flagged in the 20-48
   report and left unowned): the BuildFlow row's JSON-mode
   `missing_file=17` data point (the pseudo-finding count is
   MODE-DEPENDENT - a fix must reproduce both modes), and the buildflow
   binary-rev stamping rule (the D-lane GREEN ran `58115f7` while their
   HEAD was `24dff81` - the fleet has no rebuild cadence).
5. **Gate proof on the final tree**: full `nix flake check` EXIT 0 (the
   `stalwart-e2e` output drv `ji218g5...` is the executed one - `nix log`
   on it contains the control leg), `nix fmt -- . --check` green, md
   table-pipe lint green, md list-marker lint green, dprint 0.28.2 pass
   with a post-format diff read-back.

## b) PARTIALLY DONE

- **BuildFlow full gate**: run started at 21:23; concurrent sessions push
  the shared state DB (`SQLITE_BUSY` checkpoint warnings) - verdict must be
  read with that context. The flake gate above is the authoritative proof
  for this session's changes; buildflow re-covers formatters/linters only.
- **ARF journal evidence**: at default tracing verbosity 0.16 logs nothing
  per message, so the runtime proof is the DELIVERY OUTCOME, not a journal
  event. A traced-verbosity variant could assert `incoming-report.*`, but
  the delivery control already excludes the address-wide-swallow
  alternative; the extra assertion would only re-prove parse rather than
  consumption.

## c) NOT STARTED (owner-gated by design)

O1 (`gh auth login`), O2 (the sitting - now genuinely one sitting), O3, **→ routed 2026-10-30: O1 SATISFIED 2026-10-28 (auth live); A1-A5/C1/C4 executed 2026-10-28 (v0.5.0 + fe132422); the remainder rides the sitting sheet + TODO rows**
A1-A5, B1-B3, F1-F4, C1-C8, D4/D5, G1-G7: all untouched, all still owned by
the Z-plan. Nothing in this session consumed an owner-gated row.

## d) WHAT WENT WRONG (process, no damage)

- **The auto-commit daemon ate three commits again** (`6933fbb`, `1b88d9a`,
  `6550211`, plus `c63c7f9` for the last TODO edit). Content preserved
  exactly and the rationale lives in source comments + CHANGELOG, but the
  history shows heuristic messages instead of the reasoning. The
  same-tool-call doctrine was applied to CHANGELOG (commit `7327eab`) and
  still lost to the daemon on every non-CHANGELOG edit.
- **`nix build --rebuild` on an unbuilt drv errors** ("checking is not
  possible"); `--rebuild` implies `--check` and is only valid once an
  output exists. Cost: one wasted VM-less build invocation.
- **Ordering slip**: the subtest-list comment edit landed while the second
  VM run was already evaluating. Harmless (drv hashes ignore comments -
  confirmed: the eval after the edits still resolves to the executed
  `ji218g5...`), but the right order is edit-then-build.

## e) WHAT TO IMPROVE

1. Fold observations into the owning row in the SAME session - the two
   self-review items had been flagged and left; both took ~4 minutes.
2. When asserting "every open call is on the sheet", prove it mechanically
   (enumerate `### C|Q|D` headings in `decision-batch.md`, diff against the
   sheet's ID column) instead of trusting the sheet's own claim. That is
   the check that would have caught C36/C37/Q5 in October.
3. For MIME-detected behaviour, read the upstream parser FIRST: it decided
   the probe shape here and would have saved the guesswork.
4. Keep the runtime-budget doctrine honest: the ARF leg doubles the
   ingestion window; the comment block now states both windows and the
   reason they are not trimmed.

## f) NEXT (unchanged Z-plan order, minus what this session closed)

~~1. O1: `gh auth login -h github.com` (5 min) - four filings + tag-CI watch~~ **→ routed — SATISFIED 2026-10-28: gh auth live (10-28 report Appendix item 20)**
   parked behind it.
~~2. O2: the sitting - the sheet is now COMPLETE (C36/C37/Q5/D5/rename/~~ **→ routed — partially answered 2026-10-28 (C43/C45/contacts); C42/C44/C39-C41/C46 remain on the sheet**
   cadence/AGENTS added); ~70 min clears >51% of the remaining board.
~~3. O3 then A1-A5 (v0.5.0), B1-B3 (pbx), C1-C8 (pin advance +~~ **→ routed — unlocked lanes EXECUTED 2026-10-28 (v0.5.0 release + fe132422 pin advance); B1-B3 + verdict lanes stay owner-gated**
   verdict executions), D4/D5, G1-G7.
~~4. New, cheap: add the mechanical sheet-vs-batch ID diff as a script if the~~ **→ routed — idea stands (its own text: not worth a check yet)**
   sitting slip ever repeats (not worth a check yet).

## g) Questions I cannot answer myself

~~1. **O1 timing** - unchanged: when does `gh auth login` run?~~ **→ routed — ANSWERED: gh auth live again 2026-10-28**
~~2. **O2 timing** - the sheet is complete now; is the sitting happening?~~ **→ routed — sittings partially held 2026-10-28; the sheet still carries C42/C44/C39-C41/C46**
~~3. **C42 verdict** - evidence is complete (aggregates + ARF, runtime-verified~~ **→ routed — OPEN: pure owner call (TODO_LIST C42 row; sheet Batch 1)**
   on the pin, controls included). Retire now, or keep through
   stabilization? That is now the ONLY thing standing between C42 and done.

## Verdict

One real defect found and fixed (a sheet that promised full coverage held
three open calls plus four unowned questions), and one real evidence gap
closed at runtime (ARF ingest, with a control that excludes the
address-wide explanation). No defaults weakened, no test relaxed, no
owner-gated row touched. Gate green on the final tree.
