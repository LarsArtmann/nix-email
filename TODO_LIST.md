<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.
>
> Last verification sweep: **2026-09-15** (evening execution pass of the
> Pareto master plan: release v0.1.0/v0.2.0 cut, SystemNix pin advanced to
> v0.2.0 with relay assertions restored, TLS IMAPS test variant, CI lockstep
> guard, nixpkgs issues #563651/#563652 filed, aarch64 posture decided
> documented-manual, pin-advance runbook + docs consolidation - all now in
> CHANGELOG `[0.2.0]`). Every executable unblocked task from the plan is
> done; what remains is user-gated (D1/D2, ANNOTATE scoping) or
> post-migration polish tracked in ROADMAP.

## Status legend

| Status           | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                               |
| 🟡 `IN_PROGRESS` | Actively being worked on.                               |
| 🔵 `BLOCKED`     | Cannot proceed; external dependency or decision needed. |
| 🟢 `DONE`        | Completed. Remove from this list and log in CHANGELOG.  |

## High Impact

| Task                                                                                                                             | Status                        | Impact | Effort | Evidence                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------ | ------ | --------------------------------------------------------------------------------------------------------------- |
| dmarc-monitor live validation against a real IMAP mailbox (first poll, JSON/CSV output lands)                                      | 🔵 `BLOCKED` (D1: rua mailbox) | High   | 1h     | verified 2026-09-15: exercised by eval contract + SystemNix contract test only; needs the D1 mailbox decision   |

## Medium Impact

| Task                                                                                                                             | Status                        | Impact | Effort | Evidence                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------ | ------ | --------------------------------------------------------------------------------------------------------------- |
| Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)                                                 | 🔵 `BLOCKED` (D1: live mailboxes) | Med | 1h     | verified 2026-09-15: `docs/planning/2026-09-14_18-37` R6; needs live mailboxes (D1)                              |
| docs-health ANNOTATE pass over `docs/status/` (resolve numbered items in place with `~~item~~ done at <hash>`); scoping needs the user to name the files/time range first | 🔴 `TODO` | Med | 1h | verified 2026-09-15: no report carries an inline resolution marker yet                                          |

## Gated on D1 (live enablement)

| Task                                                                                                                             | Status                        | Impact | Effort | Evidence                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------- | ------ | ------ | --------------------------------------------------------------------------------------------------------------- |
| Rotate the three placeholder secrets in SystemNix `platforms/nixos/secrets/nix-email.yaml` and confirm sops-key-audit surfaces them as rotation-due before any live enablement | 🔵 `BLOCKED` (D1) | Med | 20min | verified 2026-09-15: file is sops-encrypted with `placeholder-rotate-before-enable-not-a-real-secret` values; nothing consumes it yet |
