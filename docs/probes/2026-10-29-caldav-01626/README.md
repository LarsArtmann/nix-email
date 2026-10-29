# CalDAV probe suite — Stalwart 0.16.26 (2026-10-29)

The GATE artifact of the Stalwart single-truth decision (SystemNix
`docs/planning/2026-10-29_22-11_stalwart-single-truth-pareto-execution-plan.md`
tasks 3-5): CalDAV was the one unmeasured surface before Stalwart may own
calendars (CardDAV is probe-pinned at 17/18 PASS on the same pin,
`../2026-10-28-carddav-01626/`).

## Setup

- Demo VM (`nixosConfigurations.demo`, `nix run .#vm`) on the existing demo
  disk; Stalwart **0.16.26**. Host port **28080** -> guest 8080 (the 10-28
  session's free-port finding; override with `CALDAV_PROBE_PORT`).
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

**PENDING — not yet run** (authored during the 2026-10-29 IO storm; the demo
VM boot is admission-gated until PSI calms). This section fills with the
PASS/FAIL table + known-deviance list after the first run; the FEATURES.md
CalDAV row and the plan's GO/NO-GO gate (task 5.4) key off it.

## Files

- `caldav_probe.py` — the suite (14 verdicts, stdlib only).
- `caldav-probe.log` — full transcript (added by the run).
- `vm-console-excerpt.log` — boot/version evidence (added by the run).
