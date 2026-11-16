# 2026-11-16 05:47 CET - Stalwart 1.x default flip: status + brutal self-review

Scope line - what this report VERIFIED and how:

- VERIFIED: `nix flake check` EXIT:0 on the final tree (all 17 x86_64
  checks, full log `/tmp/gate4.log`, 20 VM subtests green); version
  facts grounded in `flake.lock` (fe132422 -> `stalwart_0_16`
  0.16.26) + the nixos-unstable registry (`stalwart_0_16` 0.16.27,
  `stalwart_1_0` 1.0.0) + the upstream releases API (v1.1.0 latest,
  0.16 line EOL at 0.16.27); the tracer-level regression source-settled
  from BOTH upstream tarballs (v0.16.26 + v1.0.3, `enums_impl.rs`
  level tables); the five text gates green; `readme-version-lockstep`
  green BOTH directions; aarch64 shape eval green (8 arch-neutral
  checks).
- NOT verified: the demo VM actually BOOTING 1.0.3 (boot attempted,
  aborted mid-provision - the README's "demo boots 1.0.3" claim is
  eval-derived, not runtime-proven); SystemNix's current lock rev and
  rebuild automation (fleet blast radius UNKNOWN - see question 1);
  the "Bulwark 1.20.0 deployed" pairing claim (inherited from
  TODO_LIST row 79, not re-verified against their repo); upstream
  1.1.0's change contents (only the tag date was read); GitHub CI on
  the flip commits (local gate only).

Context: the owner said "Update to latest stalwart! If you think
stalwart_1_0 is good enough, use it!" - this session executed that as
the default flip to the VENDORED 1.0.3 line (not nixpkgs 1.0.0, not
upstream 1.1.0), plus every doc/test/gate consequence. The 0.15.5
question that opened the session resolved as: 0.15.5 is the migration
dump leg only (`migrateFrom015.package`, assertion-capped `< 0.16`),
never the server.

## a) FULLY DONE

1. THE FLIP: `services.stalwart.package` default is now the vendored
   `pkgs/stalwart_1_0` 1.0.3 (`modules/mail-server.nix`), mkDefault so
   consumers can pin `stalwart_0_16` until migrated. Poison-class
   warning rewritten into the option comment.
2. Wrapper 1.x dialect now default-active (all `since1_0` branches):
   vendored 1.0.14 provision CLI (the pin's 1.0.13 cannot parse the 1.x
   schema), `implicitTls` listener keys, `host` relay key - all
   VM-proven by the full gate.
3. Relay e2e de-0.16-pinned: the eval asserts (route key) and the
   bounce metrics grep are dialect-aware, grounded in both dialects'
   transcripts.
4. Tracer-level regression FOUND and FIXED: 1.0.3's trc `level()`
   table dropped the explicit Info arms for `delivery.completed` /
   `delivery.dsn-success` (they default to Debug; 0.16.26 shipped both
   as Info), so an info-level tracer silently skipped those two fate
   lines. The wrapper now renders `level = "debug"` on 1.x; the
   include set stays the fate filter; all five trail lines print on
   1.0.3 (VM-proven). `provision-plan-eval` pins the dialect-aware
   level.
5. Migration runbook gap FOUND and FIXED (the rehearsal earned its
   name): the migrated Tracer row rides a NEW opaque id and 1.x reload
   validation enforces "Only one journal tracer is allowed" - the
   cutover plan apply could never succeed on a migrated wrapper store
   (every wrapper since the 2026-11-10 delivery-tracking ship). New
   `orphan purge` subtest in `stalwart-migrate-1x-e2e`: query Tracer,
   filter `Journal` rows, delete ids via `--stdin`; then the plan
   applies clean. Runbook documented in the README ledger.
6. Both migrate e2es now PIN their 0.16 seeding nodes explicitly
   (`services.stalwart.package = pkgs.stalwart_0_16`) so the flip
   cannot dissolve the migrations they test.
7. Docs sweep for the flip: README (status blockquote -> Stalwart
   **1.0.3**, check-list prose, ledger "Stalwart 1.x" section, trail
   level facts, pin-discipline version, demo-boot note), CHANGELOG
   (Changed entry incl. dialect keys, metric renames, tracer level,
   orphan purge), AGENTS conventions bullet, FEATURES trail row,
   TELEMETRY wiring item, TODO_LIST fleet-action row, flake.nix /
   checks.nix / stalwart-1-package.nix comments.
8. Verification battery: full gate EXIT:0; five text gates green;
   lockstep green both directions; aarch64 shape eval green.

