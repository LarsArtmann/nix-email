<!-- TODO_LIST.md - living document. Open, bounded work only.
     Completed items are DELETED (they live in CHANGELOG.md).
     Long-term vision and open questions live in ROADMAP.md. -->

# TODO List

> Short-term, actionable, bounded work items, verified against the actual code.
> Long-term vision and user decisions live in ROADMAP.md.
> Items are ranked by impact. Status is verified, not assumed.
>
> Last verification sweep: **2026-09-16** (full docs-health AUDIT: all 21
> historical snapshots annotated and archived; every open item from every
> report re-verified against the tree and routed here or to ROADMAP. The
> 2026-09-15 sweep's ANNOTATE row is done - scope was "all `2026-0*` files").
> The D1/D2/Q6 user decisions gate everything in ROADMAP, not here.

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
| File third nixpkgs issue: parsedmarc unit ships NO Restart policy (a poller daemon dies on one lost boot race; fixture carries Restart=on-failure as a local workaround)              | 🔴 `TODO` | High   | 30m    | re-confirmed 2026-09-16 grep of the pinned unit (report `2026-09-16_07-04` §5.3); draft died in /tmp once - write it in docs/ first |
| File the root bug upstream at mjs/imapclient: `starttls()` assigns read-only `imaplib.IMAP4.file` (fix = `_file`); also closes #563652's drift re-check                               | 🔴 `TODO` | High   | 30m    | verified still-broken on master 2026-09-16 via `gh api` (`imapclient/imapclient.py:387`, `starttls` at :361)                        |
| Live-probe native DMARC/ARF report ingestion in the stalwart-e2e VM (mail a report in, query the report store) - upgrades the 06a keep-both verdict from source-grade to ledger-grade | 🔴 `TODO` | High   | 30m    | `docs/planning/archived/2026-09-15_19-23` §10 06a: "no live probe was run"; README ledger entry carries the same caveat                      |

## Medium Impact

| Task                                                                                                                 | Status              | Impact | Effort | Evidence                                                                                                                                  |
| -------------------------------------------------------------------------------------------------------------------- | ------------------- | ------ | ------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Relay-SASL E2E variant (Mailpit with `--smtp-auth-file`): the SASL relay path is eval-asserted + auth-less E2E only  | 🔴 `TODO`           | Med    | 45m    | `tests/stalwart-relay-e2e.nix` (authless variant); FEATURES row notes the scope                                                           |
| CI trigger on tag pushes (`on: push: tags: v*`) - releases currently run no CI at all                                | 🔴 `TODO`           | Med    | 10m    | `.github/workflows/ci.yml:12-16` triggers on branch pushes only (verified 2026-09-16)                                                     |
| Branch protection on master requiring the CI check (user GitHub-settings action; badge already in README)            | 🔵 `BLOCKED` (user) | Med    | 10m    | `gh api .../branches/master/protection` → 404 "Branch not protected" (verified 2026-09-16)                                                |
| Verify Renovate activates on the pushed repo and handles TAG pins (SystemNix pins `v0.2.0`), incl. the approval gate | 🔴 `TODO`           | Med    | 20m    | `renovate.json` (nix approval-gated, actions enabled); Dependabot now covers github-actions weekly (`.github/dependabot.yml`, 2026-09-16) |
| TLS-node: assert the SUCCESSFUL TLS-handshake journal line, not just absence of failures                             | 🔴 `TODO`           | Med    | 20m    | `tests/parsedmarc-e2e.nix` TLS subtest asserts outcome only (02-08 report §f/17)                                                          |
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
| Migration tooling compare: stalwart-vandelay vs imapsync on scratch mailboxes (R6)                                                                                     | 🔵 `BLOCKED` (D1: live mailboxes) | Med    | 1h     | `docs/planning/archived/2026-09-15_19-23` §3 L22a; needs live mailboxes (D1)                                                                   |
| Rotate the three placeholder secrets in SystemNix `platforms/nixos/secrets/nix-email.yaml` + confirm sops-key-audit flags them rotation-due before any live enablement | 🔵 `BLOCKED` (D1)                 | Med    | 20m    | verified 2026-09-16: file is sops-encrypted with `placeholder-rotate-before-enable-not-a-real-secret` values; nothing consumes it yet |

## Blocked on the user (no D1/D2 dependency)

| Task                                                                                                                                                                                   | Status                                                    | Impact | Effort | Evidence                                                                                                       |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- | ------ | ------ | -------------------------------------------------------------------------------------------------------------- |
| Resend SASL shape verification + one real Resend smoke (username/API-key-as-password against smtp.resend.com:587) - proves `relay.secretFile` against the actual smarthost             | 🔵 `BLOCKED` (needs a Resend account/API key)             | High   | 30m    | 06-48 report §g/1: refused to guess-config the flagship use; eval + auth-less E2E cover everything short of it |
| Push nix-email master (2 unpushed commits + the working-tree ci.yml pipe-lint `\b`-fix awaiting its commit)                                                                            | 🔵 `BLOCKED` (push approval)                              | Med    | 5m     | `git status -sb` → ahead 2 + `M .github/workflows/ci.yml` (verified 2026-09-16)                                |
| SystemNix: push the unpushed commits (pin-advance + a parallel session's work) and clear the CI debt (statix sweep, secret-scan `syn_` policy, 2 pin flips, gitleaks `rev=` allowlist) | 🔵 `BLOCKED` (push approval + cross-session coordination) | Med    | 2h     | 07-04 report §b/4: ≈47 commits ahead of origin; CI red for pre-existing reasons                                |
| Stalwart upstream feature request: declarative server-side Junk filing (only if ROADMAP Q6 lands on option d)                                                                          | 🔵 `BLOCKED` (ROADMAP Q6 verdict)                         | Low    | 30m    | 19-52 report §f/7; the sieve-wall ledger entry is the evidence base                                            |
| GitHub: enable Discussions or keep issues-only                                                                                                                                         | 🔵 `BLOCKED` (user preference)                            | Low    | 5m     | 06-48 report §f/40                                                                                             |
