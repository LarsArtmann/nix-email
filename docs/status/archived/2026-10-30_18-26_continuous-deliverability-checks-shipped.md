# Continuous deliverability checks — shipped, gate-green, honest self-review

| Field   | Value                                                                                                                          |
| ------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Created | 2026-10-30 18:26 CET (single session, ~2.5 h)                                                                                  |
| Owner   | Lars (request: "fully automated continuous deliverability checks!!! with alerts e.g. Desktop, SigNoz, Gatus")                  |
| Scope   | THIS session only: the deliverability-probe feature work + gate triage it dragged in                                           |
| Verdict | SHIPPED and gate-green locally (flake check + buildflow both EXIT 0); ~~origin CI NOT yet exercised (13 commits ahead, unpushed)~~ RESOLVED 2026-11-01: pushed, origin CI green (runs 41262497225 + 41265954894) |

## What shipped (short version)

- `modules/deliverability-probe.py` — stdlib-only probe: DNS (MX/SPF/DMARC/DKIM), DNSBL per outbound IP (Spamhaus 127.255.255.x error codes = WARN, never "listed"), transport TLS on 25/465/587/993 incl. SASL login, cert expiry via openssl, round-trip canary (submit on 587 → assert IMAPS arrival within SLO → delete; send-failure vs delivery-timeout distinguished). Live-smoked against a real public IMAPS host before the VM loop.
- `services.mail-server.deliverabilityChecks` in `modules/mail-server.nix` — systemd unit + timer (`OnCalendar *:0/15`, `Persistent`, `RandomizedDelaySec=120`), DynamicUser + ProtectSystem=strict hardening, canary password via `LoadCredential`, `tlsVerification = opportunistic|required`, emission-only (exit code, `report.json` + pruned history, Prometheus textfile incl. dead-man `mail_deliverability_probe_timestamp_seconds`). No OnFailure in the wrapper (consumer doctrine, eval-pinned).
- `deliverability-probe` flake package/app (`flake-modules/probe-package.nix`, single-sourced derivation in `modules/deliverability-probe-bin.nix`) — vantage runs from evo-x2/SystemNix against the public hostname. C29 dissolved operationally.
- `deliverability-e2e` VM check (12th check, all three registration sites + README row): full battery green on a real dnsmasq zone (MX/SPF/DMARC/DKIM/PTR + mock DNSBL listed/clean pair), round-trip canary green, emission contract (gauges incl. `dnsbl_listed 0`, timer shape), negatives: DNSBL listing fails naming the zone, wrong canary creds fail at `phase=send`, eval contract forced via `machine.log` (relay-e2e pattern).
- Alert wiring specs, copy-paste, in `docs/MONITORING.md` §8: Desktop/push (SystemNix `onFailure` on the unit name → Discord/ntfy), SigNoz (scrape jobs + 5 alert rules incl. the dead-man staleness rule and the row-2 queue-divergence proxy), Gatus (external TCP/TLS/DNS endpoints).
- Docs: README (option docs + check row + consumer snippet), MONITORING rows 10/13 + §3/§6 status, FEATURES (2 rows), TODO_LIST (SystemNix wiring row + header), CHANGELOG `[Unreleased]`, ROADMAP, decision-batch C24/C29 notes, export-catalog service body, AGENTS (`--rebuild` trap).
- Gate triage dragged in: jscpd had no path-exclusion surface and its only findings were frozen probe-transcript harness overlap (carddav/caldav) → global `exclude: docs/probes/**` + `skip_steps: jscpd` with rationale; statix [20] fixed by collapsing all wrapper systemd units into one block; app `meta.description` added; deadnix fixed by forcing the eval contract.

## a) FULLY DONE

