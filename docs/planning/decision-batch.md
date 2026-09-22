# Decision Batch — every open call, one page

| Field | Value |
| ----- | ----- |
| Date | 2026-09-22 (execution session) |
| Purpose | Unblock the 19 decision-gated todos (Pareto plan M2; plan file `2026-09-22_19-23_pareto-master-plan-super-email-monitoring.md` §1) |
| How to answer | Reply with the decision IDs (`D1: retire`, `C24: discord`, ...). Defaults marked **[rec]** execute on your go. |

## The big two (gate ~15 todos incl. the entire production build-out)

### D1 — Google Workspace fork
Retire Workspace mailboxes for the Stalwart VPS, or keep Workspace and run only
the parsedmarc/monitoring half?
- **[rec] Retire** (the whole ROADMAP theme 1-3 build-out assumes it; monitoring-only leaves the DR/backup/canary work half-built).
- Unblocks: M22 provisioning+DKIM, M23 backup/DR, M24 DNS Terraform, M25 migration+cutover, M26 DMARC-live+OIDC, C12 live rua validation, C14 secret rotation, C43-C51.
- Cost of delay: the "super system" end state stays a test-fleet; monitoring keeps running against reports that only exist because Workspace still sends mail.

### D2 — VPS placement and budget
Hetzner project/location, size ceiling (CX22-class?), backup target (evo-x2 btrfs pool vs StorageBox).
- **[rec]** CX22 at the same project as the domains repo; backup to the evo-x2 btrfs pool with a StorageBox second copy later.
- Unblocks: M23 backup target choice, M24 module defaults, firewall/port-25 request calendar.
- Cost of delay: blocks M22-M26 even after D1 lands.

## Session questions (from the 2026-09-22 status report)

### C24 — Alert channel (non-mail rule: alerts must not ride the mail stack they watch)
- **[rec] Discord** via the existing SystemNix DiscordSync layer (already in-fleet, phone-reachable); ntfy as fallback.
- Unblocks: M11 taxonomy routing table, M15 auth alerts, M12 queue alerts, M13 dead-man switch.

### C29 — Round-trip canary vantage (send→receive SLO probe)
- **[rec] evo-x2** (residential, independent network + DNS path; cron/systemd timer sending via Resend to a canary mailbox, asserting delivery SLO).
- Unblocks: M18 canary implementation.

## Repo policy (2-min answers)

### C18 — Branch-protection bypass
Pushes currently bypass the required `nix flake check` ("Bypassed rule violations" on push). Keep for auto-commit-daemon velocity, or strict?
- **[rec] Keep bypass** for `master` (the daemon + CI-red-on-preexisting-failures history makes strict mode high-friction), but require the check on any protected future branch.

### C19 — Renovate
Install the GitHub app or drop `renovate.json`? App NEVER ran on this repo (verified 2026-09-16); Dependabot already covers github-actions.
- **[rec] Drop the config** (dead config is drift; Dependabot just opened its first branch `dependabot/github_actions/actions-b7aede57ad`, proving the coverage path works).

### C20 — mailsuite STARTTLS issue
File the prepared draft (`docs/planning/mailsuite-starttls-issue-draft.md`, all 5 verify-before-filing gates PASSED) or skip?
- **[rec] File it.**

### C22 — GitHub Discussions
- **[rec] Keep issues-only** (single-maintainer repo; Discussions = another inbox).

### C34 — Webmail: goal or non-goal? (new question, 2026-09-22)
Stalwart ships a webadmin, not a user webmail. Roundcube/SnappyMail would be a new service in the wrapper's scope.
- **[rec] Non-goal for the wrapper** (consume via IMAP/JMAP clients; revisit only on a real demand signal). Record in ROADMAP non-goals.

## ROADMAP Q-answers (30-sec each)

### Q4 — README ops-detail level
Public README carries go-live runbook detail (migration window, DR design) with recon value.
- **[rec] Keep as-is** until D1 lands, then re-decide with the runbook actually exercised.

### Q5 — Declarative provisioning philosophy
`services.mail-server` grows `domains`/`accounts` options (idempotent oneshot vs management API), or account state stays imperative/webadmin?
- **[rec] Add the options** — the e2e already provisions via `POST /api/principal` mechanically; declarative is the NixOS contract and makes the demo/canary reproducible. (Same verdict powers M22.)

### Q6 — Spam/Junk ownership (0.15.5 tags `X-Spam-Status` but never files to Junk; settings-sieve cannot fileinto — source-verified wall)
(a) wrapper-owned JMAP provisioning automation, (b) user-managed sieve per account, (c) tag-only documented end state, (d) upstream feature request then revisit.
- **[rec] (c) now + (d)** (ROADMAP's standing recommendation); filing C21 upstream follows automatically.

### Demo-VM residue (report 21-07 g1/g2)
- **g1 Host port:** keep `18080` host-forward (an unidentified process owns `:8080` on this host) — **[rec] keep 18080 permanently**.
- **g2 dmarc-monitor in the demo:** against a local Mailpit sink (faked rua mail) — **[rec] yes, add it after the hostfwd hang is fixed** (makes the demo the full-stack story).

## Cross-repo approvals

### C17 — SystemNix push (~47 commits) + CI debt + cache sweep
- **[rec] Approve push** once the pin bump (TODO_LIST row, v0.3.1) is in; CI debt list triaged in the same pass.
- Note: I performed the LOCAL pin-bump edit + dedupe today; push stays gated on this approval.

### C14 — Rotate the 3 placeholder secrets (SystemNix `nix-email.yaml`)
Gated on D1 (rotation-due check before live enablement). **No recommendation needed** — it executes as part of M22/M26 when D1 lands.

## What is NOT a decision
- Q7 (demo VM boundary): RESOLVED 2026-09-17 — demo VM lives in THIS repo.
- Q8 (tag cadence): RESOLVED 2026-09-17 — `v0.3.1` cut.
- TLS-RPT / telemetry / RBL / rate-limit / expiry / audit / autoconfig wiring: not user-gated — execution follows the M9 verify verdicts (this session).
