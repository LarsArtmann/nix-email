# X-generation execution session: 9 lanes done in nix-email, pbx flip landed mid-flight (DNS egress saga)

Session window: 2026-10-19 ~07:55 - 12:17 CEST. Executor: Crush agent
session (X-generation plan executor). User interrupt at 12:17: FULL
STATUS + self-review, then WAIT. Concurrency context: the CardDAV-probe
session was LIVE the whole time (daemon commits 07:44-08:02+; 29 crush
processes), and a pbx-artmann session was touching that repo's AGENTS.md
(08:16-08:19).

## 0. TL;DR

| Area | Verdict |
| --- | --- |
| nix-email lanes (X9, X6, X10, X12.1, X16, X14, X1.2-verify) | DONE, gate GREEN locally (buildflow EXIT:0 at 08:26) |
| nix-email master | 10 commits AHEAD of origin - the daemon has NOT pushed since 05:52, so CI has NOT yet exercised the new lockstep step |
| CI red 05:34/05:45/05:52 | TRIAGED, not mine: the new CI ruff step catching the CardDAV session's probe files (TODO row 68 hand-off honored, evidence appended) |
| pbx-artmann X5 flip | LANDED MID-FLIGHT: flip + leg re-adds committed by their daemon (7b5f7dc), but the gate is RED on a NEW, transcript-pinned blocker (OIDC discovery fetch at reload-validation + VM egress); 14 VM runs total, NOT green at yield |
| Misc | 6 TODO rows closed with CHANGELOG entries; AGENTS.md kept within the 220-line cap (219) after my own edits briefly pushed it to 224 |

## 1. a) FULLY DONE

1. **Baseline ritual + CI triage.** git status clean at start, 5+ crush
   sessions live, same-day reports scanned. CI runs 39205296496 /
   39206210677 / 39206760255 read via log-failed: failing STEP = the
   fail-closed ruff step (added in the W tooling floor), offenders =
   CardDAV session files (`carddav_diag.py:165` F541,
   `carddav_probe.py:246` F841). Foreign in-flight files NOT touched
   (doctrine); the F541 added to TODO row 68's evidence cell so the
   owning session sees the full debt list. My cancelled plan-push run
   (39206106776) superseded by those newer pushes - no action needed.
2. **X9 - check-set single-source + lockstep check (the session's
   engineering centerpiece).** New `tests/check-expected.json` = the ONE
   canonical machine list (x86_64 + aarch64). New pure-eval check
   `check-set-lockstep` in flake-modules/checks.nix: throws at eval time
   from `nix flake check` when the declared set diverges, spelling out
   both sets. Consumers migrated to read the JSON: ci.yml lockstep step,
   ci.yml aarch64 shape step (now jq-based), pre-push
   scripts/check-inventory.sh. FOUR-sites rule honored in one change and
   the doctrine UPGRADED: AGENTS.md now says TWO sites (the JSON + the
   README prose row) because the restatement class is dead. Verified:
   green eval both arches, negative test (drifted name throws EXIT:1,
   restore passes), drift alarm green, inventory hook green, actionlint
   + shellcheck clean, `nix fmt -- . --check` green.
3. **X6 - match-property audit CLOSED.** Traced all 34
   `services.mail-server` options to consumption (plan emission,
   settings, credentials, assertions, warnings): ZERO dead/no-op
   options - the wrapper is a fresh 0.16 rewrite, no 0.15-era
   carry-overs. The snapshot-vs-wrapper matchOn divergence ledger line
   ALREADY existed (README, VM-proven 2026-10-18) - X6's second half was
   stale plan data. The dkim-survival e2e subtest the row rode on is
   green in the full gate. TODO row deleted + CHANGELOG.
4. **X10 - external-link sweep.** lychee over the living docs: 30
   unique targets, ZERO dead links; the single red is the known
   private-repo false positive (LarsArtmann/InboxClean exists, PRIVATE -
   verified via gh). TODO row deleted + CHANGELOG.
