# Stalwart Telemetry — The Right Way

How to run Stalwart's telemetry stack properly: what exists, how the pieces
fit together, and a recommended baseline that avoids the known footguns.

> **Provenance & version caveat.** Every fact below was taken from the
> official docs at https://stalw.art/docs/telemetry/ (all subpages) fetched
> on **2026-09-15**. Those pages describe the *current upstream* object
> model (WebUI `Settings › Telemetry` objects: `Tracer`, `Metrics`,
> `WebHook`, `Alert`, `TracingStore`, `MetricsStore`, `DataRetention`,
> `EventTracingLevel`). **This repo pins Stalwart 0.15.5** via nixpkgs
> (`stalwart_0_16` exists but is module-incompatible — see README ledger).
> Exact TOML key paths under `services.stalwart.settings` must be verified
> against the pinned binary before any wiring; do not re-derive keys from
> this document. Ledger doctrine applies.

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

| Subsystem | Object | Community | Enterprise |
| --- | --- | --- | --- |
| Tracing & logging (file, console, journal, OTel) | `Tracer` | ✅ | ✅ |
| Metrics via OpenTelemetry (push) + Prometheus (pull) | `Metrics` singleton | ✅ | ✅ |
| Webhooks | `WebHook` | ✅ | ✅ |
| Alerts (threshold rules → event/email) | `Alert` | ❌ | ✅ |
| Live telemetry (SSE streaming) | HTTP endpoints | ❌ | ✅ |
| History (persisted spans + metric samples) | `TracingStore`/`MetricsStore` | ❌ | ✅ |

Gating evidence: the Alerts, Live Telemetry, and History pages carry an
explicit "Enterprise feature" banner; the tracing/metrics/webhooks pages do
not. (Compare-table checkmarks on the marketing site did not render reliably
in markdown fetch — banner text is the stronger evidence.)

## 3. The right way: recommended baseline

### 3.1 Tracers

- **Always-on baseline:** one `Journal` (Linux) or `Log` tracer at `info`.
  Multiple tracers in parallel is the *designed* pattern — different
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
  the endpoint *without authentication*. Point the Prometheus scrape job
  at that path.
- **OpenTelemetry (push):** variant `Http` or `Grpc`; `interval` default
  60000 ms, `timeout` default 10000 ms. Use when a collector already owns
  fan-out (Prometheus/Jaeger/Zipkin downstream).
- Both exporters can run simultaneously against independent collectors.
- **Noise control:** `metrics` is a set (each selected metric is a key
  mapped to `true`) + `metricsPolicy`. Default is `exclude` — *selected
  metrics are suppressed, everything else is emitted*. Use `include` to
  emit only what you actually graph, instead of deleting/renaming metrics
  or filtering at the dashboard.

```json
{
  "prometheus": {
    "@type": "Enabled",
    "authUsername": "prometheus",
    "authSecret": {"@type": "Value", "secret": "password123"}
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
   remember `metricsPolicy: exclude` *suppresses the listed metrics*; the
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

| Event | Meaning | Default level |
| --- | --- | --- |
| `auth.success` / `auth.error` / `auth.too-many-attempts` | auth outcome | INFO / ERROR / WARN |
| `delivery.delivered` / `delivery.failed` | outbound delivery result | INFO |
| `delivery.dsn-*` | DSN success/temp-fail/perm-fail notifications | INFO |
| `dkim.*`, `spf.*`, `dmarc.*`, `arc.*` | sender-auth results | DEBUG (mostly) |
| `security.*` (incl. brute-force ban) | security events | — |
| `queue.*` | outbound queue lifecycle | — |
| `delivery.raw-input` / `raw-output` | full SMTP transcripts | TRACE |

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

1. **Version skew first:** pinned Stalwart is **0.15.5**; these docs
   describe current upstream. Before wiring ANY key below into
   `services.mail-server` defaults, dump the effective config from the
   pinned binary and verify the key exists with the documented shape.
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
- Exact TOML paths for the object model on 0.15.5 vs the docs' current
  object model (`Tracer` et al. may map to `telemetry.tracer.*`-style keys
  on the pinned version — UNVERIFIED, do not copy blindly).
- Whether `remote-ip` vs `remoteIp` casing in live-SSE per-key filters is
  literal (docs example uses `remote-ip=...` while the key catalogue says
  `remoteIp`).

## Sources (fetched 2026-09-15)

| Page | URL |
| --- | --- |
| Telemetry overview | https://stalw.art/docs/telemetry/ |
| Events (catalogue + key types) | https://stalw.art/docs/telemetry/events/ |
| Tracing & logging | https://stalw.art/docs/telemetry/tracing/ |
| Tracing: OpenTelemetry | https://stalw.art/docs/telemetry/tracing/opentelemetry/ |
| Metrics overview | https://stalw.art/docs/telemetry/metrics/ |
| Metrics: OpenTelemetry | https://stalw.art/docs/telemetry/metrics/opentelemetry/ |
| Metrics: Prometheus | https://stalw.art/docs/telemetry/metrics/prometheus/ |
| Webhooks | https://stalw.art/docs/telemetry/webhooks/ |
| Alerts (Enterprise) | https://stalw.art/docs/telemetry/alerts/ |
| Live telemetry (Enterprise) | https://stalw.art/docs/telemetry/live/ |
| History (Enterprise) | https://stalw.art/docs/telemetry/history/ |
