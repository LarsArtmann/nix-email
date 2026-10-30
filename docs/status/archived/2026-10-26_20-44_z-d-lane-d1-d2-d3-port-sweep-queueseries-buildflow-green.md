# Z-plan D-lane execution: D1 port-wait sweep, D2 queue-series sync, D3 buildflow gate (2026-10-26 20:44)

> Session scope: the three dependency-free Z-plan tasks (D1/D2/D3). O1
> (`gh` auth) and O2 (owner sitting) were checked FIRST and are STILL
> BLOCKED - gh token invalid at 20:38, verdict sheet unanswered - so
> every O/A/B/F/C lane stays untouched per the ordering doctrine. This
> report follows the 2026-10-26_19-00 E/F session report.

## What ran, what was verified

### D1 port-wait sweep - VERDICT: CLEAN, no changes needed

All 26 `wait_for_open_port` sites in `tests/` classified against the
module's listener doctrine (`modules/mail-server.nix:628-637`: on a
virgin 0.16 store ONLY smtp 25 + http 8080 are built-in; every other
listener binds after the boot provision + ExecStartPost restart chain,
measured ~70 s under host load):

| Class                                                               | Sites                                                                                         | Verdict                                     |
| ------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------------- |
| Non-Stalwart services (postfix/dovecot/mailpit)                     | parsedmarc-e2e 416/417/619, relay-e2e 233/234/362                                             | bind at service start; 60-120 s fine        |
| Built-in 25/8080 on default-shape nodes                             | stalwart-e2e 459/460/475/476/925 (flood node default)                                         | binds at process start; fine                |
| Provisioned ports, adequate budget                                  | relay-e2e 232 (587@180 - the E1 fix), bind-e2e 221 (8082@240), migrate-e2e 172/274 (8082@240) | >= 120 s, cite the chain                    |
| Post-restart waits (datastore-persisted set binds at process start) | bind-e2e 249/274/275, migrate-e2e 276/291, stalwart-e2e 894                                   | chain already complete; fine                |
| Blocking provision guard before probes                              | stalwart-e2e 470 + relay-e2e 240 (`systemctl restart stalwart-provision` BLOCKS)              | provisioned ports chain-complete before use |
| Probe template                                                      | debug-template.py:34 (all listeners @180)                                                     | fine                                        |

The 587@60 instance fixed earlier tonight was the ONLY under-budgeted
provisioned wait in the suite. No test file changes; nothing to rebuild.

### D2 queue-series claim - the claim lives in MONITORING.md, not README

Z-plan premise slightly off: README carries NO queue-series claim
(checked `series|Prometheus|queue` - only endpoint facts). The stale
"ONLY queue series" claim lived in `docs/MONITORING.md` §5.5
(lines 151-152 + the inventory bullet), contradicting row 2's same-file
2026-10-26 correction - a split brain inside one file. Fixed (commit
`0318b7f`): §5.5 now transcribes BOTH queue counters with the
relay-run3-full.log HELP line (`queue_rescheduled` - "Message
rescheduled for delivery", counter, observed 1), heading dated
"amended 2026-10-26", no-depth/age-gauge verdict unchanged. dprint +
pipe lint green.

### D3 full buildflow gate - GREEN (exit 0), residue fixed same-session

First full `buildflow --max-time 30m` on the final E/F tree
(`/tmp/buildflow-final.log`): gate PASSED (warning-threshold findings
only; 9 tools unavailable = the documented Nix-repo noise). Residue:

- ruff-check 17 findings -> really 2 (the known identity-parsing bug
  inflates counts, `missing_file=17` in the JSON report - already owned
  by the BuildFlow upstream TODO row): EXE001 + RUF007, both in the
  new es-ping probe. FIXED (daemon commit `650d6c8`): exec bit
  (convention: older probes ship 100755), `zip` ->
  `itertools.pairwise`, plus the 10 ruff-format nits. Re-ran
  `buildflow -s ruff-check` / `-s ruff-format` fresh (0 cache hits):
  "All checks passed!" / "16 files already formatted".
- Wide manual ruff scan (E4,E7,E9,F,EXE001,RUF over all tracked .py)
  shows 2 RUF100 in OLDER probes - selection artifacts, NOT gate
  findings (buildflow's ruleset keeps those `noqa` directives live;
  verified absent from the gate's findings). Deliberate non-fix.
- The three eval warnings (stalwart 0.15.5 pin notice, demo httpBind
  non-loopback, dovecot2 rename) are the documented set; the dovecot
  one is owned by Z-plan C4 post-bump.
- Timing-regression lines (agents-md 1ms->6ms class): noise.
- Doctor: AGENTS.md 247/220 lines (pre-existing, unchanged this
  session), BuildFlow binary behind its repo HEAD (concurrent session,
  advisory), state-db VACUUM hint (expendable).

## Commits

- `0318b7f` docs(monitoring): queue-series inventory corrected.
- `650d6c8` (daemon) fix(probe): es-ping exec bit + pairwise + format.
- This report + CHANGELOG + TODO surgery: see session-end log.

## What is NOT done and why (owner-gated, per Z-plan)

~~O1 `gh auth login` (blocks F1-F4 filings, A3 tag-CI watch, mailsuite~~ **→ routed 2026-10-30: gh auth LIVE again 2026-10-28 (z-gen O1 satisfied, re-verified this pass); O2 = the sitting sheet (partially answered 2026-10-28: C43/C45/contacts); origin CI superseded by later green runs through 40861706874 (2026-10-29)**
nudge), O2 the sitting (blocks A/B/C verdict lanes, D4/D5, G3/G7).
Origin CI on pushed `373c30a` remains unwatched until O1. No push this
session (no explicit request).
