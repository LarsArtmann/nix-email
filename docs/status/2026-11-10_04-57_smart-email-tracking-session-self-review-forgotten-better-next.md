# 2026-11-10 04:57 - smart email tracking session: full self-review - forgotten, better, next

- **Session scope**: one feature request ("We should have smart E-mail
  tracking"), interpreted as per-message delivery-fate tracking (NOT
  recipient open/click tracking - rejected on privacy posture; NOT the
  synthetic canary, which shipped 2026-10-30). Researched at the pin,
  implemented, transcript-pinned, documented, gated.
- **Tree state at report time**: everything committed by the daemon
  (batches c3fec70..315b616) EXCEPT this report (untracked; daemon's
  cadence). Full `nix flake check` EXIT:0 twice - the second run on the
  FINAL tree (all checks passed, incl. stalwart-e2e-v1, deliverability,
  parsedmarc, bind, both migrate tests; relay-e2e/stalwart-e2e green on
  explicit runs immediately before). `nix fmt -- . --check` green; pipe/
  list/anchor lints green over every touched markdown.

## a) FULLY DONE

1. **Root-cause research (source-level, at the exact pin fe132422 = 0.16.26)**:
   0.16 release builds ship NO default tracer - `Tracers::parse` builds
   global event interests ONLY from provisioned Tracers/WebHooks/
   enterprise StoreTracers; zero provisioned = the event stream drops
   before any subscriber. This retro-explains the 2026-10-17 quota
   journal-silence probe. Level tables diffed across BOTH tags
   (0.16.22 vs 0.16.26): IDENTICAL - every `delivery.*`/`queue.*`/
   `message-ingest.*` lifecycle event is default `Info`.
2. **Provision-object contract extracted from the binary's own schema**
   (`resources/schema/schema.json.gz` in the source tarball - the same
   file the lua sorter validates against): `x:Tracer` variants,
   `TracerCommon` fields + defaults, `x:EventTracingLevel`, all 637
   EventType names, `EventPolicy` include/exclude.
3. **CLI apply semantics read at source** (vendored `pkgs/stalwart-cli-1_0`
   -> upstream `stalwartlabs/cli`): `resolve_match_key` (x:Tracer has NO
   label property -> matchOn-less reconcile is REFUSED),
   `find_match` (match "*" = comparable-scalar matching; the `events`
   SET patches in place on drift), `leaked_ids` (scope-filtered
   destroy). Plan shape: reconcile + match "*" + scope `@type=Journal`.
4. **Feature implemented**: `services.mail-server.deliveryTracking.enable`
   (default ON) + the ALWAYS-rendered Tracer op (enable rides the
   option; disable = provisioned-but-disabled, never stranded).
   modules/mail-server.nix:441 (option), :1252 (op, with the full
   rationale comment).
5. **Eval contract extended**: provision-plan-eval pins the op shape
   (reconcile + "*" + Journal scope + the 22-event fate set) AND the
   disabled-still-rendered posture. Green.
6. **VM transcripts captured, then assertions pinned** (no assertion
   without a transcript): relay-e2e delivery-trail subtest (queued ->
   delivered -> DSN -> completed; deferral -> `Message rescheduled for
   delivery` -> drain; both `-u stalwart` and `-t stalwart` filters) -
   GREEN. stalwart-e2e quota subtest RE-PINNED POSITIVELY on the
   over-quota reschedule line (the 2026-10-17 silence contract
   superseded) - GREEN.
7. **journald field-drop proven empirically** (host socket probe):
   journald drops the tracer's mixed-case journal fields (`queueId`
   et al. only `[A-Z0-9_]` names persist) - the trail is description
   lines only; the WRONG `-o json` fields claim was caught and removed
   from the option description BEFORE any doc shipped it.