1. Probe script (all check classes live-smoked against real data: gmail MX/SPF/DMARC/PTR/Spamhaus-refusal classifications all behaved correctly).
2. Module options + unit + timer (eval-pinned shapes: LoadCredential, no-OnFailure, DynamicUser, timer OnCalendar/Persistent; assertions for canary credential pairing and full-address form).
3. Vantage package/app (both arches eval; x86_64 built).
4. VM e2e green end-to-end (6th build was green; all subtests).
5. Check registration lockstep (JSON + flake + README + pre-flight grep).
6. `nix flake check` EXIT 0 on the final settled tree (12 checks).
7. `buildflow --max-time 30m` EXIT 0 (32 success / 0 failed; 628 findings = documented warning-level noise classes).
8. ruff floor (E4,E7,E9,F), alejandra, dprint, pipe lint, testscript lint, statix/deadnix clean on all files I touched.
9. Docs sweep (every file the repo's doc map says owns a piece of this).
10. Decision-trail honesty: C24/C29 updated in decision-batch as agent-executed with the owner's request quoted; TODO row for the consumer half.

## b) PARTIALLY DONE

~~1. **Alert wiring** — specs + emission surfaces are complete and tested at the source; the actual Desktop/SigNoz/Gatus configuration lives in SystemNix (their repo) and is NOT wired. That half is one TODO row away, not done.~~ routed: TODO_LIST "SystemNix deliverability-alert wiring" row (Omega D1), 2026-11-01
~~2. **Eval-contract coverage of defaults** — the forced asserts pin the ENABLED shape; `module-import-eval`'s default-OFF posture list does NOT yet pin `deliverabilityChecks.enable = false` default (rateLimits/DNSBL are pinned there). Gap I noticed and did not close.~~ routed: TODO_LIST "Deliverability probe backlog" row (f/6 default pin), 2026-11-01
~~3. **EventCatalog** — service body option list updated; no ADR for the emission-only deliverability doctrine (C29-dissolve could deserve one; decision-batch note stands in for it).~~ routed: TODO_LIST "Deliverability probe backlog" row (ADR 8 candidate), 2026-11-01
~~4. **Demo VM** — correctly NOT enabled (DNS-less VM would red the DNS checks); the reasoning is not documented anywhere durable (it lived in session reasoning; now recorded here §e).~~ routed: TODO_LIST "Deliverability probe backlog" row (quickstart note), 2026-11-01

## c) NOT STARTED

~~1. Origin CI verification — 13 commits ahead, unpushed (never push without owner instruction); the ruff→lockstep→shape→flake-check chain has not exercised this change.~~ done by events 2026-11-01: pushed, origin CI green (runs 41262497225 + 41265954894)
~~2. Live-host run of the probe (D1-gated; the VPS does not exist yet).~~ routed: D1-gated (Omega E12; ROADMAP theme 1)
~~3. evo-x2 vantage timer (SystemNix wiring).~~ routed: TODO_LIST "SystemNix deliverability-alert wiring" row
~~4. SigNoz/Gatus instance validation of the §8 snippets (no access from this repo).~~ routed: TODO_LIST "SystemNix deliverability-alert wiring" row (consumer validation)
~~5. aarch64 runtime of the vantage package (eval-only at that arch).~~ routed: ROADMAP theme 6 aarch64 residue (occasional --all-systems)
~~6. The SystemNix side at all (onFailure entry, scrape jobs, rules, Gatus endpoints, sops canary secret).~~ routed: TODO_LIST "SystemNix deliverability-alert wiring" row

## d) TOTALLY FUCKED UP (all caught before shipping, zero damage in final tree)

1. **Corrupted `modules/mail-server.nix` syntax TWICE** with careless edits: first dropped `type = lib.types.submodule {` from the certificate option (bad edit target); later broke brace balance in the systemd collapse (dropped the cpu-preflight closing brace). Both caught by alejandra immediately. A second multiedit in that batch aimed at the WRONG anchor (`services.stalwart` opener) and only failed by luck of a stale-read guard — had it applied, it would have deleted the services.stalwart block opener.
2. **`--rebuild` misuse TWICE** on never-built derivations ("outputs not valid, so checking is not possible") — the flag implies a prior build; I burned two build cycles before internalizing it (now recorded in AGENTS.md).
3. **Assumed `nix fmt` covered markdown** — it does not (alejandra/.nix only); I reported "format green" while dprint had findings. Buildflow caught it; the fix reformatted 4 files including another session's finished caldav probe README (whitespace-only, gate-required, evidence text untouched).
4. **The eval-contract asserts were DEAD CODE in my first test draft** — bound but never forced; my "eval green" claims about them were vacuous until deadnix flagged it. First forcing attempt then interpolated a context-carrying ExecStart string into testScript (breaks NixOS-test eval), and during the bisect I misdiagnosed the followup error (a `.drvPath` closure-context error from my own command) as persistence of the original bug. Root cause of the real bug: `builtins.any`/`builtins.head` on a string-typed ExecStart (needed `lib.toList`). Three rounds to a one-line fix.
5. **Wrote dead garbage into probe.py on first authoring** (a `subprocess_checks_disabled` no-op class and a broken `socket_wrap`) plus a genuine syntax error in the report dict — self-caught, but the file should never have been written with them.
6. **Lost `\"` escaping through a JSON multiedit** into an assertion message → interpolation outside a string literal → nix parse error.
7. **Avoidable VM-test bugs (1st run)**: IMAP `SEARCH` before `SELECT` (state machine error printed by the server), and SMTP features read without `EHLO` on :25 (and then Stalwart's `550 Invalid EHLO domain` for a bare single-label EHLO argument). The proven patterns sat in `tests/stalwart-e2e.nix`'s imap-probe the whole time — I studied it only AFTER the first red instead of before writing the canary. ~6 VM builds (~35 min) where 2-3 were achievable.

## e) WHAT WE SHOULD IMPROVE (process + product)

Process (mine, this session):

1. **Read the proven sibling implementation BEFORE writing new protocol-touching code** — the e2e imap-probe encodes SELECT-then-fetch, client-side matching (server-side HEADER search never matched), CERT_NONE contexts, and polling discipline. The repo's whole doctrine is transcript-pinned patterns; I re-derived three of them the expensive way.
2. **Verify the formatter you claim** — run `nix develop -c dprint fmt` after ANY markdown edit; `nix fmt --check` is .nix-only here. Should be recorded in AGENTS.md (I recorded the `--rebuild` trap but not this one — see §f).
3. **Never claim "asserts pass" without forcing them** — an unforced nix assert is silent dead code; the forcing pattern (log the tail value, keep the tail a context-free string) is now demonstrated in deliverability-e2e and worth a CONTRIBUTING line.
4. **Edit discipline on big files**: my two syntax corruptions both came from choosing edit anchors one line short of a block boundary; prefer anchor-inclusive boundaries or `lsp_replace_symbol`.

Product (real gaps in what shipped):

5. **No inbound-MX leg**: the canary proves 587-submission→mailbox, but nothing in the battery sends via port 25 as an unauthenticated external sender to prove MX-acceptance→delivery (Gatus only proves the TCP connect). An `inbound` canary variant (send via :25 to the canary account) would close the loop; the 1h directory negative-cache trap makes this delicate on live hosts.
6. **Junk-folder blindness**: the canary searches INBOX only; a spam-scored canary mail would misreport as "delivery timeout (queue/backlog class)" instead of "delivered-to-Junk" — the latter is a distinct and important deliverability verdict. Should search Junk and report it as its own phase/verdict.
7. **IPv6 unsupported** in `--ips`/DNSBL/PTR (v4 only, refused at arg parse).
8. **Cert expiry only on 993/465**, not on the STARTTLS ports 25/587.
9. **`dnsblZones` default `[]`** — deliverability monitoring wants zen.spamhaus.org by default where host-side recursion exists; current default is the safe-but-silent end (README documents the tradeoff).
10. **History depth 48 × 15 min = 12 h** — thin for forensics; either raise or document the sizing.
11. **`RandomizedDelaySec=120` not an option** (minor surface asymmetry).
12. **PROBE_VERSION constant unused externally** (no `--version` flag; trivial).

## f) UP TO 50 NEXT THINGS

Upstream (this repo):

~~1. Wire SystemNix `onFailure` for `mail-deliverability-probe.service` (their repo; specs in MONITORING §8.1).~~ routed: TODO_LIST SystemNix wiring row (Omega D1.1)
~~2. SigNoz scrape jobs + the 5 rules from §8.2 on the consumer host (their repo).~~ routed: TODO_LIST SystemNix wiring row (Omega D1.2)
~~3. Gatus endpoint set from §8.3 on evo-x2 (their repo).~~ routed: TODO_LIST SystemNix wiring row (Omega D1.3)
~~4. evo-x2 vantage systemd timer running `nix run github:LarsArtmann/nix-email#deliverability-probe` with a sops canary secret (their repo).~~ routed: TODO_LIST SystemNix wiring row (Omega D1.3, vantage timer)
~~5. Watch the next origin CI run once pushed (ruff→lockstep→shape→flake-check chain; needs gh auth restored for run watching).~~ done by events 2026-11-01 (CI green, watched by the 11-01 closeout session)
~~6. Add `deliverabilityChecks.enable = false` default pin to `module-import-eval`.~~ routed: TODO_LIST "Deliverability probe backlog" row
~~7. Add the inbound-MX canary leg (send via :25 unauthenticated → assert arrival; mind the negative-cache trap).~~ routed: TODO_LIST "Deliverability probe backlog" row (inbound-MX leg)
~~8. Junk-folder search + distinct "delivered-to-junk" verdict in the canary.~~ routed: TODO_LIST "Deliverability probe backlog" row (Junk verdict)
~~9. IPv6 support in `--ips` (reverse nibble format + v6 DNSBL zones).~~ routed: TODO_LIST "Deliverability probe backlog" row (IPv6)
~~10. Cert-expiry checks for 25/587 (STARTTLS handshake + openssl s_client -starttls smtp).~~ routed: TODO_LIST "Deliverability probe backlog" row (cert on 25/587)
~~11. Consider `dnsblZones = ["zen.spamhaus.org"]` default for the acme/manual tiers (owner taste).~~ routed: TODO_LIST "Deliverability probe backlog" row (owner taste)
~~12. `deliverabilityChecks.randomizedDelaySec` option.~~ routed: TODO_LIST "Deliverability probe backlog" row (trivia tail)
~~13. `--version` flag on the probe (emit PROBE_VERSION).~~ routed: TODO_LIST "Deliverability probe backlog" row (trivia tail)
~~14. Expose per-check timeouts (currently one global `--timeout`).~~ routed: TODO_LIST "Deliverability probe backlog" row (per-check timeouts)
~~15. Consider a `deliverabilityChecks.metricsUrl` loopback probe (Stalwart /metrics/prometheus liveness as a check).~~ routed: TODO_LIST "Deliverability probe backlog" row (metricsUrl)
~~16. dmarc-monitor freshness as a probe check option (mtime of aggregate.json > 48 h — row 7 still SPEC ONLY).~~ routed: TODO_LIST "Deliverability probe backlog" row (dmarc freshness)
~~17. Parse parsedmarc sinks into the report (recent DMARC verdicts as INFO checks — closes row 6 direction).~~ routed: TODO_LIST "Deliverability probe backlog" row + ROADMAP parked follow-ons
~~18. ADR for the emission-only deliverability doctrine (candidate ADR 8 in export-catalog).~~ routed: TODO_LIST "Deliverability probe backlog" row (candidate ADR 8)
~~19. Document the demo-VM "why deliverabilityChecks stays off here" note in the quickstart.~~ routed: TODO_LIST "Deliverability probe backlog" row (quickstart note)
~~20. Consider flake-check `--all-systems` locally to build the aarch64 package at least once.~~ routed: ROADMAP theme 6 aarch64 residue (--all-systems)
~~21. Revisit jscpd skip when BuildFlow ships per-tool excludes (TODO row updated with this).~~ done 2026-10-31 (Omega D5: .jscpd.json committed, step UN-SKIPPED, 11 -> 0 clones)
~~22. BuildFlow: findings-gate severity map for jscpd "error" on evidence dirs (their repo).~~ routed: TODO_LIST BuildFlow row (their repo)
~~23. Add a `scripts/check-*` guard or CONTRIBUTING line: "force let-block asserts" (the dead-assert lesson).~~ routed: TODO_LIST "Deliverability probe backlog" row (force-assert guard)
~~24. AGENTS.md: record the `nix fmt` ≠ dprint trap (alea jacta: one line, Commands section).~~ done 2026-11-01 (AGENTS.md repo-tool traps clause, docs-health pass)
~~25. CONTRIBUTING: canonical "forcing eval contracts in VM tests" pattern (machine.log + context-free tail).~~ routed: TODO_LIST "Deliverability probe backlog" row (CONTRIBUTING forcing pattern)

Consumer/fleet (SystemNix + hosts):

~~26. Provision the live canary account + sops secret (C44-adjacent doctrine decision).~~ routed: decision-batch C44 + sitting sheet (owner)
~~27. Decide C24 formally (Discord vs ntfy for the push leg) — decision-batch row updated with the multi-channel read.~~ routed: sitting sheet policy batch (C24)
~~28. SystemNix catalog description sync for the new capability (their cadence row).~~ routed: TODO_LIST SystemNix description-sync row
~~29. When the VPS exists: enable deliverabilityChecks with `tlsVerification = "required"`, acme tier, zen zone.~~ routed: D1-gated (ROADMAP theme 1)
~~30. evo-x2 dead-man for its own vantage timer (the monitor-of-the-monitor recursion never ends).~~ routed: TODO_LIST SystemNix wiring row (evo-x2 dead-man)

Verification debt:

~~31. Push (owner action) and watch CI run green on the 13-commit batch.~~ done by events 2026-11-01 (pushed; CI green 41262497225 + 41265954894)
~~32. Live-host smoke of the whole battery (D1).~~ routed: D1-gated (Omega E12)
~~33. SigNoz instance validation of the rule YAML syntax.~~ routed: TODO_LIST SystemNix wiring row
~~34. Gatus 5.x validation of the endpoint config (starttls:// scheme availability).~~ routed: TODO_LIST SystemNix wiring row
~~35. Confirm daemon-pushed master matches my final tree byte-for-byte (13 auto-commits, no foreign edits observed — verify on push).~~ done by events 2026-11-01 (pushed range verified green; tree in sync)

Bigger follow-ons noticed but out of scope:

~~36. TLS-RPT/DMARC report digesting into the probe report (rows 5-6).~~ routed: ROADMAP theme 4 parked follow-ons (2026-11-01)
~~37. Queue-divergence rule validation against a real backlog (row 2 proxy is spec-only until a live test).~~ routed: Omega E11 (queue surface) + MONITORING row 2
~~38. MTA-STS / TLS-RPT DNS record checks (record types exist; not in battery).~~ routed: ROADMAP theme 4 parked follow-ons
~~39. DNSSEC validation posture of the probe's lookups (dig defaults; maybe +dnssec flag option).~~ routed: ROADMAP theme 4 parked follow-ons
~~40. Rate-limit the probe itself on tiny hosts (fixed 15-min cadence is fine for one canary mail; document mail-volume impact).~~ routed: ROADMAP theme 4 parked follow-ons
~~41. Consider `--notify` webhook flag (BREAKS emission-only doctrine — only if owner wants direct push).~~ routed: ROADMAP theme 4 parked follow-ons (owner-demand-only)
~~42. A `docs/probes/` transcript set for a live-host probe run (wire-claims stay source-level until then — the INBOXCLEAN transcript rule extended).~~ routed: D1-gated (transcript rule; Omega E12)
~~43. Prometheus textfile scrape alternative if node_exporter is absent (a tiny socket-activated httpd or pushgateway; consumer decision).~~ routed: ROADMAP theme 4 parked follow-ons (consumer art)
~~44. Alertmanager/SigNoz routing tree for WARN vs CRITICAL severities (consumer).~~ routed: ROADMAP theme 4 parked follow-ons (consumer art)
~~45. Fold probe duration trends into SigNoz dashboards (gauge exists; dashboard is consumer art).~~ routed: ROADMAP theme 4 parked follow-ons (consumer art)
~~46. VM-test the timer actually FIRING (the test asserts enabled + calendar, not a real tick; low value, ~15 min cost).~~ routed: ROADMAP theme 4 parked follow-ons (known low-value gap)
~~47. Property-test the dig parsers against weird TXT chunking (multi-string records with quotes/spaces).~~ routed: ROADMAP theme 4 parked follow-ons
~~48. The canary message carries no List-Id/Precedence headers — some receivers may thread-reply; consider auto-delete rule on the mailbox side.~~ routed: ROADMAP theme 4 parked follow-ons
~~49. Probe log line format could carry a stable `CHECK name status detail` prefix for journald field extraction (journalctl -g patterns).~~ routed: ROADMAP theme 4 parked follow-ons
~~50. Re-run the whole battery on the 0.16.27+ pin advances (new check rides the existing gate automatically — nothing to do, listed to remember it self-applies).~~ routed: standing ride Omega E17 (self-applies at the next bump)

## g) QUESTIONS FOR THE OWNER (cannot be figured out from the repo)

~~1. **Canary account policy on the live host**: should SystemNix provision a dedicated `canary@<domain>` account (extra store object, sops-rendered password file), or should the probe reuse an existing mailbox you own? (This is C44-adjacent: plan-borne passwords are store-visible, which is why the wrapper refuses to auto-provision it.)~~ routed: decision-batch C44 + sitting sheet (owner)
~~2. **Desktop alert leg**: formalize C24 as Discord-via-SystemNix (recommended), ntfy direct, or BOTH? And relatedly: do you ever want an opt-in `--notify <ntfy-url>` flag on the probe itself (direct push, breaks the emission-only doctrine — I deliberately did not build it)?~~ routed: sitting sheet C24; the --notify flag = ROADMAP parked follow-ons (owner-demand-only)
~~3. **Push cadence for verification**: the 13 commits sit unpushed. Say the word and I leave pushing/CI-watching to you (gh auth is dead on this machine), or you restore gh auth and I watch the run and fix any CI-only red (e.g. aarch64-shape surprise) myself.~~ done by events 2026-11-01: pushed + green (41265954894); standing rule unchanged (assistants never push)

## Session stats

| Metric                          | Value                                                            |
| ------------------------------- | ---------------------------------------------------------------- |
| Files touched                   | 19 (+1696 / −132 vs 12 commits ago)                              |
| VM builds (deliverability)      | 6 (1 green set: final 2 consecutive greens)                      |
| buildflow runs                  | 6 (red→red→red→red→red→GREEN; 3 distinct root causes, all fixed) |
| Self-inflicted syntax breakages | 3 (all caught by gate/lint, none shipped)                        |
| Final gates                     | `nix flake check` EXIT 0; `buildflow --max-time 30m` EXIT 0      |
