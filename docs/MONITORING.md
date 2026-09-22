# Monitoring & Alerting — taxonomy, coverage matrix, routing

| Field | Value |
| ----- | ----- |
| Created | 2026-09-22 (execution session; Pareto plan M11 + M9.4/M20.1) |
| Owner split | This repo owns wrapper-side sources (metrics exposure, report sinks, logs). The CONSUMER host (SystemNix) owns alert routing, Gatus external checks, Prometheus scrape, and the notification channel. |
| Standing rule | **Alerts never ride the mail stack they watch.** The delivery channel must be non-mail (C24 decision pending; recommendation: the consumer's existing Discord path). |
| Standing rule | **The monitors are monitored** (dead-man switch): every checker must itself emit a heartbeat or be covered by an `absent()`-style rule (M13). |

## 1. Severity taxonomy

| Severity | Meaning | Reaction | Channel |
| -------- | ------- | -------- | ------- |
| CRITICAL | Mail is not flowing or data is at risk (queue age high, canary broken, backup stale beyond RPO, cert expired) | Wake-up | Non-mail push (C24) |
| WARNING | Degraded but flowing (auth-failure burst, TLS-RPT failure spike, disk > 80%, quota pressure, report freshness lag) | Same-day | Non-mail push (C24) |
| INFO | Normal-but-notable (new DMARC sender org, new TLS-RPT reporter, deploy/reload happened) | Digest | Channel digest (C24) |

## 2. Signal inventory (wrapper-side sources)

| # | Signal | Source (verified) | Status | Alert condition (spec) | Sev |
| - | ------ | ----------------- | ------ | ---------------------- | --- |
| 1 | Metrics endpoint | `metrics.prometheus.enable`, `/metrics/prometheus` on the HTTP listener (README ledger 2026-09-22; e2e-asserted 200) | **AVAILABLE** (e2e asserts; wrapper exposes passthrough) | scrape by consumer; `absent()` dead-man | CRITICAL |
| 2 | Queue depth / age | `/metrics/prometheus` series (names to be transcribed from a live e2e metrics dump before rules are written - no assertion without a transcript) | **SPEC ONLY** (M12 follow-up; consumer rules) | `queue_oldest_message_age > 1h` while queue non-empty | CRITICAL |
| 3 | Over-quota retry-forever | same queue series (README ledger: over-quota mail retries forever, `Message rescheduled for delivery`) | **SPEC ONLY** | queue age high + recipient quota near limit | WARNING |
| 4 | Failed auth burst | `tracing.level.auth` (journal) or telemetry counters - source verified 0.15.5; pick ONE source at wiring time | **SPEC ONLY** (M15) | > N failed logins / 5 min per remote IP | WARNING |
| 5 | SMTP TLS-RPT failures | parsedmarc `smtp_tls.json` sink (`application/tlsrpt+json` rides the rua mailbox poll - verified + e2e-asserted 2026-09-22) | **COLLECTED** (e2e green) | new `certificate-expired`/`validation-failure` entries with failed-session-count > 0 | WARNING |
| 6 | DMARC aggregate anomalies | parsedmarc `aggregate.json` sink | **COLLECTED** (e2e green) | new sending org / policy domain; rua volume drops to zero for a domain | WARNING/INFO |
| 7 | Report freshness | mtime of `aggregate.json` / parsedmarc unit liveness | **SPEC ONLY** (M13/M23; dedupe against the consumer registry's `backup.maxAgeHours`) | mtime older than 48 h | WARNING |
| 8 | Backup freshness + restore drill | consumer backup-coordination; repo documents the `--export`/`--import` drill | **CONSUMER LAYER** (D1-gated build-out, M23) | recovery-age key exceeds RPO | CRITICAL |
| 9 | External reachability (STARTTLS :25, implicit TLS :993, cert expiry) | Gatus external checks | **CONSUMER LAYER** (M13 spec) | connect/verify failure; cert < 14 d | CRITICAL/WARNING |
| 10 | Round-trip canary (send -> receive SLO) | M18 design (vantage = C29 decision; recommendation evo-x2 timer) | **DESIGN PENDING DECISION** | delivery SLO breach (e.g. > 10 min) | CRITICAL |
| 11 | Capacity: disk + per-mailbox quota | `/metrics` series probe + quota principal fields | **SPEC ONLY** (M12/M17) | disk > 80 %; mailbox > 80 % quota | WARNING |
| 12 | Audit trail | NO audit-log knob exists in 0.15.5 (README ledger) - `tracing.level.*` + journald retention is the surface | **DOCUMENTED** | (no alert; journald retention is consumer policy) | INFO |
| 13 | Dead-man of parsedmarc + canary | systemd unit states + heartbeat | **SPEC ONLY** (M13) | unit inactive / heartbeat absent 2 periods | CRITICAL |

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

The channel decision, vantage decision, and any consumer wiring land via
`docs/planning/decision-batch.md` (C24, C29) - answer there and the
SPEC ONLY rows graduate into TODO_LIST work items.
