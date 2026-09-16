<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.
>
> Last verification sweep: **2026-09-16 (post-noon)** - native-ingestion
> live probe GREEN in the VM (store write+read verified; endpoint trap
> ledgered), relay-SASL E2E green, tag trigger + branch protection + TLS
> positive assertion verified shipped (rows removed), filing rows collapsed
> into one re-check row, master push debt cleared (bc7e954). Previous full
> AUDIT: 2026-09-16 morning (all 21 historical snapshots annotated and
> archived). The D1/D2/Q6 user decisions gate everything in ROADMAP, not
> here.

## Status legend

| Status           | Meaning                                                 |
| ---------------- | ------------------------------------------------------- |
| 🔴 `TODO`        | Not started. Needs doing.                               |
| 🟡 `IN_PROGRESS` | Actively being worked on.                               |
| 🔵 `BLOCKED`     | Cannot proceed; external dependency or decision needed. |
| 🟢 `DONE`        | Completed. Remove from this list and log in CHANGELOG.  |

## High Impact

| Task                                                                                                                                                                                  | Status    | Impact | Effort | Evidence                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| Re-check the four upstream filings for maintainer responses: nixpkgs #563651, #563652, #563777 + mjs/imapclient #662 (all OPEN, zero responses at 2026-09-16 ~12:00; #563777 and #662 filed by session 4 - the former "file it" rows are done) | 🔴 `TODO` | Med    | 10m    | `gh issue view` state check 2026-09-16 (12:54 report §f/10)                                                                         |

## Medium Impact

| Task                                                                                                                 | Status              | Impact | Effort | Evidence                                                                                                                                  |
| -------------------------------------------------------------------------------------------------------------------- | ------------------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Verify Renovate activates on the pushed repo and handles TAG pins (SystemNix pins `v0.2.0`), incl. the approval gate | 🔴 `TODO`           | Med    | 20m    | `renovate.json` (nix approval-gated, actions enabled); Dependabot now covers github-actions weekly (`.github/dependabot.yml`, 2026-09-16) |
| Lock-rev/narHash mention in release notes (or attached as release asset evidence)                                    | 🔴 `TODO`           | Med    | 10m    | `gh release list` shows both releases without rev pins (02-08 report §f/18)                                                               |

## Low Impact

| Task                                                                                                                              | Status    | Impact | Effort | Evidence                                                                                            |
| --------------------------------------------------------------------------------------------------------------------------------- | --------- | ------ | ------ | --------------------------------------------------------------------------------------------------- |
| DKIM keygen via `POST /api/dkim` + sign test leg (mirrors the webadmin flow; current test uses declarative `signature.<id>` only) | 🔴 `TODO` | Low    | 30m    | `tests/stalwart-e2e.nix` DKIM subtest; ROADMAP theme 1 has the automation idea                      |
| DKIM ed25519 second-signature test leg (the default sign expression emits two ids; only rsa is asserted)                          | 🔴 `TODO` | Low    | 20m    | README ledger `auth.dkim.sign` entry vs `tests/stalwart-e2e.nix`                                    |
| Quota semantics (accepted-at-SMTP, retried forever) into the wrapper option docs, not just test comments + ledger                 | 🔴 `TODO` | Low    | 15m    | grep `quota` in `modules/mail-server.nix` = 0 hits (2026-09-16); facts live in README ledger + test |
| dmarc-eval: assert `settings.general.offline` passthrough (the wrapper's settings contract)                                       | 🔴 `TODO` | Low    | 15m    | `tests/dmarc-eval.nix` has no offline assertion (10-41 report §f/31)                                |
| dmarc-eval: option-docs rendering drift check (wrapper output survives `nixosOption` docs rendering)                              | 🔴 `TODO` | Low    | 15m    | never built (19-39 report §f/19)                                                                    |
| parsedmarc `[reports]`/output retention option docs (disk-growth policy for the JSON/CSV sink)                                    | 🔴 `TODO` | Low    | 15m    | `modules/dmarc-monitor.nix` has no retention guidance (19-39 report §f/42)                          |
| CONTRIBUTING: add the d2 regen command (`d2 --layout=elk`) for the architecture SVGs                                              | 🔴 `TODO` | Low    | 10m    | `CONTRIBUTING.md` lacks it; SVGs re-rendered manually 2026-09-15                                    |
| README: 3-line nixos-mailserver lessons note (thin-wrapper doctrine validated by their backup/monitoring-option removal)          | 🔴 `TODO` | Low    | 10m    | 19-39 report §f/49; the study exists only in session history                                        |
| actionlint CI step alongside the YAML parse (catches expression typos YAML parsing cannot)                                        | 🔴 `TODO` | Low    | 15m    | 18-17 report §f/11; not in `.github/workflows/ci.yml` (2026-09-16)                                  |
| CI: `--gc-roots` (or equivalent) so store paths survive GC between check and debug                                                | 🔴 `TODO` | Low    | 15m    | 19-39 report §f/20; never addressed                                                                 |
| Catch-all + strict-rejection coexistence warning (product-shape question; low priority)                                           | 🔴 `TODO` | Low    | 15m    | 17-05 report §f/24; README ledger documents the test-ordering trap only                             |
| mailsuite upstream note: propose a knob to disable auto-STARTTLS (the trap generalizes to any cert-less IMAP server)              | 🔴 `TODO` | Low    | 20m    | 17-05 report §f/36; README ledger carries mailsuite/imap.py:284                                     |

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
| Stalwart upstream feature request: declarative server-side Junk filing (only if ROADMAP Q6 lands on option d)                                                                          | 🔵 `BLOCKED` (ROADMAP Q6 verdict)                         | Low    | 30m    | 19-52 report §f/7; the sieve-wall ledger entry is the evidence base                                            |
| GitHub: enable Discussions or keep issues-only                                                                                                                                         | 🔵 `BLOCKED` (user preference)                            | Low    | 5m     | 06-48 report §f/40                                                                                             |
