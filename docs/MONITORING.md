# Monitoring & Alerting — taxonomy, coverage matrix, routing

| Field         | Value                                                                                                                                                                                                 |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Created       | 2026-09-22 (execution session; Pareto plan M11 + M9.4/M20.1)                                                                                                                                          |
| Owner split   | This repo owns wrapper-side sources (metrics exposure, report sinks, logs). The CONSUMER host (SystemNix) owns alert routing, Gatus external checks, Prometheus scrape, and the notification channel. |
| Standing rule | **Alerts never ride the mail stack they watch.** The delivery channel must be non-mail (C24 decision pending; recommendation: the consumer's existing Discord path).                                  |
| Standing rule | **The monitors are monitored** (dead-man switch): every checker must itself emit a heartbeat or be covered by an `absent()`-style rule (M13).                                                         |

## 1. Severity taxonomy

| Severity | Meaning                                                                                                            | Reaction | Channel              |
| -------- | ------------------------------------------------------------------------------------------------------------------ | -------- | -------------------- |
| CRITICAL | Mail is not flowing or data is at risk (queue age high, canary broken, backup stale beyond RPO, cert expired)      | Wake-up  | Non-mail push (C24)  |
| WARNING  | Degraded but flowing (auth-failure burst, TLS-RPT failure spike, disk > 80%, quota pressure, report freshness lag) | Same-day | Non-mail push (C24)  |
| INFO     | Normal-but-notable (new DMARC sender org, new TLS-RPT reporter, deploy/reload happened)                            | Digest   | Channel digest (C24) |

## 2. Signal inventory (wrapper-side sources)

| #  | Signal                                                               | Source (verified)                                                                                                                                | Status                                                                               | Alert condition (spec)                                                               | Sev              |
| -- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------ | ---------------- |
| 1  | Metrics endpoint                                                     | `metrics.prometheus.enable`, `/metrics/prometheus` on the HTTP listener (README ledger 2026-09-22; e2e-asserted 200)                             | **AVAILABLE** (e2e asserts; wrapper exposes passthrough)                             | scrape by consumer; `absent()` dead-man                                              | CRITICAL         |
| 2  | Queue depth / age                                                    | TRANSCRIPT-PROVEN ABSENT from `/metrics`: 0.15.5 exposes NO queue-depth/age gauge (40 HELP series transcribed from the e2e dump, none queue-related). Implementable source: consumer poll `GET /api/queue/messages` (basic auth admin, §5.4) - depth = list length, age = oldest queued timestamp | **SPEC ONLY** (M12 follow-up; consumer poll rules)                                  | queue non-empty AND oldest entry > 1 h = CRITICAL (poll on the loopback/rev-proxy path) | CRITICAL         |
| 3  | Over-quota retry-forever                                             | same queue POLL (README ledger: over-quota mail retries forever, `Message rescheduled for delivery`; assert IMAP absence, not SMTP refusal)      | **SPEC ONLY**                                                                        | queue age high + recipient quota near limit                                          | WARNING          |
| 4  | Failed auth burst                                                    | `tracing.level.auth` (journal) or telemetry counters - source verified 0.15.5; pick ONE source at wiring time                                    | **SPEC ONLY** (M15)                                                                  | > N failed logins / 5 min per remote IP                                              | WARNING          |
| 5  | SMTP TLS-RPT failures                                                | parsedmarc `smtp_tls.json` sink (`application/tlsrpt+json` rides the rua mailbox poll - verified + e2e-asserted 2026-09-22)                      | **COLLECTED** (e2e green)                                                            | new `certificate-expired`/`validation-failure` entries with failed-session-count > 0 | WARNING          |
| 6  | DMARC aggregate anomalies                                            | parsedmarc `aggregate.json` sink                                                                                                                 | **COLLECTED** (e2e green)                                                            | new sending org / policy domain; rua volume drops to zero for a domain               | WARNING/INFO     |
| 7  | Report freshness                                                     | mtime of `aggregate.json` / parsedmarc unit liveness                                                                                             | **SPEC ONLY** (M13/M23; dedupe against the consumer registry's `backup.maxAgeHours`) | mtime older than 48 h                                                                | WARNING          |
| 8  | Backup freshness + restore drill                                     | consumer backup-coordination; repo documents the `--export`/`--import` drill                                                                     | **CONSUMER LAYER** (D1-gated build-out, M23)                                         | recovery-age key exceeds RPO                                                         | CRITICAL         |
| 9  | External reachability (STARTTLS :25, implicit TLS :993, cert expiry) | Gatus external checks                                                                                                                            | **CONSUMER LAYER** (M13 spec)                                                        | connect/verify failure; cert < 14 d                                                  | CRITICAL/WARNING |
| 10 | Round-trip canary (send -> receive SLO)                              | M18 design (vantage = C29 decision; recommendation evo-x2 timer)                                                                                 | **DESIGN PENDING DECISION**                                                          | delivery SLO breach (e.g. > 10 min)                                                  | CRITICAL         |
| 11 | Capacity: disk + per-mailbox quota                                   | `/metrics` series probe + quota principal fields                                                                                                 | **SPEC ONLY** (M12/M17)                                                              | disk > 80 %; mailbox > 80 % quota                                                    | WARNING          |
| 12 | Audit trail                                                          | NO audit-log knob exists in 0.15.5 (README ledger) - `tracing.level.*` + journald retention is the surface                                       | **DOCUMENTED**                                                                       | (no alert; journald retention is consumer policy)                                    | INFO             |
| 13 | Dead-man of parsedmarc + canary                                      | systemd unit states + heartbeat                                                                                                                  | **SPEC ONLY** (M13)                                                                  | unit inactive / heartbeat absent 2 periods                                           | CRITICAL         |
| 14 | Outbound bounce/complaint telemetry                                  | Resend webhooks (SASL shape doc-verified 2026-09-22: smtp.resend.com, username `resend`, password = API key, 587 STARTTLS / 465 implicit)        | **GATED on Resend account + public webhook endpoint (D1-adjacent)**                  | bounce/complaint event received                                                      | WARNING          |

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

### 5.4 Queue IR levers (management API, source-verified 2026-09-22)

`crates/http/src/management/queue.rs` routes (basic auth as admin):

| Lever           | Call                                                     | Effect                                                |
| --------------- | -------------------------------------------------------- | ----------------------------------------------------- |
| Inspect         | `GET /api/queue/messages`                                | list queued messages (id, sender, recipients, status) |
| Pause delivery  | `PATCH /api/queue/status/stop`                           | queue-wide pause (`QueueEvent::Paused(true)`)         |
| Resume          | `PATCH /api/queue/status/start` (any action ≠ "stop")    | unpause                                               |
| Hold/reschedule | `PATCH /api/queue/messages?...&at=<ts>` (+ per-id PATCH) | push retry due to `at` (the hold lever)               |
| Drop            | `DELETE /api/queue/messages` (filtered or per-id)        | cancel delivery                                       |

Quarantine review in the 0.15.5 reality = inspect queued messages +
`GET /api/queue/reports` (ingested reports) - the tag-only spam posture
(ROADMAP Q6) means there is no separate quarantine folder to review.

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
