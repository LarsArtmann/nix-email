# Z-D-lane session: full status + brutal self-review (2026-10-26 20:48)

> Scope: THIS session only (baseline ritual + Z-plan D1/D2/D3 + closeout,
> commits `0318b7f`, `650d6c8` daemon, `cc0e33c`). Predecessor reports:
> 2026-10-26_19-00 (E/F session) and 2026-10-26_20-44 (D-lane execution
> inventory). Format override note: the status-report skill's HTML default
> was overridden by the operator's explicit `.md`-at-path instruction
> (standing repo convention).

## a) FULLY DONE (this session, all verified)

1. **Baseline ritual** - clean tree at `373c30a`, corridor scan (no new
   foreign same-day reports), 23 concurrent crush processes noted, and
   the O1 blocker RE-CHECKED: `gh` token still invalid (20:38). All
   O/A/B/F/C lanes correctly left untouched per the Z-plan ordering
   doctrine.
2. **D1 port-wait sweep - VERDICT CLEAN** - all 26 `wait_for_open_port`
   sites in `tests/` classified against the module's listener doctrine
   (`modules/mail-server.nix:628-637`): only 25+8080 are built-in; every
   other Stalwart listener binds after the ~70 s boot provision+restart
   chain. The 587@60 instance (fixed earlier tonight) was the ONLY
   under-budgeted provisioned wait. Classes: non-Stalwart services
   (postfix/dovecot/mailpit), built-in ports, post-restart datastore
   binds (bind at process start), and blocking
   `systemctl restart stalwart-provision` guards. No changes, no
   rebuilds - the sweep itself is the deliverable. Extension check (this
   review): the ONE `wait_until_succeeds` port probe (relay-e2e:261,
   993 TLS handshake) already carries timeout=180 - clean too.
3. **D2 queue-series split brain FIXED** (`0318b7f`) - the Z-plan
   premise ("grep README") was wrong: README carries no queue-series
   claim. The stale "ONLY queue series" text lived in
   `docs/MONITORING.md` §5.5, contradicting row 2's same-file
   correction. §5.5 now transcribes BOTH counters from the relay-run3
   transcript (`# HELP queue_rescheduled Message rescheduled for
   delivery`, value 1), heading amended-dated, no-depth-gauge verdict
   intact. dprint + pipe lint green.
4. **D3 first full `buildflow` on the final tree - GATE GREEN (exit 0)**
   - residue triaged per the close-the-loop rule:
   - EXE001 + RUF007 + 10 ruff-format nits in the new es-ping probe:
     FIXED (daemon commit `650d6c8`; exec bit 100755 matching probe
     convention, `itertools.pairwise`, formatted; semantics-identical,
     py_compile + diff reviewed).
   - The "17 findings" were really 2 - the BuildFlow identity-parsing bug
     inflates counts (`missing_file=17` in JSON mode). Bug already owned
     by the upstream TODO row.
   - The 2 RUF100 hits in OLDER probes under my wider manual selection
     are NOT gate findings (their `noqa` directives are live under
     buildflow's ruleset - verified against the gate's actual findings
     output). Deliberate non-fix, documented.
   - Post-fix verification: `buildflow -s ruff-check` and `-s
     ruff-format` re-run FRESH (0 cache hits): "All checks passed!" /
     "16 files already formatted".
   - Known noise correctly absorbed: 3 documented eval warnings, 9
     tools unavailable, millisecond timing-regression lines, doctor
     warns (AGENTS.md 247/220 lines pre-existing; state-db VACUUM hint;
     binary behind BuildFlow HEAD - advisory, concurrent session).
5. **Closeout** (`cc0e33c`) - 2 CHANGELOG Fixed entries, 3 TODO rows
   D1/D2/D3 deleted with header truth-up, execution report at
   2026-10-26_20-44 (real timestamp via `date`). Tree clean.

## b) PARTIALLY DONE

- **D3 verification depth**: the FULL-run green verdict predates the
  probe fix; I re-verified the two affected steps fresh instead of a
  third full run. Correct efficiency/rigor tradeoff (the changed file
  feeds only ruff/python steps; AST-based tools cannot gain findings
  from formatting) - but it is a step-level, not full-gate, proof of the
  post-fix tree.
