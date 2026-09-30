# Status — Cross-Repo Integration Design Session (nix-email x InboxClean)

**When:** 2026-09-30 12:53 CEST
**Scope:** This session only (approx. 12:19-12:53 CEST, immediately after the
InboxClean local-first pivot docs session, whose report lives at
`~/projects/InboxClean/docs/status/2026-09-30_12-19_local-first-pivot-docs-session.md`).
The session answered two owner questions: (1) "nix-email vs InboxClean?" and
(2) "How can we make them work TOGETHER?" - both advisory/analysis, zero code
or doc edits in either repo. No unrelated research performed.
**Repo placement:** written in nix-email (the cwd repo); session spans both
repos, all InboxClean citations are absolute paths.
**Format note:** user explicitly requested `.md`; this overrides the
status-report skill's HTML default for this run only.

## Session summary

Verified the relationship between the two repos (siblings under SystemNix,
not consumer/producer), ingested the five InboxClean pivot docs updated at
12:19 (README, ROADMAP, ADR-023, TODO rows 172-176, status report) plus
nix-email's ROADMAP, then produced a three-seam integration design
(JMAP protocol, contract test, data flow) with a Pareto-ordered action list.
Core finding: the JMAP spike (InboxClean TODO #173) is unblocked NOW on the
nix-email demo VM - it does not wait on nix-email's gated D1/D2 production
decisions.

## a) FULLY DONE

1. **Cross-repo relationship verdict: siblings, not consumer/producer.**
   Evidence: InboxClean's flake inputs contain no nix-email input
   (`~/projects/InboxClean/flake.nix:5-23`: nixpkgs, systems, flake-parts,
   treefmt-nix, git-hooks-nix, art-dupl only); nix-email README:8 says
   "consumed by SystemNix (upstream-flake pattern, **like**
   InboxClean/DiscordSync)" - the shared thing is the consumption _pattern_,
   not a dependency edge. Delivered as a comparison table.
2. **Pin-discipline asymmetry verified.** SystemNix consumes nix-email via
   floating `?ref=master` (VIOLATION, decision-gated C17/C18) but the same
   floating ref is fine for InboxClean (no nixpkgs-version-sensitive
   contract). Evidence: nix-email README:270-278. No new research - cites
   checked against the live file.
3. **Pivot docs ingested (read, not skimmed):** InboxClean README (local-first
   repositioning), ROADMAP Theme 0, ADR-023 (the decision record: MailClient
   seam, JMAP adapter #2 targeting Stalwart, corpus = the backup, web-first
   reads, event-bus integrations), TODO rows 172-176, and the 12:19 status
   report including its partially-done/not-started gaps.
4. **nix-email-side JMAP facts grounded in code, in this session:**
   JMAP rides the HTTP listener (web admin / JMAP / REST API share port 8080:
   `modules/mail-server.nix:104`, `:467`, README:153); the demo VM forwards
   host 18080 to it (`flake.nix:201-203`, `host.port = 18080`, plain HTTP,
   creds `admin` / `demo-admin`: `flake.nix:233`, README:411).
5. **Decoupling insight delivered:** the spike needs no D1/D2 production
   decisions because the demo VM is a complete test bed (end-to-end host-
   smoked 2026-09-22 per AGENTS.md). This unblocks InboxClean row 173
   regardless of the VPS cutover.
6. **nix-email repo state verified clean and current:** working tree clean;
   the prior session's `606467e` ("Record the decided InboxClean JMAP
   integration direction") is HEAD.

## b) PARTIALLY DONE

1. **Integration design is docs-verified, not live-probed.**
   Works: every JMAP claim cites code or README read this session.
   Remains: no transcript of a live JMAP session on the demo VM (no
   `curl http://localhost:18080/.well-known/jmap` has ever been run in a
   session report I can find); the 0.15.5 JMAP capability list is unverified
   against the binary. Blocker: none - it is a ~15-minute probe.
   Effort: S. (The repo's own rule - "no new test assertion without a
   transcript" - applies to the next step, the contract doc.)
2. **Two-way coordination artifact: designed, not written.** The 12:19 report
   flagged "nix-email coordination is one-way... no shared contract artifact
   exists yet". This session specified what that artifact is (contract doc:
   pinned version, endpoint, auth, capabilities, test-account recipe, demo-VM
   usage) but no file exists yet. Effort: S/M.
3. **The "work together" answer is advisory until the owner picks a seam.**
   Pareto order was proposed (probe, contract doc, e2e assertion) and an
   offer to execute was made; nothing is committed to. Not blocked - waiting
   on owner direction (correct for exploration-mode).

## c) NOT STARTED

