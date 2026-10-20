# X-generation resumption closeout: ruff floor cleared, X17 closed, cert time bomb defused, pbx egress impossible

Session: 2026-10-20 ~09:41-10:48 CEST (resumption of the X-generation
plan; parent report
`docs/status/2026-10-19_12-17_x-generation-execution-nine-lanes-green-pbx-flip-mid-flight.md`,
mid-session report `2026-10-20_10-25_x-generation-resumption-...`).
Idle since 10:48. All claims transcript-pinned below.

## a) FULLY DONE

1. **CI ruff floor cleared (X11.1/X11.2)** - the four owned findings fixed
   (F541 `carddav_diag.py:165`; F841 `token0` + RUF059 `headers2` in
   `carddav_probe.py`; SIM115 x2 in the archived `gen-repair-spec.py`).
   The owning CardDAV session landed 08:40 without them (closeout-shaped
   README commit; no crush session in the repo after that), so the
   cross-session hold expired. Local CI-floor ruff (locked rev, exact
   CI select): "All checks passed". TODO row removed. Commits 1b44e5c
   (daemon) + 40cfed4.
2. **X17.2 - VM-test forensics audit**: seventeen redirect sites across
   all five VM tests wrote evidence only to VM-local files a `grep -q`
   consumed - a failing assertion lost the artifact. All captures now
   dump to the driver transcript on/before the failure path (brace-group
   `cat >&2` chains; assertion strength unchanged, no new pipes).
   Verified: stalwart-e2e solo GREEN; relay/migrate/parsedmarc green in
   the first full gate. Commits c430db4 (daemon) + 28e5dd7 (my brace
   closer - see (d)2).
3. **X17.1 - dump-on-failure proof**: fault-injected a failing apply via
   `scripts/vm-debug.sh` (bogus object type): apply exits 1 with
   `error: unknown object: NoSuchObjectType`, and the log dump still
   delivered 40 bytes of evidence. W18.3/W18.4 is now transcript-backed,
   not comment-claimed (/tmp/x17-run.log). TODO row removed.
   Commit 60e7916.
4. **bind-e2e cert time bomb defused** (late-session surprise): the
   final gate went red on stalwart-bind-e2e - 993 served
   `CN=rcgen self signed cert` (stalwart's RUNTIME fallback) instead of
   the pinned `CN=bind.test` cert. Root cause (fingerprint transcript,
   direct-driver debug run): the store-cached `runCommand` test cert
   carried `-days 2` and expired 2026-10-19 04:39 GMT - yesterday's
   green gate finished ~13 minutes BEFORE expiry; stalwart silently
   refused the expired material and fell back to rcgen. Nix never
   rebuilds a cached runCommand output, so short validity on a cached
   cert is a time bomb that only ever detonates. Fixed `-days 3650`
   with the load-bearing rationale in-file; bind-e2e re-run GREEN
   (fresh cert store path, probe passes). Commit d3fb4e7 (daemon).
5. **vm-debug.sh RED-check path fixed**: the GC-root `nix build` RUNS
   the VM test, so for a RED check it failed under `set -e` and aborted
   BEFORE any debug script could run - the exact case the script exists
   for (X17.1 only worked because stalwart-e2e was green). Now survives
   with a warning and debugs against the store closure. Commit d3fb4e7.
6. **Lessons recorded** (CONTRIBUTING + vm-debug.sh starter forensics,
   commit 5edbae6): (1) TEST-DRIVER VMs have NO outbound at all - with
   a valid DHCP default route, slirp DNS (10.0.2.3, resolv.conf
   correctly populated) AND direct TCP (curl 7 to 1.1.1.1:443 in 1 ms)
   fail instantly; scope-noted against the demo-VM rule (f), whose
   slirp DOES forward (proven live 2026-10-18). (2) A unit's
   ExecStartPre PATH is NOT the console PATH - bare tool names that
   work in `machine.succeed` (`ip`) fail inside unit scripts; absolute
   `${pkgs.X}/bin` store paths required.
7. **Lockstep check locally verified** (CI still has not reached it):
   `nix build .#checks.x86_64-linux.check-set-lockstep` EXIT:0.
8. **Docs**: CHANGELOG entries for all of the above; TODO rows 59/66
   closed per the DONE convention; pbx hand-off row appended to THEIR
   TODO_LIST (hermetic override, owner-gated, spec pointer);
   dprint-repaired two md files a foreign session committed
   unformatted (09ad09b); final full gate **EXIT:0** (32 success,
   0 failed, 41 s - all VM tests cached green).

## b) PARTIALLY DONE

1. **pbx X5 flip (their repo, `~/projects/pbx-artmann`)** - forensics
   complete and decisive; the last 1-line change is owner-gated:
   - Run 15: the unit-level route-wait ExecStartPre was a NO-OP that
     itself failed the provision unit - bare `ip` is not on the unit
     PATH (looped 60s, exit 1 at t=85.5). Fixed with absolute store
     paths.
   - Run 16: the apply passes ALL 30 objects, fails ONLY at the final
     `reload` action's OIDC discovery fetch - which the same run's
     forensics prove can NEVER work in a driver VM (no outbound, see
     a.6). /tmp/pbx-x5-run15.log, /tmp/pbx-x5-run16.log.
   - The hermetic override is spec'd to the line (whole-key
     `mkVMOverride` on `provision.objects.Directory.objects.pocketid`
     to a non-remote `@type` + Authentication-ref handling; wrapper
     renderer facts read: singletons render `update` ops - empty-value
     update behavior untranscripted; objects-sets with
     `reconcile=false` + empty map are harmless no-ops). Written into
     the test header + their TODO_LIST. Awaits owner blessing (it
     changes what the test proves about the OIDC directory) + one VM
     run to land the flip.
