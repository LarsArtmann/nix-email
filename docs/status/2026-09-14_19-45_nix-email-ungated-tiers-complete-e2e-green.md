# Status: nix-email — Ungated Plan Tiers Complete, Full E2E Green

- **Date**: 2026-09-14 19:45 CEST
- **Repo**: `/home/lars/projects/nix-email` (master, local ahead of `origin/master`; last authorized push was `5d31c69`)
- **Session scope**: execution of the ungated tiers of the Pareto plan (H1, R1, R2, R3; R4/R5 verified earlier), including a live-debug campaign against the real Stalwart 0.15.5 binary and three VM-test failure rounds.
- **Gate state**: `nix flake check` → **exit=0** (both checks, x86_64-linux run; aarch64 eval-only by design).
- **Format note**: user explicitly requested `.md`; the status-report skill's HTML default is overridden this once. Not propagated into the skill.

---

## a) FULLY DONE

| # | Item | Evidence |
|---|------|----------|
| 1 | **H1: aarch64 VM-test trap closed** — `stalwart-e2e` restricted to x86_64-linux via `optionalAttrs`; `dmarc-eval` remains arch-independent | `flake.nix` checks block; `nix flake check` exit=0 with clean "omitted incompatible systems" warning |
| 2 | **R1: Hetzner port-25 claim VERIFIED against official docs** — Hetzner Cloud blocks ports **25 and 465 by default, per account, BOTH directions**; unblock via limit request after 1 month + first invoice; 587 never blocked. Community guides claiming "port 25 open by default" are outdated. Consequence owned in runbook: inbound MX needs the unblock BEFORE go-live | docs.hetzner.com/cloud/servers/faq (fetched this session); README runbook step 1 + ledger entry rewritten from UNVERIFIED to VERIFIED with source and date |
| 3 | **R2 bug #1: broken 401 assertion fixed** — `curl -f` exits 22 on 401 before grep sees the code; assertion switched to `-sS` | VM subtest "admin API: fallback-admin works, anonymous rejected" passes |
| 4 | **R2 bug #2: `roles: ["user"]` required on API-created accounts** — a bare `individual` authenticates but submission is refused `550 5.7.1` because the permission set is empty (`Permission::EmailSend` check, `crates/smtp/src/inbound/auth.rs`); the webadmin adds the role silently, the raw API does not | Reproduced locally against the 0.15.5 binary (550 → 235 with role); verified in VM; test + README ledger updated |
| 5 | **R2 bug #3 (the deep one): directory negative-cache poisoning** — any SMTP traffic touching a not-yet-provisioned domain poisons `is_local_domain` = false (default TTL 1h, `crates/directory/src/core/cache.rs`); every later submission for that domain takes the MX path → in the DNS-less VM delivery never completes. Provisioning moved BEFORE all SMTP traffic | Root cause read out of v0.15.5 source (dispatch cache + default route `is_local_domain('*', rcpt_domain) → 'local'`); reproduced as local-vs-VM differential; full E2E now green |
| 6 | **R2 complete: real delivery E2E green** — provision domain+accounts → authenticated submission on 587 (STARTTLS+AUTH PLAIN) → async queue → local delivery → needle fetched from user2's INBOX via IMAPS; no panics in journal | `nix build .#checks.x86_64-linux.stalwart-e2e` exit=0; then full `nix flake check` exit=0 |
| 7 | **R3: smarthost relay spike, mechanism verified live** — `queue.route."<id>"` relay + `queue.strategy.route` engage correctly; three facts banked: (a) IfBlock routes need INDEXED keys (`route.1.if`/`route.1.then`/`route.2.else`), and `else` must sort after `if` or parsing fails; (b) relay address is DNS-resolved — bare IP literals fail "record not found for MX", use a hostname (`smtp.resend.com`); (c) Stalwart REFUSES loopback relay targets ("host resolves loopback address") — a good SSRF guard, and the reason the VM E2E cannot exercise the smarthost path | Local binary + Mailpit 1.31.0 spike; all findings in README ledger, commit `c927922` |
| 8 | **README verified-facts ledger now has ZERO unverified claims** (grep `UNVERIFIED` = 0) | Every claim states fact + method + date |
| 9 | **Green checkpoints committed explicitly** — `fbe9ca9` (e2e fix), `c927922` (relay findings), `a1a649e` (status doc) | git log |
| 10 | **R4 (metrics) and R5 (backup)** — verified in earlier work by the parallel session, entries present in ledger: `metrics.prometheus.enable` on the HTTP listener; native `stalwart --export` consistent offline backup | README ledger |
| 11 | **Debug loop hygiene** — all spike processes/processes (`stalwart`, `mailpit`) killed and `/tmp/swtest`, `/tmp/swvm`, `/tmp/r3`, `/tmp/swsrc*` cleaned after use | /tmp verified |

