# Execution Session Closeout — M14 shipped, gate green, harvest done, stale pin-truth fixed

| Field              | Value                                                                                                                                                                                                                                                                      |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Date               | 2026-09-22 22:50                                                                                                                                                                                                                                                           |
| Session type       | Execution continuation of the 2026-09-22 19-23 Pareto plan session (`docs/planning/2026-09-22_19-23_pareto-master-plan-super-email-monitoring.md`); mandate was "READ, UNDERSTAND, RESEARCH, REFLECT, execute until done" after the 21-10 status report left M14 unwritten |
| Branch / origin    | `master`; nix-email daemon-pushed throughout (working tree only FEATURES.md uncommitted at write time); SystemNix 1 commit ahead of origin (UNPUSHED, C17-gated)                                                                                                           |
| Gate state         | `nix flake check` **PASSED** (all 3 VM tests + eval checks), `nix fmt -- . --check` **green**, `module-import-eval` green on **both** arches                                                                                                                               |
| Report format note | Skill default is styled HTML; user instruction this run explicitly demanded `.md` — override honored (point-in-time snapshot, will go stale)                                                                                                                               |

Headline: the one in-progress plan item (M14) is now **shipped with a stronger design than planned** — pinned-source research falsified the plan's default-ON premise (v0.15.5 already ships two conservative inbound rate limiters), so both new wrapper options default OFF with the eval contract proving the absence posture. Full gate green. Harvest complete. Four files carried a stale "SystemNix pins v0.2.0" claim that is **provably false** (input floats `?ref=master`) — all fixed.

---

## a) FULLY DONE

