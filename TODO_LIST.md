<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.
>
> Last verification sweep: **2026-09-15** (docs-health pass). Every row below
> carries a `verified <date>` stamp; rows without a current stamp are the first
> thing the next sweep re-checks. The 2026-09-15 pass deleted 29 completed rows
> (all now in CHANGELOG `[Unreleased]`/`[0.1.0]`), then HARVESTed the
> `17:05` status report's §f into the rows below and dropped the items that
> sweep proved already done (CONTRIBUTING pipe rule, by-NAME login assertion,
> stale spam-claim sweep, TODO_LIST aarch64 rewording).

## Status legend

| Status           | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                               |
| 🟡 `IN_PROGRESS` | Actively being worked on.                               |
| 🔵 `BLOCKED`     | Cannot proceed; external dependency or decision needed. |
| 🟢 `DONE`        | Completed. Remove from this list and log in CHANGELOG.  |

## High Impact

| Task                                                                                                                                                                          | Status                              | Impact | Effort | Evidence                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SystemNix: advance the `nix-email` pin past the relay-landing rev, then restore the relay-credential assertions in `tests/test-nix-email.nix` and delete the wrapper's option-existence guard (both mark the spot) | 🔴 `TODO` (blocked on the next nix-email push) | High   | 30min  | verified 2026-09-15: wrapper guard + PIN NOTE in SystemNix `modules/nixos/services/nix-email.nix` / `tests/test-nix-email.nix`                                            |
| dmarc-monitor live validation against a real IMAP mailbox (first poll, JSON/CSV output lands)                                                                                  | 🔵 `BLOCKED` (D1: rua mailbox)       | High   | 1h     | verified 2026-09-15: exercised by eval contract + SystemNix contract test only; needs the D1 mailbox decision                                                             |
| Cut `v0.1.0`: move `[Unreleased]` into a dated section, tag, and open the GitHub release (CI's first real run rides the same push)                                              | 🔵 `BLOCKED` (push authorization)    | High   | 20min  | verified 2026-09-15: CHANGELOG has `[Unreleased]` + `[0.1.0]` but no tag/release exists; nothing is pushed (40 local commits ahead of origin)                             |

## Medium Impact

| Task                                                                                                                                                                          | Status                              | Impact | Effort | Evidence                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)                                                                                             | 🔵 `BLOCKED` (D1: live mailboxes)    | Med    | 1h     | verified 2026-09-15: `docs/planning/2026-09-14_18-37` R6; needs live mailboxes (D1)                                                                                       |
| Pin-advance runbook: one `docs/planning/` note with the bump procedure (both locks together, restore relay assertions, delete guard, `nix flake check` both repos) and the revert-condition checklist (nixpkgs ships imapclient >= 4.x; re-check the `[elasticsearch]` emission each bump - Renovate cannot watch python deps inside nixpkgs) | 🔴 `TODO`                            | Med    | 30min  | verified 2026-09-15: procedure exists only as prose across README ledger + module comments + SystemNix PIN NOTE                                                            |
| aarch64 posture: actually run `stalwart-e2e` once under qemu-aarch64 (the eval contract now builds green for aarch64; the VM test has still never run on ARM)                    | 🔴 `TODO`                            | Med    | 30min  | verified 2026-09-15: `nix build .#checks.aarch64-linux.dmarc-eval` → exit 0; `flake.nix` still gates VM tests to x86_64 with the trap comment                              |
| parsedmarc-e2e: cover a TLS-capable localMail variant (cert fixture) so the production-shaped TLS IMAP path is exercised, not just the plaintext VM fixture                        | 🔴 `TODO`                            | Med    | 1h     | verified 2026-09-15: fixture sets `ssl = "no"` because mailsuite auto-activates advertised STARTTLS (`mailsuite/imap.py:284`); no cert-capable variant exists               |
| docs-health ANNOTATE pass over `docs/status/` (resolve numbered items in place with `~~item~~ done at <hash>`); scoping needs the user to name the files/time range first         | 🔴 `TODO`                            | Med    | 1h     | verified 2026-09-15: `grep -rLn '~~' docs/status/` - no report carries an inline resolution marker today                                                                 |

