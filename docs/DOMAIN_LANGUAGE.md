# Domain Language

First draft 2026-10-31 (Ω-plan task E6; the "terms stabilize post-v0.5.0"
precondition is met - v0.5.0 shipped 2026-10-28). This file holds the
LANGUAGE of the mail stack: what each term MEANS and which document owns
the FACTS. The README "Verified-facts ledger" remains the single source
of truth for behavior; entries here point at it and never restate
transcript detail.

Bounded contexts: the wrapper and its fleet (consumption), the Stalwart
provisioning plan dialect (the core model), outbound delivery, inbound
protection, DMARC monitoring, and the store lifecycle.

## The wrapper and the fleet

- **Wrapper** - this flake's two NixOS modules, `services.mail-server`
  (the Stalwart 0.16 mail stack) and `services.dmarc-monitor`
  (parsedmarc). Defaults are `mkDefault`; consumers override through
  `services.stalwart.settings` / `services.parsedmarc.settings`. The
  name `services.stalwart-mail` is FORBIDDEN (nixpkgs rename-alias
  collision - see AGENTS.md Conventions).
- **Consumer** - a flake that imports this one. The only production
  consumer is SystemNix (the fleet host). Consumers layer their own
  sops secrets, ports, Gatus checks, and backups; those belong to the
  consumer, never here (AGENTS.md "SystemNix layers").
- **Upstream-flake pattern** - SystemNix floats this repo's `master`
  input (`nixpkgs.follows`), so a commit here reaches the fleet at
  THEIR next build; the operative compat contract is the follow, not a
  hard pin.
- **Pin / lock rev** - the `nixpkgs` input rev in `flake.lock`
  (currently `fe132422`, 2026-10-28), which decides which stalwart and
  parsedmarc versions actually run. Every "pinned version" claim must
  be grounded in the lock, never the registry (`nix eval
  github:NixOS/nixpkgs/<rev>#stalwart_0_16.version`).
- **Vendored module** - `modules/stalwart-module/`, the nixpkgs
  Stalwart 0.16 provisioning module copied in-tree while upstream PR
  #552103 is open. Retires (with a checklist in its header) when the PR
  merges into the pinned rev.
- **Datastore descriptor** - `services.stalwart.settings`, the rendered
  `config.json`: ONLY the store backend descriptor on 0.16. It is NOT a
  general config surface - listener/provisioning intent goes through
  the wrapper options and the plan, and static `server.listener` keys
  are silently ignored by the 0.16 binary (README ledger).

## Provisioning and the plan dialect

The core model: the desired state of Stalwart's store is a LIST of
JSON operations applied sequentially by `stalwart-cli apply`.

- **Plan** - that op list. The wrapper renders it from
  `services.stalwart.provision` (merged wrapper + consumer sets);
  `provision-plan-eval` pins its shape.
- **Operation (op)** - one plan entry. Verbs: `update` (patch an
  existing object), `upsert` (patch-or-create), `reconcile` (make the
  set EXACTLY the listed objects - deletes unlisted rows). Ops apply
  SEQUENTIALLY.
- **Singleton** - an entry under `provision.singletons`: one object per
  class, applied as an `update` op (e.g. `MtaOutboundStrategy`,
  `Metrics`). Has no set semantics of its own.
- **Reconcile set** - an entry under `provision.objects` with
  `reconcile = true` (wrapper-owned today: `NetworkListener`,
  `SpamDnsblServer`, plus the idempotence postures an opt into). Only a
  reconciled declarative set converges when upstream adds default rows
  (the 0.16.22 broken-DNSBL lesson; 0.16.24 made upstream rule updates
  insert-only for existing installs).
- **Match property (`matchOn`)** - the fields an upsert matches an
  existing row by. An upsert patching an existing object MUST carry its
  match property (`name` for Domain; Account match keys must be
  explicit because value-matching breaks once secrets are hashed). The
  one exception class: `MtaInboundThrottle` has no `name` - its match
  key is `description`.
- **Scope** - an optional partial object value restricting which rows a
  reconcile may DELETE. The guarded form of any destructive retirement
  (see "reconcile-destroy pattern").
- **Object id / `#id` reference** - set entries are keyed by id; other
  plan positions reference them as `#id`. References resolve ONLY
  against EARLIER ops in the SAME plan.
