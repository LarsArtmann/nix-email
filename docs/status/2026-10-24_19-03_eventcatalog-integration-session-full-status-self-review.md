---
title: "EventCatalog integration session: full status + self-review"
date: 2026-10-24 19:03
status: point-in-time snapshot (executed session report; publish rides CI handoff)
owner: lars
---

# EventCatalog integration session: full status and self-review

Covers ONLY this session (17:30-19:03): executing
[the integration plan](../planning/2026-10-24_17-07_nix-email-eventcatalog-hub-perfect-integration.md)
T1-T9 in `/home/lars/projects/nix-email` + `~/projects/eventcatalog-hub`.
Companion execution report: [18-40](2026-10-24_18-40_eventcatalog-integration-executed-publish-riding-ci-handoff.md)
(receipts). This file adds the honest part the receipts do not carry.

## a) FULLY DONE

1. **T1+T3 - exporter** `scripts/export-catalog.py` @ `456840b` (pushed):
   argparse (`-o`, `--plain`, `--selftest`), stdlib-only, idempotent
   re-export (hub retries export jobs), outdir guard, frontmatter
   yaml_str renderer (render-inventory.py parity), 2 service pages
   distilled from README module docs, 7 ADRs (5 accepted, 2 proposed
   C42/C45 - statuses honest, dates grounded in CHANGELOG),
   `users/lars.mdx`. Selftest: exact file set, frontmatter keys, version
   lockstep 1.0.0, no badges, appliesTo resolves in-tree, byte-level
   determinism, table-pipe balance.
2. **Quality gates green**: BuildFlow EXIT:0 (ruff/bandit/vulture ran,
   line lengths, exec bit), ruff direct EXIT:0, CI's fail-closed ruff
   step green on the fix commit (run 40110026400).
3. **T2+T4 - hub adoption** @ `0788a21`: exact manual-source entry incl.
   lint block, `generate-sources.sh` placement verified (between
   mesh-orders and pbx-lens), `--check` clean, dprint clean, manual +
   generated committed together. Per-source governance linter green
   (10 files, no problems).
4. **T5 (scoped) - full pipeline rehearsal EXIT:0** in a hub snapshot:
   clone from GitHub master, export, merge (badge-union proven: my
   body/frontmatter + SystemNix "not deployed" chip on the SAME page),
   governance gate zero dangling, per-source lint green, merged-render
   lint green (87 files), npm ci, generate + build,
   `check-dist-output --expect-source nix-email` OK, dist contains all
   routes, preview fetched and rendered the mail-server page.
5. **The rehearsal caught a real bug**: `refs/owner-exists` - the hub
   lints each source IN ISOLATION, so owners must resolve inside the
   tree. Fixed same session (`users/lars.mdx`, commit `456840b`),
   re-linted green, pushed. The system worked as designed.
6. **T7 - docs**: AGENTS.md "EventCatalog integration" contract section,
   README section, CHANGELOG row, FEATURES row; dprint + pipe + marker
   lints green; all pushed (`7153ed4`, `8176177`).
7. **T9 - guardrails**: TODO_LIST rows (publish handoff BLOCKED,
   description-sync TODO, deferred-kinds standing verdict DONE), plan
   annotated `executed` with a per-task verdict table.
8. **T8 partial**: 18-40 status report with receipts + CI-rate-limit
   addendum (a5bcee5).
