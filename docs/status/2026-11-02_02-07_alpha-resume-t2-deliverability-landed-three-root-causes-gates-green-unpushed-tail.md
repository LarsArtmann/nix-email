<!-- Status snapshot 2026-11-02 02:07 CET. Continuation session of the
     Alpha-plan execution (mandate: execute every zero-owner-dependency
     task; owner-gated decisions NEVER defaulted). Picks up the 00-25
     report exactly where it paused: CI red on the dprint gate, three
     standing questions. Tree at write: clean, daemon-swept; CI green
     through pushed 021148f; local commits beyond it unpushed. -->

# Alpha resume: CI recovered, T2 deliverability landed (three stacked root causes), gates green, unpushed tail (2026-11-02 02:07)

## 0. TL;DR

| Area                | Verdict                                                                                                                                                                                                                                                                                                                         |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CI                  | GREEN through pushed 021148f (run 41363025872): the dprint offender formatted + pushed; the run first died on the KNOWN cache-API throttle flake, `gh run rerun --failed` -> success. Local commits after 021148f NOT yet pushed/CI-verified                                                                                    |
| T2 deliverability   | LANDED GREEN: probe v2 (IPv6, STARTTLS cert expiry, per-check budgets, metrics-endpoint, dmarc-sink-freshness, inbound canary, junk verdict) + wrapper options + eval pin + ADR 8; deliverability-e2e EXIT 0 (all 18 checks + negatives, battery 31 s -> 3.7 s)                                                                 |
| Root causes found   | THREE stacked, each transcript-pinned before the fix: (1) dnsmasq dead-upstream 15 s stalls, (2) stalwart's OWN resolver is not the system resolver by default, (3) boot Persistent-timer race x upstream's built-in per-IP connection limiter (5 rapid conns OK, 6th instantly closed, healthy again in 2 s)                   |
| Other lanes         | E16.2 ruff-floor app landed; alias-checker floor (23-38 f/7+f/12) landed; E5.2 aggregate control landed (stalwart-e2e EXIT 0); E11.2 queue_rescheduled alert row; E8.1 verdict rowed; A5.1 verified read-only (hub workstream LANDED); ROADMAP theme-6 flipped; TODO/CHANGELOG/FEATURES/README/CONTRIBUTING/MONITORING truth-up |
| Not done here       | Full `nix flake check` with builds; push + CI watch of the tail; H1.3 (external report still absent); all owner-gated lanes (see c)                                                                                                                                                                                             |
| Frozen by ownership | BuildFlow (D3/D4) gained LIVE sessions since yesterday - recheck before ever touching; SystemNix/pbx lanes unchanged                                                                                                                                                                                                            |

## a) FULLY DONE (this session; evidence inside)

1. **CI recovered.** `nix fmt` fixed the probe README (pure table
   reflow, transcript semantics untouched); the daemon committed it and
   I pushed `1aaec31..021148f`. Run 41363025872 first failed INSIDE
   `nix flake check` on the known GitHub cache-API `ResourceExhausted`
   throttle (fmt step already green); `gh run rerun --failed` ->
   SUCCESS. Master green through 021148f.
2. **vm-debug `--script-only` no longer builds the GC root** (the
   pending edit from the last session): the GC-root build IS the VM
   test run, so the mode could burn a full VM test just to print one
   command line. Skip message + conditional cleanup echo; usage comment
   updated; shellcheck clean; functional proof run (no VM, 7m53s is
   the eval walk for driver discovery, inherent).
3. **E16.2 `.#ruff-floor`.** New app (pinned `pkgs.ruff`, both arches
   eval-verified); ci.yml ruff step rewired off
   `github:NixOS/nixpkgs/<rev>#ruff` (the measured 10 s registry eval
   walk), never-firing self-test KEPT; actionlint clean; check
   attrNames lockstep vs tests/check-expected.json UNCHANGED; positive
   - negative functional runs green locally.
4. **deprecated-alias-lint floor (23-38 f/7+f/12).** `MIN_ALIASES=150`
   parse-yield floor with a loud message; self-test extended with the
   warnAlias-moved-to-its-own-line reformat scenario (must trip the
   floor, never pass vacuously) + a boundary case; real-pin run = 215
   aliases; the check derivation rebuilds green in-sandbox. README
   check row gained the floor + the blind-spot list (f/26/f/37);
   CONTRIBUTING gained the never-name-an-unversioned-attr rule +
   how-to-run-by-hand (f/35/f/36). ROADMAP theme-6 flipped: (a)
   measured 10 s, floor moved to `.#ruff-floor`; (b) modes DONE.
