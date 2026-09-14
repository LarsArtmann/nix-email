# Status: Stalwart E2E full-path coverage + upstream verification deep-dive

**Report time:** 2026-09-14 19:39 CEST
**Scope:** This session only (~14:40–19:39): repo publication, security audit, Mailcow comparison, nixos-mailserver study, Stalwart v0.15.5 source verification, E2E test overhaul, README/AGENTS ledger work. A parallel session (17:05 report, Hetzner port-policy verification, flake arch-gating) was active concurrently; its work is noted where it intersected mine.

**Gate state at report time:** `nix flake check` GREEN (1 check run + 2 independent driver reruns, all passing). Working tree clean. **9 commits ahead of `origin/master`, NOT pushed.**

---

## a) FULLY DONE

1. **GitHub repo published**: https://github.com/LarsArtmann/nix-email (public, ssh remote, `master` tracking). Full-history secret scan before push: zero credentials; only `_secret` path references and a `"dummy"` test file.
2. **Security disclosure audit** of the public tree: no secrets, but identified recon-value items (mail hostname example in module, go-live runbook timing/DR details, `dmarc@` rua mailbox). Reported with a cheap-fix proposal; user decision pending (see c/e).
3. **Mailcow vs Stalwart + NixOS-support ranking** (research answer, session chat): verified against `nixos/modules/services/mail/` listing — nixpkgs has `stalwart.nix`, `maddy.nix`, `dovecot.nix`, `postfix.nix`; **no** mailcow/mailu/mox modules. Mailcow loses on RAM (6–8 GiB vs CX22-class target) and declarability before Docker friction even starts.
4. **simple-nixos-mailserver deep study** (shallow clone): options inventory, `external.nix` test patterns, `x509.useACMEHost` cert design, migration modules, and the key historical fact that they **removed** their backup/monitoring options — independent validation of this repo's thin-wrapper doctrine.
5. **nixpkgs `services.stalwart` module read at pinned rev `eaad089`**: `credentials`→LoadCredential→`%{file:/run/credentials/stalwart.service/KEY}%` macro chain, `openFirewall` port parsing, systemd hardening set, the `queue.*.next-hop` deprecation assertion.
6. **Stalwart v0.15.5 source verification** (tarball; docs site is client-side-rendered and unfetchable, so source IS the docs): relay keys (`queue.route.<id>` + `queue.strategy.route` expression), Prometheus (`metrics.prometheus.enable`/auth, `/metrics/prometheus` endpoint), `authentication.fallback-admin`, DKIM (`signature.<id>.*`, `auth.dkim.sign` defaults), ACME (`acme.<id>.*`, `certificate.<id>.cert/private-key`), native backup (`--export`/`--import`, 9 store families), directory cache TTLs (`directory.<id>.cache.ttl.positive`=24h / `.negative`=1h), inbound auth defaults (SPF/DMARC/iprev only on port 25).
7. **Webadmin source read** → exact `POST /api/principal` payloads (individuals need client-side sha512-crypt secrets; domains via `{"type":"domain"}`).
8. **E2E test overhaul** (`tests/stalwart-e2e.nix`): full mail path — declarative fallback-admin bootstrap → anonymous 401 → domain+account provisioning via real API → 550 unknown-recipient → IMAPS implicit-TLS (polled) → authenticated submission 587 (STARTTLS+AUTH PLAIN) → async local delivery → needle fetched from INBOX via in-VM `imap-probe` → no-crash journal gate.
9. **Four real bugs found, root-caused, fixed** (all VM-observed, not folklore):
   - directory negative cache poisoning (pre-provision probe → domain routes to MX for 1h) — fixed by test ordering, documented for go-live;
   - `"roles": ["user"]` required for submission;
   - async self-signed cert generation (>80s observed) → poll instead of single-shot;
   - testScript python runs on the DRIVER HOST, not the VM → packaged in-VM probe script.
