# Status Report — Y-plan E/F-lane Execution Session (tests, probes, formatter)

- **Date:** 2026-10-26 (evening CEST)
- **Session type:** Execution (pareto Full Execution Mode over TODO_LIST rows
  that are not owner-gated). Owner-decision rows (C39-C46, D1/D2, pbx
  blessing, release train) were NOT touched - they route through the
  prepared sitting sheet.
- **Baseline ritual:** `git status --short` clean; 16 `crush -y` processes
  (multi-session machine, expected); corridor scan found no same-day
  reports (latest: 10-25 store-advisory, zero-change).

## TL;DR

Five TODO rows closed end-to-end with green VM/gate evidence (relay bounce
subtest, EventSource ping probe x2 rows, TLS forensic breadth, dprint
T13b - the latter resolved as a plugin bump after verify-before-filing
proved the bug fixed upstream), the admin-bundle landmine defused in the
vendored copy with a corrected mechanism writeup, the flood flake's
capture-first protocol mechanized INTO the test, and the upstream watch
re-dated. One hard external blocker surfaced: **the `gh` token is expired**
- every authenticated GitHub action (filings, CI watching, the
scratch-tag dry-run's tag-CI observation) is dead until `gh auth login`.

---

## a) FULLY DONE (all with transcripts/gate evidence)

1. **E1 relay bounce-path subtest** (`tests/stalwart-relay-e2e.nix`):
   smarthost stop -> submission accepted -> deferred state asserted via
   the `queue_rescheduled` Prometheus counter (transcript-pinned value 1)
   -> smarthost recovery -> queue retry DRAINS into Mailpit (measured
   119.5 s; 300 s bound = 2.5x headroom). Never a journal grep. Check
   GREEN (run 3, EXIT:0). Also fixed a pre-existing boot flake: 587 is a
   PROVISIONED listener; the 60 s port wait expired against the ~70 s
   provision+restart chain (run-2 transcript) - now 180 s with the
   mechanism documented.
2. **E4 EventSource `ping` probe** (closes TWO rows: the Medium ping
   row + the Low JMAP anti-rot row's remainder):
   `docs/probes/2026-10-26-es-ping/` - numeric `ping` is ACCEPTED on
   0.16.22 (the 0.15.5 blanket-400 is gone) but INERT: zero keep-alive
   comments at 100 ms/1 s/2 s/5 s cadences, types=Email and types=*, up
   to 35 s windows; `ping=abc` 400s. INBOXCLEAN.md banner + parameter
   matrix updated (do NOT rely on `ping` for liveness).
3. **E6 TLS-node forensic breadth** (`tests/parsedmarc-e2e.nix`): the
   Netease + LinkedIn failure fixtures now asserted on the IMAPS node
   too (cardinal.com, recipient@linkedin.com, both timezone
   normalizations, csv row count). Host-parse dry-runs GREEN first
   (2026-10-26 re-run). Check GREEN.
4. **E3-part flood capture-first** (`tests/stalwart-e2e.nix`): the M14
   final probe now wraps in try/except that dumps journal + both probe
   logs + limiter metrics INTO the build log BEFORE failing; flood node
   gained `metrics.enable`. Check GREEN (2.15 s subtest; the capture
   path fires only on recurrence).
5. **F4 dprint T13b**: verify-before-filing OUTCOME = no filing needed.
   Reproduced the overflow-cell DROP on the pinned markdown-0.22.1
   (silent data loss), then proved markdown-0.28.2 (released 2026-10-26)
   PRESERVES the overflow cell. Action: plugin bumped 0.22.1 -> 0.28.2,
   the archived corridors are now dprint-EXCLUDED (frozen snapshots),
   the pipe lint stays. BONUS REAL FIX: MONITORING.md row 15 has been
   rendering COLUMN-SHIFTED since the 2026-10-20 edit (a raw pipe inside
   `validationFailed | Network error` faked the missing cell boundary
   and fused the condition+Sev cells) - repaired and the lint stayed
   green through the repair.
6. **Admin-bundle spelling** (vendored module): the 10-23 finding's
   mechanism was WRONG and is now corrected in the README ledger - on
   0.16 the whole webadmin block is dead code (pre-0.16 settings
   branch; `settings.webadmin` does not exist at all), so no 0.16
   consumer can hit it. The landmine (else-branch `cfg.package.webadmin`
   against a webui-only package) was proven by a forced-branch probe:
   threw `attribute 'webadmin' missing` pre-fix, evaluates
   `webui-1.0.10/webui.zip` post-fix; 0.15 line byte-identical behavior.
   Vendored copy hardened (zero behavioral delta proven); upstream
   #552103 (identical shape at head 9b15e1f, verified) fix drafted in
   `docs/drafts/552103-webui-resource-comment.md` - filing blocked on
   gh auth.
7. **F5 upstream watch re-check** (unauthenticated REST - see blocker):
   #563651 open/silent (09-16), #563652 open (10-01), #563777
   open/silent (09-16), #552103 OPEN with fresh activity (updated
   2026-10-26T00:57), #566282 MERGED confirmed, mailsuite#65 open/silent
   (10-05; nudge decision unchanged: ~11-05). Rename-watch folded in:
   nixpkgs MASTER still ships the pre-0.16 single-file
   `stalwart.nix` (fetched + read) - no module collision yet, and the
   same latent `webadmin` shape exists there.
8. **EventCatalog publish condition check**: the Forgejo mirror
   (forgejo.home.lan/lars/nix-email) carries `3f38b79` >= the required
   `456840b` (ls-remote, 2026-10-26) - publish condition 2 SATISFIED;
   the row stays blocked on the concurrent demo-flagging workstream
   (go-cqrs-lite MarkDemo code exists on master; a tagged/bumped
   release state was not determinable from here).

## b) PARTIALLY DONE

1. **Upstream filings** (W12.3/W12.4 remainder + #552103 comment +
   #563651 follow-up): ALL verified and drafted where applicable, NONE
   filed - `gh` auth expired (see d). The T13b filing resolved as
   no-filing-needed (a.5).
2. **Release scratch-tag dry-run (A3 sub-item of the v0.5.0 row)**:
   deferred with rationale - the dry-run's entire value is watching
   tag-CI fire, and CI observation needs `gh`. The procedure itself is
   unchanged in CONTRIBUTING.

## c) NOT STARTED (owner-gated or out of this session's lane)

1. Every owner-sitting row (C42-C46, C39-C41, pbx blessing, D1/D2,
   Resend, branch protection, Renovate, Discussions, qcow2 purge,
   ratifications) - the sheet at
   `docs/planning/2026-10-23_11-56_owner-sitting-ratification-verdict-sheet.md`
   is the vehicle; this session deliberately made no owner decisions.
2. BuildFlow-repo follow-ups and SystemNix CI-debt (their repos).
3. F6/F7 (README line-by-line pass, TELEMETRY key re-verify) - plan-level
   lanes, not TODO rows; not attempted this session.

## d) TOTALLY FUCKED UP (honest)

1. **A partial-multiedit landmine (caught by the gate, not by me):** the
   first bounce-subtest edit "failed" but had already applied its text;
   my follow-up edit then added a SECOND copy of the subtest, and the
   transcript run executed the broken duplicate (r-string garbage) -
   90 s burned, red run. Lesson applied: after ANY multiedit failure,
   grep the file for duplicates before building. No permanent damage.
2. Nothing else: no foreign files touched, no reverting others' work,
   the daemon's mid-session commits were verified as mine before
   building on top.

## Self-Review

**What did I forget?**

1. Initially repro'd the admin-bundle eval failure with the WRONG causal
   layer (my probe accessed `settings.webadmin`, which legitimately does
   not exist on 0.16) and nearly encoded the 10-23 mechanism verbatim -
   the three-shape probe caught it. The ledger correction is the durable
   fix.
2. The flood "posture decision" (owner taste, Y-plan E3) remains unasked;
   only the capture-first half was mine to do.

**What could I have done better?**

1. Serialized the first relay run against lighter host work - run 2's
   boot slowness (587 timeout) was plausibly my own concurrent load.
2. Checked `gh auth status` in the BASELINE ritual - the blocker would
   have been known before planning the filing lanes.

**What could I still improve?**

1. The relay-e2e boot flake (provisioned-listener port waits) may exist
   in other tests' waits on provisioned ports - a sweep is cheap and
   worth a row.

## e) WHAT WE SHOULD IMPROVE

1. **`gh auth` is a fleet-level dependency of this repo's process**
   (filings, CI watching, upstream truth) - the baseline ritual should
   include `gh auth status` so sessions plan around it instead of
   discovering it mid-lane.
2. MONITORING row 15 proves the pipe lint cannot catch an ALREADY-fused
   row (equal counts by coincidence) - the lint guards future edits,
   not history; the 0.28.2 plugin (keeps overflow cells) is the real
   systemic fix and is now pinned.

## f) Next Things

1. `[owner]` `gh auth login -h github.com` - unblocks: the #552103
   webui comment (draft ready), the #563651 follow-up, the mailsuite
   nudge (~11-05), CI watching, and the scratch-tag release dry-run.
2. `[owner]` The sitting sheet (everything C39-C46 + pbx + policy).
3. Port-wait sweep: grep tests for `wait_for_open_port` on provisioned
   ports with < 120 s budgets (the 587 lesson).
4. Upstream watch next re-check rides the next session (~11-05 for the
   mailsuite nudge decision point).

## g) Questions I Cannot Figure Out Myself

1. Whether the flood subtest's final still-gated probe should be
   HARDENED further (posture taste) or left as-is with the automated
   capture - owner call, low stakes.

---

_Gate state at report time: the three touched VM checks individually
GREEN (relay run 3, stalwart-e2e, parsedmarc-e2e); the full
`nix flake check` result is recorded in the session's final summary
(it was still running when this report was drafted - read the CHANGELOG
entry or the gate log `/tmp/gate-final.log` for the authoritative
verdict)._
