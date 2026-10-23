# X-generation resumption: ruff floor cleared, X17 closed, pbx egress verdict decisive

Session: 2026-10-20 ~09:41-10:30 CEST. Resumption of the X-generation plan
(`docs/status/2026-10-19_12-17_x-generation-execution-nine-lanes-green-pbx-flip-mid-flight.md`
is the parent report; its 3 owner questions stand unless restated here).

## a) FULLY DONE

- **CI ruff floor cleared (X11.1/X11.2)**: the four owned findings fixed
  (F541 `carddav_diag.py:165`; F841 `token0` + RUF059 `headers2` in
  `carddav_probe.py`; SIM115 x2 in the archived `gen-repair-spec.py`).
  The owning CardDAV session landed 08:40 without them (closeout-shaped
  README commit; no crush session in the repo since), so the
  cross-session hold expired. Local CI-floor ruff (locked rev, exact
  CI select): "All checks passed". Every push since 08:46 failed at the
  ruff step and SKIPPED the lockstep/shape steps - the fix unblocks all
  three. TODO row removed; commit 40cfed4.
- **X17.2 - VM-test forensics audit**: seventeen redirect sites across
  all five VM tests wrote evidence only to VM-local files a `grep -q`
  consumed; a failing assertion lost the artifact. All captures now
  dump to the driver transcript on/before the failure path (brace-group
  `cat >&2` chains; assertion strength unchanged - `&&` chains kept, no
  new pipes). stalwart-e2e re-run GREEN (EXIT:0, real execution).
  Commit c430db4 (daemon) + 28e5dd7 (brace closer the daemon raced).
- **X17.1 - dump-on-failure proof**: fault-injected a failing apply via
  `scripts/vm-debug.sh` (bogus object type): apply exits 1 with
  `error: unknown object: NoSuchObjectType` and the log dump STILL
  delivers 40 bytes of evidence. W18.3/W18.4 claim is transcript-backed
  (/tmp/x17-run.log). TODO row removed; commit 60e7916.
- **Lockstep check locally verified** (CI never reached it): `nix build
  .#checks.x86_64-linux.check-set-lockstep` EXIT:0.
- **Lessons recorded** (CONTRIBUTING + vm-debug.sh starter, commit
  5edbae6): test-driver VMs have NO outbound (see (b)); unit
  ExecStartPre PATH is not the console PATH - absolute `${pkgs.X}/bin`
  store paths required in unit scripts.

## b) PARTIAL - pbx X5 (their repo; runs 15/16 decisive)

~~- **Run 15**: the unit-level route-wait ExecStartPre was a NO-OP that~~ **NOT-DO — subsumed by the same session's 14-19 closeout (b.1 carries the final state).**
itself failed the provision unit - bare `ip` is not on the unit PATH
(`command not found` looped 60s, exit 1 at t=85.5). Fixed with
absolute store paths.
~~- **Run 16** (with the fix + new discriminators): apply passes ALL 30~~ **NOT-DO — subsumed by the same session's 14-19 closeout (b.1 carries the final state).**
objects, fails ONLY at the final `reload` action's OIDC discovery
fetch - and the forensics prove the fetch can NEVER work in a driver
VM: with a valid DHCP default route, slirp DNS (10.0.2.3, resolv.conf
correctly populated by resolvconf) AND direct TCP (curl 7 to
1.1.1.1:443 in 1 ms) both fail instantly. /tmp/pbx-x5-run16.log.
~~- **Consequence**: owner question 1 (live GET vs hermetic) is settled~~ **NOT-DO — subsumed by the same session's 14-19 closeout (b.1 carries the final state).**
by impossibility, not policy - a live fetch cannot go green in
`nix flake check` VMs. The hermetic mechanism is spec'd (whole-key
`mkVMOverride` on `provision.objects.Directory.objects.pocketid` to a
non-remote `@type` + the Authentication ref; the wrapper renderer and
option types read: singletons render `update` ops, objects-sets with
`reconcile=false` + empty map are harmless no-ops). Implementation
waits on the owner (it changes what the test proves about the OIDC
directory). Evidence + verdict written into the test header (their
daemon commits).