## b) PARTIALLY DONE

1. Vendor train: vendored 1.0.3 is now the DEFAULT, but upstream
   shipped v1.1.0 on 2026-11-09 - the vendored line is one minor
   behind upstream latest, unbumped.
2. Demo smoke on 1.0.3: the demo VM boot was attempted and aborted
   mid-provision (deliberate kill - see d3); `scripts/demo-smoke.py`
   has NOT run against a 1.0.3 server. The README now states the demo
   boots 1.0.3 - true by eval, runtime-unproven.
3. SystemNix compat check: our nixpkgs pin stays fe132422 (0.16.26,
   while nixpkgs latest is 0.16.27). Whether SystemNix's lock has
   moved, and whether their hosts rebuild automatically, was NEVER
   checked - the session pivoted to the flip before completing this.
   This is the highest-stakes open item (see question 1).
4. TODO_LIST row 69(b) is now stale: it still frames vendored 1.0.3 as
   "watch upstream" with no note that 1.1.0 shipped; row 79's Bulwark
   floor note was satisfied but not annotated.
5. `stalwart-e2e-v1` disposition: kept as a byte-identical duplicate of
   the now-1.0.3 default battery (conscious no-churn call), but the
   REPURPOSE question (pin it to stalwart_0_16 so the OLD line keeps
   behavioral coverage during the migration window) is unresolved.
6. The pin's stalwart-cli 1.0.13 still lands on PATH for 1.x hosts
   (the vendored module's `systemPackages` line is since0_16, which is
   true for 1.x) - documented in the test comment, NOT fixed in the
   module and NOT yet in the ledger.

## c) NOT STARTED

1. The live fleet migration: pbx-artmann (and any host) still runs a
   0.16 store. Because SystemNix FLOATS this repo's master, the flip
   reaches the fleet at THEIR NEXT BUILD - a 1.x binary on that store
   is the poison class (panic). TODO_LIST row added, nothing executed.
2. Consumer-side x86-64-v2 CPU check for real hosts (documented
   requirement, no implementation; VMs are covered by v2CpuPatches).
3. Pin advance fe132422 -> SystemNix's current rev (0.16.27 + friends)
   - coordinated bump, untouched.
4. nixpkgs PR #552103 retirement watch + possible wholesale deletion
   of `pkgs/stalwart_1_0*` when the pin ships a 1.x module - unchanged.
5. GitHub CI observation for the flip commits (local gate green only;
   the cache-throttle class applies).
6. Upstream filing for the 1.0.3 tracer level regression (verify-before-
   filing gate: we now HAVE transcripts + source citations; decision
   pending).

## d) TOTALLY FUCKED UP (process honesty - outcomes were green, the process was not)

1. FIVE blind VM iterations to land the orphan-purge subtest (~30 min
   wall): a truncated `--help` read missed the `--stdin` requirement;
   the table header "Id" was eaten as an id; `tr -d " "` fused table
   cells; awk's single quotes collided with the outer `sh -c` quoting.
   The transcript-first raw dump arrived in iteration 3 - it should
   have been iteration 1, and `delete --help` should have been read in
   FULL (the `--stdin` flag was on screen, truncated by my own
   `head -8`).
2. Three self-inflicted broken edits, each costing a rebuild cycle:
   a nix comment inside a python string concatenation (parse break),
   the `relayRescheduleSeries` comment WITHOUT its binding (eval
   break - I wrote the prose and forgot the code), and the awk quoting
   collision. All were caught by gates, none reached master broken -
   but that is the gate working, not me.
3. The demo-VM boot was scope creep bought for a CLI-shape probe I
   then settled faster from source + test transcripts; killed it
   mid-provision.
4. Edited flake source TWICE while a gate was running (comment-only,
   derivation-identical - benign, but the discipline is: never).
5. One WRONG claim shipped in a commit and fixed forward this session:
   the checks.nix e2e-v1 comment claimed the twin "isolates a
   default-regression (a flip-back would fail stalwart-e2e here
   first)" - false: on a flip-back BOTH suites stay green. Rewritten
   to state the redundancy honestly.
6. Predictable red not pre-empted: the vendor-train notes LITERALLY
   predicted "dialect-fix iterations here when upstream renames
   provision keys". The relay e2e's 0.16-pinned literals (route key,
   metric name) should have been audited BEFORE the first gate run -
   the first red was avoidable.

## e) WHAT WE SHOULD IMPROVE

