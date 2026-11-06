# All-latest train EXECUTION report: parsedmarc 11.2.1 GREEN, migration rehearsal at the prepare step

Session: 2026-11-06 ~02:10 - 03:58 CET. Ask: the owner's standing
"READ, UNDERSTAND, RESEARCH, REFLECT. Break this down into multiple
actionable steps... Execute and Verify them one step at a time. Repeat
until done." applied to the 02-06 report's exact-next-steps list (the
owner's "I want ALL my tech to be latest, if we need to be ahead of
nixpkgs for a while so be it!" remains the governing decision). This
report was requested mid-flight ("FULL COMPREHENSIVE & DETAILED STATUS
UPDATE! RIGHT NOW! THEN WAIT FOR INSTRUCTIONS!"): the session STOPS at
this file and waits.

## Session run (short form)

1. P0s from the 02-06 report landed: stalwart-migrate build fix
   (bindgenHook), stalwart-e2e-v1 round 5 GREEN (the full 20-subtest
   battery on vendored Stalwart 1.0.3), default stalwart-e2e rerun GREEN
   (apply-script change proven a 0.16 no-op by VM).
2. The parsedmarc 11.2.1 + mailsuite 2.3.4 train was executed END TO
   END: vendored, wrapper-seamed, lockstep-wired, VM-proven GREEN -
   including one REAL upstream contract break found and fixed
   (mailsuite 2.3.4's MaildirConnection no longer bootstraps a bare
   maildir; the wrapper now pre-creates new/cur/tmp at boot).
3. The 0.16 -> 1.0 migration rehearsal test was DESIGNED from primary
   sources, written, wired at all three anti-drift sites, and driven
   through 3 VM rounds: round 3 reaches the `prepare` step with
   seed + handoff + 1.0.3 baseline + extract all green; the prepare
   invocation fails WITH ITS LOG UNDUMPED (my own dump-every-probe rule
   violated) - cause unknown at report time, fix is one line.

## a) FULLY DONE

| Item                                   | Proof                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| stalwart-migrate build fix             | `nativeBuildInputs = [rustPlatform.bindgenHook]` (bindgen needs libclang); `nix build .#stalwart-migrate` EXIT:0; `--help` smoke shows the full prepare/run/verify/status/report/rollback interface                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| stalwart-e2e-v1 round 5 GREEN          | `nix build .#checks.x86_64-linux.stalwart-e2e-v1 -L` EXIT:0 - the whole battery incl. runtime catch-all apply (subtest 13, the round-4 blocker), JMAP, ARF ingestion, metrics, on vendored Stalwart 1.0.3 + webui 2.0.5                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Default stalwart-e2e rerun GREEN       | EXIT:0 - the provision.nix applyScript change (pkgs.stalwart-cli -> cfg.package) is a 0.16 no-op, VM-proven                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Parsedmarc deps re-derived from source | 11.2.1's own pyproject.toml fetched and read: base deps ONLY (dnspython[doh] expiringdict httpx lxml mailsuite>=2.3.4 maxminddb publicsuffixlist python-dateutil tqdm xmltodict pyyaml); 11.2.x moved every heavy sink to EXTRAS (issue #883) - dateparser/requests/urllib3/elasticsearch/kafka/azure GONE from base. mailsuite 2.3.4 pyproject also re-derived (same dep set as master's 2.3.2 expression)                                                                                                                                                                                                                                                                       |
| Pin floors verified by eval            | pin fe132422: python3 3.14.7, httpx 0.28.1, python-dateutil 2.9.0, dnspython 2.8.0 WITH optional-dependencies.doh (httpx+h2+httpcore), imapclient 4.1.0, mail-parser 4.8.0, cryptography 50.0.0, expiringdict 1.2.2, publicsuffix2/authres/dkimpy/html2text/tqdm/xmltodict/maxminddb/publicsuffixlist/lxml/pyyaml all present and in-range                                                                                                                                                                                                                                                                                                                                        |
| Vendored closure builds                | pkgs/parsedmarc/{package.nix (11.2.1), mailsuite.nix (2.3.4), default.nix (single-source assembler)}; both src hashes via `nix store prefetch-file --unpack`; `nix build .#parsedmarc` EXIT:0 incl. pythonImportsCheck                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| requires_python build fix              | round-1 build red: upstream parks `requires_python` inside [build-system] (invalid property; the pin's hatchling refuses: "Unknown properties: requires_python"). The nixpkgs-master postPatch was a REAL fix, not a python-range patch - reinstated with an honest comment (my "in range, drop it" inference was wrong, caught by the build)                                                                                                                                                                                                                                                                                                                                     |
| Wrapper package seam                   | `services.dmarc-monitor.package` option (default = the vendored closure) + ExecStart mkForce rendering from it: the pin's nixpkgs module hardcodes `ExecStart = ${lib.getExe pkgs.parsedmarc}` with NO package option (verified: services.parsedmarc exposes only enable/provision/settings - NixOS-eval probe; module source at nixos/modules/services/monitoring/parsedmarc.nix)                                                                                                                                                                                                                                                                                                |
| Lockstep follows the wrapper           | checks.nix `deployedParsedmarc` = NixOS-eval hop mirroring deployedStalwart (README check now derives BOTH versions from wrapper module defaults); `--parsedmarc ${deployedParsedmarc.version}` at both lockstep sites; readme-version-lockstep + -fires build green against the updated status block                                                                                                                                                                                                                                                                                                                                                                             |
| dmarc-eval contract raised             | parsedmarcVersion now reads the DEPLOYED package (eval.config...package.version, not pkgs.parsedmarc) and the floor moved 11 -> 11.2 (the security-fix line); builds green                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| parsedmarc-e2e GREEN                   | round 1 red: parsedmarc 11.2.1 + mailsuite 2.3.4 unit died FileNotFoundError '/var/spool/mail/dmarc/cur' at start - 2.3.3's MaildirConnection rewrite (GHSA-9jx3-p8wm-g8vw) no longer bootstraps a bare maildir and the unit races postfix's first delivery. FIX: wrapper tmpfiles pre-creates root+new+cur+tmp (four rules, recipient-owned 0700); dmarc-eval extended to pin ALL FOUR rules. Round 2: EXIT:0                                                                                                                                                                                                                                                                    |
| README status block                    | now "Stalwart **0.16.26** (1.0.3 vendored ahead...), parsedmarc **11.2.1** (vendored ahead... SECURITY fix GHSA-3588-2mr7-vrcm)" - lockstep-verified                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Migration rehearsal: research          | (1) The tool's version gate is EXACT schema equality (source-v016/adapter/mod.rs: `StoreSchema::V016(SCHEMA_VERSION)`); DATABASE_SCHEMA_VERSION = 6 in BOTH v0.16.26 and v0.16.27 (both tags' crates/common/src/lib.rs) - the pin's 0.16.26 seeder IS accepted; README's "must run v0.16.27" is prose conservatism. (2) answers.toml format from answers.rs (version int + [global.PromptId] tables; per-object under [instance]). (3) prepare needs a TTY; --non-interactive only VALIDATES. (4) target config.json shape == the module's own top-level RocksDb shape. (5) run --final --yes watches change counters 30 s, finalizes, verifies a sample, writes final-report.txt |
| Migration rehearsal: test + wiring     | tests/stalwart-migrate-1x-e2e.nix (two nodes: 0.16.26 seeder -> tar via /tmp/shared -> vendored-1.0.3 consumer; prepare via pty `script -qec` + `yes "" \| head -200` = all-recommended; run --final --yes --owner stalwart-uid:gid; cutover assertions: 0.16 password + needle mail over IMAP + plan re-apply). Wired at checks.nix + check-expected.json (surgical one-line) + README check row; attrNames + aarch64 eval guards green; check-set-lockstep green                                                                                                                                                                                                                |
| Rehearsal rounds 1-2 lessons landed    | round 1: swaks raced the provision reload-restart (fixed: post-Result double port re-wait both nodes). round 2: port-25 EXTERNAL-sender delivery stalls past swaks --timeout on RCPT policy lookups in the DNS-less VM (fixed: the e2e's proven authenticated 587 submission shape)                                                                                                                                                                                                                                                                                                                                                                                               |
| Small truth-ups                        | host-parse-fixture.py docstring + demo-vm app description: "PINNED parsedmarc" -> "DEPLOYED parsedmarc (wrapper default)"                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |

## b) PARTIALLY DONE

1. stalwart-migrate-1x-e2e round 3 (in flight at report time): seed
   (587-submission needle delivered + IMAP-verified on 0.16.26) GREEN,
   handoff GREEN, 1.0.3 virgin-store baseline GREEN, extract + configs
   GREEN - then `prepare` exits 1 WITH /tmp/prepare.log redirected and
   never dumped (driver output shows only "yes: Broken pipe", which is
   benign). The answers.toml/file assertions after it never ran. FIRST
   FIX NEXT ROUND: dump prepare.log unconditionally (e.g. wrap in
   `sh -c 'script ... > /tmp/prepare.log 2>&1; rc=$?; cat
   /tmp/prepare.log >&2; exit $rc'`) so the failure is readable, THEN
   diagnose (candidates: pty/tty nuance under `script`, state-dir
   perms, or a real store-open refusal - the schema gate SHOULD pass,
   see a). Host-side pty-mechanics rehearsal (script + trivial
   interactive prompt) is a cheap pre-flight.
2. Docs pass (partial): README status block done; host-parse/demo-vm
   wordings done. NOT DONE: README ledger bullets (the 1.x train and
   the parsedmarc train), TODO_LIST watch rows, CHANGELOG entries,
   AGENTS.md/flake.nix pin-comment truth-ups.
3. `nix fmt -- . --check` NOT run (many .nix touched this session -
   mandatory before yielding; the daemon pushes mid-session).
4. Full gate `nix flake check` NOT run yet.

## c) NOT STARTED

1. Upstream filings (owner-review-gated): provision.nix applyScript
   hardcode bug on nixpkgs PR #552103 (fresh evidence: stalwart-e2e-v1
   round-3 burn + this session's fix); parsedmarc 11.2.1 / mailsuite
   2.3.4 nixpkgs bumps (my expressions are the PR body, dep deltas
   documented in-file); stalwart 1.0.3 bump with the rocksdb 11.8.1
   FFI insight.
2. aarch64 eval/build of the new packages (eval guards green; no
   aarch64 BUILD of stalwart_1_0/parsedmarc yet).
3. Telemetry 1.0.1 series renames (docs/TELEMETRY.md section) and the
   1.0 consumer-flip runbook doc.
4. pbx-side legs that remain owner-gated (webmail switch, live 1.0
   flip, external-link-warning backends).

## d) TOTALLY FUCKED UP

1. `rg -rn` trap hit AGAIN (twice: once as `rg -rn . /dev/null` pure
   sloppiness) - hook blocked both times, nothing corrupted. The
   rule is internalized as: type `rg -n`, never compose rg flags
   from memory.
2. Dropped the nixpkgs-master requires_python postPatch on a WRONG
   inference ("python 3.14.7 is in range, patch unneeded") without
   checking WHAT the patch patches - it fixes hatchling's
   [build-system] property validation, not the range. Build caught it
   in minutes; reinstated with an honest comment. Lesson: a vendored
   patch can carry more than one reason; read its target line before
   dropping.
3. String-slop class (two instances): wrote "nixpkks" in a comment and
   a stray `>` inside the --replace-fail pattern (would have failed
   replace-fail at build). Both caught by immediate re-read. Same
   class as the prior session's placeholder-edit fire - compose the
   FULL edit, then read it back.
4. multiedit-before-view on host-parse-fixture.py and demo-vm.nix -
   the tool refused (correctly; I had grepped but not viewed).
5. First multiedit on dmarc-eval.nix DELETED a comment line (my
   old_string matched the _secret comment's first line and my
   new_string did not carry it) - repaired immediately by re-adding.
6. Self-review caught a would-be eval recursion in the rehearsal test
   (`config.environment.systemPackages ++ [...]` inside a module that
   also defines it) - replaced with a plain list (module system
   concatenates).
7. Round-3 diagnosis blind spot: prepare's output went to
   /tmp/prepare.log and the failure path never dumps it - violating
   my OWN e-4 rule from the 02-06 report (dump every redirected probe
   log right after the call). One-line fix queued.
8. The pty pipe shape `yes "" | head -200 | script -qec ...` is
   unproven mechanics (never rehearsed host-side against ANY
   interactive prompt before spending the VM round).

## e) WHAT WE SHOULD IMPROVE

1. NEW-VM-TEST CHECKLIST (extend the 02-06 e-1 pre-flight): (a) double
   port re-wait after provision Result=success (reload restarts
   stalwart), (b) readiness set = every port you will probe, (c) swaks
   shape = copy the e2e's EXACT proven invocation for the ingress path
   (587 authenticated for deliveries; port-25 only for --quit-after
   probes), (d) dump every redirected log UNCONDITIONALLY right after
   the call, (e) rehearse novel host mechanics (pty pipes) host-side
   against a trivial stand-in before burning a VM round.
2. Patch-purpose-before-dropping: when vendoring from nixpkgs-master,
   each carried/dropped patch gets a one-line WHY tied to the actual
   patched line (the requires_python lesson generalized).
3. The schema-version gate research pattern (compare
   DATABASE_SCHEMA_VERSION constants across upstream tags, then read
   the consumer's gate in source) settled the "tool wants 0.16.27,
   pin has 0.16.26" conflict in minutes with zero VM spend - encode
   the FACT in the README ledger when the rehearsal lands.
4. Version floors verified by EVAL against the PIN rev (github:
   NixOS/nixpkgs/<rev>#attr), never the registry - done right this
   session for every parsedmarc/mailsuite floor; keep as reflex.

## f) NEXT - prioritized

P0 - land the reds and close the session cleanly:

1. Rehearsal round 4: dump prepare.log unconditionally; rehearse the
   pty mechanics host-side first (script + an interactive python
   prompt). Iterate to green (candidates after the log: script/tty
   nuance, state perms, real store refusal).
2. `nix fmt -- . --check` (many .nix touched; daemon pushes
   mid-session).
3. Full gate `nix flake check > /tmp/gate.log 2>&1` (redirect, never
   pipe; budget >= 30 min; never concurrent with buildflow).
4. README ledger bullets: (a) Stalwart 1.x train - vendored
   packages.stalwart_1_0 1.0.3 + webui 2.0.5 + spam-filter 3.0.4 +
   cli 1.0.14 + migrate v1.0.6; the 1.0 dialect renames pinned by
   stalwart-e2e-v1; the schema-6 gate fact; the rehearsal pointer;
   (b) parsedmarc train - 11.2.1 + mailsuite 2.3.4 vendored, the
   Maildir bootstrap contract change (four tmpfiles rules), the
   ExecStart seam (no package option in the pin's module), the
   lockstep hop + 11.2 floor.
5. TODO_LIST rows: stalwart_1_0 bump watch, parsedmarc 11.2.x watch,
   bulwark 1.20.x patch watch; delete exhausted rows per policy.
6. CHANGELOG (Unreleased): the stalwart 1.x availability block
   (packages + stalwart-e2e-v1 + dialect fixes + migrate tool +
   rehearsal check) and the parsedmarc 11.2.1 block (vendored flip +
   tmpfiles contract + lockstep hop).
7. AGENTS.md + flake.nix comment truth-ups: parsedmarc is now
   vendored-ahead via services.dmarc-monitor.package (the pin's
   pkgs.parsedmarc stays 11.0.2 as a pin FACT).
8. Five text gates (`sh scripts/selftest-docs-gates.sh`) after the
   docs pass.

P1 - after P0:
9. Owner-gated: webmail 1.20.0 switch handoff + my post-switch no-SSH
verify-live arms (unchanged from the 02-06 g-1).
10. Owner-gated: live 1.0 flip timing - with the rehearsal green this
becomes a concrete maintenance-window plan (backup -> migrate ->
1.0.3 opt-in + consumer-side renames + 1.0.2/1.0.3 one-shots).
11. Owner-gated: external-link-warning backends (02-06 g-3).
12. Upstream filings (owner-review-gated): #552103 applyScript bug;
parsedmarc/mailsuite bumps; stalwart 1.0.3 with the FFI insight.
13. aarch64: `nix flake check --all-systems --no-build` + consider a
cross build of stalwart_1_0 + parsedmarc (ARM CAX readiness).
14. docs/TELEMETRY.md: 1.0.1 stalwart_* series renames section +
MONITORING.md consumer note.
15. 1.0 consumer-flip runbook (README or docs/; the c-4 list as a
doc): Pocket ID scopes urn:stalwart:oauth:scope:{security,
settings,full} for the Bulwark client, OidcDirectory rename
verification (requireAudience -> acceptedAudiences) BEFORE the
flip, encryption-at-rest posture, STALWART_UPDATE_ROLE_
PERMISSIONS one-shot.
16. host-parse-fixture dry-run against 11.2.1 on the aggregate
fixture (~30 s host-side; also proves the docstring change).
17. pbx truth-ups: CHANGELOG row for the vi+th callback fix (verify
the daemon carried it), AGENTS LOCALE-CALLBACK WATCH table row.
18. lessons.md candidates (crush-config, by commit): prior-session-
spec-as-a-lead, pre-flight-grep-before-VM-rounds, the new-VM-test
checklist, patch-purpose-before-dropping.
19. Archive the 02-06 report + this one once P0s land (docs/status
policy: dprint BEFORE the git mv).
20. Watch nixpkgs for stalwart_1_0 + a 1.x MODULE (the vendored-tree
wholesale-deletion trigger) and for parsedmarc >= 11.2.1 /
mailsuite >= 2.3.4 (pkgs/parsedmarc deletion trigger).
21. Consider the eval-level "1.x dialect smoke" (render plan ndjson +
apply script for both lines, diff) to catch dialect breaks
without VM rounds (02-06 e-5, still open).
22. Store-survey + release-watch mechanization (02-06 P2-18, open).
23. webui-1.0.10: add the 1.x-side webui 2.0.5 fact to the ledger
bullet (the existing 1142 line stays true for the pin line).
24. Boot-smoke script for webmail bumps (prior P2-34).
25. stalwart-review.sh read-only webmail-health leg (prior P2-35).
26. Re-check .buildflow.yml skip rationale after the new packages.
27. Demo-VM quickstart re-check (still 0.16 default; README says so).
28. Review this session's daemon auto-commits for split completeness
(0cfa36e..5e35264 batch).
29. Post-switch webmail watches (MemoryMax, ?v= keys, junk-count leg) - owner-gated on the switch.
30. IFD-free locale->callback count gate (pbx; prior P2-36).

## g) Questions for the owner (not derivable from any tree)

1. Webmail switch NOW? (Unchanged from 02-06 g-1: the 1.20.0 closure
   is built, smoked, contract-green incl. the 31-callback fix; one
   `nixos-rebuild --target-host` from your terminal lands it - I
   cannot SSH by doctrine; say the word and I hand you the exact
   command, then run the no-SSH verify-live arms myself.)
2. Stalwart 1.0 on the LIVE pbx store: once the rehearsal test goes
   green (one iteration away at report time), do you want the live
   flip scheduled as its own maintenance window (backup ->
   stalwart-migrate -> 1.0.3 opt-in + the consumer-side renames + the
   1.0.2/1.0.3 one-shot actions), or hold 1.x at "continuously
   VM-tested, not deployed" until you say go? (Your "all latest" is
   recorded; this is purely the timing of a live mail-store
   migration.)
3. Upstream engagement: file the #552103 applyScript bug and offer
   the parsedmarc 11.2.1 / mailsuite 2.3.4 / stalwart 1.0.3 bumps to
   nixpkgs myself (gh auth is LIVE), or keep everything
   owner-review-gated as before?
