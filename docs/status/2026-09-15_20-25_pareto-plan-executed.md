# Status: Pareto plan executed — release cut, consumer pin advanced, all unblocked work done

**Date:** 2026-09-15 20:25 · **Session:** execute
`docs/planning/2026-09-15_19-23_nix-email-pareto-master-plan.md` end-to-end
("GET SHIT DONE — the WHOLE TODO LIST").

## What was executed (all plan tasks that were not user-gated)

| Plan task | Outcome |
|---|---|
| L03 release | `[Unreleased]` folded into `[0.2.0] - 2026-09-15`; **v0.1.0 tagged retroactively** at `f603169` (last 2026-09-14 commit = the state the `[0.1.0]` section describes), **v0.2.0** at the release commit `598db0f`; both tags pushed; GitHub releases created for both. _(nuanced by the 02-08 review: the tags triggered no CI - the workflow fires on branch pushes only; the green run covered the same tree)_ |
| L04 SystemNix pin-advance | input bumped `1f8bb52` → **tag `v0.2.0`**, lock updated; relay-credential assertions RESTORED in `tests/test-nix-email.nix` (credential wiring + generated `queue.route` + strategy else-branch — all green against the real pinned input); option-existence guard deleted from the wrapper; contract check green |
| L05 research | `/compare` fetched as HTML (cell marks preserved), release notes v0.15.5→v0.16.22 diffed, **v0.15.5 git-tag source grepped** — cross-table in plan §10 |
| L06 overlap reviews | verdicts 06a–06e in plan §10: keep-both (native report ingestion is a free complement), viewer DEFERRED, OIDC verified present in 0.15.5 source, sieve-for-Junk unchanged (ledger wall), ROADMAP deltas proposed (harvest-gated) |
| L09+L27a | README "Pin-advance runbook" (both-locks bump + workaround-retirement re-check), cross-linked from module comments |
| L10 test strengthening | CSV row-count assertion; SECOND `Message rescheduled` line (retry LOOP proven, ~120 s cadence, 99 s wait observed); RCPT resolver-timeout cost measured per run (**66 s + 65 s**) |
| L11 TLS variant | `parsedmarc-e2e` second node: IMAPS 993 with **default certificate verification** (machine-trusted fixture CA with SANs; mailsuite `create_default_context`), ini `ssl=True`/`port=993`/no-skip asserted; report round-trips over TLS |
| L12 CI lockstep | strict set-equality guard between flake-declared checks and CI's list (both drift directions fail); local negative test proves it bites (phantom check → exit 1) |
| L13 aarch64 | one emulated `stalwart-e2e` run attempted: guest BUILDS and BOOTS (arm64 kernel + systemd) but boot alone (~6 min TCG) exceeds the driver shell timeout → **documented-manual, not CI-worthy** (evidence in the flake trap comment) |
| L14 docs | runbook→SystemNix pointer; stateVersion note found ALREADY consolidated (TODO evidence stale); pin-discipline rationale; `tests/fixtures/debug-template.py` |
| L15 filings | **NixOS/nixpkgs#563651** (host-less `[elasticsearch]`) + **NixOS/nixpkgs#563652** (imapclient 4.0.1 `starttls()` vs py3.14 read-only `imaplib.IMAP4.file`); both re-verified against master + Gate-5 searched (no dupes) + upstream mjs/imapclient main still broken; linked from the README ledger entries |
| L26 micro-decisions | probes + verdicts in plan §10 (wrapper doctrine for ROADMAP Q5 included) |
| L07 license | was already DONE before this session (MIT confirmed, ROADMAP Q3 resolved) |
| L25a threat model | already existed (`docs/THREAT_MODEL.md`) — pre-plan work had landed it |

## Failures hit and fixed (the honest list)

1. TLS-node dovecot died: `<path` prefix in `ssl_server_cert_file` makes the
   NixOS module inline file CONTENTS into dovecot.conf (dovecot's
   read-value-from-file syntax). Fixed: plain paths. Lesson → AGENTS.md.
2. TLS-node parsedmarc lost the boot race against dovecot's 993 listener
   (nixpkgs unit has no Restart policy). Fixed: fixture-level
   `Restart=on-failure` + wait for the port before the unit.
3. Ini assertion `ssl=true` failed: the parsedmarc ini generator renders
   bools Python-style (`True`). Fixed assertion. Lesson → AGENTS.md.
4. One `nix flake check` diagnostic ran with `| tail` (exit code eaten);
   re-ran gates unpiped thereafter. The final gates never wore pipes.
5. My first ledger edit clobbered the SIEVE entry header; repaired in the
   same session.

## What deliberately did NOT happen

- ~~**Harvest** of the plan's §10 ROADMAP/TODO deltas (06e, viewer-deferred
  note, Q5 doctrine) — the plan itself gates this on explicit user
  approval (§9). Say the word and docs-health HARVEST runs.~~ done (executed
  2026-09-16 by the docs-health pass: deltas applied to ROADMAP)
- L01/L02/L08 (D1, D2, spam→Junk) and L16 (ANNOTATE scoping) — user
  decisions; everything downstream of them (L17–L24, 27b/27c) stays parked.
- No weakened assertions, no priority games, non-goals untouched.

## State after this session

- nix-email `master` = `598db0f` (release commit), tags `v0.1.0`/`v0.2.0`
  pushed, releases published; full `nix flake check` green locally; CI run
  on the push in flight at writing time.
- SystemNix: pin at tag `v0.2.0` (rev `598db0f`), contract test green,
  full `nix flake check` in flight at writing time. _(later verdict: it
  FAILED at a pre-existing deadnix-check owned by parallel-session files -
  the pin-advance scope itself stayed green; see the 02-08 report b/1)_
- TODO_LIST swept down to the 4 user-gated rows.

---

## Resolution addendum (2026-09-16, docs-health pass)

The plan-task table above is a done-record (all rows have outcomes); the
two _(nuanced ...)_ notes import the 02-08 review's corrections. The
"deliberately did NOT happen" block is resolved: the harvest approval was
given and executed (2026-09-16 docs-health pass - viewer/OIDC/DNS-owner
deltas applied to ROADMAP, Q5 doctrine applied); L01/L02/L08 remain the
standing user decisions (ROADMAP open questions 1, 2, 6); L16 was this
pass's scope. Archived.