9. **Hygiene**: daemon-commit reclaim x2 (proper messages via soft
   reset), scratch dirs cleaned, preview server killed, foreign
   in-flight files never touched (webphone sources.json, the concurrent
   session's hub CHANGELOG/TODO_LIST/docs).

## b) PARTIALLY DONE

1. **T5 full-9-source green**: NOT achieved - two FOREIGN sources were
   red mid-flight (webphone export boots the app and dies on
   `/var/lib/webphone`; go-cqrs-lite master's mesh-demo calls unlanded
   `reg.MarkDemo`). Scoping to nix-email was the right call, but the
   union-with-all-sources build remains unproven until their workstream
   lands.
2. **T6 - publish**: not dispatched. Hard parts: sudo is
   agent-banned + pushing hub master TODAY would publish a red run (it
   carries their broken sources). Handoff documented (push-trigger path
   - TODO_LIST row). The `publish=false` CI rehearsal (F6.1/F6.2) also
     never ran.
3. **T8 - live verification**: local receipts only. catalog.home.lan
   pages unverified (rides T6). The nix-email Forgejo mirror was at
   15:30 (pre-exporter) at last check - NOT re-verified after my
   pushes; CI's Forgejo-side clone needs it >= `456840b`.
4. **Preview eyeball was 60% of the pages**: I fully fetched ONLY the
   mail-server page. dmarc-monitor and the 7 ADR pages were verified by
   dist route listings, not by rendered fetch. (My closing summary said
   "preview renders the page + all 7 ADR routes" - precise wording
   would have been "routes present in dist".)
5. **Origin CI green for session commits**: two red runs are the
   GitHub-API rate-limit class (magic-nix-cache 418 +
   `ResourceExhausted`; one died at Install Nix). All content steps that
   ran were green, but master's latest CI badge is red until a rerun
   lands (limit resets hourly; I did not rerun).

## c) NOT STARTED

1. Real CI dispatch + publish (F6.1-F6.4) - blocked on the concurrent
   workstream + sudo.
2. Live catalog.home.lan verification receipts (F8.1/F8.2) and
   `check-stale-sources.sh` quiet check (F6.4 tail).
3. `build-stamp.json` covers-nix-email-rev verification (CI-side
   artifact).
4. Full `nix flake check` green on origin for the session's commits
   (rate-limited away; local BuildFlow was green but whether it
   executed the VM checks vs evaluated them is not pinned in my log
   reading - assume eval-level, not VM-run).
5. SystemNix description-sync (row added; no actual sync needed yet).
6. Rerun/cleanup of the cancelled CI run 40112947029.
7. Harvesting this report's section (f) into TODO_LIST/ROADMAP (the
   critical rows already exist from T9; the rest is fuel).

## d) TOTALLY FUCKED UP (all caught and fixed, but they were MY errors)

1. **Draft artifact shipped in the first write**: `ADR_PARSED MARC =
   None` placeholder + stray `"""` = a syntax error in the very first
   file write. Sloppy draft hygiene; the selftest would have caught it,
   but it should never have been written.
2. **REPO_BASE broken-link bug PASSED the selftest**: bodies linked to
   `[...](REPO_BASE)` (a literal relative link). Caught by eyeball
   AFTER the green selftest - my test asserts frontmatter, not link
   targets. A real test gap, not just a typo.
3. **TODO_LIST row corruption**: my edit's old_string covered only the
   first table cell, appending garbage cells to the row; fixed by a
   python truncation. I violated my own rule: whole-row edits or write,
   never partial-cell matches in wide tables.
4. **Two blind full-build reruns (~25 min wasted)**: rounds 2 and 3
   failed on FOREIGN moving masters (webphone, MarkDemo). I reacted
   (rerun) before diagnosing (git log showed the daemon committing
   sources.json changes at 18:02-18:16). Lesson: in a hot environment,
   re-verify pipeline INPUTS changed since the last run before spending
   ten minutes on a build; scope down FIRST.
5. **Transient-failure adaptation was slow**: sources.json ENOENT races
   hit me THREE times before I switched to the retry-snapshot pattern.
   First occurrence should have taught the pattern.
6. **Self-created list-item hazard**: my own rewrap produced a line
   starting with `- README` (known repo dprint rule) - caught in the
   same breath, but I wrote it in the first place.
7. **--plain parity is CLAIMED but not TESTED**: the exporter documents
   that `--plain` emits an identical tree (no versioned refs exist);
   the selftest never asserts it. A claim without a test is a lie
   waiting to happen.
8. **Minor**: attempted an AGENTS.md edit before registering a file
   read (tool refused; project_context copy was in my head, but the
   contract is read-then-edit).

## e) WHAT WE SHOULD IMPROVE (incl. the self-review questions)