5. **TODO_LIST surgery.** Deleted the LANDED dprint-coverage,
   VM/debug-tooling, TELEMETRY-compression rows; deleted
   docs-health-skill-upstream (SKILLS 2527308); trimmed hygiene-trivia
   to its f12ed24 residue; MINTED: deprecated-alias-lint hardening
   backlog (f/8-f/20+f/23), vendored-module package-default (their
   g/3, BLOCKED-owner), E5.1 procedure row, E8.1 verdict row,
   deliverability trivia-tail (T2.9, owner taste); EventCatalog row
   updated (workstream landed; push-sanction gate remains). check-rows
   EXIT 0 after every pass; pipes green.
6. **Docs truth-up.** CHANGELOG entries for T1, T3, E16.2, the floor,
   and the T2 battery extension; FEATURES: 13-check set + CI currency,
   unified formatter, ruff-floor in CI row, new VM/demo-tooling row,
   deliverability row extended; README: deprecated-alias-lint row
   (floor + blind spots), deliverabilityChecks section rewritten for
   the new options, demo-VM quickstart re-smoke note + the "why off
   here" paragraph (T2.8), stale "smoke pending" heading fixed.
7. **T2 deliverability battery - LANDED GREEN** (the session's core;
   deliverability-e2e EXIT 0, battery 31 s -> 3.7 s, second idempotent
   run 0.7 s):
   - probe v2: IPv6 in `--ips`/DNSBL/PTR (family-correct reverse,
     unit-tested; the `f"{addr:032x}"` IPv6Address format bug was
     caught by that unit test and fixed via `.exploded`), cert expiry
     on 25/587 via `openssl -starttls smtp`, per-check SIGALRM
     wall-clock budgets (`--check-timeout`), `--metrics-url` endpoint
     check, `--dmarc-sink-dir` freshness check (warning severity),
     `--canary-inbound` (unauthenticated :25 to the canary mailbox),
     Junk-folder search with a distinct delivered-to-junk WARN verdict
     (INBOX first, Junk only on miss), `smtp_connect` retry-once on
     instant disconnect.
   - `overall_status` now fails ONLY on CRITICAL severity - the
     documented exit contract became code (a warning-severity FAIL
     like a stale sink surfaces in gauges without paging).
   - `_canary_fail` check-name bug fixed (inbound failures were
     mislabeled `canary-roundtrip`).
   - wrapper: `canaryInbound`, `metricsUrl`, `dmarcSinkDirectory`,
     `dmarcSinkMaxAgeHours` options + ExecStart wiring + enable-text;
     `deliverabilityChecks.enable = false` default EVAL-PINNED
     (module-import-eval, built green).
   - e2e legs: cert-25/587 + metrics-endpoint + inbound canary +
     folder asserts in the battery; stale-sink negative (check FAILS,
     overall stays pass); node pins `DnsResolver` Custom -> dnsmasq.
8. **The three stacked root causes** (each fixed only after a
   transcript pinned it):
   - dnsmasq's dead `server = ["10.0.2.3"]` forward stalled every
     foreign name ~15 s (openssl's own EHLO domain, post-DATA
     sender-auth lookups) - exactly the probe socket timeout. Fix: NO
     upstream (foreign names refused instantly) + `127.in-addr.arpa`
     local with PTR records for the probe's loopback client.
   - stalwart's OWN resolver is NOT the system resolver by default:
     post-DATA lookups went external and stalled. The 0.16 object
     dialect was discovered empirically through the Lua typecheck
     ladder: `DnsResolver."@type" = "Custom"; servers =
     [{address = "127.0.0.1";}]` (no @type on the array element).
   - the Persistent timer fires on boot and raced the subtest's manual
     battery start: ~18 rapid connections from one IP tripped
     upstream's BUILT-IN per-IP connection limiter (isolation run: 5
     rapid clean connections OK, #6 instantly closed, healthy again
     after 2 s). Fix: the test stops the timer before the battery
     (timer SHAPE stays pinned by the eval contract); the probe's
     canary connects retry once (real hosts brush the same limiter).
