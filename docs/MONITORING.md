# Monitoring & Alerting — taxonomy, coverage matrix, routing

| Field         | Value                                                                                                                                                                                                 |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Created       | 2026-09-22 (execution session; Pareto plan M11 + M9.4/M20.1)                                                                                                                                          |
| Owner split   | This repo owns wrapper-side sources (metrics exposure, report sinks, logs). The CONSUMER host (SystemNix) owns alert routing, Gatus external checks, Prometheus scrape, and the notification channel. |
| Standing rule | **Alerts never ride the mail stack they watch.** The delivery channel must be non-mail (C24 decision pending; recommendation: the consumer's existing Discord path).                                  |
| Standing rule | **The monitors are monitored** (dead-man switch): every checker must itself emit a heartbeat or be covered by an `absent()`-style rule (M13).                                                         |

> **0.16 STATE (2026-10-19, transcript-pinned from the first full gate):**
> Stalwart 0.16.22 is the tree default. The `/metrics/prometheus`
> endpoint is re-verified on 0.16.22 and the FULL series inventory is
> transcribed in §5.5 (37 HELP series, from the stalwart-e2e metrics
> dump in the gate build log). The 0.15-era REST queue levers (§5.4) are
> GONE on 0.16 (the REST family was removed; management is JMAP /
> `stalwart-cli` now). Gate-log noise note: the `nix flake check` count
> line said "running 7 flake checks" while 9 are defined - known CLI
> display noise (first seen 2026-10-17, reproduced on the first full
> nine-check gate 2026-10-19); the `attrNames` eval is the truth.

## 1. Severity taxonomy

| Severity | Meaning                                                                                                            | Reaction | Channel              |
| -------- | ------------------------------------------------------------------------------------------------------------------ | -------- | -------------------- |
| CRITICAL | Mail is not flowing or data is at risk (queue age high, canary broken, backup stale beyond RPO, cert expired)      | Wake-up  | Non-mail push (C24)  |
| WARNING  | Degraded but flowing (auth-failure burst, TLS-RPT failure spike, disk > 80%, quota pressure, report freshness lag) | Same-day | Non-mail push (C24)  |
| INFO     | Normal-but-notable (new DMARC sender org, new TLS-RPT reporter, deploy/reload happened)                            | Digest   | Channel digest (C24) |

## 2. Signal inventory (wrapper-side sources)

| #  | Signal                                                               | Source (verified)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Status                                                                                        | Alert condition (spec)                                                               | Sev                                     |
| -- | -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | --------------------------------------- |
| 1  | Metrics endpoint                                                     | `metrics.prometheus.enable`, `/metrics/prometheus` on the HTTP listener (README ledger 2026-09-22; e2e-asserted 200)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | **AVAILABLE** (e2e asserts; wrapper exposes passthrough)                                      | scrape by consumer; `absent()` dead-man                                              | CRITICAL                                |
| 2  | Queue depth / age                                                    | TRANSCRIPT-PROVEN ABSENT from `/metrics` on BOTH eras: 0.16.22 exposes NO queue-depth/age gauge (37 HELP series transcribed from the first full gate's stalwart-e2e dump, §5.5 - the only queue series is the cumulative `queue_authenticated_message_queued` COUNTER, a throughput signal, not backlog). The 0.15 REST poll (`GET /api/queue/messages`) is DEAD on 0.16 (REST removed). Implementable proxy: sustained divergence `rate(queue_authenticated_message_queued)` >> `rate(delivery_completed)` = backlog growing; the real delivery SLO stays the canary (row 10)                                          | **SPEC ONLY** (consumer rules; honest no-gauge verdict, 2026-10-19)                           | counter divergence sustained > 30 min = WARNING; canary breach = CRITICAL            | CRITICAL                                |
| 3  | Over-quota retry-forever                                             | 0.16 contract (e2e-proven): over-quota mail is ACCEPTED at RCPT (`250 Message queued`) and NEVER delivered - the 0.15 `Message rescheduled` journal line is GONE (0.16 journal is SILENT on this); detection = the row-2 counter divergence + IMAP-absence canary probes, never journal greps                                                                                                                                                                                                                                                                                                                           | **SPEC ONLY**                                                                                 | row-2 divergence + recipient quota near limit                                        | WARNING                                 |
| 4  | Failed auth burst                                                    | 0.16.22 metric series `auth_failed` / `auth_success` (§5.5, transcript-pinned) - better than the 0.15 journal counting; per-IP labeling to verify at wiring time                                                                                                                                                                                                                                                                                                                                                                                                                                                        | **SPEC ONLY** (M15)                                                                           | > N failed logins / 5 min per remote IP                                              | WARNING                                 |
| 5  | SMTP TLS-RPT failures                                                | parsedmarc `smtp_tls.json` sink (`application/tlsrpt+json` rides the rua mailbox poll - verified + e2e-asserted 2026-09-22)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             | **COLLECTED** (e2e green)                                                                     | new `certificate-expired`/`validation-failure` entries with failed-session-count > 0 | WARNING                                 |
| 6  | DMARC aggregate anomalies                                            | parsedmarc `aggregate.json` sink                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | **COLLECTED** (e2e green)                                                                     | new sending org / policy domain; rua volume drops to zero for a domain               | WARNING/INFO                            |
| 7  | Report freshness                                                     | mtime of `aggregate.json` / parsedmarc unit liveness                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | **SPEC ONLY** (M13/M23; dedupe against the consumer registry's `backup.maxAgeHours`)          | mtime older than 48 h                                                                | WARNING                                 |
| 8  | Backup freshness + restore drill                                     | consumer backup-coordination; repo documents the `--export`/`--import` drill                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | **CONSUMER LAYER** (D1-gated build-out, M23)                                                  | recovery-age key exceeds RPO                                                         | CRITICAL                                |
| 9  | External reachability (STARTTLS :25, implicit TLS :993, cert expiry) | Gatus external checks                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | **CONSUMER LAYER** (M13 spec)                                                                 | connect/verify failure; cert < 14 d                                                  | CRITICAL/WARNING                        |
| 10 | Round-trip canary (send -> receive SLO)                              | M18 design (vantage = C29 decision; recommendation evo-x2 timer)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | **DESIGN PENDING DECISION**                                                                   | delivery SLO breach (e.g. > 10 min)                                                  | CRITICAL                                |
| 11 | Capacity: disk + per-mailbox quota                                   | `/metrics` series probe + quota principal fields                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | **SPEC ONLY** (M12/M17)                                                                       | disk > 80 %; mailbox > 80 % quota                                                    | WARNING                                 |
| 12 | Audit trail                                                          | NO audit-log knob exists in 0.15.5 (README ledger) - `tracing.level.*` + journald retention is the surface                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | **DOCUMENTED**                                                                                | (no alert; journald retention is consumer policy)                                    | INFO                                    |
| 13 | Dead-man of parsedmarc + canary                                      | systemd unit states + heartbeat                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | **SPEC ONLY** (M13)                                                                           | unit inactive / heartbeat absent 2 periods                                           | CRITICAL                                |
| 14 | Outbound bounce/complaint telemetry                                  | Resend webhooks (SASL shape doc-verified 2026-09-22: smtp.resend.com, username `resend`, password = API key, 587 STARTTLS / 465 implicit)                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | **GATED on Resend account + public webhook endpoint (D1-adjacent)**                           | bounce/complaint event received                                                      | WARNING                                 |
| 15 | Provision/bootstrap failure (wrapper's own loud signal)              | `stalwart-provision.service` state on the consumer host: a FAILED unit means the listener plan did NOT apply (the nix-email#4 bind-deadlock class: server up on built-in listeners only, no 587/465). The unit's ExecStartPost restarts stalwart and waits up to 60 s for the configured URL - budget note: that verify window rides INSIDE the unit's 3 min TimeoutStartSec, so a failed apply + failed verify stays under one timeout. New failure signature since the OIDC reload-validation fetch (2026-10-20): an apply passing all objects can still fail at the final `reload` validation with `validationFailed | Network error: Discovery fetch failed` (egress/DNS class; THREAT_MODEL "0.16 exposure delta") | **SPEC ONLY** (consumer systemd alert)                                               | unit failed = CRITICAL (bootstrap-dead) |

Status vocabulary: AVAILABLE (source exists and is asserted by a check), COLLECTED (data lands in a sink), SPEC ONLY (source verified, alert rules not yet encoded anywhere), CONSUMER LAYER (belongs to SystemNix by AGENTS.md doctrine), DESIGN PENDING DECISION (blocked on a C-decision).

## 3. Coverage matrix (the C40 view)

- **Today (verified):** metrics endpoint exposed + e2e-asserted; DMARC aggregate + forensic + TLS-RPT reports collected to the JSON/CSV sink; relay + catch-all behavior covered by VM e2e; telemetry/tracing keys verified in the pinned source.
- **Planned, source-verified, unencoded (SPEC ONLY rows above):** queue/auth/capacity rules, freshness, dead-man.
- **Gaps (no source without decisions):** canary vantage (C29), alert channel (C24), external checks (consumer layer, M13), backup freshness (D1, M23).
- **Not monitorable in 0.15.5:** connection-level client-IP RBL metrics (the DNSBL surface is content-analysis inside the spam filter - README ledger); audit-log events as a first-class stream (tracing is the surface).

## 4. Routing table (consumer-side shape)

```
signal severity  ->  where it goes (consumer SystemNix layer)
CRITICAL         ->  non-mail push channel (C24; recommendation: Discord)
WARNING          ->  same channel, throttled/deduped
INFO             ->  digest (once daily)
heartbeat miss   ->  CRITICAL on the channel from a DIFFERENT vantage
```

## 5. Consumer check specs (Gatus + dead-man + auth alerts)

These are CONSUMER-layer (SystemNix) specs: this repo verifies the sources,
the consumer encodes the checks. Everything below assumes the wrapper
default HTTP bind (127.0.0.1:8080) plus either an SSH tunnel or a
reverse-proxy route for Prometheus scraping (README doctrine: never expose
the whole admin listener for metrics).

### 5.1 External reachability (Gatus, from a second vantage)

```yaml
# STARTTLS on the MX :25 (submission :587 analogous with the relay shape)
- name: smtp-starttls
  endpoints:
    - "tcp://mail.example.test:25"
  conditions: ["CONNECTED"]
  # Gatus starttls conditions per its docs; the consumer owns exact syntax.

# Implicit TLS on :993 (IMAPS)
- name: imaps-tls
  endpoints: ["tcp://mail.example.test:993"]
  conditions: ["CONNECTED"]

# Certificate expiry (the same TLS endpoints carry it)
- name: mail-cert-expiry
  conditions: ["CERTIFICATE_EXPIRATION > 14d"]
```

Alert severity mapping: connect failure = CRITICAL; cert < 14 d = WARNING.

### 5.2 Dead-man switch (the monitors are monitored)

- Every Gatus check gets `alerts` on failure AND the whole Gatus instance
  pushes a heartbeat; the absence of the heartbeat is itself alerted by a
  second vantage (or Gatus's health endpoint scraped by Prometheus with an
  `absent()` rule).
- Prometheus scrape of `/metrics/prometheus`: encode
  `absent(stalwart_up)`-style rules (exact series names from the
  stalwart-e2e metrics dump in the build log - transcribe, never guess).
- parsedmarc liveness: `systemctl is-active parsedmarc` + freshness of the
  sink (row 7) - a dead poller must page before reports go stale enough to
  matter.

### 5.3 Failed-auth alerting (row 4 spec)

- Source: the Stalwart journal's tracing auth events (0.15.5 has no
  separate audit stream - README ledger 2026-09-22). journald-based
  counting on the consumer host avoids new Stalwart config.
- Rule: > 5 failed LOGIN/IMAP/SMTP-AUTH attempts for the same remote IP
  within 5 min = WARNING (dedupe by IP, 30 min window); sustained > 50/h
  = CRITICAL.
- Companion knob (wrapper-side, source-verified + SHIPPED 2026-09-22):
  `services.mail-server.rateLimits` (default OFF - v0.15.5 already ships two
  conservative inbound limiters, README ledger (i)) stacks a sustained
  per-remote-ip damper; valid keys include `remote_ip` and
  `authenticated_as` (NOT "auth_as"), `rate = N/period` REQUIRED. The
  response, not just the alarm.

### 5.4 Queue IR levers (0.15.5 HISTORICAL - the REST family is REMOVED in 0.16)

0.15.5's `crates/http/src/management/queue.rs` routes (basic auth as
admin) - kept for rollback/forensics reference ONLY. On 0.16 the
management surface is JMAP + `stalwart-cli`; a queue-inspect equivalent
was NOT verified against 0.16.22 (verify `stalwart-cli --help` on the
pin before wiring anything here):

| Lever           | Call (0.15.5 only)                                       | Effect                                                |
| --------------- | -------------------------------------------------------- | ----------------------------------------------------- |
| Inspect         | `GET /api/queue/messages`                                | list queued messages (id, sender, recipients, status) |
| Pause delivery  | `PATCH /api/queue/status/stop`                           | queue-wide pause (`QueueEvent::Paused(true)`)         |
| Resume          | `PATCH /api/queue/status/start` (any action ≠ "stop")    | unpause                                               |
| Hold/reschedule | `PATCH /api/queue/messages?...&at=<ts>` (+ per-id PATCH) | push retry due to `at` (the hold lever)               |
| Drop            | `DELETE /api/queue/messages` (filtered or per-id)        | cancel delivery                                       |

Quarantine review in the 0.15.5 reality = inspect queued messages +
`GET /api/queue/reports` (ingested reports) - the tag-only spam posture
(ROADMAP Q6) means there is no separate quarantine folder to review.

### 5.5 Prometheus series inventory (0.16.22, transcript-pinned 2026-10-19)

The canonical transcription of every HELP series in the
`/metrics/prometheus` payload, from the first full gate's stalwart-e2e
metrics dump (build log 2026-10-19; transcribe, never guess). Queue
verdict: the ONLY queue series is the cumulative counter
`queue_authenticated_message_queued` - there is NO depth/age gauge
(row 2).

- auth: `auth_failed`, `auth_success`
- connections (active/start/request-time triplets): `smtp_`, `imap_`,
  `pop3_`, `sieve_`, `http_`, `delivery_active_connections`,
  `smtp_connection_start`, `http_connection_start`,
  `imap_connection_start`
- delivery: `delivery_attempt_start`, `delivery_attempt_time`,
  `delivery_completed`, `delivery_dsn_success`, `delivery_total_time`
- queue: `queue_authenticated_message_queued` (counter, no gauge)
- store: `store_blob_read`, `store_blob_write`, `store_data_iterate`,
  `store_data_write`
- policy/dns: `smtp_dkim_fail`, `smtp_iprev_pass`, `smtp_spf_ehlo_fail`,
  `smtp_spf_from_fail`, `smtp_mailbox_does_not_exist`
- volume: `message_authenticated_size`, `message_ingest_ham`
- counts: `domain_count`, `user_count`
- health: `resource_error`, `telemetry_log_error`, `server_memory`
- http bodies: `http_request_time`, `http_response_body`
- imap/pop3 request time: `imap_request_time`, `smtp_request_time`

## 6. Round-trip canary design (row 10, gated on C29)

- Purpose: message-level SLO probe - a mail that proves the WHOLE path
  (submit -> relay/local MX -> mailbox) works, distinct from TCP/TLS
  reachability.
- Vantage options: (a) evo-x2 residential (independent network + DNS;
  recommended - the outside view a server-side probe can never give),
  (b) consumer VPS cron, (c) in-guest (rejected: same-host probes cannot
  see routing/regression).
- Shape: systemd timer (15 min) on the vantage host sends via the relay
  path to the canary mailbox, then asserts arrival over IMAP within the
  SLO (target < 10 min); breach = CRITICAL alert (row 10).
- Failure alarm must distinguish: send failure (relay path) vs timeout
  (delivery path) - different on-call reactions.

The channel decision, vantage decision, and any consumer wiring land via
`docs/planning/decision-batch.md` (C24, C29) - answer there and the
SPEC ONLY rows graduate into TODO_LIST work items.

## 7. Threat-model cross-check (2026-09-22)

Each `docs/THREAT_MODEL.md` attacker scenario mapped to its monitoring signal:

| Threat scenario (THREAT_MODEL)                   | Monitoring signal                                                                   | Gap                                                                     |
| ------------------------------------------------ | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Open relay attempt                               | row 4 (auth failures) + row 2 (queue)                                               | none beyond the SPEC rows                                               |
| Directory-cache poisoning (mail misrouted to MX) | row 2 (queue age) + row 10 (canary catches misrouting symptomatically)              | no direct metric for negative-cache hits - acceptable, symptoms covered |
| SSRF via relay target                            | eval-time (wrapper assertions, incl. the 2026-09-22 loopback eval rejection)        | n/a - static                                                            |
| Anonymous admin API access                       | row 4 (tracing auth events also carry admin-auth failures)                          | consumer reverse-proxy exposure policy is THREAT_MODEL "out of scope"   |
| Spam into INBOX (tag-only, Q6)                   | rows 5-6 (TLS-RPT + DMARC reports give spoofing visibility)                         | no per-mailbox spam-volume series in 0.15.5                             |
| Store/secrets leakage                            | by construction (no monitoring signal exists or needed)                             | -                                                                       |
| Quota exhaustion / oversized mail                | rows 3 + 11 (queue age under quota pressure; capacity)                              | the retry-forever trap makes row 2 the operative signal                 |
| Local-part enumeration behind a catch-all        | deliberately unmonitorable (catch-all makes every RCPT valid - documented tradeoff) | accepted                                                                |
