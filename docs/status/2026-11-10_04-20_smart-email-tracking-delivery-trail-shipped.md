# 2026-11-10 ~02:00-04:20 - smart email tracking: per-message delivery trail shipped, gate green

- **Verdict**: SHIPPED. `services.mail-server.deliveryTracking.enable`
  (default ON) always reconciles ONE Journal Tracer scoped to the
  per-message fate events; `provision-plan-eval` + `stalwart-relay-e2e`
  (new delivery-trail subtest) + `stalwart-e2e` (quota re-pin) all GREEN;
  full `nix flake check` green (see gate note below).
- **What "smart E-mail tracking" became**: per-message delivery-fate
  tracking (accepted -> delivered | deferred | DSN | perm-reject |
  local-ingest), NOT recipient open/click tracking (privacy-hostile,
  rejected without discussion) and not synthetic canary (already shipped
  2026-10-30 as deliverabilityChecks).
- **Root cause found (source-proven at the pin)**: 0.16 release builds
  ship NO default tracer - `telemetry.rs Tracers::parse` populates
  global event interests ONLY from provisioned Tracers/WebHooks/enterprise
  StoreTracers; zero provisioned = the stream drops wholesale. This
  retro-explains the 2026-10-17 quota journal-silence probe AND kills the
  "0.16 changed levels" hypothesis (level tables 0.16.22 vs 0.16.26 are
  IDENTICAL, all lifecycle events default `Info` - diffed both tags).
- **Mechanism facts worth keeping** (all in README ledger / TELEMETRY §8
  item 0 / code comments - do not restate):
  - `x:Tracer` has NO label property -> a matchOn-less `reconcile` is
    REFUSED by the plan CLI ("has no match key"); the wrapper uses
    `match = "*"` (scalar-value matching; the `events` SET patches in
    place on drift) with scope `@type = Journal` (owns the one-allowed
    Journal slot; consumer Log/Otel tracers survive the leak pass).
  - journald DROPS the tracer's mixed-case journal fields (`queueId`
    et al.) - host-proven with a live socket probe; the trail is
    description lines ONLY, correlation chronological.
  - The 0.16 provision-object contract is `resources/schema/schema.json.gz`
    IN THE SOURCE TARBALL (the lua sorter validates plans against it) -
    read it straight from `stalwart_0_16.src` for any future object work.
  - `stalwart-cli apply` semantics live in the SCHEMA-DRIVEN CLI source
    (vendored `pkgs/stalwart-cli-1_0`, upstream `stalwartlabs/cli`) -
    `find_match`/`upsert_core`/`leaked_ids` answer every idempotency
    question without a VM.
- **The over-quota ledger gap CLOSED**: with the tracer, the queue emits
  `Message rescheduled for delivery` for over-quota mail (ingest fails ->
  temp-fail -> retry). The stalwart-e2e quota subtest re-pinned
  POSITIVELY on the line; the 2026-10-17 silence contract is superseded
  everywhere it is stated (README ledger quota bullet, MONITORING rows
  2-3, AGENTS doctrine line, the subtest itself).
- **Transcript-pinned fate lines** (relay-e2e + stalwart-e2e, 2026-11-10):
  relay path queued -> delivered -> DSN -> completed; deferral -> drain
  via `Message rescheduled for delivery`; local ingest via `Message
  ingested`; over-quota via the reschedule line.
- **Nearly-fatal parse gotcha (Nix)**: `mkConfig {..}.config.services...
  or null` does NOT call mkConfig on the attrset and then select - the
  WHOLE `.config.services...or null` chain is consumed as the ARGUMENT's
  attrpath (application argument = one expr_select). Symptom: the value
  silently degrades to the `or` default instead of erroring. Fix: wrap
  the application in parens. Hit once in provision-plan-eval
  (trackingOff), caught by the new assertion.
- **Superseded claims swept** (all six places): README ledger quota
  bullet; MONITORING row 2 (delivery trail + row 3 detection UPDATE);
  TELEMETRY §8 new item 0; AGENTS 0.16-doctrine line; FEATURES new row;
  ROADMAP theme 1 raw idea refined; CHANGELOG Added entry; TODO_LIST
  optional SystemNix trail-alerts row.
- **Rejected by design** (do not "fix" later): the tracer include-set
  stays fate-focused - attempt-level diagnostics (mx/connect/ehlo/auth
  chatter) deliberately excluded from defaults; promote via provision if
  a consumer wants them.
- **Next** (all optional, owner): SystemNix trail-based log alert rules
  (TODO_LIST row); InboxClean could surface the trail via JMAP/journal
  read (ROADMAP-adjacent idea, not filed).
- **Gate note**: full `nix flake check` re-run of THIS session's final
  tree - result recorded in the session close; individual check builds
  (provision-plan-eval, stalwart-relay-e2e, stalwart-e2e) were green
  BEFORE the gate (each edited check built first, per doctrine).