5. **X12.1 - upstream watch re-check.** All five watches unchanged
   within hours of the 03-59 session's re-check: #563651/#563652/
   #563777 OPEN, #552103 OPEN/unmerged (so no rename collision and no
   vendored-dir retirement trigger), mailsuite#65 OPEN (found the real
   repo: seanthegeek/mailsuite, last update 2026-10-05). Row already
   carries today's dates - no edit needed.
6. **X16 - VM debug-driver script.** `scripts/vm-debug.sh`: GC root,
   per-test driver discovery (extracted from the check derivation's
   buildCommand - the `runNixOSTest` check output is an EMPTY dir, so
   the old `<output>/bin/nixos-test-driver` recipe in CONTRIBUTING never
   matched anything), starter test-script with the capture/settle/
   no-manual-provision rules baked in. Smoke-verified END-TO-END through
   driver invocation with a no-boot script (GC root, discovery,
   `--test-script` + `-o` accepted, clean exit). CONTRIBUTING updated,
   TODO row deleted, CHANGELOG added.
7. **X14 - buildflow local-noise.** `interrogate` skipped with honest
   rationale; stale mypy rationale ("only Python is the test-driver
   template" - false since the scripts/ + vendored migration landed)
   replaced with the accepted-noise verdict; BUILDFLOW_TELEMETRY_DISABLED
   note added to .buildflow.yml (env var verified in the binary's string
   table, not invented). Verified NO-OPs (documented, not "fixed"):
   jest self-skips on missing package.json (a skip_steps entry would
   restate a default - anti-pattern), `buildflow timings --regressions`
   reports clean (the govulncheck +758% entry aged out), the
   nix-hash-fix WARN only fires in the self-heal path after a
   nix-build failure (not firing in today's dry-run). Doctor warns
   2 -> 1. TODO row deleted + CHANGELOG.
8. **X1.2 - C42 prep (verified pre-existing).** The stalw.art
   inbound-failure-parsing fetch was already attached to the C42
   decision-batch entry (fetched 2026-10-17, re-verified 2026-10-18,
   [rec] recorded, runtime gap parked). Nothing to do - verified, not
   fabricated.
9. **Final gates for MY changes.** Full buildflow EXIT:0 (26 success /
   1 failed -> the dprint detect failure, fixed by running the pinned
   dprint, second full gate EXIT:0); `nix fmt -- . --check` green; both
   arch attrNames guards green; md-pipe lint green; drift alarm green;
   annotate check-rows green on the formatter-touched reports.

## 2. b) PARTIALLY DONE

1. **X5 - pbx-artmann flip + leg re-adds (their repo) - THE BIG ONE.**
   What is DONE and committed on their master (their daemon commits
   continuously; b0afec2 is HEAD):
   - Verified the bootstrap fix (e6245c8) IS an ancestor of pbx's
     locked nix-email rev (b09480be) - the flip's precondition.
   - The deliberate `machine.fail` deadlock-pin flipped to a success
     contract: wait for the provision unit to leave activation, assert
     it did not fail, capture the provision journal as transcript.
   - All three first-draft legs re-added: implicit-TLS stub-cert
     greeting on 993/995, webadmin /jmap anonymous-401, break-glass
     admin authenticates via the runtime secret. Header doctrine
     rewritten (item 3 + the KNOWN GAP paragraph).
   - Resolver forensics block added (resolv.conf / ip addr / route /
     getent / curl dumps) - the introspection style the file already
     uses.
   What is NOT done: the check is NOT GREEN. Transcript-pinned blocker
   chain: the apply itself now SUCCEEDS through all 30 objects (the
   bootstrap fallback works: "management API answering at
   http://127.0.0.1:8080 (configured: http://127.0.0.1:8082)"), then
   the final `reload` action's 0.16 validation fetches the Directory's
   OIDC discovery (https://auth.larsartmann.cloud/
   .well-known/openid-configuration) and fails
   ("validationFailed | Network error: Discovery fetch failed"). The
   fetch needs egress; the VM picture (14 runs of forensics):
   - slirp IS present on eth0 (DHCP offer 10.0.2.15 from 10.0.2.2,
     lease completed t=14.7 in run 12),
   - but there is NO default route until dhcpcd finishes, and the
     resolver population was unreliable (run 12: lease done at 14.7,
     fetch at 39.7 still failed - resolver empty; run 13: static
     nameserver 10.0.2.3 pinned, still NXDOMAINed at probe time - but
     the probes ran PRE-lease),
   - the CURRENT committed state holds the provision unit until a
     default route exists (ExecStartPre wait-loop, wants/after
     network-online) + DHCP on eth0 + static nameserver 10.0.2.3,
   - the hermetic-stub DETOUR (hosts-pin + local HTTPS OIDC stub +
     planted CA + nginx disabled) is FULLY REVERTED; one remnant: the
     ACME webroot mkVMOverride was removed with it (nginx re-enabled,
     exactly-one-issuance assertion satisfied by the ACME-nginx
     integration again).
   OPEN QUESTION at yield: does the discovery fetch succeed once the
   route + resolver are REALLY up? Nobody has observed a post-route
   probe yet - every DNS probe so far raced the lease. The one-edit
   resume: add `machine.wait_until_succeeds("ip route show default |
   grep -q .", timeout=90)` before the forensics, run once, read the
   transcript.
   CONSEQUENCE: pbx master (their daemon pushes) is RED right now -
   red-by-my-in-progress-flip, not red-by-design anymore. Their repo's
   working tree is clean (daemon committed everything).
2. **X12 - upstream filings (the non-watch half).** NOT started beyond
   the watch: the dnsmasq-forward note, the T13b dprint pipe-cell
   filing, the #552103 evidence-comments idea - all need
   verify-before-filing reproduction passes + github-voice. New run-14
   datum for a possible filing: relay-e2e's `server = ["10.0.2.3"]`
   dnsmasq forward is very likely a blackhole in the testers framework
   too (its green plausibly rides on LOCAL answers) - worth a
   transcript before claiming anything upstream.

## 3. c) NOT STARTED

- X1 (owner sitting) - the gate on everything release-shaped. X2/X3/X4
  (CHANGELOG release pass, v0.5.0 tag, SystemNix pin advance) - blocked
  on C43/C45 answers.
- X7 (CI python-lint doctrine) - owner V2.3 blessing pending.
- X8 (e2e stability batch), X15 (TLS-node coverage), X17 (apply-log
  dump proof), X11.3/X11.4 (EventSource ping probe) - all heavy-VM or
  demo-VM work; deliberately skipped: the CardDAV session owned the
  demo VM all session and heavy builds serialize across repos (the OOM
  lesson). X17 becomes ~15 min now that scripts/vm-debug.sh exists.
- X11.1/X11.2 (ruff debt) - wait-for-CardDAV stood all session (their
  commits at 08:02, 29 crush processes); still NOT edited cross-session.
- X13 (BuildFlow upstream batch) - their binary is stale (ef32fa0 vs
  HEAD cf606f8, the binary-freshness WARN) and a concurrent session is
  committing to /home/lars/projects/BuildFlow - wait-for stands.
- X18 (SystemNix CI debt), X19 (D1-unlock prep), X20 (owner sitting #2)
  - not started; X19 is D1-gated, X20 is owner time.

## 4. d) TOTALLY FUCKED UP (own it)

1. **The egress misdiagnosis cost ~6 VM runs.** Run 5's forensics
   (eth0 link-local only, no default route, nslookup absent) ran
   PRE-lease and I concluded "this framework is multicast-only, no
   egress exists" - WRONG: runs 11/12 later showed slirp DHCP alive on
   eth0 (offer + lease). I built the whole hermetic-stub apparatus
   (OIDC stub server, CA generation, pki plant, nginx disable, users
   rescue) on a snapshot taken mid-Dhcp-handshake, then tore it down
   again. Correct behavior was: wait_until_succeeds on the route BEFORE
   any network forensics - the rule (d) settle-before-probe lesson,
   applied to my own probes instead of only to the code under test.
2. **CA-planting dead-end was foreseeable.** Three run-iterations were
   burned on writers.writePython3Bin flake8 findings (E302/E305/E501,
   the E501 caused by store-path interpolation ballooning generated
   lines) before the stub ever booted - and once it booted, stalwart's
   fetch STILL failed because rust/webpki-roots ignores the system
   trust store the CA was planted into. A five-minute check of
   stalwart's TLS backend (or a curl-vs-stalwart differential, which
   run 11's forensics accidentally provided: curl OK + stalwart fail)
   would have killed the stub path one run earlier. Verify-external-
   claims applies to MY OWN assumptions too.
3. **pbx master left RED mid-flight.** Their daemon auto-pushes; the
   flip committed at 7b5f7dc makes their gate red until the DNS fix
   lands. I knew their daemon was live (AGENTS.md commits at 08:19) and
   still worked in multiple daemon-committed increments instead of
   carrying to green (or pinning a branch) before yielding. The
   interrupt caught it - but the risk window was mine to avoid.
4. **Small stuff, own it anyway:** bare `nix fmt` died on stdin once
   (the documented trap - should have used `nix fmt .` first try); my
   TODO_LIST row-68 append initially used a cell-split that broke on
   the dprint-padded table (aborted before writing, no corruption, but
   the padded-table shape was knowable); one edit of mine dropped a
   stub-cert comment line and another clipped a sentence (both caught
   and repaired on read-back - the read-back habit is why they were
   caught); the AGENTS.md 220-line cap was briefly violated by my own
   X9 wording (doctor caught it, trimmed to 219).

## 5. e) WHAT WE SHOULD IMPROVE

1. **Network probes in VM tests must wait for the thing they probe.**
   Every DNS/egress probe in this session raced dhcpcd. A one-line
   `wait_until_succeeds("ip route show default | grep -q .")` before
   any resolver probe is the generalizable rule - candidate for the
   nix-email test doctrine + the awk pipe-lint's neighbor.
2. **The reload-validation OIDC fetch is a NEW hard dependency class**
   for every 0.16 consumer whose plan carries an OidcDirectory: the
   apply now needs live egress at reload time. The pbx fix (hold
   provision until route + resolver) is consumer-side; whether the
   WRAPPER should own a bounded route/resolver wait (or document the
   dependency in the README ledger) is an open doctrine question -
   nix-email issue #4's bootstrap class all over again, one layer up.
3. **relay-e2e's `server = ["10.0.2.3"]` forward deserves a
   transcript.** If it is a blackhole there too, its green rides on
   local answers and the comment ("forwarding upstream to the QEMU
   resolver") overstates - fix the comment or the forward.
4. **Contributing's `<output>/bin/nixos-test-driver` recipe was dead
   text** (runNixOSTest outputs an empty dir) - vm-debug.sh now encodes
   the working discovery; consider deleting the stale half-recipe from
   CONTRIBUTING so nobody follows it into a dead end like I did.
5. **The X-plan's effort estimates ran ~2x for X5** (45m estimate, multi-
   hour reality) because the plan priced the flip, not the new dependency
   class the flip exposed. Plans should price "the assertions behind the
   pin", not the pin edit.
6. **writers.writePython3Bin flake8 (E302/E305/E501 with store-path
   interpolation) is a recurring trap** - a line in the nix-email or
   BuildFlow docs would save the next three blind iterations.

## 6. f) NEXT (ranked; up to 50, bounded)

1. pbx: add the route wait to the test forensics, run once, read the
   transcript (the single highest-information run).
2. pbx: if DNS answers post-route -> expect green; if the fetch still
   fails, capture curl-vs-stalwart differential and decide.
3. pbx: if slirp DNS (10.0.2.3) is genuinely dead, decide doctrine:
   live-IdP GET vs hermetic stub vs plan-level OidcDirectory skip in VM
   (needs the owner answer - question 1 below).
4. pbx: on green, run their FULL gate; watch for the legs (993/995 TLS
   greeting, 8082 401, admin auth) - never run, never asserted.
5. pbx: update the test header (the "Zero external traffic" clause
   needs the OIDC-GET exemption wording if live-fetch is the doctrine).
6. pbx: cross-link nix-email issue #4 (the flip closes its consumer
   half); TODO row 52 in this repo -> executed, CHANGELOG here.
7. nix-email: the daemon is 10 commits ahead of origin - the next push
   exercises the NEW ci.yml lockstep/shape steps + the lockstep check
   in CI for the first time; watch that run's STEP names.
8. nix-email: expect the CI ruff step to stay red on the CardDAV debt
   until the owning session lands - do NOT weaken the step.
9. X11.1/X11.2 the moment the CardDAV session lands (4 tiny fixes).
10. X17 via scripts/vm-debug.sh (fault-inject a failing apply, prove
    the dump) - now cheap.
11. X11.3 ping probe on the demo VM once the CardDAV session releases it.
12. X9.4 residue: the count-line attribution landed in TODO row 71 -
    fold into the next BuildFlow session.
13. X12.2: reproduce the dnsmasq forward-vs-blackhole claim FIRST
    (verify-before-filing), and re-test relay-e2e's forward with the
    route-wait pattern before filing anything upstream.
14. X12.3/X12.4: the T13b dprint pipe-cell filing + venue pick
    (github-voice pass).
15. X12.5: #552103 evidence-comments (ExecStartPost-restart +
    bootstrap-fallback transcripts) when it next moves.
16. X16 polish: CONTRIBUTING's stale driver half-recipe deletion.
17. X16 polish: teach vm-debug.sh to generate route-wait-aware starter
    scripts (this session's lesson, baked into the tool).
18. X8.1/X8.2 relay bounce-path subtest (refusing smarthost, Mailpit
    counters - never journal greps).
19. X8.3/X8.4 runtime-trim + test-profile TTL doctrine.
20. X8.5 flood-flake capture-first protocol into the test header.
21. X15 TLS-node fixture breadth (Netease + LinkedIn on the IMAPS
    node).
22. X10 residue: buildflow's lychee step private-repo policy once the
    gate's lychee step actually exercises INBOXCLEAN.md.
23. X13.1-X13.8 BuildFlow batch (count gaps, ruff identity parsing,
    masking docs, threshold config) after the concurrent BuildFlow
    session lands + binary rebuild.
24. X14 residue: re-run `buildflow -d` after the next BuildFlow binary
    reinstall - the skip-unaware "interrogate not installed" preflight
    WARN may vanish with a fresh binary.
25. X6 residue: none (closed) - but the plan's option-surface audit
    should be re-run after any wrapper option change; consider an eval
    lint that pairs each option with a consumption site.
26. X2 prep (pre-C43): the CHANGELOG link-resolution pass can be
    DRAFTED without the owner (X2.1) - links only.
27. X2 prep: the C45 0.16.22 -> 0.16.26 delta table research can be
    DRAFTED (X2.2/X2.3) - the C45 verdict stays owner-gated.
28. X2.4/X2.5: scratch-tag dry-run of the release procedure - NOT
    before C43 (a dry-run tag still touches the repo; owner call).
29. X7.1/X7.2: draft the bandit/vulture scope doctrine + deeper-ruleset
    recommendation so the owner blessing is a 5-minute read.
30. X18.2 digest-based canary allowlist research (their repo).
31. X18.4 scheduled-vs-push CI divergence explanation (their repo).
32. X19.1-X19.3: the three D1-unlock prep docs (secrets rotation,
    vandelay-vs-imapsync compare plan, dmarc-live-poll checklist).
33. X20.1: package owner sitting #2 into decision-batch (C18/C19/C22/
    C24/C29/C34/Q4/demo g1-g2/qcow2/D1-D2/Resend).
34. X1 prep: the owner sitting needs ONE fresh read of decision-batch -
    consider a "decisions expired" timestamp sweep before scheduling it.
35. Annotate/archive pass over the 2026-10-19 reports (02-16, 02-35,
    03-59, 04-43, 05-18, 05-56, 06-05, 07-18) once their items close;
    03-34 stays live (queue owner).
36. This session's own report becomes an annotate candidate after the
    X5 saga closes (item 4 above).
37. docs/probes/: the 14-run pbx forensics live only in build logs -
    if the egress saga yields doctrine, archive the decisive
    transcripts under docs/probes/ like the quota-silence probe did.
38. nix-email: consider an eval-time guard that pairs declared wrapper
    options with consumption (X6's audit mechanized - catches future
    dead options at eval speed).
39. nix-email: the relay-e2e dnsmasq comment fix (or forward fix) per
    finding 3 above - small, transcript first.
40. nix-email: route-wait pattern documentation for late-DNS hosts
    alongside the DnsResolver doctrine (README ledger line).
41. BuildFlow skill note: writers.writePython3Bin flake8 trap (E-class
    with store-path interpolation) - one line in the right references.
42. SystemNix: contract-test fix preview for the v0.5.0 wrapper API
    (X4.3 prep - read-only, their repo, while waiting on C43).
43. Roadmap: the reload-validation dependency belongs in THREAT_MODEL's
    "0.16 exposure delta" (an outbound fetch at reload time).
44. MONITORING: the provision-failure alert row (05-18 item 46) should
    mention the new fetch-failure signature (validationFailed class).
45. INBOXCLEAN/ledger: no change needed - the OIDC discovery fetch is
    provision-time, not the JMAP contract - noted to prevent scope creep.
46. TODO_LIST: row 68's owner (CardDAV session) - ping via the row if
    their session ends without the fixes.
47. scripts/vm-debug.sh: consider a `--script-only` mode that writes
    the starter script without running (useful for pre-editing).
48. pbx: their AGENTS.md session was active - check their TODO/hand-off
    rows before touching pbx again.
49. CHANGELOG here: the pbx flip gets its nix-email-side entry only
    when it lands green (do not pre-log).
50. WAIT-state discipline: this session ends with two foreign/live
    sessions (CardDAV, pbx AGENTS) - the next session must re-run the
    baseline ritual before any edit.

## 7. Questions for the owner (cannot self-answer)

1. **pbx gate doctrine:** may the host-wiring VM test perform ONE
   anonymous, read-only OIDC discovery GET to the live
   auth.larsartmann.cloud (slirp egress; CI flake risk = your IdP's
   uptime), or must the gate stay 100% hermetic? Hermetic means:
   override/skip the OidcDirectory in VM plans (weaker wiring
   fidelity), or wait for an upstream stalwart lever to skip/satisfy
   reload validation offline.
2. **Wrapper doctrine:** should nix-email's wrapper own the "hold
   provision until a default route + resolver exist" ExecStartPre
   wait (all consumers inherit the determinism; release-adjacent so
   C43 timing matters), or is the route-wait a per-consumer concern
   (stay consumer-side like pbx's VM drop-in)?
3. **Red-master tolerance on pbx-artmann:** their daemon pushes every
   few minutes and my in-progress flip made their master red. For
   cross-repo lanes: is iterating on their master acceptable (fast,
   noisy), or should future cross-repo work sit on a branch / uncommitted
   until green (slow, safe)? The pbx flip is currently COMMITTED RED on
   their master.

## 8. Resume pointers

- nix-email: clean tree, 10 commits ahead of origin, gate EXIT:0
  locally at 08:26. New check: `check-set-lockstep`; canonical list:
  tests/check-expected.json; docs touched: README (check list + canon
  line), AGENTS.md (SINGLE-SOURCED + TWO-sites), CONTRIBUTING
  (vm-debug.sh), .buildflow.yml, TODO_LIST (6 rows closed), CHANGELOG.
- pbx-artmann: clean tree at b0afec2. The flip + legs + forensics +
  route-wait are all IN tests/stalwart-host-wiring.nix on their
  master. Single known blocker: reload-validation discovery fetch vs
  VM egress; resume at NEXT item 1 above.
- Debug tool: `scripts/vm-debug.sh stalwart-host-wiring` does NOT exist
  in pbx (it is an nix-email script; the pbx equivalent is
  `nix build .#checks.x86_64-linux.stalwart-host-wiring -L` + the
  driver path from the buildCommand).