10. **README ledger**: ~10 new VERIFIED bullets replacing UNVERIFIED markers; runbook steps 2/3/6 rewritten with verified keys (fallback-admin bootstrap, Resend relay snippet, native `--export` backup).
11. **AGENTS.md**: VM debug-loop recipe (`--test-script` override, existing-dir requirement for `-o`), cached-check-failure caveat, provisioning-before-SMTP ordering rule.
12. **Stability verification**: 3 consecutive full E2E passes.

## b) PARTIALLY DONE

1. **E2E behavioral coverage**: full inbound+local path done; outbound relay (Resend), DKIM signing, spam classification, quota, aliases, Junk handling all documented NOT-covered (need DNS/keys — partly go-live items, partly VM-testable with effort).
2. **Parallel-session coordination**: concurrent edits from another session (README UNVERIFIED rewrites, flake arch-gating, test reorder) raced mine twice; both times resolved by re-reading and merging (their reorder was sound but shipped a Python NameError — `def` after first call — which I fixed). Final state verified green, but mid-session I authored edits against stale file contents twice (see d).
3. **Security hardening of public repo**: audit complete, fixes proposed (genericize `mail.larsartmann.cloud` example, trim runbook ops detail) — awaiting user call.
4. **Push state**: repo created and initial push done at session start; the 9 commits from the research/test work are local-only (by the no-push rule — needs explicit go-ahead).

## c) NOT STARTED (known, deliberate)

1. VPS host module / cloud-init go-live (Hetzner CX22, rDNS, NixOS).
2. SystemNix consumer wrapper (sops, ports.nix, Gatus, onFailure, backup-coordination).
3. DNS cutover terraform (`domains` repo `stalwart-mail` module: MX/SPF/DKIM/DMARC/MTA-STS/TLS-RPT).
4. Hetzner :25 unblock request (1-month + first-invoice gate — externally clock-gated, nothing to do yet).
5. imapsync mailbox migration + Workspace rollback window.
6. `dmarc-monitor` live-IMAP exercise (eval contract only).
7. Prometheus scrape wiring (reverse-proxy route or ssh tunnel for `/metrics/prometheus`).
8. DKIM key generation automation (`POST /api/dkim` or declarative `signature.<id>`).
9. Backup timer unit around `stalwart --export` (+ restore drill).
10. Recovery age-key DR setup (runbook step 7).
11. TODO_LIST.md / FEATURES.md / ROADMAP.md do not exist in this repo (status reports + README currently carry the load; see e).

## d) TOTALLY FUCKED UP (honest ledger)

1. **Host-side IMAP probe in first test rewrite**: I wrote `imaplib.IMAP4_SSL("127.0.0.1")` directly in testScript — which executes on the driver HOST. Conceptual error I should have caught at authoring time; cost one full VM cycle (~4 min) plus a wrong first diagnosis.
2. **Cached-failure misread**: one `nix flake check` "failure" was the CACHED verdict of an unchanged derivation (same store drv path). I nearly concluded flakiness before noticing the path reuse. Now documented in AGENTS.md, but I lost a cycle to it.
3. **`rg -rn` misuse**: I repeatedly passed `-r` (REPLACE flag) as a pseudo-verbosity flag, silently corrupting several greps — including one I then had to redo with `sed`/`view`. Tool-flags-assumed, not checked.
4. **Two stale-file edit attempts**: I edited README from an earlier `cat` snapshot, not a fresh View (2/4 multiedit ops failed; the edit tool caught it — the safety net worked, the process didn't). Repeat offender pattern within one session.
5. **Unverified spec assertion in the Mailcow answer**: I quoted "CX22 (2 vCPU/4GB)" from memory without checking Hetzner's spec sheet (the parallel session verified port policy properly; I didn't verify the hardware line I asserted).
6. **Wasted log-retrieval fumbling**: `nix log` on the failed drv returned nothing (streamed logs not retained); I tried three invocation variants before pivoting to direct driver runs — should have pivoted after the first empty result.
7. **Debug-script iteration sloppiness**: first debug run used stdin script (ignored by the driver — it ran the embedded test), then a heredoc python that referenced `python3` I had myself removed from the VM. Two wasted VM boots from not re-checking my own prior changes.
8. Minor: ~600 MB of /tmp debris left (stalwart tarball + extracted tree, nms clone, e2e logs) — harmless but unhygienic.

