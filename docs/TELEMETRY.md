# Stalwart Telemetry — The Right Way

How to run Stalwart's telemetry stack properly: what exists, how the pieces
fit together, and a recommended baseline that avoids the known footguns.

> **Provenance.** Written 2026-09-15 from the official docs at
> https://stalw.art/docs/telemetry/ (all subpages) against the then-pinned
> Stalwart 0.15.5; the repo has run 0.16.x since 2026-10-17 and the pin
> (fe132422) ships **0.16.26**.
>
> **OPERATIVE TRUTH - VERDICT 2026-10-31 (0.16.26 binary + live dump,
> plan task D8; supersedes every earlier caveat in this doc):**
>
> 1. The whole object model is binary-verified present in the pinned
>    0.16.26 (`strings` over the pinned
>    `stalwart-0.16.26/bin/stalwart`): `WebhookTracer`,
>    `EventTracingLevel`, `TracingStore`, `MetricsStore`,
>    `DataRetention`, `telemetry.webhook-error`, `telemetry.alert`,
>    `spawn_webhook_tracer`, `prometheus`, `authUsername`/`authSecret`,
>    `eventsPolicy`, `holdTracesFor`/`holdMetricsFor`,
>    `metricsCollectionInterval`. Webhook/alert FIELDS moved to
>    camelCase on 0.16 (`signatureKey`, `discardAfter`,
>    `allowInvalidCerts`, `httpAuth`, `enableSpanExporter`); the
>    0.15-era kebab-case tokens (`signature-key`/`discard-after`) are
>    GONE, and the "An alert was triggered" runtime string is gone
>    (`telemetry.alert` remains).
> 2. The series surface is re-verified on 0.16.26 by a fresh
>    `stalwart-e2e` rebuild (EXIT 0, 2026-10-31):
>    `/metrics/prometheus` answers with the SAME 37-series HELP set as
>    the 0.16.22 transcription in docs/MONITORING.md §5.5 - no
>    additions, no removals. `queue_rescheduled` is LAZILY REGISTERED
>    (absent from the dump until a message is actually deferred;
>    produced within seconds by the 2026-10-26 relay-e2e deferral).
>    Series names for alert rules come from THERE or a live dump -
>    never from this doc.
> 3. On 0.16, wire telemetry through provision objects /
>    `services.stalwart.provision` singletons. The wrapper path for
>    Prometheus is the `Metrics.prometheus` singleton
>    (`"@type" = "Enabled"`, rendered by mail-server.nix under
>    `metrics.enable`); the raw `metrics.*` TOML keys are 0.15-era
>    history kept below for reference.
>
> **History (superseded interim verifications, kept for provenance):**
> 2026-09-22 - the core keys were source-verified in the 0.15.5 tarball
> (`metrics.prometheus.enable` (+ auth keys), `tracing.level.<event>`,
> `tracing.history.enable/.store`); 2026-10-05 - webhook + alert support
> binary-verified in 0.15.5 (`webhook` tracer token, `signature-key`,
> `discard-after`, `WebhookTracer` symbols, `telemetry.webhook-error` +
> `telemetry.alert`); 2026-10-19 - `/metrics/prometheus` re-verified on
> 0.16.22 through the wrapper path (200, loopback HTTP) with the
> 37-series payload transcribed into docs/MONITORING.md §5.5. Ledger
> doctrine applies: verify exact shapes against the pinned binary
> before wiring; do not re-derive keys from this document.

## 1. Mental model: one stream, many consumers

Everything starts with a single internal stream of **events** and
**metrics**. Consumers tap that stream independently, each with its own
severity threshold and event filter:

```
                    ┌─> Tracer: Log file      (info, rotation)
 Events ──filters──>├─> Tracer: Journal       (warn+ only)
 (each has a        ├─> Tracer: OtelHttp/Grpc (traces + logs to a collector)
  default level)    ├─> WebHook objects       (POST to HTTP, no level filter*)
                    └─> Live SSE (Enterprise) (real-time stream)

 Metrics ──select──>├─> OpenTelemetry push    (interval-based)
                    ├─> /metrics/prometheus   (pull/scrape)
                    ├─> Alerts (Enterprise)   (threshold expressions)
                    └─> History stores (Enterprise, persisted samples)
```