8. **Docs sweep (9 files)**: README ledger quota bullet
   (root-caused, not deleted - history kept + new verdict) + new
   front-door "Delivery tracking" section; MONITORING rows 2-3;
   TELEMETRY §8 new item 0; FEATURES row; TODO_LIST optional
   SystemNix row; ROADMAP theme 1 refined; CHANGELOG Added entry;
   AGENTS 0.16-doctrine line fixed; this report.
9. **Gates**: full `nix flake check` EXIT:0 twice (second on the final
   tree); `nix fmt -- . --check` green after every .nix/doc touch; md
   pipe/list/anchor lints green on all touched files.

## b) PARTIALLY DONE

1. **1.x trail verification**: the Tracer op APPLIES on the vendored
   1.0.3 (stalwart-e2e-v1 green inside the gate), but NO subtest asserts
   fate lines on 1.x - the trail content there is unproven (likely
   identical code family; the 1.x schema's EventType names for the
   include set are unverified - a rename would silently narrow the
   trail on a future 1.x flip).
2. **Drift-healing**: the "events SET patches in place, no duplicate
   Journal tracer" claim is source-proven (find_match/upsert_core/
   leaked_ids) but never VM-transcribed. If wrong, a wrapper bump
   changing the set creates a transient duplicate -> "Only one journal
   tracer is allowed" -> next reload aborts (the leak pass destroys the
   straggler in the SAME apply, so the window is one apply - still,
   unproven).