2. **CI exercise of the new lockstep/shape steps** - still pending:
   master is 13 commits ahead of origin (daemon has not pushed since
   06:46Z; that run predates every fix above). The next push runs
   ruff -> lockstep -> shape -> nix flake check in order for the first
   time; expected green end-to-end. Assistants never push.

## c) NOT STARTED (unchanged from the parent report)

X1-C43 release chain (X2/X3/X4), X8.1-X8.5, X15, X11.3, X12 filings,
X13 (wait-for BuildFlow session; the installed binary ef32fa0 is
already stale vs their HEAD 9e3ccb0 - doctor warned on every run
today), X18, X19, X20.

## d) TOTALLY FUCKED UP

1. **Nothing landed broken on origin** - master is unpushed, so every
   mistake below stayed local and was fixed in-session. Honest ledger:
2. **Shipped an unclosed bash brace group** in the parsedmarc dovecot
   journal chain (my multiedit's new_string simply forgot the `}`).
   The daemon swept the broken version into c430db4 before the fix;
   master carried it ~10 minutes. Caught on re-read, fixed in
   28e5dd7. A bash -n pass over edited shell fragments would have
   caught it mechanically - nix eval does NOT check embedded bash.
3. **Burned ~7 VM runs on the cert mystery before fingerprinting**:
   I theorized (lock drift? race? my edit?) across gate red + solo red
   - retries before running the 1-minute rcgen-fingerprint probe that
     named the served cert instantly. The fingerprint was the FIRST move
     the whole time.
4. **Mangled the status report mid-edit**: an edit whose old_string
   ended mid-sentence spliced section b2 into the middle of section
   b's Consequence bullet. Caught on the very next view; repaired.
5. **Commit-vs-daemon race repeated**: my explicit commits keep
   landing AFTER the daemon's sweep, fragmenting history (the ruff fix
   split across 1b44e5c/9242f73/40cfed4). The repo's own rule - edit
   and commit in the SAME tool call - was followed only sometimes.

## e) WHAT WE SHOULD IMPROVE

1. **Fingerprint-before-theory** on served-vs-pinned mismatches: dump
   the actual served cert (one vm-debug probe) before any hypothesis
   work. Would have saved ~5 VM runs and 30 minutes.
2. **Mechanize a bash-syntax check** for testScript shell fragments
   (extract each succeed string, `bash -n` it) - the unclosed-brace
   class is invisible to eval, alejandra, and the CI awk lint.
