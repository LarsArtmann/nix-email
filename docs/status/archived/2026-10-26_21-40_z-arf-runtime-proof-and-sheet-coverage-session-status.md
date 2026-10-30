# Z-lane: ARF runtime proof + owner-sitting coverage audit (2026-10-26 21:40 CET)

> Scope: THIS session only. Baseline `765970f` (clean tree), 20+ concurrent
> crush processes, no foreign same-day report in the corridors at start.
> Predecessor: `2026-10-26_20-48_z-d-lane-session-full-status-*` (D-lane
> execution + self-review) and my interim report
> `2026-10-26_21-23_z-corridor-completeness-and-arf-runtime-proof.md`
> (written before the last two fixes; this file supersedes it and adds the
> honest gaps).
> Note: the board moved UNDER this session - another session added a
> High-impact TODO row at 21:33 (`593ba15`, the reconcile-destroy retirement
> pattern). Not mine, not touched.

## a) FULLY DONE (verified, with evidence)

1. **Blockers re-verified instead of assumed.** `gh auth status` HANGS
   (20 s timeout, exit 124) - the O1 blocker is real, not stale report text.
   The hub's demo-flagging workstream has no commits (G5 stays
   external-blocked). Both re-checks cost ~1 minute and prevented two
   wasted lanes.
2. **Owner-sitting sheet - COVERAGE RE-PROOF.** The sheet's own claim
   ("Every entry here is an OPEN owner call harvested fresh") was FALSE:
   - **C36** (InboxClean topo), **C37** (build order), **Q5** (declarative
     provisioning) sat OPEN in `decision-batch.md` and appeared on no sheet.
   - The three 2026-10-26 g-questions (flood posture, report rename, report
     cadence) - the Z-plan's own O2.4 agenda - were answered nowhere.
   - The AGENTS.md line-cap doctor warning (247 vs 220) had no owner home.
   - Appendix C carried stale IDs (Resend C7.4 -> C8.3, CI lint scope D3 ->
     D4, D1/D2 C7 -> C8; C42 missing entirely).
     All fixed: seven entries added (Batch 5 + new Batch 7), header amended
     with the audit trail, budget 60 -> 70 min, Appendix C corrected.
3. **C42's LAST evidence gap closed at RUNTIME** - `stalwart-e2e` subtest
   16b. RFC 5965 `message/feedback-report` + `Feedback-Type: auth-failure`,
   unauthenticated session, `reports@example.test`, forwarding off:
   CONSUMED (30 s non-delivery window, exit 0). Delivery CONTROL - a
   report-less message to the SAME address - IS delivered (exit 0 in
   0.13 s), so the absence is report-specific. Detection shape pinned from
   upstream source FIRST (`crates/smtp-report/src/arf/parse.rs`: MIME-typed
   on `message/feedback-report`, unlike the aggregate detector's
   attachment-NAME match).
4. **Evidence trail de-staled in all four places it was claimed stale**:
   README ledger "0.16 report features", `decision-batch.md` C42 (runtime
   gap closed block with the subtest cost), the sheet's C42 STALE flag
   (RESOLVED - pure owner verdict now), TODO C42 row (no evidence gap left),
   CHANGELOG (Added + Fixed, commit `7327eab`).
5. **Two unharvested self-review items folded** into the BuildFlow row:
   JSON-mode `missing_file=17` vs pretty-mode 55 (count is MODE-DEPENDENT),
   and the binary-rev stamping rule (D-lane GREEN ran `58115f7` while their
   HEAD was `24dff81`).
6. **Proof on the final tree**: full `nix flake check` EXIT 0; the
   `stalwart-e2e` output drv `ji218g5lhfm...` is the EXECUTED one (its
   `nix log` contains the control leg; comments do not change drv hashes -
   proven, not assumed). `nix fmt -- . --check` EXIT 0, dprint 0.28.2 pass,
   md pipe lint EXIT 0, md list-marker lint EXIT 0, eval-only
   `nix flake check --no-build` EXIT 0 on the final docs tree.
   `buildflow --max-time 30m` EXIT 0: 33 success / 0 failed / 1 config
   skip, binary `58115f7`, 9 tools unavailable (expected), millisecond
   timing-regression lines (known noise).
7. **Session report + commits with real timestamps** (`date` before naming),
   no push (no instruction), no owner-gated row consumed.

## b) PARTIALLY DONE

1. **Coverage proof was ID-level, not claim-level.** I diffed the sheet
   against `decision-batch.md` headings and recommendations by READING. I
   did not mechanically extract every `### C|Q|D` heading and every `[rec]`
   line, so a stale recommendation inside an already-present row would not
   have been caught (C42's was; I did not re-read C44/C46/C52/C53 against
   their batch text beyond the rows I touched).