1. Default-change audit as a step ZERO: before flipping any module
   default, grep the whole test corpus for version-pinned literals
   (plan keys like `address`/`tlsImplicit`, metric series names,
   journal-line strings, `level = "info"` pins) and version-gate them
   in the SAME change. Codify in CONTRIBUTING.
2. Transcript-first discipline: any NEW shell probe in a VM test dumps
   its raw output to the log in iteration 1 (the round-3 lesson from
   the original migrate-1x session, re-learned the hard way).
3. Read tool surfaces COMPLETELY before scripting against them
   (full `--help`, the CLI's args parsing - `delete --stdin` was
   source-visible and help-visible).
4. Quoting doctrine for shell-in-python-in-nix: no single quotes
   inside `sh -c '...'`; double quotes for sed/awk bodies; codify in
   CONTRIBUTING "VM debug loops".
5. Never edit flake source while a gate is running.
6. Coverage honesty after a default flip: the 0.16 line lost ALL
   default-path behavioral coverage except the two migration seeding
   nodes - decide (question 2) whether the migration window needs a
   0.16 twin suite, and whether demo smoke becomes part of the flip
   checklist (it should).
7. Annotate the vendor-watch TODO row the moment upstream ships (the
   1.1.0 lag sat unnoticed in the row text).
8. Inherited claims stay flagged until re-verified (the Bulwark floor
   claim rode TODO prose into my CHANGELOG entry).

## f) Up to 50 things to get done next

Sorted by impact; `[ROADMAP]` items are brainstorm fuel for
docs-health HARVEST routing, not commitments. (1-6 are the
migration-critical cluster.)

1. `[NOW]` Decide the fleet hold vs proceed (question 1) and act on
   it BEFORE any fleet host rebuilds onto the poison boundary.
2. `[NOW]` Read SystemNix's flake.lock + rebuild automation (timer vs
   manual) to ground that decision.
3. `[NOW]` Execute the 0.16 -> 1.0 migration on pbx-artmann per the
   README runbook (stalwart-migrate v1.0.6, orphan purge, plan apply).
4. `[NOW]` Post-migration verification on pbx: needle round-trip,
   delivery-trail lines, Bulwark webmail login.
5. `[NOW]` Observe GitHub CI on the flip commits (`gh run view
   --log-failed`; grep the WHOLE failed log before any rerun).
6. `[NOW]` Demo smoke on 1.0.3 (`nix run .#vm` +
   `scripts/demo-smoke.py`), transcript under
   `docs/probes/2026-11-16-demo-smoke-103/`.
7. `[SOON]` Vendor bump 1.0.3 -> upstream 1.1.0 (3 prefetch hashes +
   cargoHash/npmDepsHash rounds + stalwart-e2e(-v1) + migrate-1x
   reruns; read SCHEMA_CHANGES for 1.1 deltas first).
8. `[SOON]` Check whether 1.1.0 pairs newer webui / spam-filter / cli
   / migrate components and bump the whole vendored train together.
9. `[SOON]` Repurpose `stalwart-e2e-v1` to pin `stalwart_0_16` during
   the migration window (two-site edit: checks.nix + README list) or
   consciously retire it.
10. `[SOON]` Add the CLI-1.0.13-on-PATH trap to the README ledger as a
    1.x gotcha (manual CLI work must use `packages.stalwart-cli-1_0`).
11. `[SOON]` Fix or consciously accept the vendored-module
    `systemPackages` line adding the pin's 1.0.13 CLI on 1.x hosts
    (wrapper override vs documented seam vs VENDOR PATCH).
12. `[SOON]` Sweep docs for residual "default stays 0.16" /
    "NOT deployed" phrasing (TODO_LIST rows, ROADMAP, ADRs, drafts).
13. `[SOON]` ADR `stalwart-pin-vs-overlay` (C45, proposed): superseded
    by the flip - annotate and close or flip its status in the
    exporter data.
14. `[SOON]` Update TODO row 69(b): 1.1.0 shipped 2026-11-09; attach
    this session's bump procedure notes (metric renames, level table).
15. `[SOON]` Update TODO row 79: Bulwark pairing verified-for-flip
    (after re-checking their deployed version).
16. `[SOON]` Harvest this report's (f) list into TODO_LIST/ROADMAP per
    docs-health HARVEST routing.
17. `[SOON]` Re-run `buildflow` once on the tree (skipped this session;
    the lint fleet adds value the gate does not).
18. `[ROADMAP]` Pin advance fe132422 -> SystemNix's current lock
    (picks up 0.16.27 as the migration line + nixpkgs updates), per
    the runbook, both repos together.