3. **vm-debug.sh discipline**: smoke-test the FAILURE path of tooling,
   not just the green path (yesterday's smoke ran only a green check).
4. **Copy proven in-repo patterns**: parsedmarc's fixture cert already
   used `-days 3650`; the bind-e2e cert predates it and was never
   swept for the hazard. A one-line grep (`-days [0-7]` in runCommand/
   writeText cert generators) is now a review reflex.
5. **Same-tool-call commits** for anything the daemon might sweep
   (release-critical rule, generalized: any file whose commit message
   matters).
6. **Warning-level ruff noise** in probe scripts (EXE001 x3, SIM115 in
   carddav_bench, FURB167) is one cheap chmod/fix batch away from zero
   - warning-level does not gate, but the floor-to-noise ratio reads
     better.

## f) NEXT (up to 50, ordered by value)

1. OWNER: bless the pbx hermetic override (spec in b.1) - one VM run
   lands the stalwart-host-wiring flip.
2. Push master (owner/daemon): first CI exercise of
   ruff -> lockstep -> shape -> nix flake check; watch the step names.
3. Mechanize bash -n over testScript shell fragments (new lint or
   BuildFlow provider; see e.2).
4. Sweep sibling repos for store-cached short-validity certs
   (`grep -rn "days [0-7]" --include='*.nix'` on cert generators).
5. X8.1/X8.2 relay bounce-path subtest (refusing smarthost, Mailpit
   counters - never journal greps).
6. X8.3/X8.4 runtime-trim + test-profile TTL doctrine.
7. X8.5 flood-flake capture-first protocol into the stalwart-e2e
   header (the flood logs now dump; the header doctrine is the rest).
8. X15 TLS-node fixture breadth (Netease + LinkedIn on the IMAPS
   node).
9. X11.3 EventSource ping probe on the demo VM (CardDAV session has
   landed; the lane is free).
10. X12.2 reproduce the dnsmasq forward-vs-blackhole claim FIRST
    (verify-before-filing), now with the driver-vs-demo scope split.
11. X12.3/X12.4 T13b dprint pipe-cell filing + venue (github-voice).
12. X12.5 #552103 evidence-comments (ExecStartPost-restart +
    bootstrap-fallback transcripts) when it next moves.
13. X13.1-X13.8 BuildFlow batch after their concurrent session lands +
    binary rebuild (ef32fa0 vs 9e3ccb0 - doctor warns every run).
14. Row 71 residue: fold the count-line attribution into the BuildFlow
    session.
15. Row 53: bandit/vulture CI-scope doctrine (owner blessing pending).
16. X7.1/X7.2: draft the bandit/vulture scope doctrine so the owner
    blessing is a 5-minute read.
17. X2.1 (pre-C43): draft the CHANGELOG link-resolution pass (links
    only, no verdict).
18. X2.2/X2.3 (pre-C43): draft the C45 0.16.22 -> 0.16.26 delta table
    research; the C45 verdict stays owner-gated.
19. X19.1-X19.3: the three D1-unlock prep docs (owner-gated D1).
20. X18 SystemNix CI debt lanes (their repo).
21. X20 owner sitting #2 packaging (C18/C19/C22 into decision-batch).
22. Warning-level ruff batch in probe scripts (EXE001 chmod +x, SIM115
    context managers in carddav_bench, FURB167 re.I aliases) - see e.6.
23. Fingerprint-first doctrine into CONTRIBUTING's VM debug section
    (one sentence - the probe shape is already in vm-debug history).
24. Consider `--keep-machine-state` guidance in vm-debug.sh for
    repeated TLS-style debugging (avoids full boots between probes).
25. Re-run `buildflow -d` after the next BuildFlow binary reinstall -
    the skip-unaware "interrogate not installed" preflight WARN may
    vanish (X14 residue).
26. X6 residue: re-run the option-surface audit after any wrapper
    option change (standing doctrine; consider an eval lint pairing
    options with consumption sites).
27. Contacts wire-claims stay source-level until a demo-VM transcript
    set exists under docs/probes/ (10k+ cards benchmark = filing gate;
    2026-10-19 assessment owns the verdict).
28. X10 residue: buildflow's lychee step private-repo policy once the
    gate's lychee step actually exercises INBOXCLEAN.md.
29. Demo VM: re-verify the login banner ports/credentials against the
    README quickstart on the next demo boot (single-source ritual).
30. docs/TELEMETRY.md is 0.15.5-era: verify keys against the pin on
    the next telemetry-adjacent session.
31. Consider a gate-log step-name assertion in CI triage docs: "a red
    run is never 'the known one' without reading the failing STEP
    name" is prose; the failure-mode table could carry the two known
    stacked causes.
