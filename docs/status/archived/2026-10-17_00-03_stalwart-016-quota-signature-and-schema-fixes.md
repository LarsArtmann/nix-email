# Status: Stalwart 0.16 upgrade - schema fixes landed, quota signature open

- **Date:** 2026-10-17 00:03 UTC
- **Session:** continuation of the 0.16 upgrade (after the two 2026-10-16 reports)
- **Gate state:** `nix flake check` NOT yet green - stalwart-e2e is one subtest
  from green (19+ pass, quota fails); relay-e2e fix landed but unverified;
  eval checks + fmt green.

## Where the upgrade stands

`tests/stalwart-e2e.nix` now fails ONLY at the quota subtest. Everything
before it - provisioning, SMTP 5xx, IMAPS, the JMAP session endpoint, the
fallback admin, submission on 587, dual DKIM, metrics, journal hygiene,
alias delivery, and the runtime catch-all apply - passes on 0.16.22.

## a) FULLY DONE

1. **JMAP session endpoint rewrite, transcript-pinned live** (demo VM
   probes, this session): `GET /jmap` = 404 for everyone; session =
   `/.well-known/jmap` -> 307 (`location: /jmap/session`) -> 200 authed;
   anonymous session = **200 with `primaryAccounts: {}`** (NOT 401 - the
   summary's assumption was wrong); anonymous API POST = 401 (the real
   enforcement point); `apiUrl` = absolute `https://<host>/jmap/` (unusable
   in a DNS-less VM - test strips scheme+authority with jq and rides the
   loopback path). Three subtests rewritten: management, JMAP
   session/mailbox/needle, restart-persistence.
2. **Domain-namespace root cause found and fixed:** the wrapper derives the
   provisioned Domain value from `services.mail-server.hostname`, and 0.16
   synthesizes account addresses as `name@<Domain.name>`. With hostname
   `mail.example.test`, every test address lived OUTSIDE the local
   namespace (auth 535'd, MAIL FROM 501'd, session rendered
   `user1@mail.example.test`). Fix: e2e hostname = `example.test`.
