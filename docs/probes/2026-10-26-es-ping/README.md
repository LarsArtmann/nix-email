# EventSource `ping` parameter probe (demo VM, 0.16.22) - 2026-10-26

Closes the last unprobed 0.16 JMAP EventSource quirk (TODO "EventSource
ping parameter probe"; INBOXCLEAN.md parameter matrix).

## Verdict

On 0.16.22 the 0.15.5 blanket `400 Invalid parameters` on `ping` is GONE
for numeric values - but the keep-alive behavior the parameter promises
is NOT observable on the wire:

| shape                                  | result                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------ |
| `ping=100` (100 ms), 12 s, types=Email | 200 OK, ZERO keep-alive comments                                                           |
| `ping=2000`, 14 s, types=Email         | 200 OK, ZERO keep-alive comments                                                           |
| `ping=5000`, 35 s, types=Email         | 200 OK, ZERO keep-alive comments                                                           |
| `ping=1000`, 12 s, types=*             | 200 OK, ZERO keep-alive comments                                                           |
| `ping=0`                               | 200 OK (accepted)                                                                          |
| `ping=abc`                             | 400 `Invalid parameters` ("could not be parsed")                                           |
| no `ping` (control), 14 s              | 200 OK, zero comments (matches the 2026-10-18 40 s window: only the state event, no pings) |
| `closeafter=no` regression guard       | 200 OK (still accepted)                                                                    |

So: `ping` is PARSED (non-numeric rejected with 400) but INERT - no SSE
comment (`: ping` class), no `event:` frame, at any cadence down to
100 ms. Consumers (InboxClean) must NOT rely on `ping` for liveness;
connection liveness stays the consumer's own timeout/reconnect logic.

## Method

`es_ping_probe.py` (in this dir) - same basic-auth + stream pattern as
the 2026-10-18 `es_probe.py`, parameterized. The demo VM ran at
127.0.0.1:18080 (`nix run .#vm`), probe from the host against the
forwarded port, creds from the README quickstart. Raw logs:
`ping-mode.log`, `control-mode.log`, `bad-mode.log`, `ping-100ms.log`,
`ping-5s-35s.log`, `ping-star.log`.