32. Parsedmarc-e2e: the fixture-cert `-days 3650` is in-VM generated
    (safe) - document that distinction once next to the bind-e2e
    comment so nobody "harmonizes" it backwards.
33. vm-debug.sh: optional `--check` arg listing *-e2e checks with
    cached-red status (saves the red-build surprise).
34. Bind-e2e: the probe uses `create_default_context(cafile=...)` -
    an SNI/hostname variant assertion (served SAN == bind.test) is
    already implied; a one-line comment linking probe to cert SAN
    would future-proof it.
35. Stalwart-e2e flood subtest: the assert messages carry counts, and
    the logs now dump - consider asserting per-connection detail only
    on failure (output hygiene, low).
36. CI: consider caching the locked-rev ruff binary (each lint step
    pays `nix run` resolution; ~13 s today, growing with py files).
37. README: the check prose row and tests/check-expected.json are the
    two sanctioned check-list sites - verify no THIRD copy crept into
    docs/ during the docs-heavy morning (drift alarm forbids it; a
    30-second grep).
38. Confirm the aarch64 lockstep shape after the next nixpkgs
    pin-advance (README pin-advance runbook owns it).
39. Upstream watch: nixpkgs #563651/#563652/#563777 + mailsuite#65 -
    re-check on the next upstream-watch cadence.
40. When the hermetic override lands (a/b.1), fold the run-17
    transcript into the pbx test header (runs 11-17 tell one story).
41. Docs-health sweep: docs/probes/<date> transcripts referenced in
    today's reports (/tmp/*.log) are volatile - consider copying the
    two decisive pbx run logs into docs/probes/2026-10-20-pbx-egress/
    before a reboot loses them.
42. CHANGELOG: the [Unreleased] Fixed section is growing release-
    worthy payload (ruff floor, cert bomb, forensics) - consider the
    release-procedure assessment step on the next release session.
43. AGENTS.md line cap (219/220): the next lesson must EDIT an
    existing bullet, not append (the doctor enforces 220).
44. Annotated status reports: none written today (no strike rows) -
    keep `annotate.go check-rows` in the ritual for future ones.
45. The `M features/README/INBOXCLEAN` unformatted-commit pattern
    (foreign sessions) - a pre-commit dprint hook would mechanize what
    I repaired by hand (BuildFlow owns the hook).
46. Reconcile the 84-warning buildflow ruff findings list vs the CI
    floor select once (row 53 overlaps; keep one canonical gap list).
47. Demo VM disk at ~/.cache/nix-email-demo/ - the pbx e2e work never
    touches it; no action, just noting the separation held.
48. Next CardDAV-adjacent session: confirm their session's final
    commit closed the probe debt (it did not fix the ruff findings -
    my fix did; their TODO hand-off protocol could note that error-
    class lint findings should never ride a hand-off row past landing).
49. When CI first exercises the lockstep step, verify the step's
    failure MODE once by... no - never weaken or fault-inject CI for
    proof; the local negative test already covers drift.
50. Idle-time hygiene: the 3.5 h idle gap between the final gate and
    this closeout - a session that ends green should closeout
    immediately (the closeout prompt arrived late; the report was
    already amended in place at 10:48, which softened the cost).

## g) QUESTIONS I CANNOT FIGURE OUT MYSELF

1. **pbx hermetic override blessing**: evidence says a live OIDC fetch
   is impossible in driver VMs (runs 15/16). Do I land the hermetic
   override in their test (whole-key `mkVMOverride` of `pocketid` to a
   non-remote `@type` - exact vocabulary discovered empirically in the
   one blessed run), or do you want the test to stay red until a
   different shape exists? It changes what the test proves about the
   OIDC directory.
2. **Push policy**: nix-email master is 13 commits ahead (ruff-floor
   fix, cert fix, X17 batch - all gate-green locally). The daemon has
   not pushed since 06:46Z. Should you push now so CI finally
   exercises the lockstep step, or is the daemon cadence deliberate?
   (I never push; asking only because CI verification of my work is
   blocked on it.)
3. **Cross-repo red-master tolerance**: the wait-for discipline
   prevented all collisions but left nix-email red ~26 h and pbx red
   ~22 h on error-class findings owned by landed sessions. Adopt a
   rule "error-class lint/typo fixes may cross a session's files once
   that session has LANDED (last commit + no live process), with the
   hand-off row as the audit trail"? Or keep the strict wait-for?
