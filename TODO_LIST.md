<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.
>
> Last verification sweep: **2026-09-16 (evening)** - backlog burn: 11 rows
> closed green (filings re-check, d2 regen cmd, quota docs, parsedmarc
> retention, actionlint CI, 2 dmarc-eval assertions, release-note pins,
> GC-root verdict, Renovate verdict, nixos-mailserver lessons, catch-all
> docs) plus the DKIM dual-sign subtest green in the VM (the
> reload-after-keygen trap ledgered in tests/stalwart-e2e.nix). Rows
> deleted; Renovate + mailsuite moved to user-blocked. Previous sweep:
> 2026-09-16 post-noon. The D1/D2/Q6 user decisions gate everything in
> ROADMAP, not here.

## Status legend

| Status           | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                               |
| 🟡 `IN_PROGRESS` | Actively being worked on.                               |
| 🔵 `BLOCKED`     | Cannot proceed; external dependency or decision needed. |
| 🟢 `DONE`        | Completed. Remove from this list and log in CHANGELOG.  |

## Medium Impact

| Task                                                                                                                                                     | Status    | Impact | Effort | Evidence                                                                                                                              |
| -------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Watch the four upstream filings for maintainer responses: nixpkgs #563651, #563652, #563777 + mjs/imapclient #662 (2026-09-16: dotlambda answered #563652 "patch only with an upstream PR first"; mjs/imapclient #663 by a parallel session answers it - watch, do not act) | 🔴 `TODO` | Med    | 10m    | `gh issue view` re-check 2026-09-16 (16-33 report §a)                                                                                 |

## Gated on D1 (live enablement)

| Task                                                                                                                                                                   | Status                            | Impact | Effort | Evidence                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | ------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| dmarc-monitor live validation against a real IMAP mailbox (first poll, JSON/CSV output lands)                                                                          | 🔵 `BLOCKED` (D1: rua mailbox)    | High   | 1h     | verified 2026-09-16: exercised by eval contract + parsedmarc-e2e VM test + SystemNix contract test; needs the D1 mailbox decision     |
| Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)                                                                                     | 🔵 `BLOCKED` (D1: live mailboxes) | Med    | 1h     | `docs/planning/archived/2026-09-15_19-23` §3 L22a; needs live mailboxes (D1)                                                          |
| Rotate the three placeholder secrets in SystemNix `platforms/nixos/secrets/nix-email.yaml` + confirm sops-key-audit flags them rotation-due before any live enablement | 🔵 `BLOCKED` (D1)                 | Med    | 20m    | verified 2026-09-16: file is sops-encrypted with `placeholder-rotate-before-enable-not-a-real-secret` values; nothing consumes it yet |

## Blocked on the user (no D1/D2 dependency)

| Task                                                                                                                                                                                   | Status                                                    | Impact | Effort | Evidence                                                                                                       |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------ | ------ | -------------------------------------------------------------------------------------------------------------- |
| Resend SASL shape verification + one real Resend smoke (username/API-key-as-password against smtp.resend.com:587) - proves `relay.secretFile` against the actual smarthost             | 🔵 `BLOCKED` (needs a Resend account/API key)             | High   | 30m    | 06-48 report §g/1: refused to guess-config the flagship use; eval + SASL E2E cover everything short of it      |
| SystemNix: push the unpushed commits (pin-advance + a parallel session's work) and clear the CI debt (statix sweep, secret-scan `syn_` policy, 2 pin flips, gitleaks `rev=` allowlist) | 🔵 `BLOCKED` (push approval + cross-session coordination) | Med    | 2h     | 07-04 report §b/4: ≈47 commits ahead of origin; CI red for pre-existing reasons                                |
| Renovate: install the GitHub app on LarsArtmann/nix-email or drop `renovate.json` - the app NEVER RAN on this repo (no Dependency-Dashboard issue, zero renovate branches/PRs, 2026-09-16); config itself is fine (nix approval-gated, actions enabled) | 🔵 `BLOCKED` (user decision: install-or-drop)   | Med    | 5m     | 2026-09-16 verdict in 16-33 report §a/11; Dependabot already covers github-actions                             |
| mailsuite auto-STARTTLS opt-out issue: file the draft or skip it - all 5 verify-before-filing gates PASSED (no knob on master - imap.py byte-identical to 2.3.1; parsedmarc #534 is the same trap with the reporter quoting the same lines); draft is voice-checked and ready | 🔵 `BLOCKED` (user decision: file-or-skip) | Low    | 5m     | draft at `docs/planning/mailsuite-starttls-issue-draft.md` (2026-09-16)                                        |
| Stalwart upstream feature request: declarative server-side Junk filing (only if ROADMAP Q6 lands on option d)                                                                          | 🔵 `BLOCKED` (ROADMAP Q6 verdict)                         | Low    | 30m    | 19-52 report §f/7; the sieve-wall ledger entry is the evidence base                                            |
| GitHub: enable Discussions or keep issues-only                                                                                                                                         | 🔵 `BLOCKED` (user preference)                            | Low    | 5m     | 06-48 report §f/40                                                                                             |