3. **journald field-drop evidence**: host-proven only; no VM `-o json`
   transcript, and the probe transcript is NOT archived under
   docs/probes/ (the README/TELEMETRY citations say "host-proven
   2026-11-10" - the receipts live in this session's shell log only).
4. **Trail volume/retention posture**: not measured (lines per message
   unknown beyond ~2-5 from transcripts), journald RateLimitBurst
   interaction unexamined, journald persistence (Storage=) never
   mentioned in the runbook. The M14 flood subtest passed WITH the
   tracer active (functional proof), but volume/limits are unstated.
5. **enable=false runtime**: eval-pinned only; no VM subtest asserts the
   trail lines disappear (source-obvious, untranscribed).

## c) NOT STARTED

1. THREAT_MODEL.md delta (journal now carries per-message mail-flow
   metadata; exposure = anyone with journal read; retention = journald
   policy).
2. docs/probes/ transcript archive for the host journald probe.
3. Trail-based log alert rules spec text in MONITORING section 8
   (the TODO row exists; the copy-paste spec text does not).
4. ROADMAP raw idea: InboxClean surfacing the trail (JMAP/journal
   read) - considered, not filed.
5. Webhook-tracer SIEM fan-out idea - not filed anywhere.
6. lessons.md commit in the crush-config repo for the general Nix
   expr_select-application gotcha (by policy needs a commit THERE, not
   an in-session write).
7. Upstream filings (see f-13/f-14) - assessment only, nothing filed.

## d) TOTALLY FUCKED UP

Nothing reached master broken; ALL of the following were caught and
fixed in-session - listed because the misses were real:

1. **Repeated a DOCUMENTED trap**: `rg -rln`/`rg -rn` is a replace
   expression, not recursive-line-number (AGENTS.md spells it out; the
   hook message says "third strike of this exact trap on this host").
   I hit the hook TWICE this session. On a repo whose AGENTS names the
   trap, zero hits was the bar.
2. **Shipped a wrong wire-claim in the option description** (`-o json`
   structured journal fields): caught by my own host probe minutes
   later and rewritten - but the first version would have been a
   textbook "wire-claim without transcript" had I moved on. The
   claim-then-verify order was backwards once.
3. **The Nix application/expr_select parse gotcha**:
   `mkConfig {..}.config.services...or null` consumes the WHOLE chain
   as the argument's attrpath, so `trackingOff` silently degraded to a
   wrong value and my first assertion fired against my own bug. Caught
   by the eval test itself within one build; parens fix; report carries
   the lesson.
4. **Schema misread**: first sourcegraph output truncated the variant
   list and I briefly concluded the Journal tracer variant did not
   exist in the schema; the full enum dump corrected it before any code
   was written.
5. **AGENTS.md double-paren** introduced in the doctrine-line edit -
   caught on the immediate re-read.
6. **Interpretation risk (the big one, unfalsifiable in-session)**:
   "smart E-mail tracking" was ambiguous (fate trail vs alias-leak
   tracing vs read receipts). I committed to the fate trail on repo
   evidence (ROADMAP queue-observability gap + ledger pain points) and
   stated the rejection of open/click tracking - but the owner never
   confirmed the interpretation. See g-1.

## e) WHAT WE SHOULD IMPROVE

1. **Archive evidence at capture time**: the host journald probe proved
   a load-bearing claim and its transcript lives nowhere durable.
   Next experiment under docs/probes/<date>/ by default.
2. **VM-verify drift paths, not just first-apply paths**: idempotency
   and drift-healing are where provision features actually break
   (version-bump class). A drift subtest is cheap on the existing VMs.
3. **Pin claims at the narrowest layer first**: the host journald probe
   (seconds) settled what would otherwise have been a guessed field
   name in a 5-minute VM loop. Keep reaching for the host-side
   equivalent first.
4. **Wire-claims: write the doc AFTER the probe lands**, not before
   (see d-2; the option description was rewritten once already).
5. **Trap discipline**: document-checked traps (rg -r) need a personal
   pre-flight, not just host hooks.
6. **Feature default posture**: ON-by-default for observability is a
   different class than the hardening-OFF posture (rateLimits/dnsbl) -
   the README section says why, but fleet volume is unmeasured; the
   owner should see g-2 before the next pbx switch.

## f) UP TO 50 NEXT THINGS (session-discovered first, then noticed-existing)

Session-discovered (this feature's tail):

1. Archive the host journald camelCase-drop probe transcript under
   docs/probes/2026-11-10-journald-field-drop/ (the README/TELEMETRY
   citations need receipts).
2. relay-e2e trail subtest: add the `-o json` dump + assert the ABSENCE
   of queueId/QUEUE_ID fields (VM-level proof of d/b-3).
3. Drift-heal VM subtest: re-apply with a CHANGED events set -> assert
   update-in-place, exactly one Journal tracer, reload healthy.
4. stalwart-e2e-v1: trail subtest on the vendored 1.0.3 (apply is
   proven; the fate lines are not).
5. Diff the 1.0.3 server schema.json.gz EventType names against the
   include set (future-proof the wrapper before any 1.x default flip).
6. deliveryTracking.enable=false VM subtest (trail lines absent).
7. Measure trail volume (lines/message) and document it + the journald
   RateLimitBurst interplay in the README section.
8. Go-live runbook: journald Storage=persistent vs volatile posture
   note (see g-3).
9. THREAT_MODEL.md: journal metadata exposure + retention delta.
10. Wrapper option `deliveryTracking.extraEvents` (consumer extension
    without hand-merging provision objects).
11. Pre-provisioned DISABLED debug tracer (TELEMETRY §3.1's own
    recommended incident pattern) as an opt-in.
12. MONITORING section 8: copy-paste trail-based log-rule spec (the
    TODO_LIST row points at their repo; the spec text should exist HERE).
13. Upstream filing assessment: stalwart journald tracer emits camelCase
    field names that journald silently drops (every Linux deployment
    affected; verify-before-filing gate: demo-VM transcript already
    exists - this one is close to fileable).
14. Upstream filing assessment: release builds ship no default tracer ->
    silently dead event stream (docs/UX bug; the webadmin form default
    contradicts the runtime).
15. pbx-artmann: verify the trail on a real host after their next
    switch (transcript back to docs/probes/).
16. 24h journal-volume datapoint on a real host (feeds g-2).
17. docs/probes/README: verdict index entry for the new probe dir.
18. crush-config repo: commit the Nix expr_select-application gotcha to
    references/lessons.md (cross-project lesson, by commit).
19. ROADMAP: file the InboxClean trail-surfacing raw idea.
20. ROADMAP: file the webhook-tracer SIEM fan-out raw idea.
21. Considered-reject note in the option description or FEATURES: a
    `deliveryTracking.level` option (YAGNI until a consumer asks).
22. Run scripts/selftest-docs-gates.sh once over the session's docs
    (individual lints ran; the combined selftest did not).
23. Release train: this feature plus the vendor train is v0.6.0
    material (CONTRIBUTING procedure; owner trigger).

Noticed-existing (open rows I touched or read during this session):

24. C42 parsedmarc retire-or-keep owner verdict (BLOCKED: owner).
25. C44 real-host account-secrets doctrine (BLOCKED: C44 decision).
26. C39 MemoryMax policy decision (BLOCKED: owner).
27. dmarc-monitor live validation against a real IMAP mailbox (D1).
28. SystemNix deliverability-alert wiring (their repo; one onFailure
    entry + scrape + Gatus specs ready to paste).
29. SystemNix CI-debt residue (their repo).
30. pbx-artmann stalwart-host-wiring flip (owner blessing + one VM run).
31. Resend SASL shape smoke (needs API key).
32. Vendored stalwart-module package-default owner call (upstream-copy
    fidelity vs correctness for raw-module consumers).
33. Branch-protection bypass policy call (C18).
34. Renovate install-or-drop (C19).
35. GitHub Discussions enable-or-keep (C22).
36. demo.qcow2 blob purge verdict (history rewrite; BLOCKED user).
37. EventCatalog hub build pipeline dead since 2026-10-28 (evo-x2
    owner; run-queue + runner unit read).
38. Webmail/Bulwark release-train watch (trigger: nixpkgs #574920).
39. Migration tooling compare: stalwart-vandelay vs imapsync (D1).
40. Secret rotation in SystemNix nix-email.yaml (D1).
41. Flood-subtest posture owner call (strict vs relax; capture-first
    is mechanized since 2026-10-26).
42. CI python-lint gate: bandit/vulture scope doctrine (owner).
43. D1/D2 the two big owner decisions gating ROADMAP themes.
44. Backup/DR VM proof reconciliation on OUR pin (ROADMAP raw idea).
45. Upstream watch: nixpkgs PR #552103 (module) merge -> retirement
    checklist for the vendored copy.
46. Upstream watch: nixpkgs #563651/#563652/#563777 + mailsuite#65.
47. Pin-advance runbook: contacts probe set re-arms at the NEXT
    stalwart bump (17/18 PASS baseline).
48. parsedmarc mailsuite fixture-drift watch (nixpkgs #566282 bump).
49. Docs-health pass: after the daemon sweeps, verify this corridor
    report + the new README section survive a formatter pass and the
    anchors stay green.
50. Next session's baseline ritual items for THIS feature: re-read the
    README "Delivery tracking" section + TELEMETRY §8 item 0 before
    touching provision rendering again (the shape is pinned in three
    places; keep them in sync or collapse to one).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **Was "smart E-mail tracking" the per-message fate trail?** My
   evidence (ROADMAP queue-observability gap, the ledger's
   journal-silence pain) points there, and I rejected recipient
   open/click tracking on privacy posture - but if you meant
   alias-leak tracing (per-service subaddressed identities + spam
   attribution) or InboxClean-side read/state tracking, the follow-up
   work list changes materially (f-19 vs a new feature).
2. **Fleet posture**: keep the tracer default ON for the deployed hosts
   (pbx-artmann etc.) at their next switch - accepting ~2-5 journal
   lines per message unmeasured - or flip it OFF there until f-16's
   volume datapoint lands?
3. **Retention**: should the trail survive reboots (consumer-side
   journald Storage=persistent as a go-live runbook requirement), or is
   per-boot volatile acceptable for incident forensics?
