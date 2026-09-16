# Status: Pareto-plan execution — full review & comprehensive status

**Date:** 2026-09-16 02:08 (Wednesday) · **Scope:** the 2026-09-15 evening
session that executed `docs/planning/2026-09-15_19-23_nix-email-pareto-master-plan.md`
("GET SHIT DONE — the WHOLE TODO LIST"), reviewed honestly at request.
Point-in-time snapshot; the living sources remain `TODO_LIST.md`/`ROADMAP.md`.

**Repo state at writing:** nix-email `master` = `62b1246` (local; remote at
`598db0f` = release commit), tags `v0.1.0`/`v0.2.0` pushed, CI green on the
release push, GitHub releases published (v0.2.0 marked Latest). SystemNix
`master` = `caf5cf83` (local; pin at tag `v0.2.0`). Two status docs sit
UNTRACKED (see e) — the auto-commit daemon has not run in ~6 h.

---

## a) FULLY DONE (this session, each verified)

| # | Item | Verification |
|---|---|---|
| 1 | **L03 — Releases cut**: `[Unreleased]` folded into `[0.2.0] - 2026-09-15`; `v0.1.0` tagged retroactively at `f603169` (last 2026-09-14 commit); `v0.2.0` at `598db0f`; both tags + master pushed; both GitHub releases created; `v0.2.0` set Latest | CI run 35006923951 **success** (all steps incl. the new lockstep guard); `gh release list` |
| 2 | **L04 — SystemNix pin-advance**: input `1f8bb52` → tag `v0.2.0`, lock updated; relay-credential assertions RESTORED (sops credential + generated `queue.route."smarthost"` + strategy `."2"."else"`); option-existence guard deleted | `nix-email-contract` check green ("all eval assertions passed" in build log); `nixosConfigurations.evo-x2` evaluates clean in the full check |
| 3 | **L10 — Test strengthening**: CSV row-count (≥2 lines); SECOND `Message rescheduled` (retry LOOP, ~120 s cadence); RCPT resolver-timeout cost measured per run | Transcript: 66 s + 65 s wall-cost lines; 2nd reschedule after 99 s wait; both VM builds green |
| 4 | **L11 — TLS IMAPS test variant**: 2nd node in `parsedmarc-e2e` (dovecot `ssl=required` + fixture CA, parsedmarc `port=993`/`ssl=True`) with DEFAULT certificate verification (no skip flag) | Subtest green: IMAPS logins in journal, report JSON identity-asserted over TLS, no CERTIFICATE_VERIFY_FAILED |
| 5 | **L12 — CI lockstep guard**: strict set-equality flake-checks ↔ CI list (both drift directions fail) | Local negative test (phantom check → exit 1); guard step ✓ in the green CI run |
| 6 | **L13 — aarch64 posture decided**: one emulated `stalwart-e2e` run (qemu binfmt + TCG): guest builds & boots (arm64 kernel + systemd) but boot alone (~6 min) exceeds the driver shell timeout | Measured transcript; decision written into the `flake.nix` trap comment: manual-only, not CI-worthy |
| 7 | **L05 — Research closure**: `/compare` as HTML (cells preserved), release notes v0.15.5→v0.16.22, **v0.15.5 git-tag source grep**; cross-table in plan §10 | DKIM rotation & automated DNS = 0.16-only; native report ingestion IS in 0.15.5; OIDC/TOTP/autoconfig/POP3/JMAP-WS/encryption-at-rest present; PROXY protocol absent |
| 8 | **L06 — Overlap verdicts** (06a–06e, plan §10): keep-both (native ingestion complements parsedmarc), viewer DEFERRED, OIDC source-verified, sieve-for-Junk unchanged (ledger wall), ROADMAP deltas proposed | Written; ledger entry added (source-tag method explicitly labeled, not binary-grade) |
| 9 | **L09 + L27a — Pin-advance runbook**: README section (both-locks bump + workaround-retirement re-check: imapclient py3.14, `[elasticsearch]` emission, 0.15.5 key re-verify), cross-linked from both module comments | Written + cross-links in place |
| 10 | **L14 — Docs consolidation**: runbook→SystemNix wrapper pointer; pin-discipline rationale; `tests/fixtures/debug-template.py`; stateVersion note found ALREADY consolidated (stale TODO evidence) | All in README/tests/AGENTS |
| 11 | **L15 — nixpkgs filings**: [NixOS/nixpkgs#563651](https://github.com/NixOS/nixpkgs/issues/563651) (host-less `[elasticsearch]`), [#563652](https://github.com/NixOS/nixpkgs/issues/563652) (imapclient 4.0.1 `starttls()` vs py3.14) | Re-verified vs master, Gate-5 searched (no dupes), imapclient upstream main still broken; voice-checker passed; linked from ledger |
| 12 | **L26 — Micro-decisions** incl. wrapper doctrine for ROADMAP Q5 | Plan §10 |
| 13 | Full `nix flake check` (nix-email) green — all four checks | Exit 0 |
| 14 | Living docs swept: TODO_LIST down to 4 user-gated rows; FEATURES refreshed (TLS variant, aarch64 decision, lockstep, license-confirmed, pin tag); AGENTS.md gotchas (dovecot `<` prefix, ini `True` bools) | Files written |
| 15 | L07 (license) + L25a (threat model) were already done pre-session — verified, not redone | CHANGELOG/ROADMAP/docs |

## b) PARTIALLY DONE

1. **"Both repos green" (04d) is conditional.** SystemNix's full
   `nix flake check` FAILS at `deadnix-check` — **pre-existing, proven by
   building the identical check at the pre-change baseline (19:58 commit,
   exit 1 there too)**; flagged files (`hot-db.nix`, `integration.nix`,
   `test-crush-config.nix`) belong to a parallel active session. My
   pin-advance scope is green (contract + evo-x2 + everything evaluated
   before the failure), but the letter of "both repos green" is unmet
   through no fault of this change. Left unfixed deliberately (not my
   changes; parallel work in flight).
2. **06a verdict is source-grade, not ledger-grade.** Native report
   ingestion in 0.15.5 was established by reading the tag source
   (`smtp/src/reporting/`, CLI `report.rs`) — no live probe (mail a report
   into the VM's Stalwart, query the report store) was run. The ledger
   entry says so explicitly.
3. **Plan §10 harvest is proposal-only** — ROADMAP/TODO deltas (viewer
   deferral, OIDC "when D1", Q5 doctrine, DNS-owner guard) await the
   approval the plan itself gates on (§9).
4. **Local-only commits.** nix-email remote is 3 doc/auto commits behind
   local (post-tag housekeeping); SystemNix's pin-advance commits are
   local too (no push was part of the task; no push order given).
5. **CI's tag blind spot.** The workflow triggers on branch pushes only —
   the tags themselves triggered nothing. The green run covers the same
   TREE (master = release commit), so coverage is equivalent, but "CI ran
   on the tag" (plan 03e's letter) did not literally happen.
6. **L13 "record runtime"** recorded boot-phase numbers only (the run died
   at the driver shell timeout, ~6 min in); a full-run time does not exist.
   The decision doesn't need it, but the plan asked for a number I could
   only bound (>1 h by extrapolation).

## c) NOT STARTED (all gated — physically impossible without user input)

- **L01 (D1 Workspace fork)**, **L02 (D2 VPS/budget)**, **L08 (spam→Junk,
  ROADMAP Q6)**, **L16 (ANNOTATE — needs user to name files/time range)**.
- The D1/D2-gated production spine: **L17** Terraform DNS module, **L18**
  VPS provisioning, **L19** ACME/DKIM/admin bootstrap, **L20** backup/DR,
  **L21** dmarc-monitor live, **L22** migration + MX cutover, **L23**
  Gatus/RBL/freshness.
- Post-migration: **L24** (PG sink, Paperless, smartd), **L25b** OIDC
  wiring (verified available; needs the D1 host + Pocket ID), **L27b**
  Resend keep-or-retire, **L27c** placeholder-secret rotation.
- **docs-health HARVEST** of plan §10 (approval-gated).

## d) TOTALLY FUCKED UP (all caught & fixed in-session; none shipped)

1. **File mangling by my own multiedit**: the parsedmarc-e2e TLS-node
   insert spliced into the MIDDLE of the machine node (syntactically
   broken file), and my first tls-node draft contained a
   self-referential `inherit (config.services.dovecot2.settings)` — an
   infinite-recursion bug. Parse/eval caught both before any VM run.
2. **README ledger clobber**: an edit REPLACED the SIEVE/JUNK-FILING
   entry header instead of inserting before it. Noticed on the next grep,
   repaired.
3. **Pipes on gate/diagnostic commands — twice**, against the explicit
   repo rule. The worst one printed `CONTRACT_EXIT=0` for a FAILED eval
   (`nix build … | tail` ate the exit code). Caught because I verified
   the log content instead of trusting the echo; re-ran everything
   unpiped thereafter.
4. **Assumed ini bool rendering** (`ssl=true`) without reading the
   generator → one failed 5-minute VM run. The generator renders
   Python-style `True`. Lesson → AGENTS.md.
5. **Release-order slip**: `gh release create` ran v0.2.0 first, making
   `v0.1.0 (tagged retroactively)` the repo's "Latest" release for ~1 h
   until I noticed and fixed it (`gh release edit v0.2.0 --latest`).
6. **Tool sloppiness**: `rg -rln "report"` — the `-r ln` REPLACED matches
   in the display output mid-research (recognized instantly, harmless);
   two edit-staleness failures against the formatter/daemon race.
7. **v0.1.0's boundary is a heuristic**: tagged at an auto-commit
   (`f603169`), not a curated release commit — the tree matches the
   CHANGELOG section, but the boundary is my inference from commit dates.

## e) WHAT WE SHOULD IMPROVE (brutal self-review)

**What did I forget?** Nothing material dropped (final L01–L27 cross-check
held). Smaller: the Latest-release flag (fixed late); assuming the
auto-commit daemon would persist the 20:25 status doc — **it never did; the
file is still untracked 6 h later** (daemon apparently stopped). Anything
that mattered was re-verified, not assumed.

**What's stupid that we do anyway?** (1) SystemNix's CI is DARK — a red
`deadnix-check` sat unnoticed; gates that never run are decoration.
(2) Parallel sessions + auto-commit daemon on SystemNix make baseline
attribution expensive — I had to build a git-worktree proof for what should
be a one-look question. (3) Triple-write of the same findings (plan §10 /
README ledger / AGENTS) — cross-linked, but drift is one lazy edit away.

**What could I have done better?** Read the option/generator source BEFORE
asserting its output format (the `ssl=True` run); never pipe a gate — I
broke my own rule twice; write `.md`-format edits as whole-block rewrites
when the formatter daemon is racing me; create releases in ascending order
or set `--latest` explicitly.

**What could still be improved (concrete):**
1. Live-probe native report ingestion in the VM (upgrade 06a to
   ledger-grade; ~30 min).
2. Negative-test the lockstep guard's OTHER direction (flake declares a
   new check, CI list stale — logically covered by set-equality, not
   independently proven).
3. The TLS-node boot race exposed a third nixpkgs gap: the parsedmarc
   unit ships NO Restart policy (a poller daemon dies on one lost race) —
   reportable upstream alongside #563651/#563652.
4. Relay-auth E2E variant (Mailpit WITH SASL) — the SASL relay path is
   eval-asserted + auth-less E2E only.
5. File the root bug at mjs/imapclient (starttls `_file` assignment) —
   nixpkgs#563652 describes it; upstream is where the fix lands.
6. Consider attaching a `flake.lock`/narHash as release "asset" evidence,
   or at least mention the lock rev in release notes.
7. CI trigger on tag pushes (`on: push: tags: v*`) if tag-runs matter.

**Did I lie to you?** No — with one near-miss worth naming: the pipe-eaten
exit code PRINTED success for a failed eval; I caught it by reading the
log and said so in the session. Also the first "green" parsedmarc-e2e of
the session was the pre-TLS version; I flagged that and rebuilt rather
than counting it.

**Ghost systems?** None created: TLS node → check; lockstep guard → CI;
runbook → cross-linked; fixture CA → TLS node; debug-template.py is
deliberately unexecuted (it is a template). Nothing wired to nothing.

**Split brains?** One candidate accepted: measured wall-cost lives in test
comments AND CHANGELOG (comments are canonical, CHANGELOG is history);
pin-advance procedure lives in README with module-comment pointers. The
ledger §10-summary ↔ plan §10 relationship is declared, not duplicated
blindly.

**Tests?** Coverage grew on every axis this session (TLS path, retry-loop
proof, row counts, lockstep, measured budgets). Still thin: relay SASL
path (eval-only), native report ingestion (untested), no
negative/deployment-shape tests for consumers beyond SystemNix's mock-sops
pattern.

**Scope creep?** None — every addition was a forced fix or an explicitly
planned item; non-goals untouched; no assertion weakened.

## f) Up to 50 things to do next (brainstorm, not commitments; gating marked)

**Zero-minute user decisions:** 1. D1 record + unblock sweep · 2. D2
record · 3. spam→Junk Q6 call (recommendation (c)+(d) on the table) ·
4. ANNOTATE scope (files/time range) · 5. HARVEST approval for plan §10 ·
6. push approval for local commits (nix-email docs + SystemNix pin).

**Unblocked repo work (small):** 7. live-probe native report ingestion in
VM (ledger-grade 06a) · 8. file the mjs/imapclient upstream issue (root
fix) · 9. relay-SASL E2E variant · 10. lockstep negative test, flake
direction · 11. third nixpkgs finding: parsedmarc unit Restart policy ·
12. offer/implement the nixpkgs PR for #563651 (shape proposed in the
issue) · 13. CI trigger on `tags: v*` · 14. branch protection requiring
the CI check on master · 15. README CI badge · 16. verify Renovate updates
TAG pins (v0.2.0 → next tag) with a dry run · 17. TLS-node: assert the
successful TLS-handshake journal line (not just absence of failures) ·
18. mention the lock rev in release notes (or attach it) · 19. add the
two AGENTS.md gotchas to CONTRIBUTING's ledger rules pointer · 20. grep
audit: no other `cmd | tail` in scripts/CI (rule enforcement by eyes).