9. **E5.2 landed**: the aggregate-ingestion subtest gained its
   delivery control (same-address no-report message delivered
   normally - mirrors 16b's proven shape); stalwart-e2e EXIT 0.
   Combined-subtest evaluation: NO - separate subtests keep their own
   failure locus + journal dumps, and the ~45 s swaks stalls ARE the
   evidence (runtime-budget doctrine).
10. **E11.2**: `MailQueueRescheduled` alert row in MONITORING 8.2 with
    the lazy-registration encoding (absent series = zero deferrals;
    dashboards must expect missing, not zero). E11.1 was already
    covered by the 2026-10-31 D8 pass (row 2).
11. **E8.1 verdict** (read-only in their repo): BuildFlow ships NO
    replacement scanner (their own H3 row pins vulnix itself);
    go-vulncheck is Go-only, osv-scanner is lockfile-based - neither
    covers nix derivation closures. Rowed BLOCKED-external with the
    re-arm condition.
12. **A5.1 verified read-only**: the hub demo-flagging workstream
    LANDED (demo-badge rendering pinned by a dist assertion + closed
    on live-site evidence; webphone adopted as a source). A5.2/A5.3
    (hub push / ci-dispatch / live-verify) remain push-sanction-gated.

## b) PARTIALLY DONE

1. **Final verification tail**: the local commits after 021148f are
   daemon-committed but NOT pushed / not CI-verified; the FULL
   `nix flake check` with builds has NOT run this session (per-check
   greens only: deliverability-e2e, stalwart-e2e, module-import-eval,
   deprecated-alias-lint).
2. **H1.3**: the f12ed24 session's report still has not landed in the
   corridor (external; row stays).
3. The vm-debug cache starter still holds this session's last debug
   script (inbound-stall take-5) - harmless residue.

## c) NOT STARTED (gated, by design)

1. Owner-gated, never defaulted: O1 sitting + O3 verdict recording,
   A1/A2 filings, B1-B3 pbx landing, C1-C10 executions, D10 prep pack,
   R1 timeout policy, T2.9 trivia trio (rowed).
2. Owned by LIVE sessions: D1/D2 (SystemNix), D3/D4 (BuildFlow - it
   was unowned yesterday, it is NOT now; recheck `pgrep` before any
   future attempt), E9.2/E12/E13/E14 (D1 hosts).
3. External: E4 (A5 publish), E17 (next stalwart bump), E5.1 (tracing
   object shape unverified - the stalw.art docs pages render as JS
   chrome; rowed with the exact procedure).

## d) TOTALLY FUCKED UP (all caught in-session)

1. **Arg-order faceplant**: my first vm-debug `--check` call passed
   the script path as the CHECK name (flags consume positionals);
   one cycle burned, no lint ran.
2. **Nested-heredoc escaping bit TWICE**: literal `"` injected into
   the e2e jq asserts (caught by reading the diff back), then
   `\\r\\n` mismatches in the in-guest payload - debug payloads moved
   to base64. A `--payload-file` mode on vm-debug would kill the
   class.
3. **Two false theories before evidence**: PTR forwarding (falsified
   by the per-step dialog: EHLO/MAIL/RCPT/DATA-354 all 0.0 s), then
   "Custom resolver alone fixes it" (falsified by the 5 ms close
   run). The transcript-first loop (isolate, then fix) cost three VM
   cycles but every landed fix is pinned.
4. **A pre-existing bug surfacing**: `overall_status` failed on ANY
   FAIL regardless of severity while its docstring promised
   CRITICAL-only since 2026-10-30 - found while designing the sink
   severity, fixed at root (behavior now matches the documented
   contract; all existing negatives re-proven).

## e) WHAT WE SHOULD IMPROVE

1. Ledger the verified `DnsResolver` Custom dialect
   (`servers = [{address = ...}]`, no element @type) in the README
   0.16 ledger - it cost a typecheck ladder to discover.
2. Probe connection hygiene: one battery makes ~9-10 SMTP/TLS
   connections; a future probe could reuse connections or pace them
   (upstream's built-in limiter is 5-ish per short window).
3. vm-debug `--check` should validate that a check-name positional
   does not look like a path (the d/1 faceplant class is mechanizable).

## f) NEXT (ranked)

1. Push the local tail (or let the daemon) and watch CI green BY STEP
   NAME (rerun only on the known throttle class).
2. Full `nix flake check` WITH builds (redirected log, EXIT read,
   never concurrent with buildflow) - the session's last open proof.
3. Pre-push suite: check-inventory, check-testscript-shell, pipes,
   check-rows, `nix fmt -- . --check`.
4. H1.3 when the f12ed24 report lands; E5.1 when the tracing shape is
   binary-verified.
5. THE SITTING (O1) remains the >51% unlock; nothing defaulted.

## g) QUESTIONS FOR THE OWNER

1. **Push sanction for the tail**: 021148f was pushed to verify the CI
   recovery per the mandate; the newer batch (T2 battery + docs +
   e2e/stalwart-e2e greens) is daemon-committed locally - push it, or
   leave it for your window?
2. **A5.2/A5.3 (hub publish chain)**: the blocker is now ONLY the
   push sanction (hub master push or `sudo ci-dispatch` on evo-x2) -
   go, or reserve?
3. (Standing) The sitting sheet Batches 1-8 - still yours, still the
   51% gate; the repo's zero-owner lanes are now exhausted except the
   verification tail above.

---

_Point-in-time snapshot 2026-11-02 02:07 CET. Waiting for instructions._