## b) PARTIALLY DONE

| # | Item | Gap |
|---|------|-----|
| 1 | **aarch64 support** — eval-only on aarch64 is a workaround, not support. No e2e coverage on ARM; nobody has ever run the VM test there | Needs a cross-VM decision or explicit `badPlatform` documentation |
| 2 | **R3 end-to-end round trip** — mechanism verified, but no full submission→Mailpit arrival succeeded locally (loopback guard + IP-literal DNS limits). The real Resend path is untested by definition until D2 gives a VPS | A two-node VM test (stalwart + mailpit nodes) would close this deterministically |
| 3 | **Plan tracking** — the Pareto plan has 118 micro-tasks; this session tracked 5 top-level todos. Tier progress: H1 ✅, R1 ✅, R2 ✅, R3 ~80%, R4 ✅ (prior), R5 ✅ (prior), R6 ❌, everything D-gated ❌ | Plan doc's mermaid graph not updated with completed nodes |
| 4 | **README header stamp** — "What is built and verified (2026-09-14)" not refreshed with the new session's additions (roles requirement, cache poisoning, relay syntax) | 1-line fix |
| 5 | **Session docs** — a second status report appeared mid-session from the parallel session (`19-39_stalwart-e2e-full-path-and-source-verification.md`); I committed it but neither report is annotated as superseding/overlapping the other | docs-health ANNOTATE pass |

## c) NOT STARTED (gated or untouched)

1. **I1 — SystemNix integration** (input, consumer wrapper, ports.nix, sops, Gatus, onFailure→Discord) — gated on **D3** (repo visibility/license determines the input URL).
2. **H7 — LICENSE** — gated on **D3**.
3. **V1 — VPS provisioning** (Hetzner host, cloud-init, rDNS/PTR, port-25 limit request) — gated on **D1/D2**.
4. **T1/T2 — Terraform `stalwart-mail` module** (MX, SPF, DKIM, DMARC rua, MTA-STS, TLS-RPT) — gated on D1.
5. **V2/V3/V4 — admin bootstrap on VPS, declarative account provisioning, DKIM automation** — gated on D1/D2.
6. **M1 — evo-x2 dmarc-monitor enablement**; **M2 — Workspace retirement / migration runbook execution** — gated on D1.
7. **R6 — vandelay / imapsync dry-runs** — needs live mailboxes (D1).
8. **Project documentation set** — no `TODO_LIST.md`, `FEATURES.md`, `ROADMAP.md` exist yet (docs-health BUILD never run on this repo).
9. **CI** — no GitHub Action running `nix flake check` on push.
10. **DMARC ladder automation** (none→quarantine→reject driven by parsedmarc output) — design exists, nothing built.

## d) TOTALLY FUCKED UP

Nothing shipped is broken — the flake is green end-to-end. But four things went genuinely wrong this session and deserve honesty:

1. **I executed from a stale snapshot and paid for it.** My context said the test had 3 subtests; it actually already contained the full provisioning E2E from a parallel session. I burned a VM run and an edit conflict discovering what `git log` + reading the file would have shown in 30 seconds. READ BEFORE ACT — including `git log`, not just files.
2. **Three edit conflicts from an uncoordinated parallel session.** My edits raced another session's edits to the same two files ("file has been modified since read" twice). I nearly double-applied the roles fix. Two agents on one working tree with no coordination is a data-loss lottery that happened to pay out.
3. **I guessed at nondeterminism before reading source.** The "No TLS certificates available" failure: I first shipped a `wait_until_succeeds` retry (treating it as a cert-gen race), then the NEXT failure was the cache bug. The cert warning turned out to be benign all along; the retry papered over a symptom instead of finding the cause. The memory lesson "E2E repro beats log-message assumptions" applies to diagnoses too — I re-learned it at the cost of ~2 extra VM runs (~6 min).
4. **The auto-commit daemon shredded history again** — ~10 "chore: auto-commit (heuristic)" commits interleaved with the three meaningful ones, including committing my README edit mid-flight (which then made my next edit fail on a stale read). Explicit per-checkpoint commits helped; the daemon still races every write.

## e) WHAT WE SHOULD IMPROVE

1. **Session-start ritual**: before any edit — `git log --oneline -15` + `git status` + grep the target files. The snapshot is always stale.
2. **Single-writer rule**: if a parallel session is active, partition files (one takes tests/, other takes docs/) or serialize on a lockfile note in AGENTS.md.
3. **Source-read-first for weird failures**: for any non-deterministic test failure, fetch the relevant crate source BEFORE writing retries/workarounds. Cost: ~2 min. Saves: entire VM cycles.
4. **Loop-check the VM log more aggressively**: the "Configuration build error" lines at startup were in the very first failing log and I only noticed them 3 runs later — they were the parse-error breadcrumbs for both the roles issue era and the relay syntax.
5. **Promote debug findings into fast local repro**: the /tmp binary loop again proved ~10× faster than VM cycles; formalize it in AGENTS.md as THE debug procedure (it is documented, but I still reached for the VM first twice).
6. **Bank the (f) list into TODO_LIST.md** immediately (docs-health HARVEST) — timestamped reports rot; the repo still has no living TODO file.
7. **Commit report docs with the session's final commit** rather than letting the daemon give them a "heuristic" parent.
8. **Add the two-node relay VM test** so the smarthost path gets CI coverage instead of a one-off local spike.

## f) Up to 50 things to get done next

*(Impact-ordered inside tiers; D-gated items are marked.)*

**Decisions (unblock everything downstream)**
1. D1: Retire Google Workspace mailboxes for a Stalwart VPS, or keep Workspace and run monitoring-only? *(gates 3–46)*
2. D2: VPS placement (which Hetzner project), size (CX22-class?), backup target (evo-x2 btrfs pool vs StorageBox)? *(gates 3–8, 26)*
3. D3: Repo public vs private + LICENSE choice? *(gates 4, 47)*

**Integration (I-tier)**
4. I1: SystemNix `flake.nix` input + `modules/nixos/services/nix-email.nix` consumer wrapper (after D3).
5. I2: Register mail ports in SystemNix `lib/ports.nix`.
6. I3: sops template for `fallback-admin.secret` + `services.stalwart.credentials` wiring.
7. I4: Gatus checks (starttls :25, tls :993, cert expiry >720h, HTTP admin via tunnel) + onFailure→Discord.
8. I5: homepage.nix entry for the mail stack.
9. I6: Prometheus scrape of `/metrics/prometheus` (reverse-proxy route or tunnel; do NOT expose the admin port).
10. I7: SystemNix-side eval + VM test importing the upstream module.

**Testing hardening (T-tier)**
11. T1: Two-node VM test (stalwart + Mailpit node) to E2E the smarthost relay despite the loopback guard.
12. T2: VM test for the `is_local_domain` cache behavior (regression guard for the poisoning fix).
13. T3: parsedmarc E2E — feed a sample DMARC aggregate report through a local mailbox, assert JSON output.
14. T4: Backup E2E — run `--export` in the VM, wipe store, restore, assert message survival.
15. T5: aarch64 decision: run the VM test under qemu once, or document `x86_64-only` loudly.
16. T6: Add `directory.cache.ttl.negative` as a module option (dev/test hosts want it low).
17. T7: Declarative provisioning option in `services.mail-server` (accounts/domains via systemd oneshot calling the management API at boot) — makes V3 unattended.