1. **M14 wrapper options (`modules/mail-server.nix`)** — `services.mail-server.rateLimits` (`enable`/`id`/`rate`/`keys`; opt-in sustained damper, default `600/1h` per `remote_ip`) and `services.mail-server.spamFilter.dnsbl.servers` (typed entries: `scope` enum `ip|domain|email|url`, `zone`/`tag` emitted as **quoted** expression constants, `tag` optional). Both default OFF. Eval-time assertions: throttle-key vocabulary (incl. the `authenticated_as`-not-`auth_as` trap) and per-server non-empty zones.
2. **M14 eval contract (`tests/module-import-eval.nix`)** — three new proofs: (1) default settings contain NO `queue.*` and NO `spam-filter.dnsbl.*` keys (absence posture, scoped note for the nixpkgs module's own `spam-filter.resource`), (2) enabled shapes render exactly (limiter keys/rate; dnsbl scope + `'zen.spamhaus.org'`-style quoted zone/tag), (3) invalid inputs (`auth_as` key, empty zone) trip the module's assertion list. Green on x86_64 **and** aarch64.
3. **README verified-facts ledger (i) + (j)** — rate limiting: upstream `DEFAULT_SETTINGS` ships `queue.limiter.inbound.ip` (`remote_ip`, `5/1s`) and `.sender` (`[sender_domain, rcpt]`, `25/1h`) per boot.rs:85-94; full key vocabulary; `rate` grammar `<digits>/<digits><ms|s|m|h|d>`; "false/none/unlimited" silently disables; limiters STACK (all matching must allow); enforcement is connection-gating (`session.is_allowed()`, spawn.rs:45) — a pre-SMTP hangup, not a 4xx. DNSBL: no master switch (server list IS the switch), required `scope` set, unquoted zone dies in the tokenizer ("Invalid variable or constant", tokenizer.rs:342), content-analysis-only, per-server `enable` default true, max-check caps. All with file:line, dated 2026-09-22.
4. **MONITORING.md corrections** — row 2 rewritten: transcript-proven that 0.15.5 exposes NO queue-depth/age gauge (40 HELP series, none queue-related); the implementable spec is now a consumer poll of `GET /api/queue/messages` (§5.4 routes). Row 3 aligned to the poll source. §5.3 `auth_as` typo fixed + companion knob updated to the shipped `rateLimits` option.
5. **Full aggregated gate** — `nix flake check` exit 0 (stalwart-e2e, stalwart-relay-e2e, parsedmarc-e2e all passed; dmarc-eval + module-import-eval eval green; aarch64 covered by the manual builds + eval guards) and `nix fmt -- . --check` green. The relay-e2e pass doubles as M14's behavior proof: default emits zero keys, runtime untouched.
6. **Harvest** — `CHANGELOG.md` [Unreleased] filled (11 Added / 3 Changed / 1 Fixed incl. the M7 lock-mystery verdict); `TODO_LIST.md` swept (6 DONE rows deleted: pin guard, flake-parts guard, module-import-eval, relay IfBlock follow-ups, lock-mystery investigation, IMAP-LOGIN doc row; upstream-watch row updated — **imapclient #663 MERGED 2026-09-18**; presence-list row reworded for the _next_ bump; SystemNix row rewritten); `FEATURES.md` gained the two M14 rows + SystemNix truth fix; `AGENTS.md` stale-pin correction + M14 doctrine note (do not flip defaults ON).
7. **Stale-fact corrections (verified live, not from memory)** — SystemNix consumes this flake via `github:LarsArtmann/nix-email?ref=master` (flake.nix:671) and **never pinned v0.2.0**; the flake-parts dedupe follow + relock (nix-email `2659abb`, `nix-email-contract` GREEN) are committed locally. Corrected in: README pin-discipline paragraph (now states the violation + decision gate), FEATURES.md consumer row, AGENTS.md conventions, decision-batch C17, TODO_LIST row.
8. **`docs/planning/decision-batch.md` C17 rewritten** with the corrected facts (dedupe done locally, unpushed; hard-pin-vs-float surfaced as an explicit call).

## b) PARTIALLY DONE

~~1. **M14 runtime evidence** — eval-verified + source-verified keys, but the limiter was never tripped in a VM (no flood-probe subtest) and DNSBL lookups were never exercised (need resolver DNS; same DNS-less-VM wall as pyzor). Only the default-OFF path is runtime-exercised (via the passing gate).~~ done - flood-node subtest trips the wrapper limiter at runtime: exactly 3 banners + 7 pre-banner hangups (02-58 a/8; ledger (m))
~~2. **MONITORING.md** — the spec is complete (taxonomy, 14 rows, levers, canary design), but **zero alert rules are encoded** anywhere; every SPEC-ONLY row (2, 3, 4, 5, 7, 8, 9, 11, 12, 13, 14) waits on C24 + consumer-side encoding work.~~ still open - the SPEC-ONLY rows wait on C24 + consumer-side encoding (decision-batch; unchanged)
~~3. **SystemNix dedupe + relock** — done locally, committed by the daemon, `nix-email-contract` green; **UNPUSHED** and gated on C17 push approval; hard-pin-vs-float undecided.~~ still open - committed locally, push C17-gated (unchanged)
~~4. **TLS-RPT** — E2E green in this repo (RFC 8460 fixture through parsedmarc 11.0.1 routing → `smtp_tls.json/csv` asserted); SystemNix-side rua mailbox wiring and any live validation remain D1-gated.~~ done(here) - RFC 8460 e2e green in this repo (21-10 a/8); SystemNix-side rua wiring stays D1-gated
~~5. **Upstream watch** — mjs/imapclient half closed (#663 merged); the three nixpkgs PRs (#563651, #563652, #563777) still open and unwatched this segment.~~ imapclient half closed (#663 MERGED 2026-09-18); the three nixpkgs PRs still open (TODO_LIST watch row, re-checked 2026-09-22)
~~6. **FEATURES.md honesty** — the two new options are labeled `FULLY_FUNCTIONAL` on eval-only evidence (certificate-row precedent), but a stricter reading is PARTIALLY_FUNCTIONAL until runtime-exercised.~~ done - the rows carry explicit evidence qualifiers (rateLimits: runtime-trip proof since 2026-09-22; DNSBL: eval-only until D1 - ledger (j))
~~7. **rateLimits consumer ergonomics** — no `match` option exposed (passthrough-only, not called out in the description) and no sizing guide written (21-10 report item 37).~~ done - README "Rate-limit sizing" + match-passthrough documentation + option description extended (02-58 a/16)

## c) NOT STARTED

- ~~**D1/D2-gated production build-out**: M22 declarative domains/accounts, M23 backup/DR, M24 DNS Terraform, M25 migration/cutover, M26 DMARC-live + OIDC; C12 live rua validation; C14 placeholder-secret rotation; sops-key-audit run.~~ still open - TODO_LIST D1-gated rows (unchanged; hard-gated by design)
- ~~**Monitoring encoding** (C24/C29-gated): queue-poll alert rule, auth-failure journald rules, dead-man switch, Gatus templates, capacity rules, Resend webhook telemetry, routing table, round-trip canary implementation.~~ still open - all SPECCED in MONITORING.md; encoding waits on C24/C29 + consumer-side work
- ~~**demo-VM hostfwd/API hang root-cause** (C57) and the g2 Mailpit-sink demo extension.~~ root-cause DONE (02-58 a/3-a/4: firewall + systemd-PATH curl); g2 still open (user call)
- ~~**docs-health ANNOTATE passes** over the five candidate reports + archive sweep (zero eligible until annotate runs).~~ done - 02-58 a/11-a/14 (five candidates) + the 2026-09-29 pass (seven more reports annotated; 17_17-28 archived)
- ~~**Resend live actions**: API key for the :587 smoke; webhook endpoint setup.~~ still open - TODO_LIST blocked row + decision-batch C16-adjacent (user actions)
- ~~**User-decision batch**: C18/C19/C20/C22/C34, Q4/Q5/Q6 — all unanswered (all have recommendations ready).~~ still open - decision-batch (unchanged)
- ~~**New from this session**: repo-wide sweep for further stale version claims (ROADMAP.md and older planning docs were NOT checked this session — the v0.2.0 rot was found in four files; odds are it is not alone).~~ done - the 2026-09-29 docs-health pass checked ROADMAP + both planning docs; the 19-23 plan's two v0.2.0→v0.3.1 pin-claims corrected inline; living docs grep-clean
- ~~Dependabot branch (`dependabot/github_actions/...`) review.~~ done - PR #2 squash-merged 2026-09-22 (02-58 a/2)

## d) TOTALLY FUCKED UP

Nothing shipped broken — the gate is green, every change is daemon-committed, and no false claim survived the session (the two stale-claim classes were caught and fixed). The screwups below are process-level, all self-caught pre-push:

1. **Repeated the `rg -rn` replacement trap** — AGENTS.md explicitly documents that `-r` REPLACES matches; I ran it anyway and read corrupted output once (raw `sed` reads of the real files saved the analysis). This is a "known failure mode, repeated" — the worst class.
2. **Two wasted build cycles on authoring bugs**: (a) referenced `rendered.*` JSON attrs as if they were let bindings (`defaultHasQueue` undefined-variable error); (b) wrote the rate regex without the period digits (`[0-9]+/(ms|s|m|h|d)`) **while the Rate parser source was open in front of me** — `split_once('/')` + Duration-parse of the remainder makes `<digits><suffix>` unambiguous.
3. **Default-absence assertion scoped too broad** — asserted no `spam-filter` key at all; the nixpkgs module legitimately emits `spam-filter.resource`. Caught at build, fixed with a scoped assertion + explanatory note.
4. **The plan's M14 premise itself was wrong** — "rate-limiting is safe to default ON" was written last session without checking upstream `DEFAULT_SETTINGS`. The session's own verify-before-wire doctrine was applied at the wrong phase (code time, not design time). Evidence caught it this session and the design flipped to opt-in, but a session was spent carrying a falsified premise.
5. Minor: one no-op edit inside a multiedit batch (old_string == new_string), and one TODO_LIST edit that assumed the wrong row order (failed, redone with correct context).

## e) WHAT WE SHOULD IMPROVE

1. **Verify plan premises against the pinned source at DESIGN time** — the DEFAULT_SETTINGS discovery belonged in the planning session. Rule of thumb: every "safe default" claim about Stalwart config needs a boot.rs/source citation before it enters a plan.
2. **Treat AGENTS.md failure-mode warnings as pre-flight checks**, not folklore: re-read the relevant warning before every `rg` invocation until the `-r` reflex dies.
3. **Standardize the raw-attrset + JSON-twin pattern** in eval tests (keep `renderedAttrs` for asserts, `builtins.toJSON renderedAttrs` for the builder greps) — it prevents the scoping bug class entirely.
4. **Build the targeted check first even when the change is "provably unaffected"** — the doctrine exists because the reasoning is usually right but not always; the cost is minutes.
5. **FEATURES labels**: introduce an "eval-verified, runtime path: default-only" evidence phrasing (or PARTIALLY_FUNCTIONAL) for options never runtime-exercised, so the inventory cannot outpace the proof.
6. **Annotate overturned plan designs in the plan file's appendix** — the 21-10 report still describes the abandoned default-ON design; living docs record the truth but the snapshot now misleads a fresh reader.
7. **One stale claim = sweep for siblings**: when a false version/pin claim surfaced, four more instances existed. Next time, `rg` the whole repo (incl. ROADMAP, docs/planning) in the same breath.
8. **Consumer ergonomics in the same PR as the option**: the `match`-passthrough note and sizing guidance should ship with the option, not trail it.

## f) 50 things to get done next (brainstorm, impact-sorted; HARVEST must route these into TODO_LIST/ROADMAP, not entomb them here)

**Decisions (minutes each, unblock everything below)**

~~1. D1 — retire Workspace vs monitoring-only (the master gate).~~ still open - decision-batch D1 (unchanged; the master gate)
~~2. D2 — VPS placement/size/backup target (rec: CX22, evo-x2 btrfs + StorageBox later).~~ still open - decision-batch D2 (unchanged)
~~3. C24 — alert channel for non-mail rules (rec: Discord via DiscordSync, ntfy fallback).~~ still open - decision-batch C24 (unchanged)
~~4. C29 — round-trip canary vantage (rec: evo-x2).~~ still open - decision-batch C29 (unchanged)
~~5. C17 — approve SystemNix push (dedupe commit + fleet CI-debt backlog).~~ still open - decision-batch C17 (unchanged)
~~6. NEW — SystemNix pin policy: hard-pin `?ref=v0.3.1` per doctrine vs keep floating `?ref=master`.~~ still open - C17a; UNBLOCKED 2026-09-23 (the v0.4.0 stable ref now exists)
~~7. C18 — keep or drop the branch-protection bypass.~~ still open - decision-batch C18 (unchanged)
~~8. C19 — install Renovate or drop the dead config.~~ still open - decision-batch C19 (unchanged)
~~9. C20 — file the prepared mailsuite STARTTLS issue or skip.~~ still open - decision-batch C20 (draft ready)
~~10. C22 — GitHub Discussions yes/no.~~ still open - decision-batch C22 (unchanged)
~~11. C34 — webmail: record as non-goal?~~ still open - decision-batch C34 (unchanged)
~~12. Q4 — README ops-detail level.~~ still open - decision-batch Q4 (unchanged)
~~13. Q5 — declarative provisioning philosophy (feeds M22).~~ still open - decision-batch Q5 (feeds M22)
~~14. Q6 — spam/Junk ownership verdict (feeds the upstream filing).~~ still open - decision-batch Q6 (feeds the upstream filing)
~~15. g1/g2 — demo host port 18080 permanent; Mailpit sink in the demo.~~ still open - g1 settled by usage (18080 IS the documented demo port); g2 dmarc-in-demo pending (decision-batch)

**Monitoring encoding (unblocked the moment C24 lands)**
~~16. Queue alert via `GET /api/queue/messages` poll (row 2, now implementable).~~ done(spec) - MONITORING row 2 + §5.4; encoding C24-gated
~~17. Over-quota queue-age rule (row 3).~~ done(spec) - MONITORING row 3; encoding C24-gated
~~18. Failed-auth journald rules (rows 4 + §5.3).~~ done(spec) - MONITORING rows 4 + §5.3; encoding C24-gated
~~19. Dead-man switch + `absent()` rules (§5.2).~~ done(spec) - MONITORING §5.2; encoding C24-gated
~~20. Gatus check templates for the VPS (§5.1).~~ done(spec) - MONITORING §5.1; implementation consumer-side (D1)
~~21. Capacity rules — disk + mailbox quota (row 11).~~ done(spec) - MONITORING row 11 (disk/quota > 80%); encoding C24-gated
~~22. Resend webhook bounce/complaint telemetry (row 14).~~ routed - decision-batch C16-adjacent (user action)
~~23. Severity→channel routing table (needs C24).~~ done(spec) - MONITORING routing section; final channel C24-gated
~~24. Round-trip canary implementation (needs C29).~~ done(spec) - MONITORING §6; vantage C29-gated
~~25. Rua-sink freshness poller (row 7).~~ done(spec) - MONITORING row 7 (48 h mtime bound + backup.maxAgeHours dedupe); encoding C24-gated

**D1 build-out**
~~26. M22 declarative `domains`/`accounts` options + DKIM provisioning.~~ still open - D1-gated (ROADMAP theme 1)
~~27. M23 backup/DR design + restore drill on the real host.~~ still open - D1-gated (ROADMAP theme 1)
~~28. M24 DNS (Terraform) — MX/SPF/DKIM/DMARC/TLS-RPT records.~~ still open - D1-gated (ROADMAP theme 2)
~~29. M25 migration window + cutover runbook.~~ still open - D1-gated (ROADMAP theme 3)
~~30. M26 DMARC-live + OIDC wiring.~~ still open - D1-gated (ROADMAP theme 4/5)
~~31. C12 live rua mailbox validation (first real poll).~~ still open - TODO_LIST D1-gated row
~~32. C14 rotate the 3 placeholder secrets + rotation-due check.~~ still open - TODO_LIST D1-gated row
~~33. sops-key-audit pass over SystemNix secrets.~~ still open - D1-gated (rides M22/M26)

**Repo work (no decisions needed)**
~~34. Root-cause the demo-VM hostfwd/API hang (C57), then land the withheld demo docs.~~ done - ROOT-CAUSED + FIXED 2026-09-22 (02-58 a/3-a/4); withheld demo docs landed same day
~~35. docs-health ANNOTATE passes over the five candidate reports, then archive sweep.~~ done - 02-58 a/11-a/14 (five candidates) + the 2026-09-29 pass (seven more reports; 17_17-28 archived)
~~36. Repo-wide sweep for stale version/pin claims (ROADMAP.md + docs/planning unchecked).~~ done - 2026-09-29 docs-health pass: the 19-23 plan pin-claims corrected inline, living docs grep-clean
~~37. Rate-limiter sizing note for consumers (status-report item 37).~~ done - README "Rate-limit sizing" section (02-58 a/16)
~~38. Document the `match`-expression passthrough path for rateLimits/DNSBL conditional zones.~~ done - README sizing section + option descriptions (02-58 a/16)
~~39. Flood-probe subtest for `rateLimits` (runtime proof of a tripped limiter).~~ done - stalwart-e2e flood node, runtime trip asserted (02-58 a/8; ledger (m))
~~40. Decide DNSBL runtime-evidence path (DNS-having VM variant or documented eval-only).~~ done - documented eval-only until the D1 live host (ledger (j) verdict; 02-58 a/9)
~~41. FEATURES honesty pass — "eval-verified" phrasing for non-runtime-exercised rows.~~ done - evidence qualifiers on the M14 rows (see b/6)
~~42. Cut v0.4.0 (CHANGELOG [Unreleased] already carries a release-worthy payload).~~ done - v0.4.0 cut, pushed, tag CI green, GitHub release Latest (05-55 a/7)
~~43. Review/merge the Dependabot github-actions branch.~~ done - PR #2 squash-merged 2026-09-22 (02-58 a/2)
~~44. Note the nixpkgs stalwart 0.16 availability warning in the compat watch (gate log emits it every eval).~~ done - already covered: README Pin-advance runbook + AGENTS compat doctrine carry the 0.16 watch
~~45. Resend API key + one live :587 SASL smoke (needs the key from you).~~ still open - TODO_LIST blocked row (needs the key)
~~46. SystemNix CI-debt triage + worktree cache sweep (C17 payload).~~ still open - TODO_LIST blocked row (C17 payload)
~~47. Hetzner port-25 unblock request calendar (D2 follow-up).~~ still open - D2 follow-up (ROADMAP theme 1)
~~48. OIDC/reverse-proxy working example for the loopback HTTP listener (Caddy protectedVHost doctrine).~~ still open - D1-gated (ROADMAP §5)
~~49. Annotate the 21-10 status report: M14 items now resolved (non-destructive appendix).~~ done - M14 items annotated 2026-09-22 (02-58 a/15); remaining rows closed in the 2026-09-29 pass
~~50. Re-run the fleet eval guards whenever SystemNix's lock moves (habit; already mechanized in-flake).~~ done - mechanized in-flake (the pin-identity guard trips on drift; 21-10 a/1)

## g) Three questions only you can answer

1. **D1 + D2**: Retire Google Workspace mailboxes and execute the full build-out on a CX22-class VPS (backup to evo-x2, StorageBox later) — as recommended — or keep Workspace and run monitoring-only? Everything in section (c) rows 26-33 queues behind this.
2. **C24 + C29**: Approve Discord (SystemNix DiscordSync, ntfy fallback) as the non-mail alert channel AND evo-x2 as the canary vantage? Both are recommendations; monitoring encoding (section f, rows 16-25) starts the moment you answer.
3. ~~**C17 + pin policy**: Approve the SystemNix push (dedupe commit is ready, ~1 commit here + the fleet's CI-debt backlog), and should the input be hard-pinned to `?ref=v0.3.1` per the pin-discipline doctrine, or stay floating `?ref=master`?~~ tag leg RESOLVED - `v0.4.0` cut 2026-09-23 (05-55 a/7), so C17a has a stable ref to pin to; the SystemNix push + pin choice remain open (decision-batch C17)

---

WAITING FOR INSTRUCTIONS.