## e) WHAT WE SHOULD IMPROVE

1. **Provision-before-probe is a product hazard, not just a test rule**: any pre-provision SMTP touch on a domain bounces its mail for up to 1h (negative cache). Consider exposing `directory."internal".cache.ttl.negative` guidance (or a wrapper mkDefault) for dev/test hosts; on the VPS, provision domains FIRST in the runbook (done in docs, enforce during go-live).
2. **The E2E suite still cannot test outbound** — a `queue.route` relay pointed at an in-VM dummy SMTP sink (python `aiosmtpd`-style listener via a small systemd service in the test node) would make relay/DKIM-signing testable hermetically. This is the single highest-value test investment available.
3. **Ledger vs TODO split brain risk**: verified facts live in README (right), but actionable next steps have no TODO_LIST.md; status-report (f) sections keep re-generating them. Create TODO_LIST.md and harvest.
4. **Push cadence**: repo created at session start, everything since is unpushed — 9 commits of drift. Decide a push policy (manual gate vs push-on-green).
5. **Test determinism budget**: E2E is now ~2.5–4 min with two intentional DNS-stall waits (~60s) and poll loops; acceptable, but a second VM test file would multiply CI time — keep one VM test, grow subtests inside it.
6. **Session-wide tool discipline**: rg flag misuse, stale-file edits, and stdin-driver misuse all share one root cause — assuming tool behavior instead of reading it. (Process fix: 10-second `--help`/fresh View before first use of any invocation pattern this session.)
7. **Journal detail visibility**: Stalwart's serial-console lines hide event DETAILS (only `journalctl -o verbose` shows them); the test's no-crash gate greps names only — a details-level assertion would catch more, but needs a curated benign-list (resolver/pyzor/ASN-download lines) to stay honest.
8. **Parallel-agent edit protocol**: two agents editing README/tests concurrently worked only because the edit tool's staleness check caught collisions. Explicitly claim files or sequence edits in future multi-agent sessions.

## f) Next up to 50