## Low Impact

| Task                                                                                                                                                                          | Status                              | Impact | Effort | Evidence                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| LICENSE: confirm the shipped MIT choice (file exists, `Copyright (c) 2026 Lars Artmann`; flipping is a one-file change)                                                          | 🔵 `BLOCKED` (user confirmation)     | Low    | 5min   | verified 2026-09-15: `LICENSE` in tree; GitHub picks up MIT metadata on push                                                                                             |
| File the two verified upstream nixpkgs issues: (a) parsedmarc module emits a host-less `[elasticsearch]` section with `provision.elasticsearch = false`; (b) parsedmarc built against imapclient 3.1.0, broken on python 3.14. Filing needs authorization; the diagnosis is re-verified against CURRENT nixpkgs master (see evidence) | 🔴 `TODO`                            | Low    | 45min  | verified 2026-09-15 vs master: (a) still unfixed - `elasticsearch.ssl`/`.cert_path` defaults survive the same `filterAttrsRecursive` filter; (b) imapclient 4.0.1 DROPPED the `imap4.py` `open()` override that assigned `self.file`, but `imapclient.py` `starttls()` still assigns it, so 4.x on py3.14 still breaks the STARTTLS-upgrade path (`imaplib.py:337` is the read-only property) |
| CI lockstep guard: fail the flake when a check exists in `flake.nix` but is missing from CI's expected-checks list (today the list is hand-maintained in two places)              | 🔴 `TODO`                            | Low    | 30min  | verified 2026-09-15: CI hardcodes `dmarc-eval stalwart-e2e stalwart-relay-e2e parsedmarc-e2e`; `flake.nix` independently declares the same four                                     |
| parsedmarc-e2e: assert the report CSV row count (or a robust minimum size) instead of `test -s` only                                                                            | 🔴 `TODO`                            | Low    | 15min  | verified 2026-09-15: `tests/parsedmarc-e2e.nix` CSV subtest greps `example.com` and checks non-empty                                                                     |
| stalwart-e2e: prove the ~65 s negative-cache subtest cost is purely SPF/DNS timeouts (and leave it), so the runtime budget is documented rather than assumed                       | 🔴 `TODO`                            | Low    | 20min  | verified 2026-09-15: `ran out of time` notes in the resolver-bound subtests; no timing breakdown asserted                                                                    |
| README runbook: point the parsedmarc enablement checklist at the SystemNix wrapper (the runbook targets raw consumers today)                                                     | 🔴 `TODO`                            | Low    | 15min  | verified 2026-09-15: README runbook has the raw-consumer path only                                                                                                        |
| Consolidate the `mail-server.stateVersion` unit-name coupling (currently explained in three places) into one canonical note                                                      | 🔴 `TODO`                            | Low    | 20min  | verified 2026-09-15: README ledger + `modules/mail-server.nix` comment + AGENTS.md each restate it                                                                        |
| Pin discipline note: document why `nix-email` pins a hard rev while InboxClean uses `?ref=master`                                                                                | 🔴 `TODO`                            | Low    | 10min  | verified 2026-09-15: SystemNix `flake.nix` uses a rev for nix-email; the rationale lives only in the compat-doctrine comment                                             |
| Preserve the good VM debug script (wait_for_open_port per listener, one send + per-variant probes, journal dump) as a `tests/fixtures/` debug template                            | 🔴 `TODO`                            | Low    | 20min  | verified 2026-09-15: the working pattern is described in AGENTS.md but the script itself lived in `/tmp`                                                                   |

## Gated on D1 (live enablement)

| Task                                                                                                                                                                          | Status                              | Impact | Effort | Evidence                                                                                                                                                              |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Rotate the three placeholder secrets in SystemNix `platforms/nixos/secrets/nix-email.yaml` and confirm sops-key-audit surfaces them as rotation-due before any live enablement    | 🔵 `BLOCKED` (D1)                    | Med    | 20min  | verified 2026-09-15: file is sops-encrypted with `placeholder-rotate-before-enable-not-a-real-secret` values; nothing consumes it yet                                     |