\* Webhooks select events by explicit list (`events`/`eventsPolicy`), not by
severity; they do carry a `level` field for minimum severity, but the
primary selection mechanism is the event list.

**Events** are hierarchical identifiers (`auth.success`,
`delivery.delivered`, `dkim.pass`) — hundreds of them across ~45 families
(see §6). Each event has a **default level**: `info`, `warn`, `error`,
`debug`, or `trace`. Each event also carries structured **key-value pairs**
(`accountId`, `remoteIp`, `domain`, `queueId`, …) — see §7. A tracer with
`level: warn` records every event whose default level is `warn` or more
severe. Per-event defaults can be overridden with an `EventTracingLevel`
object (`{"event": "auth.success", "level": "debug"}`) — useful to promote
one noisy/interesting event without raising global verbosity.

## 2. Feature matrix (edition gating)

| Subsystem                                            | Object                        | Community | Enterprise |
| ---------------------------------------------------- | ----------------------------- | --------- | ---------- |
| Tracing & logging (file, console, journal, OTel)     | `Tracer`                      | ✅        | ✅         |
| Metrics via OpenTelemetry (push) + Prometheus (pull) | `Metrics` singleton           | ✅        | ✅         |
| Webhooks                                             | `WebHook`                     | ✅        | ✅         |
| Alerts (threshold rules → event/email)               | `Alert`                       | ❌        | ✅         |
| Live telemetry (SSE streaming)                       | HTTP endpoints                | ❌        | ✅         |
| History (persisted spans + metric samples)           | `TracingStore`/`MetricsStore` | ❌        | ✅         |

Gating evidence: the Alerts, Live Telemetry, and History pages carry an
explicit "Enterprise feature" banner; the tracing/metrics/webhooks pages do
not. (Compare-table checkmarks on the marketing site did not render reliably
in markdown fetch — banner text is the stronger evidence.)

## 3. The right way: recommended baseline

### 3.1 Tracers

- **Always-on baseline:** one `Journal` (Linux) or `Log` tracer at `info`.
  Multiple tracers in parallel is the _designed_ pattern — different
  consumers are supposed to get different slices of the stream.
- **Pre-provision a debug tracer with `enable: false`.** During an incident,
  flip `enable` (and/or the level) instead of editing the live baseline —
  no other consumer is disturbed.
- **Backpressure:** default behavior when a tracer can't keep up is to
  apply backpressure to the event path. Set `lossy: true` only where
  dropping entries beats stalling (e.g. a temporary `trace`-level console
  tracer during debugging).
- **Event filtering:** `events` + `eventsPolicy` (`include` = only listed;
  `exclude` = everything except listed). Narrow noisy consumers instead of
  suppressing events globally.
- **Common fields on every variant:** `enable`, `level`, `lossy`,
  `events`, `eventsPolicy`.
- **OTel variants** (`OtelHttp`, `OtelGrpc`): `endpoint` (required for
  Http), `enableLogExporter`/`enableSpanExporter` (default true), `throttle`
  (default `"1s"`), `timeout` (default `"10s"`), `httpAuth`
  (`Unauthenticated`|`Basic`|`Bearer`), `httpHeaders`.
  **Tokens go in `httpAuth`, never as an `Authorization` entry in
  `httpHeaders`** — headers are for custom headers only.

### 3.2 Metrics

- **Prometheus (pull):** enable the `prometheus` field on the `Metrics`
  singleton, variant `Enabled`, which exposes **`/metrics/prometheus`**.
  **Always set `authUsername`/`authSecret`** — leaving both unset exposes
  the endpoint _without authentication_. Point the Prometheus scrape job
  at that path.
- **OpenTelemetry (push):** variant `Http` or `Grpc`; `interval` default
  60000 ms, `timeout` default 10000 ms. Use when a collector already owns
  fan-out (Prometheus/Jaeger/Zipkin downstream).
- Both exporters can run simultaneously against independent collectors.
- **Noise control:** `metrics` is a set (each selected metric is a key
  mapped to `true`) + `metricsPolicy`. Default is `exclude` — _selected
  metrics are suppressed, everything else is emitted_. Use `include` to
  emit only what you actually graph, instead of deleting/renaming metrics
  or filtering at the dashboard.