2. **`consumed` vs `parsed`.** The probe proves consumption (no delivery)
   and a delivered control. It does NOT capture an analyzer event, because
   0.16 at default tracing verbosity logs nothing per message. So "parsed"
   remains an inference from report-specific consumption. A
   traced-verbosity variant would pin `incoming-report.*` event names.
3. **BuildFlow verdict context.** The run emitted `SQLITE_BUSY` resume
   checkpoint warnings (a concurrent session shares the state DB) and my
   verdict ran on binary `58115f7` (their HEAD is ahead). The green is
   real for the steps that ran, but the fleet still has no rebuild cadence.
4. **The ARF subtest costs +45 s** (302 s -> 342 s script time; two swaks
   uploads at ~45 s each because RCPT policy lookups stall in the DNS-less
   VM). Documented in the runtime-budget block, not optimized.

## c) NOT STARTED (owner-gated or newly surfaced by this session)

~~1. O1 `gh auth login` (owner, 1 command): four drafted filings, the tag-CI~~ **→ routed — SATISFIED 2026-10-28: gh auth live (z-gen O1)**
   watch, and the origin-CI observation of the pushed tree wait on it.
~~2. O2 the sitting (~70 min now): every A/B/C/D4/D5/G-lane item.~~ **→ routed — partially held 2026-10-28; C42/C44/C39-C41/C46 remain on the sheet**
~~3. O3 recording verdicts into `decision-batch.md` + TODO re-row + README~~ **→ done — verdicts recorded 2026-10-28 (decision-batch banners) + this pass re-rows TODO_LIST**
   banner.
~~4. A1-A5 (v0.5.0 release train), B1-B3 (pbx + corridor closeout), F1-F4~~ **→ routed — A-lanes EXECUTED 2026-10-28; B1-B3 + verdict lanes owner-gated**
   (filings), C1-C8 (pin advance + verdict executions), D4/D5, G1-G7.
~~5. **The two stale documents my fix created**: TODO's owner-sitting row and~~ **→ done — both stale documents updated (TODO sweep note 2026-10-26 21:07; z-plan O2 line this pass)**
   the Z-plan's O2 line still list the OLD decision set (they omit
   C36/C37/Q5, flood, rename, cadence, AGENTS). See (d).
~~6. **Orphan decisions**: C36/C37/Q5 (and arguably Q5 above all) have NO~~ **→ done — execution homes exist: ROADMAP open question 5 residue + sheet Batch 5**
   TODO row. A verdict cannot be executed against a row that does not
   exist - Q5's declared `domains`/`accounts` work has no home.

## d) TOTALLY FUCKED UP (process; no data loss)

1. **The auto-commit daemon ate FIVE commits of this session's work**
   (`6933fbb`, `1b88d9a`, `6550211`, `c63c7f9`, `e795847`) before my explicit
   commits (`7327eab`, `315bf34`, `d74224d`). Content is byte-preserved and
   the rationale lives in source comments + CHANGELOG, but history shows
   "chore: auto-commit N changed file(s) (heuristic)" where the reasoning
   should be. The same-tool-call doctrine worked for CHANGELOG and lost for
   every other file.
2. **I fixed ONE document and left TWO inconsistent** - the classic
   `verschlimmbessern`: adding seven rows to the sheet without updating
   TODO's "one sitting clears the blocked rows above" row or the Z-plan's
   O2 task line means a future reader of either gets the OLD decision list.
   Caught in this self-review, not before shipping.
