<!-- Z-generation master plan. Generated 2026-10-26 19:54 CEST (`date` CLI).
     Sources: TODO_LIST.md (post-2026-10-26 E/F-lane execution batch: 4 rows
     closed gate-green in CHANGELOG 6368238 + b9adde4), the Y-plan
     (2026-10-23_11-49, whose executed tasks live in CHANGELOG; Z absorbs
     its unexecuted remainder), the 2026-10-26_19-00 session status +
     brutal self-review, decision-batch.md (C38-C53), and the two KEPT-LIVE
     reports. Every open TODO_LIST row maps to exactly one task (Appendix
     A). New rows surfaced by the 2026-10-26 session are harvested into
     TODO_LIST by this plan (Appendix B). -->

# Z-generation: through the owner unblock to the 0.16 fleet (Pareto plan)

## 0. State of the world (verified 2026-10-26 19:5x CEST)

- FULL `nix flake check` GREEN on the 11-check set + `nix fmt --check` +
  dprint + pipe lint + CI ruff floor (all re-run green tonight, including
  over the new tracked probe python).
- The E/F-lane batch LANDED tonight: relay bounce subtest (queue deferred
  proof + 119.5 s drain), EventSource `ping` verdict (accepted-but-inert,
  two rows closed), TLS forensic breadth, flood capture-first mechanized,
  dprint 0.28.2 bump (+ the MONITORING row-15 column-shift repair),
  admin-bundle local hardening with the mechanism corrected in the ledger.
- TWO hard external blockers own the horizon:
  (1) the OWNER SITTING (sheet prepared 2026-10-23, still unanswered) and
  (2) `gh` auth EXPIRED (found 2026-10-26) - every authenticated GitHub
  action (4 drafted filings, CI watching, the release dry-run's tag-CI
  observation) waits on a one-line owner command.
- The fleet still runs v0.4.0 = the 0.15 world; the BREAKING 0.16 payload
  sits fully loaded in CHANGELOG `[Unreleased]`, e2e-proven, gate-green.
- Upstream truth re-dated 2026-10-26 (unauthenticated REST): all watched
  items unchanged; #552103 has fresh activity; nixpkgs master still ships
  the pre-0.16 module (no rename collision yet).

## 1. Doctrine constraints (non-negotiable while executing - the anti-Verschlimmbesserung contract)

1. Never weaken module defaults or the CI ruff floor to make a test pass -
   fix the test (or the claim).
2. Check add/remove = the TWO sanctioned sites (`tests/check-expected.json`
   - README prose row); pre-flight `grep -rn '<name>' .github scripts tests
     README.md`.
3. Upstream filings: verify-before-filing first, github-voice second; no
   filing without a measured victim; drafts in `docs/drafts/` until auth.
4. No claim without a transcript (test assertions AND docs claims AND
   timestamps in artifact filenames - `date` before naming).
5. Release-critical files (CHANGELOG above all): edit and commit in the
   SAME tool call - the daemon races explicit commits.
6. Gate commands redirect, never pipe - including `echo $?` after a piped
   command (bit the author 2026-10-26).
7. New tracked python = CI ruff floor run BEFORE yielding a session
   (F401-class escape found by forced self-review, fixed same day).
8. Do not "fix" deliberate-OFF hardening defaults; do not touch
   owner-gated rows without the sitting's verdicts; their-repo lanes run
   on their cadence.
9. One change = one logical unit; the gate decides - not vibes, not cache
   hits (`--rebuild` when execution is the claim).
10. Annotated status reports: per-cell strikes, lint after every formatter
    pass, archive only via git mv + manifest row.

## 2. The Pareto cut (what actually moves the result)

**The result** = "Lars's fleet runs production mail on Stalwart 0.16 via
SystemNix, monitored, with a trustworthy gate, a burnable backlog, and
upstream truth current."