19. `[ROADMAP]` After that advance: if the pin ships `stalwart_1_0`
    WITH a module, evaluate deleting the vendored dir + re-pointing.
20. `[ROADMAP]` Track nixpkgs #552103; retire `modules/stalwart-module`
    per its in-file checklist when it merges into the pinned rev.
21. `[ROADMAP]` File the 1.0.3 tracer level regression upstream
    (verify-before-filing + github-voice; victims + transcripts exist:
    the level() tables at both tags + the relay-e2e journal
    transcripts).
22. `[ROADMAP]` JMAP/CardDAV/CalDAV transcript re-baselining on 1.0.3
    (the 0.16.22-era JMAP claims are transcript-pinned to the old
    line; the flip changes their "deployed" framing).
23. `[ROADMAP]` Re-export the EventCatalog tree after the flip settles
    (idempotent exporter; hub version lockstep 1.0.0 unaffected).
24. `[ROADMAP]` CONTRIBUTING: add the default-change audit checklist
    (item e1) as a section.
25. `[ROADMAP]` CONTRIBUTING VM debug loops: codify the quoting +
    transcript-first rules (items e2/e4).
26. `[ROADMAP]` Release procedure: cut the version tag for the flip
    (CHANGELOG [Unreleased] -> release; owner timing).
27. `[ROADMAP]` FEATURES: add a "Stalwart 1.x default" surface row
    after the demo smoke lands.
28. `[ROADMAP]` TELEMETRY: sweep series-name framing - the 1.x
    `stalwart_*_total` prefix family belongs in its fact set now.
29. `[ROADMAP]` Consider an eval check pinning the ledger's
    "default is 1.0.3" claim (lockstep covers the blockquote only).
30. `[ROADMAP]` parsedmarc-e2e / deliverability-e2e co-verified 1.0.3
    in this gate - annotate FEATURES rows with the co-verification.
31. `[ROADMAP]` Watch stalwartlabs/stalwart-migrate for > v1.0.6
    (answers.toml schema stability is the rehearsal's pty contract).
32. `[ROADMAP]` Upstream watch row (nixpkgs #563651/#563652/#563777,
    #552103) - standing, re-check dates.
33. `[ROADMAP]` Consumer-side x86-64-v2 CPU check for real hosts
    (implementation shape TBD; the VM assertion approach is proven
    impossible).
34. `[ROADMAP]` Consider marking the v1 store's migrated Log tracer in
    the runbook as keep-but-note (operator guidance for hosts that
    provisioned custom Log/Otel tracers).
35. `[ROADMAP]` Flatten the migrate-1x header comment to include the
    CLI-absolute-path rationale (currently split between header and
    subtest).
36. `[ROADMAP]` scripts/check-md-anchors: the new ledger bullet added
    no heading - fine; keep the anchor check in the flip checklist.
37. `[ROADMAP]` Consider `git town sync` stash-ritual caution for the
    next session opening (the daemon pushed several heuristic commits
    this session; verify no stash residue at next resume).
38. `[ROADMAP]` TODO_LIST fleet row: attach the exact runbook command
    sequence (extract - prepare - run --final - marker - purge - plan)
    so the operator does not re-derive it.
39. `[ROADMAP]` Demo VM: confirm the 1.0.3 default boots clean after
    the aborted boot left state in ~/.cache/nix-email-demo (wipe or
    verify).
40. `[ROADMAP]` Keep the deprecated-alias-lint selftest green on the
    next buildflow pass (the flip removed the last bare-`pkgs.stalwart`
    default comment reference; nothing to do unless red).

## g) Questions I can NOT figure out myself

1. FLEET BLAST RADIUS: SystemNix floats this repo's master, so the
   flip reaches fleet hosts at their next rebuild. Do the fleet hosts
   rebuild AUTOMATICALLY (timer/cron), and do you want a consumer-side
   hold (`services.stalwart.package = pkgs.stalwart_0_16` in
   SystemNix) shipped BEFORE the migration, or is a manual rebuild
   window guaranteed so the migration can happen first?
2. E2E-V1 DISPOSITION during the migration window: keep it as a
   redundant 1.0.3 twin, or re-point it to pin `stalwart_0_16` so the
   OLD line keeps full behavioral coverage until every host has
   migrated?
3. VENDOR TRAIN: bump the vendored line 1.0.3 -> upstream 1.1.0 now
   (new hashes + e2e reruns, one more moving part), or freeze at 1.0.3
   until the live pbx migration has landed?