3. **`nix build --rebuild` on an unbuilt drv errors** ("checking is not
   possible") - one wasted invocation; `--rebuild` implies `--check`.
4. **Ordering slip**: the subtest-list comment edit landed while a VM run
   was already evaluating. Harmless (comments do not enter drv hashes -
   verified), but the order should be edit-then-build.
5. **I trusted my own grep scope**: the archived-corridor check for
   C36/C37/Q5 was an afterthought, and it surfaced that Q5 may already have
   a partial doctrine answer (`docs/status/archived/2026-09-15_19-19_*`:
   "wrapper doctrine note ... (feeds ROADMAP Q5) done"). The sheet presents
   Q5 as fully open. I did not resolve whether that note settles Q5 or only
   informs it.

## e) WHAT WE SHOULD IMPROVE

1. **Mechanize the coverage claim.** A ~20-line script that extracts every
   `### (C|Q|D|R)[0-9]+` heading from `decision-batch.md` and every ID cell
   from the sheet, then prints set differences, turns "prove it" from a
   15-minute read into one command. This session's whole defect class is
   exactly what that script catches.
2. **Update the pointer graph with the content.** Any change to the sitting
   set must touch THREE sites (sheet, TODO's sitting row, Z-plan O2) - the
   same anti-drift rule the repo already applies to flake checks.
3. **Give every decision an execution home.** A verdict with no TODO row is
   a verdict that never lands (Q5 is the proof). Add an "unlocks" row at
   answer time, in the same edit that records the verdict (O3).
4. **Fold observations in the same session they appear.** The two BuildFlow
   items were flagged by the previous self-review and left; they took four
   minutes here.
5. **Read the upstream parser before shaping a probe.** `arf/parse.rs`
   decided the probe shape and would have saved the first design pass.
6. **Stamp the tool rev on every verdict** (flake check: the drv path;
   buildflow: its binary rev). Without it, "green" is unfalsifiable after a
   sibling session rebuilds the tool.
7. **Keep the runtime-budget comment honest as tests grow** - the ARF leg
   doubled the ingestion window; the block now states both windows and why
   they are not trimmed.

## f) UP TO 50 THINGS TO GET DONE NEXT (impact-sorted)

Owner micro-actions (cheapest, unblock the most):

~~1. `gh auth login -h github.com` (O1) - unblocks 2-6.~~ **→ routed — SATISFIED 2026-10-28: gh auth live (z-gen O1; 10-28 report Appendix item 20)**
~~2. Post the ready #552103 webui-resource comment (`docs/drafts/`).~~ **→ routed — owner-review-gated (TODO_LIST admin-bundle row; the 2026-10-28 ON HOLD posture)**
~~3. Re-verify + post the nixpkgs#563651 follow-up (host-less `[opensearch]`).~~ **→ routed — ON HOLD per owner 2026-10-28, draft review before posting (TODO_LIST watch row)**
~~4. Watch the tag-CI fire on the release dry-run once auth exists.~~ **→ done — superseded by the real cut: tag-CI watched and greened 2026-10-28 (v0.5.0 release)**
~~5. Answer the sitting sheet (~70 min) - all A/B/C/D4/D5/G lanes.~~ **→ routed — partially held 2026-10-28 (C43/C45/contacts); C42/C44/C39-C41/C46 remain on the sheet**
~~6. Decide C42 now that evidence is complete (retire vs keep).~~ **→ routed — OPEN: pure owner call (TODO_LIST C42 row; sheet Batch 1)**
~~7. Confirm the push posture for the unpushed local commits (C38 sub-question).~~ **→ done — superseded: master pushed; v0.5.0 released from it 2026-10-28**

Docs / board consistency (mine to do, all small):

~~8. Update TODO's owner-sitting row to the new decision set (C36/C37/Q5,~~ **→ done — DONE 2026-10-26 21:07: the TODO_LIST sweep note records all seven calls in sheet Batches 5+7**
   flood, rename, cadence, AGENTS).
~~9. Add an errata line to the Z-plan's O2 row listing the added calls.~~ **→ done — the z-plan O2 line updated this pass (2026-10-30) with the full post-audit decision set**
~~10. Point the D5 flood TODO row at Batch 7 of the sheet.~~ **→ routed — TODO_LIST flood row + sheet Batch 5 own it**
~~11. Point the CI blue row / python-lint row at the sheet's "CI" row.~~ **→ routed — TODO_LIST CI python-lint row + sheet CI item**
~~12. Add a TODO row for Q5's execution (declarative `domains`/`accounts`).~~ **→ routed — execution home = ROADMAP open question 5 residue (0.16-born option-surface ideas) + sheet Batch 5**
~~13. Add TODO rows (or explicit "other repo" notes) for C36/C37 execution.~~ **→ routed — cross-repo lanes (InboxClean topology, build order); sheet Batch 5 owns them**
~~14. Check whether the 2026-09-15 doctrine note settles Q5; annotate the~~ **→ done — ROADMAP open question 5 already carries the resolution (OVERTAKEN BY EVENTS 2026-10-17) + the 0.16-born-ideas residue**
    sheet row as PARTIAL if it does.
~~15. Record the coverage-audit method in the sheet header (done) and in~~ **→ routed — method recorded in the sheet header (done there); the CONTRIBUTING section was not added**
    CONTRIBUTING's sitting section (not done).
~~16. Write `scripts/check-sheet-coverage.sh` + wire it into CI if cheap.~~ **→ routed — idea stands (not worth a check yet, per the 21-23 f/4 verdict)**
~~17. Add the ARF subtest to the README "What is built and verified" prose~~ **→ done — README stalwart-e2e check row names the full subtest set incl. native DMARC + ARF ingestion (verified this pass)**
    restatement (the check list is single-sourced; the subtest count prose
    is not).
~~18. Update `FEATURES.md`'s dmarc-monitor row if it implies failure parsing~~ **→ done — FEATURES mail-server row now names native ARF ingest (added this pass)**
    is parsedmarc-only (checked: FEATURES describes parsedmarc-e2e, not the
    Stalwart-native surface - one sentence may help).

Test / code hardening:

~~19. Traced-verbosity variant asserting an analyzer event name (pins~~ **→ routed — parked test idea (the delivery control already excludes the address-wide alternative)**
    `incoming-report.*`, closes "parsed vs consumed").
~~20. Trim the ARF absent window if a transcript ever shows the delivery~~ **→ NOT-DO — do-not-trim-blind standing rule (its own text)**
    path is visible sooner (do not trim blind).
~~21. Fold the control idea into the AGGREGATE subtest (same~~ **→ routed — parked idea (defense in depth for the aggregate leg)**
    address-wide-swallow concern applies there).
~~22. Consider one combined report-ingestion subtest to share the ~45 s RCPT~~ **→ routed — parked idea (runtime optimization)**
    lookups across both report types.
~~23. Assert the ARF needle absence in a SECOND recipient (defence in depth~~ **→ routed — parked idea (defense in depth)**
    against a routing change).
~~24. Re-run the full gate on the next .nix change and compare script time to~~ **→ done — superseded: later gates ran green with runtime numbers (10-26/10-28 reports)**
    the 342 s baseline.

Release path (owner-verdict dependent):

~~25. A1 CHANGELOG `[Unreleased]` date/link pass (links resolve, blocks~~ **→ done — v0.5.0 cut commit 06ab701 (CHANGELOG rename, same-call)**
    merged) + same-call commit.
~~26. A2 release-tree gate proof with both logs archived as release evidence.~~ **→ done — release-tree proof 2026-10-28: flake check EXIT:0 + buildflow EXIT:0 (10-28 report Appendix 2/3)**
~~27. A3 scratch-tag dry-run of the CONTRIBUTING release procedure.~~ **→ done — SKIPPED in favor of the real cut (z-gen banner)**
~~28. A4 cut v0.5.0 (annotated tag, push, tag-CI green, gh release).~~ **→ done — v0.5.0 RELEASED 2026-10-28 (tag-CI green after two diagnosed reds, gh release)**
~~29. A5 README banner + FEATURES + AGENTS release-state lines.~~ **→ done — README banner flipped to the 2026-10-28 state (10-28 report Appendix 5)**
~~30. SECURITY.md version/contact bump at the cut.~~ **→ done — cut commit includes the SECURITY version bump (06ab701)**

Consumer / pin advance:

~~31. C1 pin advance + the #566282 `provision.elasticsearch` -> `opensearch`~~ **→ done — fe132422 pin advance landed 2026-10-28 (10-28 report)**
    port (preflight grep first).
~~32. C2 #552103 retirement check against the new pin (or C45 overlay).~~ **→ done — C45 SUPERSEDED: the pin ships 0.16.26; #552103 OPEN, vendored dir stays**
~~33. C3 SystemNix contract-test fix + pin bump to v0.5.0.~~ **→ done — premise superseded 2026-10-28: SystemNix floats this repo master**
~~34. C4 post-bump checks (aarch64 shape, dovecot rename warning gone, watch~~ **→ done — at the advance: aarch64 shape, dovecot warning gone, watch re-dated**
    re-date, `disabledModules` collision verdict).
~~35. G4 CardDAV probe re-run (17/18 baseline) on the first real bump.~~ **→ done — RUN 2026-10-28: 17/18 PASS on 0.16.26 (row closed, re-arms at the next bump)**
~~36. SystemNix description-sync refresh when wrapper capabilities change.~~ **→ routed — TODO_LIST description-sync row**

Upstream / external:

~~37. F2 #563651 follow-up verification (cli.py probe on current master).~~ **→ routed — ON HOLD per owner 2026-10-28 (draft review first)**
~~38. F3 mailsuite#65 nudge at ~11-05 after re-reading their `imap.py`.~~ **→ routed — calendar item ~2026-11-05 (TODO_LIST watch row)**
~~39. F4 dnsmasq-forward resolver note: pick venue, draft, file.~~ **→ routed — TODO_LIST upstream-filings row (venue + gh)**
~~40. G1 BuildFlow batch: 204-vs-4 bandit gap, `running N flake checks` stale~~ **→ routed — TODO_LIST BuildFlow row (their repo)**
    count, ruff identity parsing in BOTH output modes, detect-only steps,
    vulture policy, masking docs, threshold as config.
~~41. G5 EventCatalog publish + live verify once the demo-flagging workstream~~ **→ routed — TODO_LIST EventCatalog publish row (external workstream pending)**
    lands (mirror condition already satisfied).
~~42. G6 next upstream watch re-check at the nudge date; fold the rename~~ **→ routed — TODO_LIST watch row (~11-05 cadence)**
    watch into C2.

Gate / machine hygiene:

~~43. Decide whether AGENTS.md's 220-line doctor cap should be accepted~~ **→ routed — owner taste (sheet Batch 7 AGENTS item)**
    (now on the sheet as AGENTS) or the file trimmed.
~~44. BuildFlow state DB 0.63 GB + VACUUM hint: schedule a periodic purge.~~ **→ routed — BuildFlow-repo hygiene (their tool, their repo; the 20-48 e/5 note owns it)**
~~45. Establish a buildflow-binary rebuild cadence after sibling sessions~~ **→ routed — TODO_LIST BuildFlow row (binary-rev stamping + rebuild-after-sibling note)**
    land (or namespace the state DB per rev to stop `SQLITE_BUSY`).
~~46. Rename the mis-timestamped `20-15` status report per the REPORT-RENAME~~ **→ routed — REPORT-RENAME verdict on the sheet (Batch 5); name kept meanwhile, the absorbing report carries the truth**
    verdict.
~~47. Decide the combined-vs-two-report cadence (REPORT-CADENCE verdict) and~~ **→ routed — REPORT-CADENCE verdict on the sheet (Batch 5)**
    encode it in the status-report skill.

New row from the concurrent session (their fix, our doctrine):

~~48. Document the reconcile-destroy retirement pattern beside the `relay`~~ **→ routed — TODO_LIST reconcile-destroy row (added 593ba15)**
    option and consider the opted-in empty reconciled set (`593ba15` row).
~~49. Add a test or eval guard for "retiring an option leaves stale store~~ **→ routed — rides the reconcile-destroy row (its "guarded automated path" consideration)**
    rows" if the pattern is confirmed on a second option.
~~50. Batch the next docs-health pass over the 2026-10-26 corridor (three~~ **→ done — THIS pass (2026-10-30 docs-health): corridor annotated + archived**
    same-day reports now) once the owner settles cadence.

## g) THREE QUESTIONS I CANNOT ANSWER MYSELF

~~1. **Does the 2026-09-15 wrapper-doctrine note already settle Q5?**~~ **→ routed — ROADMAP open question 5 carries the OVERTAKEN-BY-EVENTS resolution; the archived note stands as scope context**
   (`docs/status/archived/2026-09-15_19-19_*`: "wrapper doctrine note ...
   (feeds ROADMAP Q5) done — 26d doctrine written"). If it does, Q5 on the
   sheet is a PARTIAL answer, not an open one; if it does not, say so and I
   will annotate the archived pointer. I cannot tell from the note alone
   whether its "which features get options vs pass-through" doctrine covers
   `domains`/`accounts` specifically.
~~2. **C42 verdict, now that the evidence is complete** (aggregates AND ARF,~~ **→ routed — OPEN: pure owner call (TODO_LIST C42 row; sheet Batch 1)**
   runtime-verified on the pin, with a delivery control): retire
   `services.dmarc-monitor`, or keep through 0.16 stabilization and
   re-decide at D1? Evidence no longer discriminates; this is taste and
   risk appetite.
~~3. **Push posture for the local-only commits** (the prior session's open~~ **→ routed — superseded by events: master pushed and v0.5.0 released 2026-10-28**
   question, still unanswered): push now (`373c30a` was the last pushed
   rev), or hold everything for the v0.5.0 release push? Four commits plus
   the daemon's pickups are local; CI cannot observe any of it until a
   push, and the tag-CI watch needs auth anyway.

## Verdict

Two real defects found: a coverage claim that was false on the one document
gating >51% of the plan, and a "docs-verified" evidence claim that could be
retired at runtime. Both fixed with transcripts and gate-green proof. But I
fixed the sheet without fixing the two documents that POINT at it - that is
this session's honest failure, and it is issue #1 of the improvement list.
No defaults weakened, no assertion relaxed, no owner-gated row consumed.