```json
{
  "prometheus": {
    "@type": "Enabled",
    "authUsername": "prometheus",
    "authSecret": { "@type": "Value", "secret": "password123" }
  }
}
```

(In production prefer the `EnvironmentVariable` or `File` secret variants
over `Value`.)

### 3.3 Webhooks

- **List events explicitly.** Wildcard patterns are NOT supported — every
  event to be delivered must be named in `events`.
- **Always set `signatureKey`.** Each request body is HMAC-signed and the
  base64 signature is carried in the `X-Signature` header; verify it on the
  receiver before trusting the payload.
- **Keep `allowInvalidCerts: false`** (default). Enabling it silently
  downgrades transport security.
- **Delivery semantics:** `lossy: false` means events accumulate until
  delivered or `discardAfter` (default 300000 ms = 5 min) elapses; `throttle`
  (default 1000 ms) batches events within a window into one POST;
  `timeout` default 30000 ms. Choose `lossy: true` only for best-effort
  sinks (analytics), never for a SIEM feed.
- Payload: `{"events": [{"id", "createdAt", "type", "data"}]}` where
  `data` varies by event type.

### 3.4 Enterprise extras

- **Alerts** (`Alert` objects): `condition` is an expression over live
  metric values evaluated continuously; fires when true. Metric identifiers
  in expressions use **underscores instead of dots/hyphens**
  (`store_foundationdb_error`, not `store.foundationdb-error`) because the
  expression language restricts variable names. Notifications: `eventAlert`
  (emits a `telemetry.alert` event — forward it with a webhook) and/or
  `emailAlert` (from/to/subject/body, with `%{metric}%` placeholders such
  as `%{store.foundationdb-error}%`).
- **History:** `TracingStore`/`MetricsStore` singletons select the backend
  (`Disabled` | `Default` = main data store | dedicated backend). Retention
  on `DataRetention`: `holdTracesFor` default `"30d"`, `holdMetricsFor`
  default `"90d"`, `metricsCollectionInterval` is a **cron expression**
  (default: hourly at minute 0). Prefer a **dedicated backend** (or
  `Disabled`) over `Default` on the main store — telemetry retention should
  not compete with mail data for the same store. Queried via JMAP.
- **Live telemetry:** see §5.

## 4. What NOT to do (anti-patterns)

1. **`trace` level on an always-on tracer in production.** Use a dedicated,
   temporary, ideally `lossy` tracer; `trace` logs nearly every internal
   operation (e.g. `delivery.raw-input`/`raw-output` include full SMTP
   transcripts — sensitive data).
2. **Exposed `/metrics/prometheus` without basic auth.** Both credential
   fields unset = no authentication. Behind a firewall does not count.
3. **Assuming webhook wildcards.** `events: {"delivery.*": true}` silently
   matches nothing — every event must be listed by exact ID.
4. **Bearer tokens in `httpHeaders`.** The exporter has `httpAuth` for that;
   headers are for custom headers.
5. **Reaching for Live SSE when History is the right tool.** The live stream
   is ephemeral — if you need "what happened an hour ago", that's History
   (persisted, JMAP-queryable), not the SSE endpoint.
6. **Quieting dashboards by muting metrics at the source** without intent —
   remember `metricsPolicy: exclude` _suppresses the listed metrics_; the
   naming is a frequent source of inverted config.
7. **Raising an event's level override (`EventTracingLevel`) and forgetting
   it** — it changes what every tracer below that level records.

## 5. Live telemetry over SSE (deep dive)

**Transport:** Server-Sent Events — a plain HTTP GET where the server holds
the response open (`text/event-stream`) and writes one `data:` line per
event; one-way server→client; browsers consume via `EventSource` with
auto-reconnect. No Stalwart config object exists for it — open the endpoint
and the stream flows. **Enterprise-only.**

**Traces endpoint: `/api/telemetry/traces/live`**

- Continuous SSE stream; each event is one JSON object with the event's
  structured key-value pairs (the §7 catalogue).
- Server-side filters (per request):
  - `?filter=error` — substring match across **every** structured key
    (quick search).
  - Any structured key as its own query parameter; constraints combine:
    `?remote-ip=192.168.1.1&domain=example.org` (docs example — only
    entries matching ALL constraints are sent).
- **Always filter on busy servers** — the unfiltered stream can be too
  large to process interactively.

