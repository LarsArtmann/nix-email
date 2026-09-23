# Status Report — Pareto Resume: T12 Forensic Fixture First Run RED (2026-09-23 03:21)

Session context: resumed the 2026-09-22/23 Pareto backlog-burn master plan
(`docs/planning/2026-09-22_23-25_pareto-backlog-burn-master-plan.md`) from the
02:58 interruption snapshot. Prior-session state (per resume summary): T03–T11,
T13, T14, T20 completed; T12 in progress; T15, T02, Final gate, close-out
pending. This session executed: todo-list correction → git/origin verification
→ T12 source verification → fixture selection → test edit → fmt → targeted VM
check. **The targeted check went RED on the new forensic subtest.** Report
covers this session's run and what was observed in it.

Tree at report time: `master` ahead 20 of origin (daemon auto-commits; the
daemon committed the T12 test edit and this report's predecessors — nothing
manually pushed, no force-push). Format note: `.md` per explicit user request
(this skill's canonical format is HTML; override flagged).

---

## a) FULLY DONE (this session)

1. **Todo-list correction** — marked T08/T09/T10/T11 completed (stale in the
   pasted resume snapshot), T12 in_progress, T15/T02/Final/Close-out/Cleanup
   pending. No completed task was redone.
2. **Git/origin state verified** — `ahead 19` at resume, `ahead 20` at report
   time; origin untouched by me; daemon behavior as documented (AGENTS.md).
3. **T12 source verification completed against the pinned parsedmarc 11.0.1**
   (`/nix/store/vr9xzgcykqdpn30zcldjxcir6qg0d6j0-python3.13-parsedmarc-11.0.1`),
   with three plan-changing findings:
   - `config.py` contains NO forensic keys; the `[general] save_failure`
     default comes from argparse (`save_failure=False`, cli.py:2598) — but:
   - **`save_output` writes failure.json/failure.csv/samples/*.eml
     UNCONDITIONALLY once `output` is set** (cli.py:2117-2130 →
     `__init__.py:3443+`); the `save_*` flags gate only the NETWORK sinks
     (elastic/kafka/s3/...). So the e2e node needs NO settings change —
     fixture-only extension. (This falsified the resume summary's step (a)
     assumption "set them explicitly if off" — they don't need to be on.)
   - `append_json` skips empty inputs (`__init__.py:3407-3410`): failure.json
     is NOT created by aggregate-only parses → `test -s failure.json` is an
     honest wait signal, not a false green.
   - Detection contract pinned: `message/feedback-report` part + later part
     in `EMAIL_SAMPLE_CONTENT_TYPES` (`__init__.py:157, 2088-2123`);
     `parse_failure_report` REQUIRES `source_ip` (KeyError → InvalidFailureReport);
     `reported_domain` falls back to the sample's From domain; feedback fields
     regex `^([\w\-]+): ([^\r\n]+)\r?$` (colon+space mandatory); delivery_result
     substring-normalized (`smg-policy-action` → `policy`).
4. **Fixture selected and pinned** — upstream's own
   `samples/forensic/subject.eml` at the SAME pinned rev the aggregate fixture
   uses (`f45ab94e`), downloaded via GitHub API, structure verified byte-for-byte
   (3971 bytes; multipart/report; feedback fields incl. Source-IP 10.10.10.10,
   Reported-Domain domain.de, Delivery-Result smg-policy-action; message/rfc822
   sample with Subject literally "Subject"). sha256 → nix32
   `13ibxmd1pid5qcfbj97jwbsbh7ynpkgrbs6jhq0sy0vm6dwp1j85`.
   Rationale: a real reporter artifact beats hand-reconstructed MIME (the
   `message/*` child-nesting gotcha is documented inside parsedmarc's own
   `_decode_mime_payload`, :1916-1940).
5. **Test extended** (`tests/parsedmarc-e2e.nix`, 4 edits):
   - header WHY comment now names all three report classes;
   - `forensicSampleReport` fetchurl fixture (fetchurl, not inline: 4 KB of
     quoted-printable/base64 German content — zero transcription risk);
   - `sendEmail` sends the .eml VERBATIM as raw bytes (third SMTP send);
   - new subtest "forensic failure report rides the same mailbox poll":
     wait on failure.json, five jq identity assertions (feedback_type,
     reported_domain, source.ip_address, delivery_result normalization,
     parsed_sample.subject), samples/Subject.eml existence, failure.csv
     row-count + domain grep. All file-based, no pipes (CI lint contract).
6. **`nix fmt .` + `nix fmt -- . --check` GREEN** after the edits.
7. **Docs rows located, deliberately NOT yet edited** (transcript-first
   doctrine): FEATURES.md:58 (parsedmarc-e2e row) and TODO_LIST.md:60 (T12 row)
   stay untouched until a green transcript exists.

Carried-over green state from the prior session (not this session's work, still
true on the tree): stalwart-e2e (incl. flood node), parsedmarc-e2e BEFORE this
session's addition, both eval checks both arches, statix 0 findings.

## b) PARTIALLY DONE

1. **T12 — parsedmarc forensic/failure-report coverage.** Everything in a)/3-5
   is done; verification is RED (see d). The failure is ISOLATED: in the red
   run, every pre-existing subtest stayed green (unit/ini contract, aggregate
   identity, CSV, SMTP TLS-RPT, StateDirectory journal greps) — the new
   subtest is purely additive, so existing coverage is not regressed.
   Diagnostic facts already established from the run:
   - fetchurl fixture built fine (3971 bytes downloaded, hash verified);
   - `send-email >&2` SUCCEEDED in 1.45 s → all three sends left the script,
     postfix accepted the forensic mail (envelope `dmarc@localhost`);
   - `failure.json` never appeared within the 120 s bound;
   - no "Unable to parse"/"skipping" lines matched in the captured build log —
     the poller either silently skipped the message or errored with wording my
     greps missed; the FULL journal is retrievable via
     `nix log /nix/store/4rj9gk39xwh646dwgy2vn7yhdd0vla58-vm-test-run-parsedmarc-e2e.drv`.
   - Candidate causes (untested): IMAP fetch/mailsuite decode path for
     nested `message/*` parts; poller classification of multipart/report;
     a parse error line present but not matching my grep patterns.
     NOT yet done: root-cause, fix, green rerun, FEATURES/TODO row updates.
     Remember: failed check results are CACHED — any rerun needs the fixed file
     (which the fix will provide).
2. **Close-out (planned)** — TODO_LIST Dependabot row deletion, buildflow row
   sweep, CHANGELOG residue consolidation: located in plan, not executed
   (sequenced behind T12/T15/Final by design).

## c) NOT STARTED

1. **T12 root-cause/diagnosis** of the red subtest (only first-run evidence
   gathered so far).
2. **T15** — buildflow full pass (dprint md-table alignment over the
   2026-09-22 table edits + repairs), then `nix fmt -- . --check`.
3. **Final aggregated gate** — `nix flake check` has NEVER run on the final
   tree (every constituent green individually as of the prior session; the
   new red subtest now makes it definitively red until T12 lands).
4. **T02 — cut v0.4.0** (user-gated: the 02:58 report's g/1 question is still
   unanswered; recommendation on record: cut now).
5. **Close-out rows** (Dependabot deletion + CHANGELOG line, buildflow row,
   21-10 annotate row, archive-sweep row).
6. **Cleanup** — `/tmp/demo-t03/*` GC roots (vm-root, vm-fixed, vm-fixed2,
   driver-root, console.log, smoke-final.txt) still pinned.

## d) TOTALLY FUCKED UP!

1. **T12 first verification run: RED.** The new forensic subtest failed its
   FIRST assertion (`test -s /var/lib/parsedmarc/reports/failure.json` timed
   out at 120.35 s). Exact transcript line:
   `!!! Test "forensic failure report rides the same mailbox poll" failed with
   error: "action timed out after 120.35 seconds (timeout=120.0)"`.
   Log preserved at `/tmp/t12-parsedmarc-e2e.log` (EXIT:1).
   Not yet known whether this is a fixture-delivery problem, a parsedmarc
   classification/parsing behavior my source reading missed, or an assertion
   design error on my side. No fix attempted yet (user requested report +
   wait). The tree currently carries a red check — CI on the daemon's next
   push WILL go red on it. That is the single most urgent fact in this report.

## e) WHAT WE SHOULD IMPROVE!

1. **Host-side parser dry-run before VM burn (THE lesson of this session).**
   The pinned parsedmarc package sits in the host store; a 30-second
   `python3 -c` one-shot calling `parsedmarc.parse_report_email()` on
   `/tmp/forensic-subject.eml` (I already have the exact bytes) would have
   validated the entire detection + shape chain BEFORE burning a ~5-minute
   VM build. I skipped it and paid one full red cycle. This belongs in
   AGENTS.md as a working rule: "fixture-driven VM test edits: dry-run the
   pinned parser on the host first when the package is in the store."
2. **Diagnosability of the new subtest**: the subtest greps nothing from the
   parsedmarc journal on timeout. A `journalctl -u parsedmarc` dump (to
   /tmp, then grep the file — pipe-free) inside the subtest, or at minimum
   in the failure path, would have handed me the skip/error line for free.
   The pre-existing "no file-output errors" subtest already dumps the
   journal — mirror that pattern.
3. **My grep-of-grep antipattern**: verifying `get_ip_address_info` offline
   output keys via `grep ... | grep -n` returned NOTHING and I proceeded on
   inference (the CSV path reads `source.ip_address` unconditionally) without
   closing the gap directly. The inference was probably right, but
   "returned nothing" ≠ "verified". Extract identifiers mechanically, and
   when a verification grep comes back empty, treat that as a failure to
   verify, not as supportive evidence.
4. **Failed-check cache discipline**: the red verdict is now cached; the next
   full-gate run before a T12 fix would replay it. Any post-fix verification
   must run the targeted check FIRST (file changed → new derivation), then
   the aggregate gate.
5. **Daemon-push exposure of red trees**: the daemon committed the red test
   edit within minutes (ahead 20). It pushes mid-session per its policy —
   a red check can hit CI from a push no human explicitly made. Mitigation
   is speed (fix before next daemon push) and the `nix fmt`-style pre-verify
   habit extended to "run the targeted check before yielding whenever a check
   file changed" — I did run it, but only after ALL edits; running it
   immediately after the test edit (before any doc work) is the tighter loop.

## f) Next things to get done (impact-sorted; ~40)

**Unblock the red tree (now):**

1. Diagnose T12 red: `nix log` the failed drv for the full parsedmarc journal
   (look for skip/error lines around the forensic mail).
2. Host-side dry-run: run pinned `parsedmarc.parse_report_email()` on
   `/tmp/forensic-subject.eml` — proves whether detection/parse works at all
   outside the IMAP path.
3. If detection is fine host-side: inspect the IMAP/mailbox path (mailsuite
   fetch → classification) — likely the real gap.
4. Add journal dump to the forensic subtest failure path (diagnosability).
5. Re-run targeted `nix build .#checks.x86_64-linux.parsedmarc-e2e -L` (file
   changed → cache bypassed) until GREEN.
6. Update FEATURES.md:58 + TODO_LIST.md:60 from the GREEN transcript only.
7. Check `git status -sb` + whether the daemon already pushed the red tree;
   if pushed, note the red CI run and let the fix flip it.

**Plan remainder (order per master plan):**

8. T15: `buildflow` full pass (dprint table alignment over 2026-09-22 edits);
   review diff before accepting; `nix fmt -- . --check`.
9. Final aggregated gate: `nix flake check > /tmp/gate-final.log 2>&1;
   echo "EXIT:$?"` (~8-9 min) — must be green before T02.
10. CHANGELOG: fold the T12 forensic-coverage entry into [Unreleased].
11. Close-out: delete TODO_LIST Dependabot row + CHANGELOG line (PR #2 merged
    last session).
12. Close-out: buildflow row sweep + 21-10 annotate row + archive-sweep row
    (only 16_20-49 archivable so far).
13. Close-out: CHANGELOG residue consolidation (annotates/archives, release
    runbook, stateVersion, statix re-collapse, sizing note).
14. Cleanup: drop `/tmp/demo-t03/*` GC roots (AGENTS debug-loop hygiene).
15. `gh run list` green verification at the very end.

**User-gated (cannot proceed without input):**

16. g/1 (STILL OPEN since 02:58): cut v0.4.0 now? Recommendation: yes.
17. Push authorization for T02 (master + tag + `gh release create`) — harness
    default forbids pushes without explicit ask.
18. T16/C17: SystemNix push approval (dedupe+relock green locally).
19. T17: Resend API key for the live :587 SASL smoke.
20. T18: SystemNix CI-debt triage (gated on T16).
21. T19 verdict: demo.qcow2 history purge (~140 MB, needs force-push —
    forbidden without approval) vs accept-clone-weight.
22. T21/D1+D2: production build-out slices (M22 provisioning, M23 backup/DR,
    M24 DNS, M25 migration, M26 DMARC+OIDC, C12 rua live, C14 secrets).
23. T22 verdicts: mailsuite STARTTLS issue file-or-skip (draft ready),
    Stalwart Junk upstream request, Renovate install-or-drop, Discussions
    toggle.
24. T23 standing: next-pin-bump presence re-verify (fires on NEXT bump).

**Improvements noticed this session (candidates, most → AGENTS/TODO routing):**

25. AGENTS.md working rule: host-side dry-run of pinned parsers before VM
    fixture burns (lesson above).
26. Subtest diagnosability: journal-dump-on-timeout pattern for async
    wait_until_succeeds subtests.
27. Anti-pattern note: empty grep output is not verification (grep-of-grep).
28. Consider a tiny host-side eval of `parse_failure_report` on the fixture
    as a permanent fast regression layer (seconds vs minutes) — maybe a
    `runCommand` check beside the VM test.
29. Re-verify `.data.errors` / GTUBE / catch-all ledger claims stay accurate
    when T12 work touches README (docs drift guard).
30. TODO_LIST freshness sweep after T12 lands (row 60 wording says "check
    parsedmarc's failure-report sample" — done; rewrite as done+evidence).

**Standing backlog visible in TODO_LIST during this session (not started,
not forgotten):**

31. dmarc-monitor live validation against a real IMAP mailbox (BLOCKED: D1).
32. mailsuite auto-STARTTLS upstream filing (BLOCKED: user file-or-skip).
33. TLS-node boot-race Restart policy upstreaming decision (nixpkgs parsedmarc
    unit ships no Restart).
34. Renovate/Dependabot cadence policy (C19) — first Dependabot PR was merged;
    decide automation stance.
35. `nixpkgs-lib.follows` eval guard (TODO_LIST-tracked from flake-parts
    migration).
36. Upstream workaround-retirement triggers (nixpkgs PRs #563651/#563652/
    #563777 — re-checked green last session; keep evidence fresh on next bump).
37. README "Try it in a VM" port-forwarding table: keep in sync with any
    future httpBind default change.
38. Statix W20 recursion guard: any new dotted-key group in tests must be
    collapsed at introduction (not retroactively).
39. Vulnix replacement decision (NVD feed retired; skip documented in
    .buildflow.yml) — revisit when a maintained scanner lands in nixpkgs.
40. Change Log discipline: every gate-green change this session (T12 edits)
    needs its CHANGELOG line at close-out, not at release time.

## g) Questions I can NOT figure out myself

1. **v0.4.0 (g/1, now blocking twice over)**: cut the release once T12 is
   green and the full gate passes — yes or no? (Recommendation on record:
   cut now; tag push is reversible, nothing consumes tags yet.)
2. **Push authorization for the release**: may I push `master` + the
   annotated tag and create the GitHub release when T02 runs? The harness
   forbids pushes without an explicit ask, so I need this in writing even
   if v0.4.0 is approved.
3. **Red-tree exposure policy**: if the daemon pushes the currently-red tree
   to origin before the T12 fix lands, do you want me to treat flipping that
   red CI run as the immediate top priority (pause everything else), or
   proceed in order and fix within the session regardless?

---

_Report written 2026-09-23 03:21–03:25 from session evidence: resume summary,
`/tmp/t12-parsedmarc-e2e.log` (EXIT:1), pinned parsedmarc 11.0.1 source reads,
`git status` (ahead 20). Now waiting for instructions._