- **BuildFlow upstream row evidence**: my run produced a NEW data point
  (JSON-mode `missing_file=17` vs the row's recorded pretty-mode
  `missing_file=55`) that I did NOT fold into the TODO row. Tiny,
  unclaimed.

## c) NOT STARTED (all owner-gated or their-repo - untouched BY DESIGN)

O1 (`gh auth login`), O2 (the sitting), O3 (verdict recording), A1-A5
(v0.5.0 release train), B1-B3 (pbx + corridor closeout), F1-F4
(filings), C1-C8 (pin advance + verdict executions), D4/D5 (O2-gated),
G1-G7 (their-repo/external cadence). Full tables with dependencies live
in the Z-plan
(`docs/planning/2026-10-26_19-54_SUPERB-pareto-z-generation-*.md`).

## d) TOTALLY FUCKED UP (nothing broken - two process failures)

- **The daemon ate my probe-fix commit** (`650d6c8`): I separated the
  file edits from the commit by two buildflow verification rounds, and
  the daemon landed the change under a generic "chore: auto-commit"
  message. Content preserved exactly (5+/2-), but the documented
  rationale ("why exec bit, why pairwise, RUF100s are selection
  artifacts") exists only in the CHANGELOG, not next to the diff. The
  AGENTS.md same-tool-call doctrine exists precisely for this and I
  applied it to CHANGELOG but not to the probe file.
- **Line-number surgery on a shared mutable file**: I deleted the three
  TODO rows via `sed -i '87,89d'` - line numbers from a grep run two
  tool calls earlier. If the daemon or a concurrent session had touched
  TODO_LIST in that window, I would have deleted the WRONG rows
  silently. I verified the diff immediately after (the three intended
  rows, nothing else), so no damage - but text-match deletion
  (`/^| Port-wait sweep/d`) was the safe form and I did not use it.

## e) WHAT WE SHOULD IMPROVE

1. **Commit immediately after every fix** - not "after verification
   rounds". Verification can re-run against the committed tree; the
   daemon race cannot be won after the fact. (Would have saved the
   650d6c8 message.)
2. **Never line-number-edit shared files** - always text-match anchors
   (sed patterns or edit-tool old_strings). Multi-session machine makes
   line numbers stale by the minute.
3. **AGENTS.md is 27 lines over its 220 cap** (doctor keeps flagging;
   pre-existing, unchanged this session - I correctly refused to add
   D-lane lore). Needs an owner-tasted trim, not an agent-typed essay.
4. **BuildFlow binary freshness**: my GREEN verdict ran on `58115f7`
   while the BuildFlow repo HEAD is `24dff81` (concurrent session) -
   every gate verdict should note the binary it ran on, or the fleet
   needs a rebuild cadence after sibling sessions land.
5. **Host hygiene**: buildflow state DB 0.63 GB + cache 83% free pages
   (VACUUM hint) - expendable, but the slow creep is real; a periodic
   purge belongs in (f).
6. **Ruff floor asymmetry**: CI runs E4,E7,E9,F; buildflow's deeper
   ruleset catches EXE/RUF/FURB-class residue only at gate time (my
   probe shipped 12 fixable findings through the CI floor). The V2.3
   owner question (move deeper rules into CI?) has a fresh data point
   now.
7. **Fold new evidence the moment it appears** - the `missing_file=17`
   JSON-mode data point should have gone into the BuildFlow TODO row in
   the same session that observed it (this review caught it instead).

## f) Next things (28 real items - Z-plan owns the full 80-micro-task graph)

| #  | Item                                                                                            | Gate          |
| -- | ----------------------------------------------------------------------------------------------- | ------------- |
| 1  | O1: `gh auth login -h github.com` (owner, 5 min) - unblocks items 12-15, 19, CI watching        | owner         |
| 2  | O2: THE SITTING (verdict sheet, ~65 min) - unblocks items 3-11, 16-18, 24-28                    | owner         |
| 3  | O3: record verdicts into decision-batch + TODO re-row + README banner                           | O2            |
| 4  | A1: CHANGELOG Unreleased link/date pass + duplicate-block merge (same-call commit)              | O3            |
| 5  | A2: release-tree gate proof (full flake check + buildflow, logs archived)                       | A1            |
| 6  | A3: scratch-tag dry-run of the CONTRIBUTING release procedure                                   | A2, O1        |
| 7  | A4: CUT v0.5.0 (rename, SECURITY bump, annotated tag, push, tag-CI green, gh release)           | A3            |
| 8  | A5: README/AGENTS/FEATURES release-state lines                                                  | A4            |
| 9  | B1: pbx hermetic override landing (their repo, whole-key mkVMOverride per spec)                 | O2            |
| 10 | B2: nix-email side of pbx landing (CHANGELOG + row close + issue #4 cross-link)                 | B1            |
| 11 | B3: corridor closeout - the two kept-live reports' open arrows to verdicts, archive via git mv  | B1            |
| 12 | F1: post the #552103 webui-resource comment (draft ready in docs/drafts/)                       | O1            |
| 13 | F2: re-verify + post the nixpkgs#563651 follow-up (host-less `[opensearch]` persists on master) | O1            |
| 14 | F3: mailsuite#65 nudge at ~11-05 (re-read their master imap.py first)                           | O1, calendar  |
| 15 | F4: dnsmasq resolver-note: venue decision + github-voice draft + file + cross-ref               | O1            |
| 16 | C1: pin advance + #566282 opensearch port (preflight grep, rename, strip guard, 2 checks green) | A4            |
| 17 | C2: #552103 retirement OR C45 overlay execution per verdict                                     | C1, O2        |
| 18 | C3: SystemNix contract-test fix + pin bump to v0.5.0 (their repo)                               | A4            |
| 19 | C4: post-bump checks (aarch64 shape, dovecot warning gone, watch re-date, rename watch)         | C1            |
| 20 | C5: C44 account-secrets doctrine implementation + THREAT_MODEL update                           | O2            |
| 21 | C6: C39 MemoryMax ownership verdict landing                                                     | O2            |
| 22 | C7: C42 dmarc-monitor retire-or-keep execution                                                  | O2            |
| 23 | C8: D1-unlock prep pack (rotation runbook, vandelay-vs-imapsync plan, dmarc checklist, Resend)  | O2, C5        |
| 24 | D4: CI python-lint doctrine landing (bandit/vulture scope) per V2.3 blessing                    | O2            |
| 25 | D5: flood posture per taste verdict (close as-is or soften + rerun)                             | O2            |
| 26 | G1: BuildFlow upstream batch (count gaps, identity parsing, detect-only, vulture policy)        | their cadence |
| 27 | G2: SystemNix CI-debt lanes (credential, canary allowlist, 2 pin flips, divergence doc)         | their cadence |
| 28 | G3-G7: qcow2 purge verdict, contacts probe re-run on bump, EventCatalog publish, watch cadence, | O2 / external |
|    | policy executions - see Z-plan section 3                                                        |               |

Session-surfaced micro-items to fold at the next TODO touch (NOT yet
harvested): the `missing_file=17` JSON-mode evidence enrichment (item
26's row), and the AGENTS.md trim decision (needs owner taste).

## g) Questions I cannot figure out myself

1. **O1 timing**: when will you run `gh auth login -h github.com`? Four
   drafted filings, the tag-CI watch, and the origin-CI observation of
   the pushed `373c30a` are all parked behind it.
2. **O2 timing**: when is the sitting? The verdict sheet
   (`docs/planning/2026-10-23_11-56_owner-sitting-ratification-verdict-sheet.md`)
   gates >51% of the remaining plan - every A/B/C/D4/D5/G-lane item.
3. **Push decision**: this session added 3 local commits
   (`0318b7f`, `650d6c8`, `cc0e33c`) on top of the pushed `373c30a`.
   Push now, or hold and ride them into the v0.5.0 release push (A4)?
   (Held: no push instruction this session.)

## Verdict

No damage, no ghost systems, no new split brains (one FIXED: the
MONITORING §5.5/row-2 contradiction). Two process failures caught and
owned (daemon-eaten commit message, line-number surgery). All three
D-lane tasks closed with evidence. The board is now entirely
owner-gated: O1 is a one-line command, O2 is one sitting.
