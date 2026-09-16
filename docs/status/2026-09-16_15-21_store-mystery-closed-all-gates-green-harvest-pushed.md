# Status 2026-09-16 15:21 — Store-mystery closed (wrong endpoint), all gates green, harvest pushed

Session 6 (continuation of session 5's residue under the standing
READ-UNDERSTAND-RESEARCH-REFLECT directive). Everything the 12:54 report
left open on the nix-email side is done; the repo is green end to end.

## a) FULLY DONE (this session, each verified)

| # | Item | Verification |
|---|------|--------------|
| 1 | **Store-mystery SOLVED in the first hour**: `/api/queue/reports` is the OUTBOUND report queue (`OutgoingReportList`, management/queue.rs:419) — permanently `total:0` here; incoming reports are at `/api/reports/{dmarc,tls,arf}` (`IncomingReportList`, management/report.rs:83). Same response shape, different key family. The write path was NEVER broken: `report.analysis.store` defaults `"30d"` (config/smtp/report.rs `property_or_default`), the `DmarcReportWithWarnings` path stores like any other | v0.15.5 source + bundled `api/v1/openapi.yml` side-by-side read; live VM: `{"data":{"items":["329837850705005775_1792150943"],"total":1}}` |
| 2 | **Second shape-trap fixed pre-emptively**: list items are `"<id>_<expires>"` STRINGS, not objects — detail URL takes the item verbatim (`.data.items[0]`, not `.data.items[0].id`) | handler source (`format!("{id}_{expires}")`); detail GET 200 in the green run |
| 3 | **stalwart-e2e GREEN (EXIT:0)** — native-ingestion subtest fully green: DMARC aggregate mailed → consumed (IMAP absent-probe) → NOT delivered → `total:1` → detail parses. Journal "DMARC report received with warnings" present; journal-hygiene subtest (exactly 2 config errors) NOT affected | `/tmp/e2e-final.log` EXIT:0; subtest transcript :1738-1849 |
| 4 | **Full `nix flake check` EXIT:0** (all checks; VM results satisfied from fresh store builds) | `/tmp/flake-check-final.log` |
| 5 | **Master pushed and CI GREEN**: bc7e954 → run 35092101106 `success` (first master run carrying native ingestion + relay-SASL + endpoint fix) | `gh run view` |
| 6 | **dependabot PR #1 rebased and GREEN**: `@dependabot rebase` sent after the eval-config root cause landed in master; run 35092306558 `success` — mergeable, merge decision left to the user | `gh pr view` rollup |
| 7 | **README ledger**: new entry — incoming `/api/reports/dmarc` vs outbound `/api/queue/reports`, the `store` default, the string-items shape, and the warning NOT to copy the 0.15.5 CLI's own `report list` URL | README.md ledger tail (method+date stamped) |
| 8 | **README architecture section**: stalwart-e2e bullet gains the ingestion leg; stalwart-relay-e2e bullet updated from "auth-less variant" to SASL (`--smtp-auth-file`) truth | README.md checks section |
| 9 | **CHANGELOG**: session-5 fixes (relay-e2e eval/log/mailpit trio, native-ingestion quartet+endpoint) under Fixed; session-4 residue under Added (tag trigger + branch protection, TLS positive assertion, filings #563777/#662 + #563652 cross-link) | CHANGELOG.md [Unreleased] |
| 10 | **AGENTS.md**: python-stdlib SMTP-sink swaks forensics recipe; `rg -rln` replace-footgun note; and (self-review catch) the stale "Local debug loop (much faster than the VM)" bullet replaced with the host-spike DEAD END verdict from session 5 — that bullet had drifted into contradicting the 12:54 report | AGENTS.md Commands section |
| 11 | **HARVEST (docs-health skill loaded first)**: TODO_LIST — 6 done rows DELETED (live-probe ingestion, relay-SASL variant, tag trigger, branch protection, TLS assertion, push-debt), the 2 stale "file it" rows collapsed into 1 recheck row (both already filed as #563777/#662, `gh issue view` all OPEN zero responses), sweep note rewritten. FEATURES.md — native-ingestion row ADDED, stalwart-e2e evidence extended, relay row updated to SASL. ROADMAP open questions verified current (D1/D2/Q6 present). Markdown-table consistency linted | per-file edits; every deleted row verified against code/`gh api` BEFORE deletion (ci.yml:15 tags, branch protection contexts, parsedmarc-e2e.nix:388-393 TLS line, relay-e2e.nix:135 auth-file) |
| 12 | **Docs harvest pushed**: 43cd0b4 (incl. the AGENTS fix), tree clean | `git push` fast-forward |

## b) PARTIALLY DONE

1. **CI on the docs push (43cd0b4)** — launched, verdict pending at report
   time (docs-only diff; the VM checks should replay from cache). If it
   redds for a NON-docs reason, that is a fresh finding, not drift.
2. **AGENTS.md anti-ghost discipline**: caught my own `reportEnabled`/
   `reportAddresses` wrapper-option ghost in FEATURES.md 30 s after writing
   it (no such options exist — it's raw `services.stalwart.settings`
   passthrough) and corrected the row. The catch worked; the ghost should
   never have been drafted.

## c) NOT STARTED (user-gated or deliberately deferred)

- **PR #1 merge** — green and mergeable; left for the user (dependency
  bumps are a product decision; §f/7 of the 12:54 report said "merge or
  leave for user").
- **GH013 unblock → SystemNix push (~75+ commits)** — user click gates it;
  the deploy-key recipe in SystemNix AGENTS.md then proves itself.
- **Q6 junk-filing verdict, D1/D2 license one-liners, `syn_` secret-scan
  policy, ANNOTATE scope for docs/status** — standing user queue, untouched
  (correctly).
- **Re-check the four filings for maintainer responses** — routed to
  TODO_LIST (10 m, next session).

## d) TOTALLY FUCKED UP (honest failures this session)

1. **Trust-then-verify AGAIN (the recurring sin)**: the wrong endpoint was
   inherited from session 5, which had copied the CLI's URL without
   checking what the CLI's URL *means*. The fix took one hour of source
   reading — after TWO sessions of key-family theorizing. The openapi.yml
   answer sat in the source tree the whole time. Same class as the jq
   `length` bug: assert the OBSERVED contract, never the assumed one —
   this is now ledgered with the explicit "do not copy the CLI" warning.
2. **FEATURES.md ghost row**: wrote `reportEnabled`/`reportAddresses` as
   if the wrapper owned them; the anti-ghost grep caught it immediately.
   Cost: one edit round-trip. Root cause: I drafted the row from the
   FEATURE mental model, not from modules/mail-server.nix.
3. **Self-review caught a drift I had already noticed and skipped**: the
   AGENTS.md "local debug loop, much faster than the VM" bullet directly
   contradicted session 5's host-spike dead end — I flagged it mid-harvest
   in my own reasoning, got pulled into CHANGELOG/TODO_LIST, and left it
   stale for ~90 minutes until the user's "What did you forget?" forced
   the re-scan. Noticing-and-not-fixing is worse than not noticing.
4. **`rg -rn` footgun hit me AGAIN** (second session in a row, this time on
   `struct ReportAnalysis` — output silently rewritten to "n"). Mitigated
   by the new AGENTS.md note, but twice-means-muscle-memory: stop typing
   `-rn`, type `-n` and `-l` separately.

## e) WHAT WE SHOULD IMPROVE

1. **Read the spec before the theory**: when two endpoints share a
   response shape, the API's own openapi.yml (shipped in the source tree)
   is a 5-minute disambiguator. Make "grep the bundled spec" step one of
   any API-mystery debug, ahead of storage-internals reading.
2. **Ghosts die in drafting, not in review**: the FEATURES ghost and the
   endpoint bug share a root cause — writing from the mental model. The
   fix is mechanical: any row/claim naming an option, endpoint, or file
   gets `rg`'d against the tree BEFORE the sentence is finished, not after.
3. **Noticed drift = immediate edit**: the AGENTS.md contradiction lived
   because "fix it on sight" lost to "finish the harvest first". For
   2-minute doc fixes there is no queue — the queue IS the failure.
4. **Harvest discipline worked** — every deleted TODO row was verified
   against code or `gh api` before deletion, and the filings' true state
   (all four OPEN, zero responses) collapsed two stale "file it" rows into
   one recheck row. Keep this exact pattern.

## f) NEXT (bounded, roughly ordered)

1. Watch the 43cd0b4 CI run to green (docs-only; expected cache replay).
2. User: merge or leave dependabot PR #1 (green, mergeable).
3. Re-check the four filings for responses (nixpkgs #563651, #563652,
   #563777; mjs/imapclient #662) — TODO_LIST row exists.
4. User: GH013 unblock click → SystemNix push (~75+ commits) → watch the
   clean-tree CI, deploy-key recipe in anger.
5. User: Q6 junk-filing verdict (per-account sieve accepted vs draft the
   Stalwart upstream feature request).
6. User: D1/D2 license one-liners → unblocks the ROADMAP P2 spine.
7. User: ANNOTATE scope verdict for docs/status (this file included).
8. User: `syn_` secret-scan policy for SystemNix.
9. TODO_LIST residue, impact order: Renovate tag-pin activation check;
   lock-rev/narHash in release notes; DKIM API-keygen + ed25519 legs;
   dmarc-eval offline/docs assertions; retention option docs; CONTRIBUTING
   d2 regen; actionlint CI step; --gc-roots; nixos-mailserver lessons note;
   mailsuite auto-STARTTLS upstream note; catch-all warning row.
10. Resend SASL smoke (needs API key) — last relay-gap item.
11. Release 0.3.0 cut once PR #1 merges (CHANGELOG [Unreleased] is thick).

## g) QUESTIONS (cannot resolve myself)

1. **Merge dependabot PR #1?** It is green and mergeable (run 35092306558,
   `nix flake check` passed on the rebased branch). I left it open —
   dependency bumps felt like your call. Say the word and I merge.
2. **GH013 unblock click** (standing): SystemNix is ~75+ commits ahead and
   holding; the URL is in the 12:54 report §g/1.
3. **ANNOTATE scope** (standing): may I inline-annotate done-items in
   recent reports (12:54 + this one), or does the original scope question
   still gate all annotation?

## Session artifacts

- Logs: `/tmp/e2e-final.log` (green stalwart-e2e, EXIT:0),
  `/tmp/flake-check-final.log` (full gate EXIT:0).
- Key evidence: report-ids JSON in the e2e transcript
  (`329837850705005775_1792150943`, total:1).
- Pushes: bc7e954 (fixes+ledger) → CI 35092101106 success; 43cd0b4
  (harvest+AGENTS) → CI pending at write time.
- PR #1: rebased by dependabot after my comment; run 35092306558 success.