- **Ghost systems: none created.** The exporter is wired end-to-end
  (sources.manual.json -> pipeline -> dist -> preview-verified page).
  The only dead-weight candidate (a `.eventcatalog-hub.json`
  convention file) was explicitly rejected in the plan.
- **Split brain (real, small, acknowledged)**: ADR content now lives in
  TWO places - README ledger/ROADMAP prose AND exporter data dicts.
  Status flips (C42/C45) must happen in the exporter while the README
  keeps its own narrative. The AGENTS section pins "flip in the
  exporter data", but nothing MECHANICALLY enforces sync. Improvement:
  a selftest or lint that greps the exporter's proposed-ADR ids against
  ROADMAP's open-decision ids, or accept the drift risk explicitly.
- **Test honesty**: add (1) absolute-URL assertion for body links
  (kills the REPO_BASE class), (2) `--plain` byte-parity assertion,
  (3) optionally a YAML round-trip check once a yaml lib is acceptable
  (it is not, stdlib-only - so instead assert the exact frontmatter
  line shapes, which the selftest half-does).
- **Verification depth**: "preview eyeball" should mean EVERY new page
  fetched (9 files = 9 fetches), not one representative + listings.
- **Pipeline discipline in hot environments**: snapshot + scope-first
  rehearsal is the pattern that worked (round 4, EXIT:0, ~5 min) - it
  should have been round 2.
- **Scope creep: none** - deferred-kinds guard held (no channels,
  no manifest, no convention file, zero hub pipeline changes).
- **Nothing useful was removed**; no legacy added.

## f) Up to 50 next things (brainstorm fuel - TODO_LIST/ROADMAP candidates, NOT commitments)

Publish chain (highest impact first):

1. Verify the nix-email Forgejo mirror carries >= `456840b`.
2. Watch for the concurrent demo-flagging workstream landing (webphone
   export fix + go-cqrs-lite MarkDemo tagged/bumped).
3. Push hub master (or `sudo bash scripts/ci-dispatch.sh build.yml
   master` on evo-x2) once clear.
4. Watch the first full-9-source CI run to green (`ci-log.sh --steps`).
5. Verify catalog.home.lan `/docs/services/mail-server/1.0.0` (body
   ours, chips SystemNix).
6. Verify `/docs/services/dmarc-monitor/1.0.0` live.
7. Verify all 7 `/docs/adrs/<id>/1.0.0` routes live.
8. Verify `build-stamp.json` covers the nix-email rev.
9. Verify `check-stale-sources.sh` quiet post-publish.
10. Append live URLs/screenshots to the 18-40 report (ANNOTATE mode).
11. Archive the 17-07 plan per corridor policy once T6/T8 close.
12. Rerun the rate-limited CI runs once the GitHub budget resets
    (`gh run rerun`), confirm master badge green.

Exporter hardening:

13. Selftest: assert body links are absolute http(s) URLs.
14. Selftest: assert `--plain` output is byte-identical to default.
15. Add `--check` mode (export to tempdir, diff against an existing
    tree) as a CI-able drift guard.
16. ADR cross-links: `related:` between vendor-stalwart-016-module and
    stalwart-pin-vs-overlay; parsedmarc-keep-or-retire and
    hardening-defaults-off.
17. Decide + document the version policy for content changes (see
    question 2).
18. Assert the exact frontmatter line SHAPES (not just keys) so
    yaml_str drift is caught.
19. When C42 resolves: flip the ADR status + update the dmarc-monitor
    body caveat + CHANGELOG in one commit.
20. When C45 resolves: same for stalwart-pin-vs-overlay (+ re-check the
    vendor drift note inside it).
21. Consider a `decisionMakers:` field on ADRs (contract supports it;
    owner-gated calls deserve the attribution).
22. mail-relay authored body decision (see question 3).

Content depth (each small):

23. dmarc-monitor body: parsedmarc ini passthrough example.
24. mail-server body: link docs/MONITORING.md pointer (consumer-side
    Gatus contract).
25. mail-server body: link docs/THREAT_MODEL.md.
26. mail-server body: demo-VM quickstart pointer (`nix run .#vm`).
27. Service bodies: mention `docs/INBOXCLEAN.md` JMAP contract
    (consumer ecosystem).