| Slice                         | Tasks                                                                                                                                                  | Cumulative outcome                                                                                                           | Why this slice                                                                                                 |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **1% -> 51%**                 | O1 (gh auth) + O2 (ONE owner sitting: C43/C44/C45/C39/C41/C46, pbx blessing, D1/D2, Resend key, policy batch, flood taste, report-cadence g-questions) | Every blocked row unblocks at once: the release train, all filings, the consumer advance, live enablement, the corridor tail | ~65 min of owner time + one login command gate MORE than half of all remaining value; nothing else comes close |
| **4% -> 64%**                 | + A1-A5 (cut v0.5.0) + B1-B3 (pbx flip + corridor closeout) + F1-F4 (post-auth filing batch)                                                           | The breaking 0.16 upgrade is TAGGED and released; pbx master greens; upstream truth is filed, not drafted                    | The release is the ONLY thing between the fleet and 0.16; the filings are finished work sitting behind auth    |
| **20% -> 80%**                | + C1-C8 (SystemNix pin advance, #566282 port, post-verdict executions, D1 prep) + D1-D5 (gate-trust hygiene incl. tonight's residue)                   | The fleet ACTUALLY runs 0.16; the gate and docs carry tonight's lessons forward                                              | A release nobody consumes is half a release; unverified docs claims rot the next session                       |
| **the remaining 80% -> 100%** | G1-G7 (their-repo batches, pin-advance rides, EventCatalog publish, watch cadence, policy executions)                                                  | Burnable backlog: real but deferrable, each lane session-sized                                                               | None of it blocks the fleet; all of it is queued behind verdicts, bumps, or external landings                  |

Ordering below is exactly this cut, top to bottom. Nothing in F/C/D may
jump ahead of an unblocked O/A/B task (exception: D-lane residue items
D1-D3 are minutes-scale and ride ANY waiting window).

## 3. Level-1 plan (30-100 min tasks, ALL open TODO rows, impact-sorted)

| ID | Phase | Task                                                                                                                                                                                                                                              | Impact | Effort | Value | Depends on           |
| -- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------ | ----- | -------------------- |
| O1 | 0     | `[owner]` `gh auth login -h github.com` + verify (`gh auth status`); unblocks F1-F4, A3-A4 CI watching, the mailsuite nudge                                                                                                                       | High   | 5m     | 51%   | -                    |
| O2 | 0     | `[owner]` THE SITTING: answer C43 (v0.5.0 doctrine), C44 (secrets), C45 (package), C39/C41/C46, pbx hermetic blessing, D1/D2 timeline, Resend key, C18/C19/C22/C24/C29/C34/Q4, flood posture taste + the two report g-questions (rename, cadence) | High   | 65m    | 51%   | O1 (nice-to-have)    |
| O3 | 0     | Record verdicts: decision-batch answer lines, TODO re-row pass (delete closed, unblock gated), README banner truth-up                                                                                                                             | High   | 30m    | 51%   | O2                   |
| A1 | A     | CHANGELOG `[Unreleased]` date/link pass (links resolve, duplicate blocks merged) + same-tool-call commit                                                                                                                                          | High   | 45m    | 64%   | O3 (C43=cut)         |
| A2 | A     | Release-tree gate proof: full `nix flake check` AND full `buildflow` (30m budget), logs archived as release evidence                                                                                                                              | High   | 45m    | 64%   | A1                   |
| A3 | A     | Scratch-tag dry-run of the CONTRIBUTING release procedure (walk end-to-end on a throwaway annotated tag; tag-CI observation needs O1)                                                                                                             | High   | 30m    | 64%   | A2, O1               |
| A4 | A     | CUT v0.5.0: rename Unreleased, merge blocks, SECURITY.md bump, annotated tag, push, tag-CI watch green, gh release + link checks                                                                                                                  | High   | 60m    | 64%   | A3                   |
| A5 | A     | README banner flip to v0.5.0 + AGENTS/FEATURES release-state lines                                                                                                                                                                                | Med    | 15m    | 64%   | A4                   |
| B1 | B     | Land the pbx hermetic override (their repo, post-blessing): apply the spec'd whole-key mkVMOverride, VM run green, their gate green                                                                                                               | High   | 60m    | 64%   | O2                   |
| B2 | B     | nix-email side of the pbx landing: CHANGELOG entry + TODO row close + cross-link issue #4                                                                                                                                                         | Med    | 15m    | 64%   | B1                   |
| B3 | B     | Corridor closeout: convert the open arrows in the two kept-live reports (12-17, 14-19) to verdicts, annotate, lint, git mv + manifest row                                                                                                         | Med    | 45m    | 64%   | B1                   |
| F1 | F     | Post the #552103 webui-resource comment (draft ready: `docs/drafts/552103-webui-resource-comment.md`); watch for maintainer response                                                                                                              | Med    | 15m    | 64%   | O1                   |
| F2 | F     | Post the nixpkgs#563651 follow-up comment: re-verify the host-less `[opensearch]` shape still persists on master (cli.py check), then post draft                                                                                                  | Med    | 30m    | 64%   | O1                   |
| F3 | F     | mailsuite#65 nudge (~11-05 decision point): re-read their master imap.py against the quoted three lines, then post the nudge or record the skip                                                                                                   | Low    | 20m    | 64%   | O1, calendar         |
| F4 | F     | dnsmasq-forward resolver note: decide venue (nixpkgs test idioms vs dnsmasq docs), draft via github-voice, file, cross-ref the relay-e2e comment                                                                                                  | Low    | 45m    | 64%   | O1                   |
| C1 | C     | Execute the #566282 port at the pin advance: preflight `grep -rn 566282`, rename `provision.elasticsearch` -> `opensearch`, strip guard, dmarc-eval + parsedmarc-e2e green                                                                        | High   | 60m    | 80%   | A4 (new pin exists)  |
| C2 | C     | Stalwart surface re-check per runbook: #552103 retirement if merged into the pin (vendored dir out; restore meta.doc + partOf, drop the ExecStartPost patch) OR C45 overlay execution                                                             | High   | 45m    | 80%   | C1, O2 (C45 verdict) |
| C3 | C     | SystemNix side (their repo): contract-test fix for the v0.5.0 wrapper API, pin bump to v0.5.0, their CI green                                                                                                                                     | High   | 60m    | 80%   | A4                   |
| C4 | C     | Post-bump checks: aarch64 lockstep shape, dovecot rename warning gone, upstream watch re-date, rename-watch verdict (disabledModules collision check)                                                                                             | Med    | 30m    | 80%   | C1                   |
| C5 | C     | C44 execution: implement the chosen account-secrets doctrine (sops-rendered apply OR credential-file type OR admin-created doc), THREAT_MODEL.md update                                                                                           | High   | 90m    | 80%   | O2 (C44 verdict)     |
| C6 | C     | C39 execution: MemoryMax ownership verdict landed (wrapper mkDefault or consumer-layer doc in module header / THREAT_MODEL)                                                                                                                       | Med    | 30m    | 80%   | O2                   |
| C7 | C     | C42 execution: dmarc-monitor retire-or-keep per verdict (retire = module removal + eval/test updates; keep = one stalw.art docs fetch first)                                                                                                      | High   | 45m    | 80%   | O2                   |
| C8 | C     | D1-unlock prep pack: secrets-rotation runbook (SystemNix placeholders), vandelay-vs-imapsync compare plan, dmarc live-poll checklist, Resend smoke (needs the key)                                                                                | Med    | 90m    | 80%   | O2, C5               |
| D1 | D     | Port-wait sweep: `grep -rn "wait_for_open_port" tests/`, flag every PROVISIONED port waited with < 120 s budget, normalize with the 587 rationale (2026-10-26 flake transcript)                                                                   | Med    | 45m    | 80%   | -                    |
| D2 | D     | README queue-series claim verify: grep for the "only queue series" phrasing; sync with tonight's MONITORING correction (`queue_rescheduled` exists); transcript-cite                                                                              | Med    | 30m    | 80%   | -                    |
| D3 | D     | Full `buildflow` run on the final tree (the wrapper gate never ran in the E/F session); fold residue into the BuildFlow TODO row                                                                                                                  | Med    | 30m    | 80%   | -                    |
| D4 | D     | CI python-lint doctrine landing: bandit/vulture scope + whether buildflow's deeper ruleset moves into CI - draft is 20m; lands on the O2 blessing                                                                                                 | Low    | 30m    | 80%   | O2 (V2.3 blessing)   |
| D5 | D     | Flood posture execution per the taste verdict: "keep strict" = close the row as-is (capture-first already mechanized); "relax" = soft-warning rework + rerun stalwart-e2e                                                                         | Low    | 30m    | 80%   | O2                   |
| G1 | G     | BuildFlow upstream batch (their repo): count-gap reconciliation (204-vs-4 bandit, 0-checks count line), ruff identity parsing, detect-only proposal, vulture policy, masking docs                                                                 | Low    | 90m    | 100%  | their session landed |
| G2 | G     | SystemNix CI-debt lanes (their repo): Actions credential, digest canary allowlist, 2 pin flips, scheduled-vs-push divergence doc                                                                                                                  | Med    | 60m    | 100%  | -                    |
| G3 | G     | qcow2 purge per verdict: git-filter-repo + daemon-pause + `--force-with-lease`, OR record the accept-clone-weight verdict and close                                                                                                               | Low    | 45m    | 100%  | O2                   |
| G4 | G     | Pin-advance contacts probe set: carddav_probe.py 17/18 baseline re-run + README dialect diff (rides the first real Stalwart bump)                                                                                                                 | Low    | 30m    | 100%  | C1                   |
| G5 | G     | EventCatalog publish + T8 live-verify once the demo-flagging workstream lands (mirror condition already satisfied 2026-10-26)                                                                                                                     | High   | 20m    | 100%  | external workstream  |
| G6 | G     | Upstream watch cadence + rename watch: next re-check rides the mailsuite nudge date (~11-05); rename-watch rides C1/C2                                                                                                                            | Med    | 15m    | 100%  | F3, C1               |
| G7 | G     | Policy executions post-sitting: branch protection per C18 verdict, Renovate install-or-drop per C19, Discussions per C22, secrets rotation + migration compare at D1 enablement                                                                   | Med    | 90m    | 100%  | O2, D1               |

Sum of scheduled (non-owner, non-ride) work: ~14-16 h across 27 tasks;
nothing larger than one focused session. The two owner micro-sittings
(O1 + O2) gate >51% of it.

## 4. Level-2 plan (micro-tasks, max 12 min active each, ALL tasks)

Waits (gate/CI/VM runs) are `[wait]`; owner micros are `[owner]`.

| ID   | Task (max 12 min active)                                                                                         | Parent | Depends  |
| ---- | ---------------------------------------------------------------------------------------------------------------- | ------ | -------- |
| O1.1 | `[owner]` Run `gh auth login -h github.com`; confirm `gh auth status` clean                                      | O1     | -        |
| O1.2 | Smoke: `gh run list` answers; note the newest run id in this plan's errata                                       | O1     | O1.1     |
| O2.1 | `[owner]` Open the verdict sheet; answer C43 + C45 + C44 + C39/C41/C46                                           | O2     | O1       |
| O2.2 | `[owner]` pbx hermetic blessing + D1/D2 timeline + Resend key handoff                                            | O2     | O1       |
| O2.3 | `[owner]` Policy batch C18/C19/C22/C24/C29/C34/Q4 + [rec] ratifications                                          | O2     | O1       |
| O2.4 | `[owner]` Flood posture taste + report rename + report cadence (the three g-questions)                           | O2     | O1       |
| O3.1 | Write verdicts into decision-batch.md (answer lines + dates)                                                     | O3     | O2       |
| O3.2 | TODO re-row pass: delete closed rows, flip BLOCKED -> TODO, re-date the sweep banner                             | O3     | O3.1     |
| O3.3 | README banner + FEATURES release-state truth-up; same-tool-call commit                                           | O3     | O3.2     |
| A1.1 | Inventory `[Unreleased]` links; list every PR/issue ref                                                          | A1     | O3       |
| A1.2 | Verify each link target resolves; fix dead ones                                                                  | A1     | A1.1     |
| A1.3 | Merge duplicate Added/Changed/Fixed blocks; commit in the SAME call                                              | A1     | A1.2     |
| A2.1 | `nix flake check` on the release tree, redirect to log `[wait]`                                                  | A2     | A1       |
| A2.2 | `buildflow --max-time 30m` full run `[wait]`; read per-step findings                                             | A2     | A2.1     |
| A2.3 | Archive both logs under docs/ as release evidence; note warnings-only verdicts                                   | A2     | A2.2     |
| A3.1 | Re-read CONTRIBUTING "Release procedure"; list deviations since v0.3.1                                           | A3     | A2       |
| A3.2 | Cut scratch annotated tag; push; observe tag-CI fire `[wait]`                                                    | A3     | A3.1     |
| A3.3 | Delete scratch tag; write deviations into the procedure if any surfaced                                          | A3     | A3.2     |
| A4.1 | CHANGELOG cut to 0.5.0 + fresh empty Unreleased; same-call commit                                                | A4     | A3       |
| A4.2 | SECURITY.md contact/version bump check                                                                           | A4     | A4.1     |
| A4.3 | `git tag -a v0.5.0`; verify tagged tree (`git show v0.5.0:CHANGELOG.md`)                                         | A4     | A4.2     |
| A4.4 | Push master + tag; watch tag-CI to green `[wait]`                                                                | A4     | A4.3     |
| A4.5 | `gh release create` with notes; verify links + first consumer fetch                                              | A4     | A4.4     |
| A5.1 | README banner + AGENTS + FEATURES release-state lines; dprint + lint; commit                                     | A5     | A4       |
| B1.1 | Re-read their test-header spec verbatim (pbx stalwart-host-wiring.nix)                                           | B1     | O2       |
| B1.2 | Apply the whole-key mkVMOverride exactly as spec'd; their gate build `[wait]`                                    | B1     | B1.1     |
| B1.3 | Read the run transcript; on red capture BEFORE rerun (their debug loop rules)                                    | B1     | B1.2     |
| B1.4 | Commit on their master (their daemon); confirm their CI green `[wait]`                                           | B1     | B1.3     |
| B2.1 | nix-email CHANGELOG entry + TODO row close + issue #4 cross-comment (post-auth)                                  | B2     | B1       |
| B3.1 | Convert open arrows in 12-17 to verdicts; per-cell strike form; lint                                             | B3     | B1       |
| B3.2 | Same for 14-19; lint both                                                                                        | B3     | B3.1     |
| B3.3 | git mv both to archived/ + manifest rows; commit                                                                 | B3     | B3.2     |
| F1.1 | Re-verify the draft's claims against PR head (sha + passthru facts still true)                                   | F1     | O1       |
| F1.2 | github-voice pass; post the comment; record the comment id                                                       | F1     | F1.1     |
| F2.1 | Re-verify the host-less opensearch shape on current master (cli.py probe)                                        | F2     | O1       |
| F2.2 | Draft + post the follow-up; retitle if still accurate                                                            | F2     | F2.1     |
| F3.1 | After ~11-05: diff mailsuite master imap.py vs the quoted three lines                                            | F3     | O1       |
| F3.2 | Post the nudge or record the skip decision in the watch row                                                      | F3     | F3.1     |
| F4.1 | Decide venue for the dnsmasq note (where does the pattern get fixed/documented)                                  | F4     | O1       |
| F4.2 | Draft via github-voice; verify; file; cross-ref relay-e2e comment                                                | F4     | F4.1     |
| C1.1 | Preflight `grep -rn 566282` across the repo; read the runbook step 2                                             | C1     | A4       |
| C1.2 | Bump the pin (SystemNix-locked rev pair per doctrine); lock update                                               | C1     | C1.1     |
| C1.3 | Rename provision.elasticsearch -> opensearch; strip guard                                                        | C1     | C1.2     |
| C1.4 | dmarc-eval + parsedmarc-e2e green `[wait]`; commit                                                               | C1     | C1.3     |
| C2.1 | Check #552103 merge state vs the new pin rev                                                                     | C2     | C1       |
| C2.2 | If merged: retire modules/stalwart-module/ per the in-file checklist; else execute C45 verdict (overlay or stay) | C2     | C2.1     |
| C2.3 | Full gate green on the post-retirement tree `[wait]`                                                             | C2     | C2.2     |
| C3.1 | Their contract test: update to the v0.5.0 wrapper API shape; green `[wait]`                                      | C3     | A4       |
| C3.2 | Their pin bump `?ref=v0.5.0`; their CI green `[wait]`                                                            | C3     | C3.1     |
| C4.1 | aarch64 shape eval; dovecot warning check; record verdicts                                                       | C4     | C1       |
| C4.2 | Watch row re-date with the new pin facts                                                                         | C4     | C4.1     |
| C5.1 | Implement the chosen C44 doctrine in the wrapper (per verdict)                                                   | C5     | O2       |
| C5.2 | Tests: eval contract + (if VM-shaped) one e2e leg green `[wait]`                                                 | C5     | C5.1     |
| C5.3 | THREAT_MODEL.md update; ledger row; CHANGELOG; commit                                                            | C5     | C5.2     |
| C6.1 | Land the MemoryMax verdict where it belongs; doc line + CHANGELOG                                                | C6     | O2       |
| C7.1 | If retire: module removal + dmarc-eval/parsedmarc-e2e/demo-eval updates; gate `[wait]`                           | C7     | O2       |
| C7.2 | If keep: stalw.art failure-parsing docs fetch; ledger row; close the ADR                                         | C7     | O2       |
| C8.1 | Secrets-rotation runbook draft (SystemNix placeholders)                                                          | C8     | O2, C5   |
| C8.2 | vandelay-vs-imapsync compare plan (scratch-mailbox procedure)                                                    | C8     | C8.1     |
| C8.3 | dmarc live-poll checklist + Resend smoke if the key landed                                                       | C8     | C8.2     |
| D1.1 | Grep all wait_for_open_port calls; classify built-in vs provisioned                                              | D1     | -        |
| D1.2 | Fix every under-budgeted provisioned wait; cite the 587 transcript                                               | D1     | D1.1     |
| D1.3 | Rebuild affected checks `[wait]`; gate green                                                                     | D1     | D1.2     |
| D2.1 | Grep README for the queue-series claims; read each in context                                                    | D2     | -        |
| D2.2 | Sync with the MONITORING correction; transcript-cite; dprint + commit                                            | D2     | D2.1     |
| D3.1 | Full buildflow run, redirect to log `[wait]`; read findings                                                      | D3     | -        |
| D3.2 | Fold residue into the BuildFlow TODO row; close or file per the loop-closed rule                                 | D3     | D3.1     |
| D4.1 | Draft bandit/vulture scope + deeper-ruleset recommendation (5-min owner read)                                    | D4     | O2       |
| D4.2 | Land in ci.yml on blessing; negative self-test; CI green `[wait]`                                                | D4     | D4.1     |
| D5.1 | Execute the taste verdict: close row as-is, or soften the final probe + rerun `[wait]`                           | D5     | O2       |
| G1.1 | Reproduce the 204-vs-4 bandit gap in their repo; root-cause aggregation vs flags                                 | G1     | -        |
| G1.2 | Fix the ruff identity parsing (missing_file=55 pseudo-findings)                                                  | G1     | G1.1     |
| G1.3 | The remaining documented batch items (detect-only, vulture policy, masking docs, threshold config)               | G1     | G1.2     |
| G2.1 | Actions credential + digest canary allowlist (their repo)                                                        | G2     | -        |
| G2.2 | The 2 pin flips + scheduled-vs-push divergence doc                                                               | G2     | G2.1     |
| G3.1 | Per verdict: run the purge (daemon-pause + filter-repo + force-with-lease) OR record accept-weight and close     | G3     | O2       |
| G4.1 | On the bump: re-run carddav_probe.py; diff the dialect notes vs the 17/18 baseline                               | G4     | C1       |
| G5.1 | On workstream landing: push hub master (or ci-dispatch); verify T8 checks live                                   | G5     | external |
| G6.1 | Next watch re-check at the nudge date; fold rename-watch into C2's retirement check                              | G6     | F3, C2   |
| G7.1 | Execute each policy verdict as it lands (branch protection, Renovate, Discussions)                               | G7     | O2       |
| G7.2 | At D1 enablement: secrets rotation + migration compare + dmarc live validation                                   | G7     | O2, D1   |

## 5. Execution graph

```mermaid
flowchart TD
    O1["O1 [owner] gh auth login"] --> O2["O2 [owner] THE SITTING (verdict sheet)"]
    O2 --> O3[O3 record verdicts]
    O1 --> F1[F1 post #552103 comment]
    O1 --> F2[F2 post #563651 follow-up]
    O1 --> F3[F3 mailsuite nudge ~11-05]
    O1 --> F4[F4 dnsmasq note: venue + file]
    O3 --> A1[A1 CHANGELOG date/link pass]
    A1 --> A2[A2 release-tree gate proof] --> A3[A3 scratch-tag dry-run] --> A4[A4 CUT v0.5.0] --> A5[A5 banner flips]
    A4 --> C1[C1 pin advance + #566282 port]
    A4 --> C3[C3 SystemNix contract + pin bump (their repo)]
    C1 --> C2[C2 #552103 retirement / C45 overlay] --> C4[C4 post-bump checks]
    C1 --> G4[G4 contacts probe re-run]
    O2 --> B1[B1 pbx override landing] --> B2[B2 nix-email side] --> B3[B3 corridor closeout]
    O2 --> C5[C5 C44 secrets doctrine]
    O2 --> C6[C6 C39 MemoryMax]
    O2 --> C7[C7 C42 dmarc-monitor verdict]
    O2 --> D4[D4 CI lint doctrine landing]
    O2 --> D5[D5 flood posture]
    O2 --> G3[G3 qcow2 purge or verdict]
    O2 --> G7[G7 policy executions]
    C5 --> C8[C8 D1-unlock prep pack] --> G7
    D1[D1 port-wait sweep] --> GATE[full gate green]
    D2[D2 README queue-series sync] --> GATE
    D3[D3 buildflow final run] --> GATE
    A2 -.-> D3
    EXT1[external: demo-flagging workstream] --> G5[G5 EventCatalog publish + verify]
    F3 --> G6[G6 watch cadence + rename watch]
    C2 --> G6
```

## Appendix A — Coverage proof (every open TODO_LIST row -> task)

| TODO_LIST row (section)                        | Task                                |
| ---------------------------------------------- | ----------------------------------- |
| Cut v0.5.0 (release path)                      | A1-A5                               |
| SystemNix pin advance to v0.5.0                | C3                                  |
| C42 dmarc-monitor retire-or-keep               | O2/C7                               |
| C44 account-secrets doctrine                   | O2/C5                               |
| C45 Stalwart package on 0.16                   | O2/C2                               |
| dmarc-monitor live validation                  | C8/G7                               |
| MemoryMax policy (C39)                         | O2/C6                               |
| SystemNix CI-debt residue (their repo)         | G2                                  |
| pbx stalwart-host-wiring flip                  | O2/B1                               |
| CI python-lint remainder (V2.3)                | O2/D4                               |
| Flood-subtest posture                          | O2/D5                               |
| Upstream filings remainder                     | F1/F4                               |
| Upstream watch (+ mailsuite nudge)             | F3/G6                               |
| BuildFlow upstream follow-ups (their repo)     | G1                                  |
| 0.16 admin-bundle spelling (upstream comment)  | F1                                  |
| Watch the nixpkgs stalwart rename              | C2/G6                               |
| Pin-advance contacts probe set                 | G4                                  |
| EventCatalog publish handoff                   | G5                                  |
| SystemNix description-sync cadence             | C3 (rides the same consumer change) |
| Migration tooling compare (D1)                 | C8/G7                               |
| Rotate placeholder secrets (D1)                | G7                                  |
| Resend SASL verification                       | C8 (key) / G7                       |
| Branch-protection policy (C18)                 | O2/G7                               |
| Renovate install-or-drop (C19)                 | O2/G7                               |
| GitHub Discussions (C22)                       | O2/G7                               |
| Purge demo.qcow2 blobs                         | O2/G3                               |
| gh auth login (owner)                          | O1                                  |
| Ratify [rec] adoptions (owner sitting)         | O2                                  |
| Deferred EventCatalog kinds (standing verdict) | no-op (done marker, stays)          |

## Appendix B — New rows this plan harvests into TODO_LIST

1. Port-wait sweep (D1) - Medium, 45m - evidence: relay-e2e run-2 flake
   transcript 2026-10-26 (587 provisioned-listener chain).
2. README queue-series claim verify (D2) - Medium, 30m - evidence:
   MONITORING row-2 correction tonight (`queue_rescheduled` exists).
3. Full buildflow run on the final tree (D3) - Medium, 30m - evidence:
   the E/F session verified via the manual stack only (self-review e2).

The rename of the mis-timestamped 20-15 report and the report-cadence
change are NOT harvested - both are open g-questions awaiting O2 verdicts.

## Errata / verification sweep

- Sweep date: 2026-10-26 19:5x CEST, directly after the E/F execution
  batch (gate + CI floors green at sweep time).
- Rows closed tonight and therefore NOT re-planned: relay bounce subtest,
  EventSource ping (x2), TLS forensic breadth, dprint T13b (resolved as
  plugin bump - no filing).
- The admin-bundle row's local half is DONE (vendored hardening + ledger
  correction); only the upstream comment remains (F1).