**Production server (V-tier, after D1/D2)**
18. V1: Provision Hetzner VPS + NixOS cloud-init + rDNS/PTR.
19. V2: File the port-25/465 limit request EARLY (1-month + invoice requirement — calendar it).
20. V3: Admin bootstrap on VPS (credential file, no wizard).
21. V4: DKIM keygen automation (POST /api/dkim, keys into sops, `signature.<id>` wiring).
22. V5: ACME/Let's Encrypt certs replacing self-signed (`acme.<id>` config + DNS-01 or HTTP-01 path).
23. V6: SPF `v=spf1 mx -all`, DMARC `rua=mailto:dmarc@…`, MTA-STS + `_smtp._tls` TLS-RPT records.
24. V7: Firewall review — exactly the listener ports, admin loopback-only.
25. V8: Queue-depth/queue-age alerting via Prometheus metrics.
26. V9: Backups — `stalwart --export` systemd timer + offsite target + MONTHLY restore test.
27. V10: Log retention + journal size caps on the VPS.
28. V11: Disk sizing/quota policy (per-account quotas, `queue.quota`).

**DNS/Terraform (T-domain-tier)**
29. TF1: `stalwart-mail` Terraform module in the domains repo.
30. TF2: Apply per-domain `.tf` wiring for the first pilot domain (pick one, not all 16).
31. TF3: MX TTL lowering procedure + rollback window (2 weeks Workspace overlap).
32. TF4: rDNS automation via Hetzner API (or documented manual step).

**Monitoring/DMARC (M-tier)**
33. M1: Enable `dmarc-monitor` on evo-x2 against the `dmarc@` mailbox.
34. M2: DMARC ladder automation (none→quarantine→reject from parsedmarc data).
35. M3: Gatus external-view checks for the VPS from evo-x2.
36. M4: Blacklist (RBL) monitoring (MXToolbox or self-check).

**Migration (after D1)**
37. MG1: imapsync dry-run Workspace→Stalwart for one test mailbox.
38. MG2: vandelay evaluation (R6) vs imapsync — pick one.
39. MG3: Full mailbox migration BEFORE MX switch; Workspace as rollback.
40. MG4: Post-migration cutover checklist (MX flip, verify SPF/DKIM/DMARC alignment, mail-tester).

**Hygiene/docs**
41. H1: Create `TODO_LIST.md` + `FEATURES.md` + `ROADMAP.md` (docs-health BUILD; harvest section f).
42. H2: Annotate the three existing status reports with current-state markers (docs-health ANNOTATE).
43. H3: Refresh README header stamp + consumer snippet with the new module facts.
44. H4: Mirror the new verified facts (roles requirement, cache poisoning, relay syntax) into `AGENTS.md` — they currently live only in README.
45. H5: Update the Pareto plan's mermaid graph + mark completed micro-tasks.
46. H6: GitHub Action: `nix flake check` on push/PR (fails closed, asserts it actually ran checks).
47. H7: LICENSE + repo visibility switch (after D3).
48. H8: Push `master` to origin (behind by many commits; push is NOT authorized by default — ask).
49. H9: Kill or tune the auto-commit daemon for this repo (it committed half-edited files twice this session).
50. H10: Threat-model doc: what the loopback guard does/doesn't protect, admin exposure policy, secret inventory.

## g) Questions I cannot figure out myself

1. **D1**: Do we retire Google Workspace and move real mailboxes to a Stalwart VPS — or keep Workspace and run only the parsedmarc/monitoring half? This decides whether the VPS/Terraform/migration tier is scope at all.
2. **D2**: If VPS: which Hetzner project/location, what size ceiling (CX22-class?), and is the backup target the evo-x2 btrfs pool or a Hetzner StorageBox?
3. **D3**: Should `nix-email` be a public repo (with which LICENSE), or stay private? This determines the exact SystemNix flake-input URL shape (`github:LarsArtmann/nix-email` + public vs `git+ssh`).

---

**Awaiting instructions.**