28. When v0.5.0 ships: refresh the Consumers section (pin version,
    0.16-world language).

Split-brain + sync discipline:

29. Roadmap-decision-id vs exporter-ADR-id sync check (mechanical).
30. SystemNix description-sync when v0.5.0 changes capabilities.
31. dmarc-monitor go-live badge flip: verify it rides the inventory
    with zero source changes (assert in the next rehearsal).
32. Hub AGENTS: nix-email as the documented MANUAL-source example
    (their doc, their call).

Hub-side observations (their repo, filed here as noticed):

33. lint-sources.sh could print per-source durations (forensics for
    hangs like webphone's).
34. build.sh could validate `sources.json` mtime vs run start (moving-
    master guard) - or at least log the revs it will use up front.
35. The export-retry loop retries deterministic failures once (15s) -
    a data-dir EPERM is not transient; a cheap failure-classifier
    could save the retry minute.
36. Rate-limit mitigation for CI (magic-nix-cache tuning / concurrency
    group) - two red runs today were pure infra.
37. `check-dist-output` could assert the .well-known/api-catalog
    linkset includes every expected source's services (nix-email
    included).

Session/process lessons (crush-config lessons.md candidates):

38. Moving-master rule: re-verify pipeline inputs before long runs in
    hot environments; scope-first rehearsals.
39. Partial-cell edit ban in wide tables (whole row or python fix).
40. Per-source-isolation lint implies: every referenced user/team must
    ship in-tree (cross-project lesson for any future source repo).
41. Retry-snapshot pattern for files being atomically rewritten by
    other processes (jq/cat with retry loop).

Small hygiene:

42. The plan's mermaid graph says "T6a fail -> LOG -> FIX" - with FIX
    pointing back at T1; in reality T6 failures can be foreign (this
    session's case) - future plans should model a foreign-red exit.
43. Cancelled CI run cleanup / branch-protection check after red runs.
44. Verify whether BuildFlow's nix-flake-check step executed VM checks
    or eval-only for this session (read the step output explicitly).
45. Screenshot receipts for user-facing proof (fetch-text suffices for
    me, not for humans).
46. Add the exporter's `--selftest` to CI as a cheap explicit step
    (ruff does not run it; BuildFlow does not either - only I did,
    manually).
47. EventCatalog integrations page (`docs/generated/integrations`)
    should list nix-email post-publish - verify.
48. llms.txt / api-catalog include the two services - verify
    post-publish.
49. Consider pinning the exporter's catalog "content version" in
    CHANGELOG Unreleased so v0.5.0 release notes mention the catalog
    export as a feature.
50. This report: after T6/T8 close, ANNOTATE (never rewrite) with the
    final publish receipts.

## g) Questions I can NOT figure out myself

1. **Who pushes hub master when the concurrent workstream lands?** A
   future session of me, or you personally? It fires build.yml, which
   publishes straight to catalog.home.lan - a user-visible artifact. I
   documented the push-trigger path, but the trigger finger is a policy
   call (and sudo ci-dispatch is yours only).
2. **Catalog version policy**: services stay `1.0.0` lockstep with the
   inventory renderer forever, or do material body changes bump to
   1.1.0+ (forking the id's version set vs the inventory's 1.0.0 - the
   strict gate tolerates it, the pages grow a version history)? Same
   question for ADRs on status flips (bump vs edit-in-place at 1.0.0).
3. **Does `mail-relay` deserve an authored nix-email body?** It is a
   third inventory row (deployed on evo-x2) whose implementation IS
   this repo's `services.mail-server.relay` option - but the deployed
   relay may be a different thing entirely (SystemNix-owned?). I cannot
   tell from the inventory row alone whether authoring it here would be
   truth or a lie.

---

Session end state: nix-email master @ `a5bcee5` pushed and clean; hub
master carries the adoption `0788a21` (unpushed, riding the concurrent
workstream); all corridor docs updated. WAITING FOR INSTRUCTIONS.