**Repo & hygiene (1–8)**
1. Push the 9 local commits to origin (after user go-ahead).
2. Genericize `example = "mail.larsartmann.cloud"` in `modules/mail-server.nix:42` to `mail.example.com`.
3. Trim/move operational runbook detail (migration window, DR key design, backup topology) out of the public README.
4. Create TODO_LIST.md + FEATURES.md (this report's (f) as seed).
5. Add `.gitignore` entry for `docs/status/*.html` artifacts if HTML reports ever land (currently .md only).
6. Clean /tmp debris (stalwart-src, tarball, nms clone) — or leave to reboot, but note it.
7. Add flake check GitHub Action (nix flake check on x86_64-linux) mirroring the local gate.
8. Repo topics/description polish on GitHub (mail, nixos, stalwart, dmarc).

**Tests — highest value first (9–20)**
9. Outbound relay test: in-VM dummy SMTP sink + `queue.route."sink"` + assert the sink receives the message.
10. DKIM signing test: declarative `signature.<id>` with a test RSA key, assert `DKIM-Signature` header on submission.
11. DKIM keygen via `POST /api/dkim`, then sign — mirrors the webadmin flow end-to-end.
12. Assert anonymous admin API stays 401 across restarts (auth survives RocksDB state).
13. Test `metrics.prometheus.enable = true` → `/metrics/prometheus` returns 200 (and 401 with auth set).
14. Quota test (nixos-mailserver pattern): 1KB quota account, second mail bounces.
15. Alias/catch-all principal test (emails[] with extra alias).
16. Junk-folder delivery probe variant (spam-flagged message lands in Junk, not INBOX).
17. Restart-persistence test: deliver, `systemctl restart stalwart`, message still in INBOX (state survives).
18. Details-level journal assertion with curated benign-filter (resolver.type, pyzor, ASN "Resource error", "No TLS certificates available" during cert-gen window).
19. Add dmarc-eval assertion that wrapper output survives `nixosOption` docs rendering (option docstring drift check).
20. Drive the E2E with `--gc-roots` in CI to avoid store GC between check and debug.

**Module surface (21–28)**
21. Consider `openFirewall` split: module currently opens ALL listener ports incl. 8080? (verify — httpBind is loopback so `parsePorts` may still add 8080 to firewall; if so, gate it).
22. Add `domains` list option (auto-create domain principals at first boot via systemd oneshot + fallback-admin) — kills the provision-before-probe hazard operationally.
23. Same oneshot could declaratively sync accounts from a list (idempotent POST /api/principal via `wantedBy`).
24. Wrapper option for relay (`services.mail-server.relay = { address, port, username, secretFile; }`) generating the verified `queue.route` + `queue.strategy.route` TOML — turns the ledger entry into product.
25. `certificate` option tier: `self-signed | acme | manual` mirroring nms's x509 design with mutual-exclusion assertions.
26. `metrics.enable` wrapper option wiring `metrics.prometheus.*` + Gatus-friendly bind guidance.
27. Assertion: warn if `httpBind` is non-loopback (README says reverse-proxy only).
28. `stateVersion` docs: add migration note hook for the eventual 0.16 nixpkgs move (module-incompatible per ledger).

**Go-live prep (29–40)**
29. VPS NixOS host skeleton in SystemNix consuming this flake (DiscordSync pattern).
30. sops secrets: fallback-admin secret + relay secret via `services.stalwart.credentials`.
31. Backup oneshot/timer: `stalwart --export` to /backup + pull to evo-x2 pool (backup-coordination).
32. Restore drill: `--import` into a scratch VM from an export (validates the backup claim).
33. Gatus checks from README into the consumer (smtp-mx, imaps, cert-expiry).
34. Prometheus scrape path for /metrics/prometheus (reverse-proxied, basic-auth'd).
35. DKIM keys + DNS TXT via terraform module; selector rotation plan.
36. DMARC ladder automation driver (read parsedmarc output, recommend policy step).
37. imapsync dry-run against Workspace (creds + bandwidth window).
38. rDNS/PTR set at Hetzner + verify with `dig -x`.
39. MTA-STS policy file + TLS-RPT rua wiring.
40. Hetzner :25 unblock request the day the 1-month/invoice gate clears (calendar item).

**dmarc-monitor (41–45)**
41. Live IMAP exercise against a real mailbox (needs creds/host decision).
42. Add `[reports]`/output retention option docs (disk growth policy for JSON/CSV).
43. Gatus/onFailure wiring example in README (consumer side).
44. Eval-contract test for `general.output` + `_secret` across BOTH nixpkgs pin moves (guard on versionOlder).
45. Consider `systemd` hardening overrides for parsedmarc service (ProtectSystem etc.) as mkDefault suggestions.

**Docs & meta (46–50)**
46. README: replace "What is built and verified (2026-09-14)" date-stamp convention with per-section dates (stalwart vs dmarc diverge soon).
47. CONTRIBUTING note: verified-facts ledger rules (how to add a bullet: source-path citation or VM observation date).
48. Link the two 2026-09-14 status reports from README or drop them from docs/rot tracking.
49. Record the nixos-mailserver lessons section in README (currently only in session history) — 3 lines max.
50. Add `flake-check-all-systems` note (aarch64 intentionally omitted per flake gating; document why in README).

## g) Questions I cannot answer myself

1. **Push or hold?** The 9 session commits are local-only (no-push rule). Push to `origin/master` now, or do you want to review the README/test diff first?
2. **Public vs private repo, and runbook trimming?** The audit found no secrets but real recon value (hostname example, migration window, DR design). Keep public + trim ops detail, keep public as-is, or go private?
3. **Declarative provisioning in the wrapper (f.22/23):** should `services.mail-server` grow `domains`/`accounts` options (systemd oneshot creating principals idempotently), or does account state stay strictly imperative/webadmin per Stalwart doctrine? This is a product-philosophy call (declarative drift vs. operational simplicity) I can argue either way.