3. **0.16 account schema pinned by apply transcripts:** `User.name` is the
   LOCAL PART (a full address fails apply: "Invalid email local part |
   Properties: name"); there is NO `emailAddress` field (silently dropped);
   the synthesized address is the unique `email` index and the auth
   identity; MAIL FROM outside the address set = 501. All plans now carry
   localpart names; dead `emailAddress` fields removed from e2e,
   relay-e2e, demo-vm; demo-eval contract updated (name + Domain.name pair
   - no-legacy-field assert).
4. **relay-e2e stale-red discovered and fixed:** the "green" from the
   previous session was stale - the stored run failed at boot: dnsmasq's
   black-hole upstream (192.0.2.1) made the SpamPyzor#singleton reload
   validation fail ("Invalid address: failed to lookup address
   information"), the apply aborted, listeners never spawned, port 587
   starved. Fix: forward upstream to 10.0.2.3 (same resolution path as
   every other node). Rebuild pending.
5. **Catch-all runtime apply: three plan-dialect lessons, all
   transcript-pinned:** (1) `#id` references resolve ONLY against earlier
   ops in the same plan (Domain upsert must precede the Account whose
   domainId references it); (2) an upsert patching an existing object must
   carry its match property (`name` for Domain); (3) `credentials` must be
   the indexed-map form `{"0":{...}}`, not a JSON array ("Invalid value for
   object property | Properties: credentials"). The subtest now passes.
6. **Failure visibility hardening:** the catch-all apply dumps its log even
   on failure (assert with message); a silent log cost one full VM run.
7. **0.16.26 upstream research:** reload-doesn't-rebind-listeners remains
   open upstream (issue #352, since 2024 - nothing to file, our
   ExecStartPost restart patch stays); broken default DNSBL rows fixed
   upstream in 0.16.23 (commit 87de8601, `bit_and` function) - our
   empty-DNSBL reconcile stays anyway (default-OFF posture, not just the
   bug).
8. Eval checks (module-import-eval, demo-eval, dmarc-eval) green; `nix fmt
   -- . --check` green; all edited files parse-clean.
9. Stale VM cleanup: killed the 6.5 h-old parked demo VM (console orphaned
   by the session restart) and two leftover nixbld test VMs (other
   projects' builds were identified and left alone).

## b) PARTIALLY DONE

~~1. **stalwart-e2e:** one subtest left - quota. The 0.15 journal signature~~ done - journal SILENCE pinned + subtest re-pinned (03-34 a/1-a/2, `e5f5da1`); e2e green 17/17
`Message rescheduled for delivery` never appears in 0.16 within 60 s.
Three debug-driver attempts to capture the 0.16 retry signature failed
on an INSTRUMENT bug: long-running swaks under `machine.execute` in the
debug driver dies (status 28/-1, empty log) in the provision-restart
window; the last probe ran but the message never got submitted
(journal: NO quota/retry/queue lines at all). The main-run submission
works, so this is a debug-instrument issue, not a product issue.
~~2. **relay-e2e:** dnsmasq fix + account shape landed, rebuild not yet run.~~ done - relay-e2e green 3/3 in a real run (03-34 a/4)
~~3. **Gate:** full check suite + `nix flake check` + buildflow pending on~~ done - full gate green: nix flake check + buildflow + fmt EXIT:0 (03-34 a/5)
the quota fix.

## c) NOT STARTED

~~1. Docs sweep: README (quickstart ports/domain unchanged but the~~ done - the 2026-10-17 docs-health pass + 03-34 a/8 (README quota facts)
provision/login contract changed), AGENTS.md doctrine (the new schema

- plan-dialect lessons), CHANGELOG breaking entry, FEATURES, TODO_LIST
  harvest, INBOXCLEAN re-verification note, the 0.16.26 findings into the
  README ledger.
  ~~2. Cleanup: parked demo VM (background shell 0DA) still running;~~ done - 03-34 a/11 (GC roots, /tmp artifacts; the parked demo VM was already dead)
  /tmp/st-e2e-root + /tmp/st-debug-driver GC roots; /tmp debug scripts.
  ~~3. Archive decision for the two 2026-10-16 status reports (archive policy:~~ done - archived in the 2026-10-17 docs-health pass (every forward item closed or routed below)
  only when all forward-looking items are closed - the 50-task backlog
  below supersedes them).

## d) TOTALLY FUCKED UP (own errors, paid in VM runs)

1. **Schema conclusion without an apply transcript:** I read the Rust
   struct dump (`User.name` = "user@domain" doc comment) and renamed all
   accounts to full addresses - a full VM run later, apply said "Invalid
   email local part". The struct docs were loose; the validator is the
   truth. Transcript-first must extend to schema claims.
2. **Guessed plan-order fix:** I reversed the catch-all ops on a plausible
   theory (catchAllAddress needs its account) without a transcript - wrong
   direction; the real rule (in-plan `#id` resolution) only surfaced once
   the apply log was dumped. Two runs spent.
3. **drv-forensics rabbit hole:** after the visibility fix, identical drv
   hashes sent me hunting stale evals - wasted effort on `strings .drv`
   greps (testScript never lives in .drv text) and nix-log attribution.
   The actual mechanism: cached-failure replay + daemon reformat commits
   mid-run. Should have bumped the drv immediately.
4. **Inherited stale "green":** the summary's relay-e2e GREEN claim was
   already dead (its stored run was red at boot, hours earlier). I built
   on that trust instead of verifying.

## e) WHAT WE SHOULD IMPROVE

1. Rule extension: **no schema claim without an apply transcript** (or
   struct + validator cross-check). Struct docs have been wrong once.
2. Every logged artifact in VM tests dumps on failure by default, not on
   success.
3. Debug-driver probes must `systemctl start stalwart-provision.service`
   (idempotent) + settle BEFORE probing - port-open != server-ready (the
   ExecStartPost restart window eats connections).
4. Long-running debug commands via `machine.execute` are unreliable
   (channel closes; status 28/-1, empty logs) - use packaged helper
   scripts or `succeed(... || true)` with file capture.
5. Never trust a sibling report's "green" - read the stored run log first.
6. Serialize heavy VM builds: three concurrent VM builds (this repo +
   pbx-artmann + SystemNix) OOM-killed one run mid-flight.
7. The daemon reformats/commits mid-session - re-read files after every
   pause (two stale-read edit failures this session, both caught by
   exact-match failures).

## f) NEXT TASKS (priority order)

~~1. Capture the 0.16 over-quota retry signature (fix the debug probe:~~ done - journal silence pinned (03-34 a/1)
succeed-wrapped swaks with `|| true`, or a packaged probe script) and
re-pin the quota subtest to the transcript-observed line(s).
~~2. Rebuild stalwart-e2e to green (expect: full pass).~~ done - green 17/17 subtests in a real run (03-34 a/3)
~~3. Rebuild stalwart-relay-e2e (dnsmasq + shape fixes) to green.~~ done - green 3/3 (03-34 a/4)
~~4. Full check suite: all six checks in one `nix build` command.~~ done - all six checks in one suite (03-34 a/5)
~~5. `nix flake check` (redirect + echo-exit procedure).~~ done - EXIT:0 all checks passed (03-34 a/5)
~~6. `nix fmt -- . --check` before yielding.~~ done - EXIT:0 (03-34 a/5)
~~7. buildflow gate.~~ done - EXIT:0, 35 spawns, warnings-only nix-checker (03-34 a/5)
~~8. Verify ci.yml lockstep lists unchanged (no check added/removed -~~ done - verified mechanically: 6=6 x86_64 + aarch64 shape (03-34 a/6)
expected unchanged).
~~9. README sweep: verified-facts ledger entries for every new transcript~~ done - the docs-health pass ledger section + 03-34 a/8 quota facts
fact (JMAP session endpoint shapes, anonymous 200/{} contract, User
name/localpart + synthesized address, #id in-plan resolution, Domain
match-property, credentials indexed-map, hostname=Domain.value,
dnsmasq upstream requirement for reload validation).
~~10. README quickstart re-check: demo login demo@mail.demo.test /~~ done in part - contract verified in tree (this pass); the live walk rides the demo-smoke TODO row
demo-nixemail-2026 still correct (it is - the demo namespace was
already coherent).
~~11. README "Pin-advance runbook" note: 0.16.23 fixed the DNSBL bit_and~~ done in part - 0.16.23 DNSBL + x86-64-v2 notes in the runbook (this pass); the delta table rides C45
class; 0.16.26 also needs x86-64-v2 (breaking) - relevant to Q2 below.
~~12. AGENTS.md: fold the new doctrine (schema-transcript rule, plan~~ done - 0.16 doctrine + upgrade-loop rules (this pass) + debug-instrument rules (03-34 a/7)
dialect, execute-in-debug-driver trap, relay dnsmasq requirement).
~~13. CHANGELOG: breaking-change entry (0.16 object model, vendored module,~~ done - BREAKING entry with the gate-green state (this pass)
hostname=domain contract, admin via systemd-creds required).
~~14. FEATURES.md: honest 0.16 inventory (what the wrapper covers now).~~ done - status flips incl. backup BROKEN + e2e/relay green (this pass)
~~15. TODO_LIST: strike resolved rows (JMAP rework, catch-all apply, quota~~ done - TODO_LIST rebuilt this pass; the 03-34 rows harvested
once green), harvest section f of this report.
~~16. INBOXCLEAN.md: add re-verification note - JMAP auth identity is the~~ done in part - 0.16 banner (this pass); full re-verification rides the demo-smoke row (03-34 b/5)
synthesized address; session endpoint moved; probe transcripts are
0.15-historical.
~~17. docs/MONITORING.md + docs/TELEMETRY.md: 0.16 metrics/telemetry keys~~ done in part - caveats (this pass); the quota alert rule + key spot-check are TODO rows (03-34 e/7 + f/16 + f/23)
spot-check against the binary (version-skew caveat).
~~18. File the 0.16.22->0.16.26 delta somewhere durable (ledger table:~~ routed - C45 TODO row (03-34 b/1 + f/5)
bit_and fix, x86-64-v2 requirement, #352 still open).
~~19. Kill parked demo VM (shell 0DA) + remove GC roots~~ done - 03-34 a/11
(/tmp/st-e2e-root, /tmp/st-debug-driver) + /tmp debug scripts.
~~20. Decide the demo VM debug-instrument fix (FIFO console) worth~~ done - AGENTS debug-loop rules (this pass + 03-34 a/7)
documenting in AGENTS.md - it worked but the restart-window trap
should be written down.
~~21. Consider a `quota-probe` helper (packaged script) so quota assertions~~ superseded - MOOT: silence pinned with a negative journal assertion; no helper needed
don't depend on inline swaks timing.
~~22. Sweep the wrapper for other `#id` usages that rely on cross-plan~~ routed - TODO match-property audit row
references (consumer runtime plans will hit the same rule).
~~23. Document the runtime-plan dialect in the vendored module's~~ routed - the README 'Stalwart 0.16' ledger section carries the dialect (this pass); the vendored stalwart.md pass rides the #552103 retirement
stalwart.md (indexed-map lists, match-property requirement).
~~24. Add a module-import-eval assertion pinning the e2e hostname=domain~~ done in part - demo-eval pins the name+Domain pair (00-03 a/3); the module-import-eval assert rides the provision-plan-eval row
contract (hostname must equal the Domain value consumers expect).
~~25. Add demo-eval-style eval asserts for relay-e2e shapes (account~~ routed - TODO provision-plan-eval row (ride-along)
localpart + domain object present) so shape regressions fail cheaply.
~~26. Check whether the Domain upsert patch (name + catchAllAddress only)~~ routed - TODO match-property audit row (ride-along)
merged or replaced the boot object - assert dkimManagement survived
(post-apply domain read via CLI inspect) or accept the default.
~~27. Assert the JMAP session username renders the synthesized address~~ routed - the JMAP subtests pass (03-34 a/3); the username-render assert rides the JMAP anti-rot row
(user2@example.test) - pins the namespace contract end-to-end.
~~28. Add an explicit anon-API-401 assertion to the restart-persistence~~ routed - TODO JMAP anti-rot row (ride-along)
subtest (it currently only re-checks primaryAccounts empty).
~~29. Consider asserting `location: /jmap/session` on the 307 (header~~ routed - TODO JMAP anti-rot row (ride-along)
capture) - currently only the final 200 is asserted.
~~30. Sweep tests for remaining `<**`-style 0.15 transcript assumptions~~ done - the quota casualty re-pinned (03-34 a/2); e2e green 17/17
against 0.16 wording (the quota line is the confirmed casualty; audit
the rest).
~~31. Confirm the flood-node limiter subtest numbers on 0.16 (M14 evidence~~ done - flood passed its first 0.16 exercise (03-34 a/3); the robustness note is a TODO row
re-verification - 3 banners / 7 hangups transcript pending).
~~32. Verify provisioning idempotency on e2e: second boot-apply line should~~ routed - TODO demo-smoke/probes row
read 0 failed (transcript exists in build logs - archive the number).
~~33. Update docs/status archive policy actions: annotate the two~~ done - this pass archived the 10-16 reports + 01-22
2026-10-16 reports with supersession pointers once the gate is green.
~~34. README: document the anon-session-200 posture (consumer-relevant:~~ done - README JMAP quickstart + INBOXCLEAN banner (this pass)
InboxClean must treat primaryAccounts {} as unauthenticated).
~~35. INBOXCLEAN probe re-run on 0.16 (JMAP adapter contract) after the~~ routed - TODO demo-smoke/INBOXCLEAN row
gate is green - schedule, don't do inline.
~~36. Re-verify dmarc-eval + parsedmarc-e2e are truly decoupled (grep for~~ done - grep 2026-10-17: zero `services.stalwart` refs in parsedmarc-e2e + dmarc-eval
services.stalwart references) - believed done, one more cheap grep.
~~37. Add the "smtpd relay not allowed" wording check to the e2e unknown~~ routed - TODO relay bounce-path row
recipient subtest if 0.16 changed the 550 detail (currently code-only

- fine, but note it).
  ~~38. Check `stalwart-cli check` (config validator) as a cheaper pre-apply~~ routed - TODO provision-plan-eval row (ride-along idea)
  gate in the provision unit - possible upstream 0.16 addition worth
  wiring.
  ~~39. Consider upstreaming the dnsmasq-upstream lesson to the nixpkgs PR~~ routed - upstream watch row (verify-before-filing first)
  thread (test-environment note) AFTER verify-before-filing.
  ~~40. Evaluate whether the ExecStartPost restart patch should move upstream~~ routed - upstream watch row
  (nixpkgs PR #552103) with our transcript - same verify-first gate.
  ~~41. Backlog the 0.16.26 package override experiment (store already has~~ routed - C45
  stalwart-0.16.26 built - someone can test quickly) - gated on Q2.
  ~~42. Sweep for `startDate`/`emailAddress`-era option references anywhere~~ done - era markers (this pass); the remaining deep sweep is a TODO row
  in docs (README wrapper option table) that 0.16 renamed/dropped.
  ~~43. Re-run the host-side parser dry-run script (parsedmarc fixtures) once~~ won't implement routinely - fire on fixture/pin changes (the AGENTS rule's trigger); the gate went green without it
  before the full gate to catch fixture drift early - cheap.
  ~~44. Verify the demo VM from scratch in a scratch dir (README "Try it in~~ routed - TODO demo-smoke row
  a VM") on the 0.16 closure - the summary's smoke was pre-rename.
  ~~45. Double-check `virtualisation.memorySize = 2048` nodes against the~~ routed - TODO e2e polish row (ride the next VM-test touch)
  OOM incident - consider 1536 for the flood node.
  ~~46. Time the full e2e run and compare with the 0.15 era (regression~~ done in part - per-subtest timings exist in the green run log (03-34 a/3); the regression watch folded into the e2e polish row
  signal for the retry backoff length).
  ~~47. Consider tagging the quota retry period explicitly in the plan~~ superseded - MOOT: the journal is silent, nothing to align (03-34 a/1)
  (SystemSettings queue settings) if the 0.16 backoff is minutes-long,
  so the test stays fast and the product stays explicit.
  ~~48. Write the missing AGENTS.md note: `nix log` attribution + cached~~ done - AGENTS cache/empty-log + gate rules carry the class (this pass)
  failure replay trap (this session's d3).
  ~~49. Confirm no other test reads `/jmap` directly (grep - done mentally,~~ done - grep 2026-10-17: the remaining /jmap/ references are the anon-401 POST, a comment, and the apiUrl assert - no dead reads
  do it mechanically).
  ~~50. Update the three open questions below into decision-batch.md once~~ done - C42-C46 recorded (this pass)
  answered.

## g) QUESTIONS I CANNOT ANSWER MYSELF

~~1. **Release doctrine:** cut `v0.5.0` with the vendored 0.16 module once~~ routed - decision-batch C43
the gate is green, or hold until nixpkgs PR #552103 lands in our
SystemNix pin and we can retire the vendored module first? (Affects
whether v0.5.0 carries the two vendor patches as permanent API.)
~~2. **Package version doctrine:** stay on `stalwart_0_16` = 0.16.22 from~~ routed - decision-batch C45
the SystemNix-pinned nixpkgs rev, or overlay to 0.16.26 (fixes the
DNSBL validation class upstream; but 0.16.26 requires x86-64-v2 and
drifts from the consumer pin)?
~~3. **Quota assertion fate:** if 0.16's confirmed journal signature only~~ closed - realized as the journal-silence posture: SMTP-accept + IMAP-absence + negative journal assertion (03-34 a/1-a/2)
appears after a multi-minute backoff - keep the retry-loop assertion
with a longer timeout (slower e2e), assert only SMTP-accept +
IMAP-absence (weaker but stable), or pin an explicit short retry
schedule in the test plan (product-visible setting change)?

---

_Generated 2026-10-17 00:03 UTC; stalwart-e2e at 19+ green subtests, one
open; relay-e2e fix pending rebuild; full gate pending._
