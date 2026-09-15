<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.
>
> Last full verification sweep: **2026-09-15** (docs-health pass). Every row
> below carries a `verified <date>` stamp; rows without a current stamp are
> the first thing the next sweep re-checks. The 2026-09-15 sweep deleted 29
> completed rows (all now in CHANGELOG `[Unreleased]`/`[0.1.0]`).

## Status legend

| Status           | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                               |
| 🟡 `IN_PROGRESS` | Actively being worked on.                               |
| 🔵 `BLOCKED`     | Cannot proceed; external dependency or decision needed. |
| 🟢 `DONE`        | Completed. Remove from this list and log in CHANGELOG.  |

## High Impact

| Task                                                                                                                                                    | Status       | Impact | Effort | Evidence                                                                                                                  |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------ | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| SystemNix: advance the `nix-email` pin past the relay-landing rev, then restore the relay-credential assertions in `tests/test-nix-email.nix` and delete the wrapper's option-existence guard (both mark the spot) | 🔴 `TODO` (blocked on the next nix-email push) | High | 30min  | verified 2026-09-15: wrapper guard + PIN NOTE in `modules/nixos/services/nix-email.nix` / SystemNix `tests/test-nix-email.nix` |
| dmarc-monitor live validation against a real IMAP mailbox (first poll, JSON/CSV output lands)                                                             | 🔵 `BLOCKED` (D1: rua mailbox) | High | 1h     | verified 2026-09-15: exercised by eval contract + SystemNix contract test only; needs the D1 mailbox decision |

## Medium Impact

| Task                                                                                                                                                    | Status       | Impact | Effort | Evidence                                                                                                                  |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------ | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)                                                                        | 🔵 `BLOCKED` (D1: live mailboxes) | Med | 1h     | verified 2026-09-15: `docs/planning/2026-09-14_18-37` R6; needs live mailboxes (D1) |
| aarch64 posture: actually run `stalwart-e2e` under qemu-aarch64 once (the x86_64-only loud documentation shipped; the run itself is still open)            | 🔴 `TODO`    | Med    | 30min  | verified 2026-09-15: `flake.nix` gates VM tests to x86_64 with the trap comment; no ARM run has ever happened |

## Low Impact

| Task                                                                                                                                                    | Status       | Impact | Effort | Evidence                                                                                                                  |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------ | ------ | --------------------------------------------------------------------------------------------------------------------------- |
| LICENSE: confirm the shipped MIT choice (file exists, `Copyright (c) 2026 Lars Artmann`; flipping is a one-file change)                                     | 🔵 `BLOCKED` (user confirmation) | Low | 5min   | verified 2026-09-15: `LICENSE` in tree; GitHub picks up MIT metadata on push |