**D1/D2-gated production spine (L17–L23 micro-tasks, from the plan):**
21. Terraform `stalwart-mail` skeleton · 22. MX+SPF+DKIM records · 23.
DMARC rua + MTA-STS + `_smtp._tls` · 24. canary-first rollout plan · 25.
NixOS VPS config via domains-repo cloud-init · 26. rDNS/PTR · 27.
firewall review · 28. Hetzner port-25/465 limit request (calendar the
1-month+invoice gate) · 29. log/disk policy · 30. ACME tier switch +
issuance verify · 31. DKIM keygen → sops + rotation note · 32. admin
bootstrap oneshot (roles:["user"]!) · 33. export timer + offsite target ·
34. recovery age key into sops group · 35. FIRST restore drill (calendar
monthly) · 36. queue-depth/age alerts · 37. dmarc@ mailbox + first live
poll · 38. DMARC ladder step none→quarantine · 39. Gatus freshness
(dedup vs backup.maxAgeHours) · 40. migration tooling compare
(vandelay vs imapsync) · 41. full migration + 2-week rollback window ·
42. MX cutover canary-first + post-checks (mail-tester, alignment) ·
43. Gatus starttls/tls/expiry + RBL + non-mail alert path.

**Post-migration polish:** 44. parsedmarc PG-sink experiment · 45.
Paperless off Gmail app passwords · 46. smartd decoupled from mail relay ·
47. InboxClean JMAP/IMAP spike · 48. Resend keep-or-retire doc.

**Watch items:** 49. nixpkgs `services.stalwart` 0.16-module compat check
cadence (runbook step exists — keep it alive) · 50. triage replies on
#563651/#563652 (maintainer responses may unblock workaround retirement).

## g) Questions I can NOT figure out myself

1. **D1:** Do we fork Google Workspace onto the Stalwart VPS (yes/no)?
   Everything in f/21–f/48 hangs on this one word.
2. **D2:** If yes — which Hetzner project/location, budget ceiling
   (CX22-class?), and backup target (evo-x2 pool vs StorageBox)?
3. **May I HARVEST plan §10 (+ this report's f-list) into
   TODO_LIST/ROADMAP and push the local commits** (nix-email doc commits +
   SystemNix pin-advance)? Both are deliberately parked pending your word.
