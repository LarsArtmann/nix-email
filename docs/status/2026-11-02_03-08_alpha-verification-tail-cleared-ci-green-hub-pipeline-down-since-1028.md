<!-- Status snapshot 2026-11-02 03:08 CET. Continuation of the Alpha-plan
     execution under the owner's blanket finish-everything mandate; closes
     the 02-07 report's verification tail + questions 1 and 2 (executed, see
     d/3 for the sanction interpretation). Tree at write: daemon-swept;
     origin green through 3b4286e. -->

# Alpha close-out: gate green, tail pushed + CI green, hub publish fired - but the hub build pipeline is down since 10-28 (2026-11-02 03:08)

## 0. TL;DR

| Area                | Verdict                                                                                                                                                                                          |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| nix-email master    | GREEN through `3b4286e` (run 41372640022): the full 15-commit tail pushed; one intermediate red (dprint on the raw TODO row - the daemon raced my fmt fix out of the push; root-caused by STEP NAME, fixed, re-pushed green) |
| Full gate           | `nix flake check` EXIT:0 WITH builds on the final tree (4 eval-class derivations rebuilt; VM e2e cache-valid from this session's executed runs)                                                   |
| Report e/1-e/3      | ALL CLOSED: DnsResolver Custom dialect ledgered in README 0.16; vm-debug `--check` rejects path-like check names (guard proven, shellcheck clean); probe connection-pacing rowed                  |
| Hub A5.2/A5.3       | A5.2 EXECUTED (hub master `97d0223..cdfb512` pushed to the Forgejo; build.yml fires on push); A5.3 T8 VERIFIED live (bodies, chips, ADR routes - receipts in a/6) - but against the STALE 10-28 build |
| Hub freshness       | BROKEN since 2026-10-28T03:38Z: four 03:23 nightlies missed, the stale-sources OVERDUE self-heal is not landing, and the push-triggered run stayed unpublished after ~2 h - owner eyes on evo-x2 needed (b/1) |
| Still owner-gated   | O1 sitting (the >51% unlock), all C/B/D/R lanes unchanged; H1.3 (f12ed24 report) still absent                                                                                                    |

## a) FULLY DONE (this session; evidence inside)

1. **Pre-push suite green**: check-inventory, check-testscript-shell
   (287 fragments/12 files), check-md-table-pipes, check-rows on
   TODO_LIST, `nix fmt -- . --check` (after one dprint pass over the new
   row).
2. **README 0.16 ledger row (02-07 e/1)**: "Stalwart's OWN resolver is NOT
   the system resolver by default" - the take-4 transcript facts plus the
   `DnsResolver` Custom dialect (`servers = [{address = ...}]`, NO element
   `@type`, the Lua typecheck ladder that discovered it) sit beside the
   2026-09-15 system-resolver entry.
3. **vm-debug path-guard (02-07 e/3)**: a check name matching `*/*` or
   `.*` fails fast with the flags-before-positionals usage hint (the d/1
   faceplant class mechanized); proven live (exit 1 on a path-like name),
   shellcheck clean; CHANGELOG T1 entry extended.
4. **Probe connection hygiene rowed (02-07 e/2)**: new TODO_LIST row
   (pool-or-pace vs the built-in per-IP limiter; retry-once already
   landed; behavioral, needs a VM re-proof) - not defaulted, rowed with
   the isolation-run evidence.
5. **Full gate**: `nix flake check > /tmp/gate.log; EXIT:0` - all checks
   passed, 4 derivations rebuilt in-gate (eval class incl. dmarc-eval),
   VM e2e derivations cache-valid because THIS session executed them
   (deliverability-e2e battery 3.7 s, stalwart-e2e EXIT 0) with unchanged
   inputs.
6. **Tail pushed, CI green**: `021148f..881fa8b` pushed, run 41372119515
   went RED on the dprint step (see d/1), fix `3b4286e` pushed in the
   same call as its verification, run 41372640022 SUCCESS. FEATURES CI
   currency updated to the new run.
7. **Hub A5.2/A5.3 executed** (sanction reading in d/3):
   - A5.2: hub master pushed `97d0223..cdfb512` to the canonical Forgejo
     (`origin`, evo-x2) - the push event is build.yml's trigger. The
     GitHub twin stays a no-push downstream mirror (untouched).
   - A5.3 T8 against the LIVE site (the served 10-28 build):
     `catalog.home.lan/docs/services/mail-server/1.0.0` renders OUR
     authored body (listeners table, option surface, 0.16 doctrine,
     consumers); the `not deployed` orange chip unions in from the
     SystemNix inventory (chip mechanism live); `/docs/adrs/
     thin-wrapper-doctrine/1.0.0/` renders the full decision record
     (Context/Decision/Consequences, applies-to both services, owner);
     7 ADRs live; build-stamp present and honest (builtAt 10-28 - see
     b/1).

## b) PARTIALLY DONE

1. **The hub build pipeline has not published since 2026-10-28T03:38Z**
   (dist tip `29879bf`, stamp builtAt 2026-10-28T03:25:46Z): four nightly
   crons (03:23) produced nothing, the stale-sources OVERDUE self-heal
   (probe exits 2 -> dispatches build.yml) is evidently not landing, and
   my push-triggered run stayed unpublished ~2 h after the push. From
   this vantage queued/failed/dead-runner are indistinguishable (the
   Forgejo UI/API is closed to anonymous; ssh is outside this session's
   toolset). Owner procedure: on evo-x2 read the Forgejo run queue for
   lars/eventcatalog-hub and `systemctl status gitea-runner-evo-x2`
   (runbook: hub README + SystemNix docs/services/forgejo.md).
2. **ADR 8 (deliverability-probe-emission-only) is exported (selftest: 8
   adrs) but NOT yet live**: it rides the first GOOD build after the
   <=6 h Forgejo mirror pull of tonight's nix-email `3b4286e` push. The
   live site currently renders the 10-28 7-ADR set (verified, a/7).
3. H1.3: the f12ed24 session's report still has not landed (row stands).

## c) NOT STARTED (gated, by design)

1. Owner-gated, never defaulted: O1 sitting + O3 verdict recording,
   A1/A2 filings, B1-B3 pbx landing, C1-C10 executions, D10 prep pack,
   R1 timeout policy, T2.9 trivia trio (rowed).
2. Owned by LIVE sessions at session start: D1/D2 (SystemNix), D3/D4
   (BuildFlow), E9.2/E12/E14 (pbx/D1 hosts) - recheck `pgrep -x crush`
   before any future attempt.
3. NEW: evo-x2 build-pipeline inspection (b/1) - needs host access.

## d) TOTALLY FUCKED UP (all caught in-session)

1. **The daemon race bit the PUSH this time**: my `nix fmt` fix of the
   new TODO row sat uncommitted while I pushed; `881fa8b` shipped the
   RAW row and CI went red on the dprint step. Caught by reading the
   failing STEP NAME (never "the known one" without it); fixed by
   committing + pushing the formatted row in the SAME tool call as its
   `nix fmt --check` proof. The AGENTS rule "edit and commit in the
   SAME tool call" extends to fmt FIXES: an uncommitted fix is a red
   push waiting to happen.
2. (Carried lesson, honored here) gate commands redirect + read EXIT;
   CI read by step name; rerun only on the known throttle class - no
   reruns were needed this session.
3. **Sanction interpretation, recorded for audit**: the owner's blanket
   "execute and verify everything, keep going until done" response to
   the 02-07 questions was read as push sanction for (a) the nix-email
   tail (explicitly the pending todo) and (b) the hub master push
   (A5.2's primary path, the owner's own repo, non-force, already-
   committed work). The `sudo ci-dispatch` alternative was NOT taken
   (remote-host root is outside a blanket mandate). If this reading was
   too broad, both pushes are ordinary master commits and revertible.

## e) WHAT WE SHOULD IMPROVE

1. Nothing new beyond what is rowed (probe connection hygiene row, e5.1
   procedure row, E8.1 row). The hub-side nightly/self-heal failure is
   a candidate hub-repo row once the owner's inspection names the
   cause - filed from their side, not speculatively from here.

## f) NEXT (ranked)

1. OWNER: evo-x2 runner/Forgejo inspection (b/1) - until the pipeline
   lands a build, every source push (incl. tonight's nix-email ADR-8
   export) is invisible on catalog.home.lan.
2. THE SITTING (O1) remains the >51% unlock; nothing defaulted.
3. H1.3 when the f12ed24 report lands; E5.1 when the tracing shape is
   binary-verified.

## g) QUESTIONS FOR THE OWNER

1. **evo-x2 build pipeline**: the hub has not published since 10-28
   (b/1). Yours to inspect (run queue + `gitea-runner-evo-x2`); say the
   word if you want a read-only evidence pack beyond b/1.
2. (Standing) The sitting sheet Batches 1-8 - the repo's zero-owner
   lanes are now exhausted; the verification tail was the last one.

---

_Point-in-time snapshot 2026-11-02 03:08 CET. Waiting for instructions._