## b2) FULLY DONE (late-session surprise) - the bind-e2e cert time bomb

- The final gate went red on stalwart-bind-e2e: 993 served
  `CN=rcgen self signed cert` (stalwart's RUNTIME fallback) instead of
  the pinned `CN=bind.test` cert. Root cause (fingerprint transcript,
  vm-debug direct-driver run): the store-cached `runCommand` test cert
  carried `-days 2` and expired 2026-10-19 04:39 GMT - yesterday's
  green gate finished ~13 minutes BEFORE expiry; stalwart then
  silently refused the expired cert material and fell back to rcgen.
  Nix never rebuilds a cached runCommand output, so short validity on
  a cached cert is a time bomb that only ever detonates. Fixed with
  `-days 3650` + the load-bearing rationale in-file; bind-e2e re-run
  GREEN. vm-debug.sh also gained the missing RED-check path: its
  GC-root build RUNS the test and used to abort under `set -e` before
  any debug script could run (the exact case the script exists for).
  Daemon commit d3fb4e7.

## c) NOT STARTED (unchanged from the parent report)

X1-C43 release chain (X2/X3/X4), X8, X15, X11.3, X13 (wait-for **→ carried by the 14-19 closeout + TODO_LIST rows**
BuildFlow session - binary is already stale vs their HEAD 9e3ccb0),
X18, X19, X20, X12 filings.

## d) Fucked up

- Nothing new. Cosmetic: the auto-commit daemon raced my explicit
  commits twice, splitting the ruff fix and the X17.2 batch across
  daemon/explicit commits - content complete, history fragmented.

## e) Improvements

- The `machine.execute(...)[0]` + `cat >&2` + `assert` ordering (dump
  BEFORE assert) is now the uniform pattern in all five VM tests - keep
  it that way in new tests.
- vm-debug.sh starter now dumps network state up front; future egress
  mysteries die in the first transcript.

## f) NEXT (top items)

1. Owner: bless the hermetic pbx override (spec in (b)) - one more **→ 14-19 f/1 = TODO pbx row (owner, open)**
   pbx VM run lands the flip.
   ~~2. Next nix-email daemon push: first CI exercise of ruff->lockstep->~~ done — pushed; run 39864876276 (2026-10-22) green end-to-end
   shape->flake-check in order; expect GREEN end-to-end (no push from
   assistants - daemon/owner action).
2. X8/X15 heavy VM lanes (relay bounce-path, TLS-node breadth) - each **→ TODO_LIST rows**
   is its own session-sized run.
3. X12.2: reproduce the dnsmasq forward-vs-blackhole claim BEFORE **→ TODO_LIST upstream-filings row**
   filing (verify-before-filing); note the new scope split (driver VM
   vs demo VM egress differ).
4. X13 after the BuildFlow session lands + binary rebuild (their HEAD **→ TODO_LIST BuildFlow row**
   9e3ccb0 is already ahead of the installed binary ef32fa0).
5. X7.1/X7.2 bandit/vulture doctrine draft (owner blessing = 5-min **→ TODO_LIST CI python-lint row**
   read).

## g) Owner questions (unchanged set, evidence upgraded)

1. pbx live-fetch doctrine: ANSWERED BY EVIDENCE - live is impossible **→ TODO pbx row (hermetic blessing pending)**
   in driver VMs; only the hermetic shape remains. Bless it?
2. Wrapper-owned route-wait vs consumer-side: the working instance is **→ owner call (TODO pbx row evidence)**
   consumer-side (pbx test file). Should the WRAPPER ship a route-wait
   affordance for network-directing consumers?
3. Cross-repo red-master tolerance: yesterday's wait-for discipline **→ owner call (cross-repo policy)**
   worked (no collisions), but it left master red for ~26h. Keep the
   wait-for, or add an "error-class fixes may cross a LANDED session's
   files" rule with the hand-off row as the gate?
