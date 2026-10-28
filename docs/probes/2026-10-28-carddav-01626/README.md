# CardDAV probe re-baseline — Stalwart 0.16.26 (2026-10-28)

Owner verdict (g/3 of the pin-advance session report): re-run the
CardDAV probe suite on 0.16.26 to re-pin the INBOXCLEAN/CRM dialect
claims after the fe132422 advance (stalwart_0_16 0.16.22 -> 0.16.26).

## Setup

- Demo VM (`nixosConfigurations.demo` via `extendModules`, FIFO console)
  on the existing demo disk; Stalwart **0.16.26** (`stalwart --version`
  in-guest). Host port **28080** -> guest 8080 (18080 was squatted by an
  unrelated `webphone` process; the probe copy in this dir is the 10-19
  script with only `PORT` changed - diff it to verify).
- `stalwart-cpu-preflight.service` (new in the wrapper this session):
  **active, Result=success** on `-cpu max` — the first live proof of the
  x86-64-v2 preflight. Development note: the first boot caught a
  false-positive (SSE3 is named `pni` in /proc/cpuinfo; the substring
  "sse3" only ever occurs inside "ssse3") — fixed before this run;
  excerpt in `vm-console-excerpt.log`.

## Verdict

**17/18 PASS — the 0.16.22 baseline reproduced unchanged.** The one FAIL
is the SAME genuine server fact as the 2026-10-19 baseline (T04.4: a
garbage non-vCard PUT is accepted with 201 instead of a 4xx — see the
10-19 README verdict 4; not a regression, dialect-identical on 0.16.26).

Covered and PASS: well-known redirect, principal + addressbook-home-set,
book enumeration, MKCOL, PUT v4.0 + v3.0 round-trip, supported-report-set
shape, addressbook-query (text-match + param-filter + anyof/allof),
multiget, sync-collection round-trip (token advances), duplicate-UID
rejection, ETag If-Match stale-412 + matching-2xx.

## Files

- `carddav_probe.py` — the 10-19 suite, PORT=28080 only.
- `carddav-probe.log` — full transcript (18 verdicts).
- `vm-console-excerpt.log` — preflight/stalwart/version evidence.