- **Provision-before-probe** - ordering doctrine: any SMTP probe
  against a domain that is not yet provisioned poisons the directory
  negative cache and routes that domain to MX instead of local
  (`directoryCacheTtlNegative` is the TTL knob). Catch-alls must land
  AFTER unknown-recipient probes (they make every local part
  deliverable and silently disable 5xx rejection for the domain).
- **Catch-all** - `Domain.catchAllAddress` pointing at an ACCOUNT's
  email address (the 0.16 object model; the 0.15 `"@<domain>"`
  principal shape is dead).
- **Quota** - `quotas.maxDiskQuota` (bytes) on the User object. Per-
  account data, deliberately not a wrapper option. Over-quota mail is
  SMTP-ACCEPTED but never delivered.
- **Synthesized address** - the wrapper builds account email addresses
  from local part + the provisioned domain; IMAP/JMAP login keys on the
  SYNTHESIZED address, not the principal name (0.16 schema).
- **Journal silence** - the 0.16 default-verbosity behavior where the
  journal prints nothing per-message (quota/retry/reschedule lines from
  0.15 are gone). Consequences: delivery-absence assertions are
  IMAP-absence + journal-silence, never SMTP refusal or journal grep.

## Outbound delivery

- **Direct-to-MX** - the default outbound posture (`relay = null`):
  Stalwart delivers via DNS MX itself.
- **Smarthost / relay** - an authenticated submission target
  (Resend in the fleet design) that takes every non-local message.
  Wrapper shape: `services.mail-server.relay`.
- **MtaRoute** - the store row describing a relay target (Relay
  variant: address, port, TLS mode, optional SASL secret by File
  reference).
- **Route expression / MtaOutboundStrategy** - the singleton deciding
  per-message routing: `is_local_domain -> 'local'`, else the relay's
  route id (or `'mx'` when direct-to-MX). The 0.16 replacement of the
  0.15 `queue.route`/`queue.strategy.route` TOML pair.
- **Reconcile-destroy pattern** - retiring a wrapper option (e.g.
  `relay = null`) stops EMITTING its derived objects but does NOT
  retire the store rows (the plan is upsert-only per set). Remedy: a
  one-shot, scope-pinned empty reconciled set on the affected class
  (documented beside the `relay` option, mail-server.nix header).
  Blanket reconcile on a consumer-extensible class is forbidden - it
  would destroy consumer-declared rows.

## Inbound protection

- **DNSBL** - DNS blocklist checks on the inbound SMTP connection.
  OFF by default in the wrapper (posture, not omission);
  `spamFilter.dnsbl` reconciles the (empty-by-default) server set.
- **Rate limiter / MtaInboundThrottle** - a Stalwart throttle row; the
  wrapper's `rateLimits` renders one with key vocabulary like
  `authenticated_as` and matches on `description` (it has no `name`).
  Hardening defaults stay OFF by design.
- **Deliverability probe** - the wrapper's continuous self-check
  (`deliverabilityChecks` + the bundled probe binary): transport/TLS
  health on 25/465/587/993, DNS posture, DNSBL listing - textfile
  metrics for the consumer's scrape.

## DMARC monitoring

- **Aggregate report / ARF** - the feedback-report format mailbox
  providers send describing DMARC outcomes for a domain; parsedmarc
  ingests them.
- **parsedmarc / dmarc-monitor** - the report processor; the wrapper's
  second module (`services.dmarc-monitor`) runs it against the local
  IMAP mailbox that collects reports (localMail).
- **localMail** - the postfix maildir the monitor watches; the wrapper
  pre-creates it at BOOT via tmpfiles (a systemd `ReadWritePaths` `-`
  prefix is evaluated once at namespace setup and a later-created path
  never becomes writable - AGENTS.md Working rules).

## Store lifecycle

- **Store object** - a row in Stalwart's embedded store, as opposed to
  a **plan object** (a JSON entry in an apply op). Plans shape store
  objects; stopping the shaping never deletes them (hence the
  reconcile-destroy pattern).
- **Store boundary / poison class** - the 0.15 -> 0.16 store format
  break: a 0.16 binary PANICS on a pre-0.16 store AND poisons the
  settings subspace for 0.15.5 before dying. The unit guard
  (default.nix) and the migration script's preflight are the hard
  boundary; recovery mode runs on
  `STALWART_RECOVERY_MODE_PORT` (never assume 8080).
- **Snapshot-derived plan** - `stalwart-cli snapshot` output: id-keyed
  upserts WITHOUT Account matchOn. A known, accepted divergence from
  the wrapper's `match = ["name"]` plans (both work; do not "fix"
  either toward the other - README ledger).
