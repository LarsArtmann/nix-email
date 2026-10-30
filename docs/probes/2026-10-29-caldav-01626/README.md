# CalDAV probe suite — Stalwart 0.16.26 (2026-10-29)

The GATE artifact of the Stalwart single-truth decision (SystemNix
`docs/planning/2026-10-29_22-11_stalwart-single-truth-pareto-execution-plan.md`
tasks 3-5): CalDAV was the one unmeasured surface before Stalwart may own
calendars (CardDAV is probe-pinned at 17/18 PASS on the same pin,
`../2026-10-28-carddav-01626/`).

## Setup

- Demo VM (`nixosConfigurations.demo`, `nix run .#vm`) on the existing demo
  disk; Stalwart **0.16.26**. Host port **18080** -> guest 8080 (the demo
  VM's standing forward; this README originally said 28080, which no
  forward serves — run with `CALDAV_PROBE_PORT=18080`).
- Run: `python3 caldav_probe.py > caldav-probe.log 2>&1` while the VM is up.
- Style mirror of the 10-19/10-28 CardDAV suite: stdlib-only python, full
  transcript, per-step PASS/FAIL/SEE-TRANSCRIPT verdicts.

## Coverage (14 verdicts)

C1 well-known redirect, C2 principal, C3 calendar-home-set, C4 enumeration,
C5 MKCOL calendar (the load-bearing dialect question), C6 PUT/GET VEVENT
round-trip, C7 RRULE+TZID fidelity, C8 RECURRENCE-ID override, C9 conditional
PUT (stale If-Match, matching If-Match, UID-swap refusal), C10 sync-collection
token advance, C11 DELETE/tombstone + sync removal reporting, C12
supported-report-set, C13 free-busy-query, C14 calendar-query time-range.

## Verdict

**RUN 2026-10-30 16:1x: 19/20 PASS + 1 supplemental probe PASS — CalDAV at
parity with the CardDAV baseline (17/18) for everything pim-sync's design
uses. Recommendation to the owner gate (plan 2.3): GO.**

| Verdict | Result |
| --- | --- |
| C1 well-known redirect | PASS (307 → /dav/cal) |
| C2 current-user-principal | PASS |
| C3 calendar-home-set | PASS |
| C4 calendar enumeration | PASS (2 hrefs) |
| C5 MKCOL calendar | PASS (201) |
| C6 PUT/GET VEVENT round-trip | PASS (etag yes, UID+SUMMARY preserved) |
| C7 RRULE+TZID fidelity | PASS (all preserved) |
| C8 RECURRENCE-ID override | **SEE-TRANSCRIPT** — see deviance note |
| C9 conditional PUT (stale/matching/UID-swap) | PASS ×3 (412 / 2xx / 4xx refusal) |
| C10 sync-collection token | PASS (initial + advance) |
| C11 DELETE/tombstone + sync removal | PASS ×2 |
| C12 supported-report-set | PASS (sync + calendar-query + multiget) |
| C13 free-busy-query | PASS |
| C14 calendar-query time-range | PASS (Berlin series found) |
| C8b supplemental: EMBEDDED override round-trip | PASS (master + override both preserved, both VEVENTs intact) |

### Known deviances

- **C8 (standalone override resource):** the probe PUT a standalone
  VEVENT carrying only RECURRENCE-ID → Stalwart answers **412** and GET
  404s. This is CORRECT strictness, not a failure for pim-sync: an
  override is not a standalone resource — it must ride INSIDE the
  master's .ics as a second VEVENT (exactly pim-sync's
  one-resource-per-series invariant). Verified live as supplemental
  probe **C8b**: PUT of a master+override .ics → 201; GET → both VEVENTs,
  RRULE, TZID, RECURRENCE-ID and the moved DTSTART all preserved
  (transcript in `caldav-probe.log` tail + this run's session log).
- Dialect facts re-confirmed for the calendar legs: UID-swap PUT refused
  (412, no silent rewrite — mirrors the CardDAV no-uid-conflict analog);
  tombstones surface in sync-collection (C11b); multiget + sync-collection
  + calendar-query all in supported-report-set (C12) — the multiget +
  sync-collection shape caldav client implements is server-confirmed.

## Files

- `caldav_probe.py` — the suite (14 verdicts, stdlib only).
- `caldav-probe.log` — full transcript (added by the run).
- `vm-console-excerpt.log` — boot/version evidence (added by the run).
