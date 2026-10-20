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

- **Run 15**: the unit-level route-wait ExecStartPre was a NO-OP that
  itself failed the provision unit - bare `ip` is not on the unit PATH
  (`command not found` looped 60s, exit 1 at t=85.5). Fixed with
  absolute store paths.
- **Run 16** (with the fix + new discriminators): apply passes ALL 30
  objects, fails ONLY at the final `reload` action's OIDC discovery
  fetch - and the forensics prove the fetch can NEVER work in a driver
  VM: with a valid DHCP default route, slirp DNS (10.0.2.3, resolv.conf
  correctly populated by resolvconf) AND direct TCP (curl 7 to
  1.1.1.1:443 in 1 ms) both fail instantly. /tmp/pbx-x5-run16.log.
- **Consequence**: owner question 1 (live GET vs hermetic) is settled
  by impossibility, not policy - a live fetch cannot go green in
  `nix flake check` VMs. The hermetic mechanism is spec'd (whole-key
  `mkVMOverride` on `provision.objects.Directory.objects.pocketid` to a
  non-remote `@type` + the Authentication ref; the wrapper renderer and
  option types read: singletons render `update` ops, objects-sets with
  `reconcile=false` + empty map are harmless no-ops). Implementation
  waits on the owner (it changes what the test proves about the OIDC
  directory). Evidence + verdict written into the test header (their
  daemon commits).

## c) NOT STARTED (unchanged from the parent report)

X1-C43 release chain (X2/X3/X4), X8, X15, X11.3, X13 (wait-for
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

1. Owner: bless the hermetic pbx override (spec in (b)) - one more
   pbx VM run lands the flip.
2. Next nix-email daemon push: first CI exercise of ruff->lockstep->
   shape->flake-check in order; expect GREEN end-to-end (no push from
   assistants - daemon/owner action).
3. X8/X15 heavy VM lanes (relay bounce-path, TLS-node breadth) - each
   is its own session-sized run.
4. X12.2: reproduce the dnsmasq forward-vs-blackhole claim BEFORE
   filing (verify-before-filing); note the new scope split (driver VM
   vs demo VM egress differ).
5. X13 after the BuildFlow session lands + binary rebuild (their HEAD
   9e3ccb0 is already ahead of the installed binary ef32fa0).
6. X7.1/X7.2 bandit/vulture doctrine draft (owner blessing = 5-min
   read).

## g) Owner questions (unchanged set, evidence upgraded)

1. pbx live-fetch doctrine: ANSWERED BY EVIDENCE - live is impossible
   in driver VMs; only the hermetic shape remains. Bless it?
2. Wrapper-owned route-wait vs consumer-side: the working instance is
   consumer-side (pbx test file). Should the WRAPPER ship a route-wait
   affordance for network-directing consumers?
3. Cross-repo red-master tolerance: yesterday's wait-for discipline
   worked (no collisions), but it left master red for ~26h. Keep the
   wait-for, or add an "error-class fixes may cross a LANDED session's
   files" rule with the hand-off row as the gate?
