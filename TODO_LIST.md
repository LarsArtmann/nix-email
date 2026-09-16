<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.
>
> Last verification sweep: **2026-09-16 (late evening, docs-health AUDIT)** -
> all seven 2026-09-16 status reports annotated inline and archived; their
> open items re-verified against the tree and harvested here (reload
> assertion, pre-push hook, 0.3.0 release, protection policy, hygiene
> bundle). PR #1 merged 16:08 UTC - the 0.3.0 gate cleared. The D1/D2/Q6
> user decisions gate everything in ROADMAP, not here.

## Status legend

| Status           | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                               |
| 🟡 `IN_PROGRESS` | Actively being worked on.                               |
| 🔵 `BLOCKED`     | Cannot proceed; external dependency or decision needed. |
| 🟢 `DONE`        | Completed. Remove from this list and log in CHANGELOG.  |

## High Impact

| Task                                                                                                                                                                                                    | Status    | Impact | Effort | Evidence                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ------ | ------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Cut release 0.3.0: cut the CHANGELOG `[Unreleased]` section, tag `v0.3.0` (CI now runs on `v*` tags), release notes with the exact nixpkgs lock `rev`/`narHash` (v0.1.0/v0.2.0 both shipped `eaad089…`) | 🔴 `TODO` | High   | 1h     | UNBLOCKED 2026-09-16: dependabot PR #1 MERGED (16:08 UTC) - the last gate the 18-03 report waited on; `[Unreleased]` is thick (relay, native ingestion, DKIM dual-sign, pipe-lint, devShell) |

## Medium Impact

| Task                                                                                                                                                                                                                                                                     | Status    | Impact | Effort | Evidence                                                                                                                          |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- | ------ | ------ | --------------------------------------------------------------------------------------------------------------------------------- |
| Watch the four upstream filings for maintainer responses: nixpkgs #563651, #563652, #563777 + mjs/imapclient #662 (dotlambda's "patch only with an upstream PR first" is answered by mjs/imapclient #663 - re-checked OPEN/unmerged 2026-09-16 evening; watch the merge) | 🔴 `TODO` | Med    | 10m    | `gh` re-checks 2026-09-16 (16-33 report §a; #663 state verified this sweep)                                                       |
| Assert the `/api/reload` precondition directly in the DKIM dual-sign subtest: `jq -e '.data.errors \| length == 0'` on the reload response - a re-broken reload then fails HERE, not one step later via "DKIM signer not found"                                          | 🔴 `TODO` | Med    | 10m    | `tests/stalwart-e2e.nix:518` cats the response but no `.data.errors` assertion exists (rg: 0 hits, 2026-09-16); 18-03 report §e/4 |
| Git pre-push hook running `nix fmt -- . --check` (repo-shipped script + `core.hooksPath`, plus a CONTRIBUTING note) - kills the unformatted-push CI-red class (two red master runs on 2026-09-16, ~13 min public red)                                                    | 🔴 `TODO` | Med    | 15m    | 18-03 report §d/1; AGENTS.md fmt-before-yield rule is prose - the hook makes it mechanical                                        |

## Low Impact (hygiene)

| Task                                                                                                                                                         | Status    | Impact | Effort | Evidence                                                                                                             |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------- | ------ | ------ | -------------------------------------------------------------------------------------------------------------------- |
| Investigate the nixpkgs `dovecot2.protocols` rename warning emitted during our check evals - ours to fix, or nixpkgs-internal noise?                         | 🔴 `TODO` | Low    | 30m    | observed in gate logs 2026-09-16 (08-03 report §f/4)                                                                 |
| Root-cause which formatter rewrote `{ ... }` to `{...}` in `tests/*.nix` (dprint is documented json/yaml/markdown-only; alejandra owns `nix fmt`)            | 🔴 `TODO` | Low    | 30m    | 08-03 report §f/5; identify the foreign editor before trusting style gates                                           |
| Re-render both architecture SVGs together (`d2 --layout=elk`, CONTRIBUTING) + full 36-label d2↔SVG re-diff (geometry drift from the 2026-09-16 label rewrap) | 🔴 `TODO` | Low    | 15m    | 08-08 report §b/1 + §f/12-14: only a 1-label spot-check plus the inherited 17-59 diff stand behind "content current" |