**Metrics endpoint: `/api/telemetry/metrics/live`**

- `?metrics=server.memory,queue.count` — restrict to named metrics.
- `?interval=30` — sampling interval in seconds.
- Each line: one JSON object describing a single data point.

**Consumers:** the WebUI Dashboard is the intended consumer (formats the
stream, provides filter controls). Ad-hoc: `curl -N
https://host/api/telemetry/traces/live?filter=...`.

**Unverified:** the docs do not state the auth requirements for these
endpoints. They live under `/api/` (same surface as the admin API), so
assume administrator authentication — verify against the binary before
relying on it.

## 6. Event families (catalogue overview)

Hundreds of events across ~45 families. Counts from the Events page
(2026-09-15):

`smtp` (82) · `delivery` (38) · `store` (37) · `imap` (37) · `acme` (27) ·
`jmap` (22) · `manage-sieve` (19) · `web-dav` (18) · `pop3` (18) · `dkim`
(18) · `milter` (17) · `outgoing-report` (15) · `incoming-report` (15) ·
`network` (13) · `spam` (12) · `sieve` (12) · `queue` (12) · `config` (12) ·
`mail-auth` (10) · `limit` (10) · `dane` (10) · `cluster` (10) ·
`calendar` (8) · `telemetry` (7) · `spf` (7) · `purge` (7) ·
`message-ingest` (7) · `http` (7) · `auth` (7) · `tls` (6) · `task-queue`
(6) · `security` (6) · `mta-sts` (6) · `manage` (6) · `arc` (6) · `server`
(5) · `resource` (5) · `mta-hook` (5) · `iprev` (5) · `dmarc` (5) ·
`housekeeper` (4) · `eval` (4) · `tls-rpt` (3) · `push-subscription` (2) ·
`ai` (2)

Representative events worth knowing for a mail server baseline:

| Event                                                    | Meaning                                       | Default level       |
| -------------------------------------------------------- | --------------------------------------------- | ------------------- |
| `auth.success` / `auth.error` / `auth.too-many-attempts` | auth outcome                                  | INFO / ERROR / WARN |
| `delivery.delivered` / `delivery.failed`                 | outbound delivery result                      | INFO                |
| `delivery.dsn-*`                                         | DSN success/temp-fail/perm-fail notifications | INFO                |
| `dkim.*`, `spf.*`, `dmarc.*`, `arc.*`                    | sender-auth results                           | DEBUG (mostly)      |
| `security.*` (incl. brute-force ban)                     | security events                               | —                   |
| `queue.*`                                                | outbound queue lifecycle                      | —                   |
| `delivery.raw-input` / `raw-output`                      | full SMTP transcripts                         | TRACE               |

Full table with descriptions and default levels:
https://stalw.art/docs/telemetry/events/

## 7. Structured key catalogue (for filters)

Every event entry can carry key-value pairs; the supported key types (used
by the live-SSE per-key filters and present in webhook/trace payloads):

`accountId` · `attempt` · `blobId` · `causedBy` · `changeId` · `code` ·
`collection` · `contents` · `date` · `details` · `dkimFail` · `dkimNone` ·
`dkimPass` · `dmarcNone` · `dmarcPass` · `dmarcQuarantine` · `dmarcReject` ·
`documentId` · `domain` · `due` · `elapsed` · `expected` · `expires` ·
`from` · `hamLearns` · `hostname` · `id` · `interval` · `key` · `limit` ·
`listenerId` · `localIp` · `localPort` · `mailboxId` · `messageId` ·
`name` · `nextDsn` · `nextRenewal` · `nextRetry` · `oldName` ·
`parameters` · `path` · `policy` · `protocol` · `queueId` · `rangeFrom` ·
`rangeTo` · `reason` · `remoteIp` · `remotePort` · `renewal` · `reportId` ·
`result` · `size` · `spfFail` · `spfNone` · `spfPass` · `status` ·
`strict` · `tls` · `to` · `total` · `totalFailures` · `totalSuccesses` ·
`type` · `uid` · `uidNext` · `uidValidity` · `url` · `used` · `validFrom` ·
`validTo` · `value`

## 8. Wiring into this flake (nix-email) — checklist

