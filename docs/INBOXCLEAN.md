# InboxClean ↔ nix-email JMAP contract

The server-side counterpart of InboxClean's
[`docs/spec/jmap-spike.md`](https://github.com/LarsArtmann/InboxClean)
(M12 spike, ADR-023 "JMAP over IMAP"). Everything here is
**live-verified against the pinned binary** — each claim names its
transcript under `docs/probes/2026-10-05-jmap-demo-vm/` (probes run
2026-10-05 against the demo VM, Stalwart **0.15.5** as packaged by the
pinned nixpkgs rev). The repo's transcript rule applies across the
boundary: a claim without a transcript is a guess, and a pin advance
that touches Stalwart re-runs the probe (see "Re-verification" below).

> Version note: InboxClean's spike header says "Stalwart v1.0.0". The
> pinned binary self-reports and packages as **0.15.5**
> (`/nix/store/*-stalwart-0.15.5/bin/stalwart`; `service.version` string
> in the binary; nixpkgs package name). Treat 0.15.5 as the contract
> version.

## Endpoints and auth (demo VM posture)

- Discovery: `GET /.well-known/jmap` with HTTP Basic auth returns the
  session document. Unauthenticated requests still return 200 with
  **empty** `accounts` (matches InboxClean F056).
- **Basic-auth username = the full principal NAME**
  (`demo@mail.demo.invalid`), not a local part — same name-resolution
  rule the README ledger records for IMAP LOGIN
  (`session-user.json`: `jmap-probe@mail.demo.invalid` / `demo` → 200;
  bare `jmap-probe` → 401).
- The session's `apiUrl`/`eventSourceUrl`/`uploadUrl`/`downloadUrl` are
  **hostname-based** (`http://mail.demo.invalid:8080/...`). A client
  reaching the VM over the host forward MUST rewrite the host to
  `127.0.0.1:18080` before use (InboxClean spike already does this;
  `mailbox-probe.json` + `push-event.txt` were all captured over the
  rewritten URLs). In production the same rewrite is the reverse
  proxy's job — keep the loopback bind and let the proxy own TLS.
- Principal provisioning (server-side recipe, mirrors the demo
  oneshot): `POST /api/principal` with `type: individual`,
  `roles: ["user"]` (REQUIRED or submission is refused — README
  ledger), `emails`, and a `secrets` array carrying the sha512-crypt
  hash. Verified live: `create-probe-user.txt` (200, `data:4`).

## Capabilities (live-verified, `session-admin.json` / `session-user.json`)

Server-level: `jmap:core`, `jmap:mail`, `jmap:submission`, `jmap:blob`,
`jmap:websocket`, `jmap:sieve`, `jmap:vacationresponse`, `jmap:quota`,
`jmap:principals` (+`:availability`), `jmap:calendars` (+`:parse`),
`jmap:contacts` (+`:parse`), `jmap:filenode`.

Account-level for a `roles: ["user"]` principal: the same list minus
`jmap:quota` and the principals/availability pair (admin-only) — the
delta InboxClean's adapter may rely on: **mail/submission/blob/websocket
are present on plain user accounts**.

InboxClean-relevant core limits (from their F056, unchanged on this
pin): `maxCallsInRequest` 16, `maxObjectsInGet/Set` 500, upload cap
50 MB.

## Push vs poll (the sync verdict, probe 2026-10-05)

**Verdict: push works and is cheap to consume — use push for liveness,
keep one poll sweep as startup/fallback. Evidence:**

- `GET /jmap/eventsource/?types=Email` (or `types=*`) returns
  `200 text/event-stream` and, on a delivered message, emits an
  RFC 8620 §7.1 `StateChange` event naming the account with per-type
  state strings:

  ```
  event: state
  data: {"@type":"StateChange","changed":{"e":{"Thread":"saq","Mailbox":"saq","EmailDelivery":"saq","Email":"saq"}}}
  ```

  (`push-event.txt`: stream opened, SMTP delivery via :2525, event
  observed ~5 s later; the delivered message is then visible to
  `Email/query` — `email-after-push.json`.)
- **Parameter quirk (pin-specific):** the session template advertises
  `{types}`, `{closeafter}`, `{ping}`, but 0.15.5 answers
  `400 Invalid parameters` when `closeafter` or `ping` are present at
  any value; only `types` is accepted (matrix-probed, both user and
  admin). Clients must send `?types=<comma-list-or-*>` alone and treat
  disconnects as the closeafter signal.
- `urn:ietf:params:jmap:websocket` (`/jmap/ws`) is the other push
  channel; EventSource is the simpler one for a spike-grade consumer.
- Poll parity: `Email/query` carries `queryState` and
  `canCalculateChanges: true` (InboxClean F057), so
  `Email/query`+`Email/changes` incremental sync remains the fallback
  and the startup path.

## TLS posture delta (demo vs production)

The demo VM serves **plain HTTP** behind the host forward — acceptable
ONLY for the throwaway `.invalid` VM. Production (the mail-server
wrapper) terminates ACME TLS on the same listener, and neither
InboxClean nor parsedmarc should ever disable certificate verification:
the parsedmarc e2e runs with DEFAULT verification against a
self-signed-but-properly-SAN'd fixture, so the client side has no
skip-verify knob to reach for. The adapter's TLS config should be
"system trust store, SNI = the real hostname", demoing only over the
plain-HTTP forward.

## Label/keyword mapping (server side of InboxClean's F062 table)

- Gmail-style labels → JMAP **custom mailboxes** (`Mailbox/set`
  create/rename/destroy) plus **keywords** for flags:
  `$seen` (read), `$flagged` (star), `$junk`, `$answered`,
  `$forwarded` — null removes a keyword.
- Inbox is a mailbox with `role: "inbox"`, not "absence of labels";
  junk is the `role: "junk"` mailbox AND the `$junk` keyword AND
  `X-Spam-Status` (the demo files unauthenticated inbound there — the
  spam filter is real, README ledger).
- System roles on a fresh account: `inbox`, `trash`, `junk`, `drafts`,
  `sent` (`mailbox-probe.json`).

## Re-verification (when does this doc go stale?)

Any nixpkgs pin advance that moves `services.stalwart` past 0.15.5
invalidates every wire claim here. Re-run the probe set (boot
`nix run .#vm`, re-capture the four transcripts, diff capabilities and
the eventsource parameter matrix) before shipping the bump — the
pin-advance runbook (README) owns the procedure; this doc owns the
wire-level expectations.