## Gated on D1 (live enablement)

| Task                                                                                                                                                                   | Status                            | Impact | Effort | Evidence                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------- | ------ | ------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| dmarc-monitor live validation against a real IMAP mailbox (first poll, JSON/CSV output lands)                                                                          | 🔵 `BLOCKED` (D1: rua mailbox)    | High   | 1h     | verified 2026-09-16: exercised by eval contract + parsedmarc-e2e VM test + SystemNix contract test; needs the D1 mailbox decision     |
| Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)                                                                                     | 🔵 `BLOCKED` (D1: live mailboxes) | Med    | 1h     | `docs/planning/archived/2026-09-15_19-23` §3 L22a; needs live mailboxes (D1)                                                          |
| Rotate the three placeholder secrets in SystemNix `platforms/nixos/secrets/nix-email.yaml` + confirm sops-key-audit flags them rotation-due before any live enablement | 🔵 `BLOCKED` (D1)                 | Med    | 20m    | verified 2026-09-16: file is sops-encrypted with `placeholder-rotate-before-enable-not-a-real-secret` values; nothing consumes it yet |

## Blocked on the user (no D1/D2 dependency)

| Task                                                                                                                                                                                                                                                                                          | Status                                                    | Impact | Effort | Evidence                                                                                                                     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------ | ------ | ---------------------------------------------------------------------------------------------------------------------------- |
| Resend SASL shape verification + one real Resend smoke (username/API-key-as-password against smtp.resend.com:587) - proves `relay.secretFile` against the actual smarthost                                                                                                                    | 🔵 `BLOCKED` (needs a Resend account/API key)             | High   | 30m    | 06-48 report §g/1: refused to guess-config the flagship use; eval + SASL E2E cover everything short of it                    |
| SystemNix: push the unpushed commits (pin-advance + parallel sessions' work), clear the CI debt (statix sweep, secret-scan `syn_` policy, 2 pin flips, gitleaks `rev=` allowlist), and sweep the worktree caches (`.cache/signoz-src`, `.cache/gatus-src`, `nixos.qcow2`)                     | 🔵 `BLOCKED` (push approval + cross-session coordination) | Med    | 2h     | 07-04 report §b/4: ≈47 commits ahead of origin; CI red for pre-existing reasons; cache list from 08-16 report §Self-Review/4 |
| Branch-protection policy: pushes currently BYPASS the required `nix flake check` (remote: "Bypassed rule violations") - keep the bypass for auto-commit-daemon velocity, or go strict (daemon pushes rejected until CI-green)?                                                                | 🔵 `BLOCKED` (user policy call)                           | Med    | 5m     | 18-03 report §g/3 + §f/23; bypass observed live 2026-09-16                                                                   |
| Renovate: install the GitHub app on LarsArtmann/nix-email or drop `renovate.json` - the app NEVER RAN on this repo (no Dependency-Dashboard issue, zero renovate branches/PRs, 2026-09-16); config itself is fine (nix approval-gated; its `github-actions` scope would duplicate Dependabot) | 🔵 `BLOCKED` (user decision: install-or-drop)             | Med    | 5m     | 2026-09-16 verdict in 16-33 report §a/11; Dependabot already covers github-actions                                           |
| mailsuite auto-STARTTLS opt-out issue: file the draft or skip it - all 5 verify-before-filing gates PASSED (no knob on master - imap.py byte-identical to 2.3.1; parsedmarc #534 is the same trap with the reporter quoting the same lines); draft is voice-checked and ready                 | 🔵 `BLOCKED` (user decision: file-or-skip)                | Low    | 5m     | draft at `docs/planning/mailsuite-starttls-issue-draft.md` (2026-09-16)                                                      |
| Stalwart upstream feature request: declarative server-side Junk filing (only if ROADMAP Q6 lands on option d)                                                                                                                                                                                 | 🔵 `BLOCKED` (ROADMAP Q6 verdict)                         | Low    | 30m    | 19-52 report §f/7; the sieve-wall ledger entry is the evidence base                                                          |
| GitHub: enable Discussions or keep issues-only                                                                                                                                                                                                                                                | 🔵 `BLOCKED` (user preference)                            | Low    | 5m     | 06-48 report §f/40                                                                                                           |