0. **SHIPPED DEFAULT (2026-11-10):** the wrapper always provisions ONE
   `Journal` Tracer via a `reconcile` plan op (`match = "*"`, scope
   `@type = Journal`) include-scoped to the per-message fate events at
   `info` (`services.mail-server.deliveryTracking.enable`, default true).
   Why a provisioned tracer is REQUIRED at all (source-proven at the
   pin, `telemetry.rs Tracers::parse`): 0.16 release builds ship NO
   default tracer - with zero provisioned `Tracer` objects the global
   event interests stay EMPTY and the stream drops before any subscriber
   (this retro-explains the 2026-10-17 quota-journal-silence probe; the
   0.16.22 and 0.16.26 level tables are identical, all `delivery.*`/
   `queue.*`/`message-ingest.*` lifecycle events are default `Info`).
   The wildcard match is load-bearing: `x:Tracer` has NO label property,
   so a matchOn-less `reconcile` is refused ("has no match key"); value
   matching keys on the comparable SCALAR fields and the `events` SET
   patches in place on drift; the `@type = Journal` scope keeps
   consumer-created Log/Otel tracers out of the leak-destroy pass.
   Trail reality (transcript-pinned relay-e2e + stalwart-e2e
   2026-11-10): description lines only under `journalctl -t stalwart` -
   journald DROPS the tracer's mixed-case journal fields (`queueId` et
   al.; journald accepts only `[A-Z0-9_]` names, host-proven), so
   per-message correlation is chronological, never field-keyed.

1. **Version truth first:** the pin ships Stalwart **0.16.26** and the
   object model is binary-verified at that version (see the verdict
   above). Provision singletons still evolve between minors - before
   wiring ANY key into `services.mail-server` defaults, verify the
   exact object shape against the pinned binary.
2. **Wrapper doctrine:** any defaults this repo ships must be `mkDefault`;
   consumers (SystemNix) override via `services.stalwart.settings`.
   Monitoring integrations (Prometheus scrape jobs, Gatus, alert routing)
   belong to the **consumer wrapper**, not here.
3. **Prometheus endpoint:** if exposed, always with basic auth; credentials
   via the consumer's sops secrets (`EnvironmentVariable`/`File` variants),
   never committed `Value` secrets.
4. **E2E tests:** new VM assertions only with transcript evidence (grep the
   line from an actual test log first) — project rule, doubly so for
   telemetry where log volume is large and levels interact.
5. **Log hygiene:** if a log-file tracer lands in defaults, pair it with
   rotation and `logrotate` ownership in the module, not just the setting.

## 9. Open / unverified items

- Auth requirements of `/api/telemetry/traces/live` and
  `/api/telemetry/metrics/live` (docs silent; admin-API auth assumed).
- ~~Exact TOML paths for the object model on 0.15.5 vs the docs' current
  object model~~ RESOLVED 2026-10-31 for the 0.16 path: wire through
  provision singletons (verdict above); the 0.15-era TOML question died
  with the 0.15 pin.
- Whether `remote-ip` vs `remoteIp` casing in live-SSE per-key filters is
  literal (docs example uses `remote-ip=...` while the key catalogue says
  `remoteIp`).

## Sources (fetched 2026-09-15)

| Page                           | URL                                                     |
| ------------------------------ | ------------------------------------------------------- |
| Telemetry overview             | https://stalw.art/docs/telemetry/                       |
| Events (catalogue + key types) | https://stalw.art/docs/telemetry/events/                |
| Tracing & logging              | https://stalw.art/docs/telemetry/tracing/               |
| Tracing: OpenTelemetry         | https://stalw.art/docs/telemetry/tracing/opentelemetry/ |
| Metrics overview               | https://stalw.art/docs/telemetry/metrics/               |
| Metrics: OpenTelemetry         | https://stalw.art/docs/telemetry/metrics/opentelemetry/ |
| Metrics: Prometheus            | https://stalw.art/docs/telemetry/metrics/prometheus/    |
| Webhooks                       | https://stalw.art/docs/telemetry/webhooks/              |
| Alerts (Enterprise)            | https://stalw.art/docs/telemetry/alerts/                |
| Live telemetry (Enterprise)    | https://stalw.art/docs/telemetry/live/                  |
| History (Enterprise)           | https://stalw.art/docs/telemetry/history/               |