| Item                                                            | Why not started                                                                        | Priority                             |
| --------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------ |
| Live JMAP probe on the demo VM                                  | Advisory session; probe was proposed, owner has not pulled the trigger                 | Critical - unblocks everything below |
| Shared JMAP contract doc (nix-email side) + ADR-023 back-link   | Blocked on probe transcript (evidence-first)                                           | High                                 |
| JMAP E2E assertions in `stalwart-e2e` (contract test seam)      | Blocked on probe + contract doc                                                        | High                                 |
| InboxClean `contracts.MailClient` extraction (row 172)          | Their build order starts here; zero interface code exists (confirmed 12:19, unchanged) | Critical (InboxClean-side)           |
| Go JMAP client library evaluation (row 173)                     | Nothing vetted - per verify-external-claims, do not assume a library exists            | High                                 |
| Local corpus + SQLite/FTS5 index (row 174)                      | No schema (migration v11 territory), no Maildir layout spec                            | High                                 |
| Corpus-backed web reads (row 175)                               | `handlers.go:289`/`:1338` still call live Gmail; depends on 174                        | High                                 |
| Event-bus consumers: CRM (Ledger) feed, CV classifier (row 176) | Transport decision (in-process/webhook/MCP) owner-gated                                | Medium                               |
| MCP server mode owner decision (#156)                           | Memo ready, awaiting owner call                                                        | Medium                               |
| `DB_SYNCHRONOUS` / corpus durability decision                   | Owner-gated, escalated by corpus-as-backup                                             | High (decision)                      |
| Deployment topology decision (where InboxClean + corpus live)   | See section g, Q1                                                                      | High (decision)                      |

## d) TOTALLY FUCKED UP

1. **Two wasted reads via the wrong tool.** First attempted to read the
   InboxClean docs through the QMD knowledge base (`mcp_qmd_get`) - "Document
   not found" twice; the project files are not indexed there. Switched to
   `view`. Severity: trivial (two round trips). Root cause: assumed indexing
   instead of checking. Mitigation: none needed beyond not repeating it.
2. **A `rg hostfwd` dead-end that masked a real mechanism.** Grepping
   `hostfwd` in nix-email's flake.nix returned nothing, yet the forward
   exists - it is spelled `host.port = 18080` at `flake.nix:201-203`. My
   first answer cited the `:169` comment and README:411, which happened to be
   accurate, but the mechanism line was only located during THIS report's
   verification pass. Severity: none in the delivered answer (citations were
   right), but it is the from-memory/mechanism-assumed class the repo's
   "extract cross-file identifiers mechanically" rule exists to kill.
   Mitigation applied: verified before writing this report.
3. **Pre-existing, re-observed, still stale (NOT mine, flagged twice now):**
   InboxClean ROADMAP Theme 6 lists "Bulk action UI" as an open raw idea
   while the README documents the bulk bar + bulk keyboard actions as
   shipped. This split brain was already called out in the 12:19 report
   (section e) and survived that session's stale-framing sweep. Severity:
   docs-trust erosion in a repo that just did a truth pass. Mitigation:
   one-line ROADMAP strike-through, S effort.
4. **Pre-existing, carried: InboxClean AGENTS.md over its own size budget**
   (406 lines vs BuildFlow's 377 max as of 12:19, made worse by that session
   and explicitly left as debt). Every new session-context block makes it
   worse. Severity: process debt, creeping. Mitigation: diet pass, M effort.

## e) WHAT WE SHOULD IMPROVE

- **Label the evidence class in cross-repo answers.** "Docs-verified" and
  "transcript-verified" are different tiers; the repo's no-assertion-without-
  transcript rule should extend to design answers, not only test assertions.
  Impact: prevents a contract doc (and then an adapter) being written against
  unprobed behavior. Fix: run the probe before writing the contract doc - the
  probe is step 1 of the Pareto list for exactly this reason.
- **Cross-repo relative links rot.** InboxClean's ROADMAP links nix-email as
  `../nix-email` (works on disk, breaks on GitHub); ADR-023 uses the full
  URL. Inconsistent within one repo. Impact: broken pointers for every
  non-local reader. Fix: normalize to absolute GitHub URLs in the next
  InboxClean docs touch (S).
- **Cross-repo sessions have no placement convention.** This report lives in
  nix-email (cwd) while the sibling session report lives in InboxClean; the
  integration itself has no home yet. Fix: the contract doc (next-actions #5)
  becomes the durable home; session reports stay per-repo by cwd (S,
  decision noted in g? no - I can decide this myself: cwd-repo placement,
  contract doc owns the durable truth).
- **Chat-delivered designs are entombed.** The three-seam integration design
  exists only in this conversation. Per the status-report skill's own
  warning, section (f) below must be HARVESTed into TODO_LISTs (nix-email
  gets new rows; InboxClean rows 172-176 get refinements, not duplicates) or
  it dies in this timestamped file. Fix: run docs-health HARVEST on this
  report next.
- **f-list routing rigor:** InboxClean TODO rows 172-176 already exist; the
  f-items below deliberately REFINE them (e.g. "row 173: replace unverified
  test-bed assumption with probe transcript") instead of re-listing them.
  HARVEST must respect that.

## f) Up to 50 things we should get done next

Ranked by impact within four phases. Impact: Critical/High/Medium/Low.
Effort: S (<30min) / M (30min-2hr) / L (>2hr). Items marked DECISION are
owner calls, not implementation.

### Phase 1 - Evidence first (do before anything else)

1. Boot the demo VM (`nix run .#vm`) and probe JMAP from the host:
   `curl http://localhost:18080/.well-known/jmap` with `admin`/`demo-admin`;
   save the transcript. Impact Critical, S, Verification.
2. Probe JMAP as a NON-admin principal: create a demo individual with
   `roles: ["user"]` (the known API gotcha) and authenticate as that user -
   the adapter will run as a mailbox owner, not the admin. Impact High, S,
   Verification.
3. Record the 0.15.5 JMAP capability list from the session response
   (core/mail/submission/push URNs), pinned to the transcript. Impact High,
   S, Verification.
4. Test whether JMAP EventSource/push works on 0.15.5 demo (decides
   InboxClean sync: poll vs push). Impact High, M, Verification.

### Phase 2 - The shared contract artifact

5. Write the JMAP contract doc in nix-email (`docs/INBOXCLEAN.md` or README
   section): pinned Stalwart version, endpoint, auth model, capabilities,
   test-account recipe, demo-VM quickstart. Impact High, S, Documentation.
6. Link the contract doc from InboxClean ADR-023 and TODO row 173 - closes
   the "coordination is one-way" gap. Impact High, S, Documentation.
7. Document the TLS posture delta in the contract: demo VM is plain HTTP;
   production requires ACME/real certs - the adapter must support both,
   insecure-skip ONLY for demo. Impact Medium, S, Documentation.
8. Define the label/keyword mapping (InboxClean labels vs Stalwart JMAP
   keywords/flags) in the contract doc. Impact High, M, Documentation.
9. Fix cross-repo relative links (`../nix-email` to absolute URLs) in
   InboxClean ROADMAP/ADR. Impact Low, S, Cleanup.
10. Decide the contract-doc home convention for future cross-repo artifacts
    (recommendation: upstream repo owns its surface docs; nix-email README
    pin-discipline section is the precedent). Impact Medium, S, DECISION.

### Phase 3 - nix-email side (the contract test seam)

11. Add JMAP assertions to `stalwart-e2e`: session GET + mailbox query/get on
    a seeded account, file-based assertions per repo rules. Impact High,
    M/L, Quality.
12. If JMAP testing becomes its own flake check instead: update BOTH ci.yml
    guard lists in the same commit (x86_64 lockstep `expected=` + aarch64
    shape guard) - the known same-commit rule. Impact High, S, Quality.
13. Seed a dedicated JMAP test principal (`roles: ["user"]`) in the e2e
    fixture. Impact Medium, S, Quality.
14. Add a demo-VM JMAP curl quickstart to README "Try it in a VM" once the
    probe transcript exists. Impact Medium, S, Documentation.
15. Document the JMAP reverse-proxy posture in the runbook (8080 stays
    loopback/reverse-proxied; JMAP clients never get raw exposure). Impact
    Medium, S, Documentation.
16. Rule for the contract: no InboxClean adapter assertion may cite Stalwart
    behavior without a demo-VM transcript (extends the repo's existing
    transcript rule across the contract boundary). Impact Medium, S,
    Documentation.
17. HARVEST this report into nix-email TODO_LIST (rows 1-16 above as bounded
    tasks; DECISION items to ROADMAP open decisions as C-numbered entries).
    Impact Medium, S, Documentation.

### Phase 4 - InboxClean side (refine rows 172-176, do not duplicate)

18. Row 172: draft the `contracts.MailClient` interface as a design doc
    FIRST (types before code, capability flags per ADR-023). Impact
    Critical, M, Feature.
19. Row 173: replace the "demo VM is the test bed" assumption with the probe
    transcript + endpoint facts from Phase 1. Impact High, S, Documentation.
20. Row 173: evaluate Go JMAP client libraries (nothing vetted exists;
    verify-external-claims before any choice is encoded). Impact High, M,
    Quality.
21. Row 173 spike scope: prove list + raw fetch + label/state ops against
    the demo VM, transcript per assertion. Impact High, M, Feature.
22. Row 174: corpus schema design doc before code (migration v11 territory:
    Maildir layout, FTS5, SHA-256 content-hash keys). Impact High, L,
    Feature.
23. Row 174 gate: `DB_SYNCHRONOUS`/durability decision - corpus-as-backup
    escalates SQLite durability to first-class. Impact High, S, DECISION.
24. Row 175: repoint web reads from live `ListMessages` to corpus +
    projections (sites known: `handlers.go:289`, `:1338`). Impact High, L,
    Feature.
25. Row 176: event-consumer transport decision (in-process webhook vs MCP-
    only first). Impact Medium, S, DECISION.
26. #156 MCP memo: make the owner call the pivot re-prioritized. Impact
    Medium, S, DECISION.
27. Deployment topology decision: InboxClean (and the corpus) on evo-x2 at
    home vs on the VPS beside Stalwart. Impact High, S, DECISION (also g/Q1).
28. Sequencing decision: start the JMAP spike now on the demo VM, or hold
    until D1/D2 production decisions land. Impact High, S, DECISION (g/Q2).
29. Build-order refinement: rows 173 and 174 are independent (the corpus can
    be built Gmail-only) - decide corpus-first vs adapter-first for the
    "backup ALL emails" goal. Impact High, S, DECISION (g/Q3).
30. Reconcile the ROADMAP Theme 6 bulk-UI row with the README's shipped bulk
    bar (pre-existing split brain, flagged twice). Impact Medium, S,
    Documentation.
31. InboxClean AGENTS.md diet to within the 377-line BuildFlow budget.
    Impact Medium, M, Cleanup.
32. Add the ADR-023 pointer paragraph to `docs/ARCHITECTURE.md`. Impact Low,
    S, Documentation.
33. Verify the Paperless live path (rows 22/141) before row 174 makes it
    load-bearing. Impact Medium, M, Quality.
34. Design the event-push topology doc: Stalwart JMAP push, sync --watch,
    corpus, event bus, consumers. Impact High, M, Documentation.
35. Design the account model: Stalwart principals as InboxClean accounts
    (slug model extends; admin-issued vs per-user credentials). Impact
    Medium, M, Documentation.
36. Plan corpus ingestion order across the migration: Gmail corpus now,
    Stalwart corpus post-cutover, one InboxClean over both. Impact Medium,
    M, Documentation.
37. Plan the corpus's own DR (it IS the backup: offsite copy, restore drill -
    ties into nix-email ROADMAP's backup theme). Impact Medium, M, Feature.
38. Keep the Gmail adapter at parity during the pivot so the corpus backfill
    is not blocked on JMAP. Impact Medium, M, Feature.

(38 items - stopped where the list would pad; items 1-4 are the critical
path and everything else is sequenced behind them.)

## g) Up to 3 questions I can NOT figure out myself

1. **Where does InboxClean (and the corpus) live in the JMAP era - evo-x2 at
   home, or the VPS beside Stalwart?** What I tried: ADR-023 says "local
   corpus under owner control" but never pins the host; nix-email's ROADMAP
   gates production on D1/D2 without naming InboxClean's host; the Gatus
   section ("on evo-x2, external viewpoint") implies evo-x2 is the always-on
   home box. The answer unblocks: where THE backup physically lives, its DR
   design, row 175 deployment, and the auth path (LAN/tunnel vs public).
   This is an infrastructure + security-posture call only you can make.
2. **Start the JMAP spike on the demo VM now, or hold until D1/D2 land?**
   What I tried: verified the demo VM is a complete test bed (host-smoked
   2026-09-22, JMAP listener confirmed in config), so the spike is
   technically unblocked today - but the account the adapter will eventually
   serve (real mailbox, real TLS, real credentials) appears only after the
   production cutover you have gated. If you would rather not context-switch
   mid-gating, the spike slides and the corpus (which is Gmail-only-capable)
   goes first. Priority call, yours.
3. **After the MailClient seam (row 172): adapter-first (173) or
   corpus-first (174)?** What I tried: ADR-023's build order lists
   seam, spike, corpus, web, integrations - but reading it closely, the
   corpus does not actually depend on JMAP (it can be built and fed from the
   Gmail adapter alone), so the canonical order is a choice, not a
   constraint. The two orders optimize for different owner goals: corpus-
   first delivers "backup ALL emails" (goal #1) sooner; adapter-first
   delivers the self-hosted integration and de-risks the Stalwart dependency
   sooner. Which goal bites first is product intent - yours.

WAITING FOR INSTRUCTIONS.
