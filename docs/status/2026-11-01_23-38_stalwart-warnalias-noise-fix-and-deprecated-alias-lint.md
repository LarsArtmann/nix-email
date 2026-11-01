<!-- Status snapshot 2026-11-01 23:38 CET. Single-session report: the
     owner's question "why do we still get the stalwart 0.15.5 warning in
     pbx-artmann on switch?" and everything that followed from it. No new
     research outside that lane. Tree state at write: nix-email clean at
     7a94432 (daemon-swept); pbx-artmann dirty from a parallel lane
     (TODO_LIST.md, scripts/review/mail.sh) - untouched by me. -->

# Stalwart warnAlias switch noise: migration-default fix + `deprecated-alias-lint` (2026-11-01 23:38)

## 0. TL;DR

| Area             | Verdict                                                                                                                                                                                                                    |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Trigger          | pbx-artmann printed "`stalwart` is currently pinned to `0.15.5`" 4x per switch, 7-8x per rebuild, despite running Stalwart 0.16.27                                                                                         |
| Root cause       | nixpkgs `aliases.nix:2555` retires `stalwart` via `warnAlias`; nix-email's 0.15 migration default (`migration.nix:64`) named that bare alias, and pbx forces it (script in systemPackages + the 0.16 assertion)            |
| Fix landed       | default now `pkgs.stalwart_0_15`; pbx eval 4 warnings -> 0; the migration-script derivation is byte-identical                                                                                                              |
| Systemic guard   | new `deprecated-alias-lint` flake check + `scripts/check-deprecated-aliases.py`, self-tested, parses the alias set from the SAME pin the build uses; on the pre-fix tree it names exactly both offenders with line numbers |
| Gates at yield   | `nix flake check` green x3, lockstep/inventory/README anti-drift green, alejandra + dprint (edited files) + ruff + both markdown lints clean                                                                               |
| Left red (known) | repo-wide `nix fmt -- . --check` still fails on 2 pre-existing files (`TODO_LIST.md`, `docs/probes/2026-11-01_demo-smoke-tooling/README.md`)                                                                               |
| Not pushed       | everything after `d0ae969` is local; pbx's lock sits at `d0ae969`, so the guard and docs are not in any consumer pin yet                                                                                                   |

## a) FULLY DONE (this session; evidence inside)

1. **Diagnosis, transcript-grounded.** The warning text lives in
   `pkgs/top-level/aliases.nix:2555` as `stalwart = warnAlias "..." stalwart_0_15`,
   and `lib/derivations.nix:254-271` (`warnOnInstantiate`) wraps EVERY
   attribute of the derivation in `lib.warn` - so any force (`.version`,
   `.outPath`, `.drvPath`) prints. Two force sites in this tree, both
   through the migration module: the 0.16-only assertion
   (`modules/stalwart-module/migration.nix:371-372`) and pbx installing
   the script into `environment.systemPackages`
   (`hosts/pbx/mail.nix:638-640`, which interpolates `mig.package.version`
   and `lib.getExe mig.package`). The deployed server was never affected:
   `modules/mail-server.nix:945` sets `package = pkgs.stalwart_0_16`
   (0.16.27 at the pbx pin `31ecbaca`).
2. **The fix.** `services.stalwart.migrateFrom015.package` default ->
   `pkgs.stalwart_0_15`; `tests/stalwart-migrate-e2e.nix:60` -> same;
   option description now states why the bare alias must not come back
   and that both versioned attrs ship in the same nixpkgs era (so a
   `or pkgs.stalwart` fallback would protect nothing).
3. **Fix proven twice.** (i) In nix-email: `stalwart-migrate-e2e.drvPath`
   unchanged (`m27938ladrav6zmjv44dfzl99bi7pkzc`), eval 0 warnings.
   (ii) In pbx-artmann: toplevel eval went from 4 "evaluation warning"
   lines to 0; `nix-store -qR` shows the SAME migrate-script derivation
   (`4f8dm3gsr09x22d15m5949pnwn32jww3-stalwart-migrate-from-015`); the
   differing toplevel drvPaths were diffed by derivation JSON and differ
   only in `nixos-version`/`etc`/`system-path`, i.e. flake-path and
   dirty-tree metadata, never the mail closure.
4. **Consumer lock trail.** pbx's `nodes.nix-email.locked.rev` moved
   4b7c2e8 -> d0ae969; the FIRST `nix flake update nix-email` was a
   correct no-op because GitHub `master` was still 4b7c2e8
   (`git ls-remote` verified). I did not push; d0ae969 appeared upstream
   afterwards.
5. **The new systemic guard: `scripts/check-deprecated-aliases.py`.**
   Parses every `warnAlias` name out of the pinned
   `pkgs/top-level/aliases.nix` (215 aliases at the nix-email pin,
   227 at the pbx pin, dotted `gnome2.gtkglext` and nested
   `intel-oneapi.base` both covered), masks comments and string bodies
   while keeping `${...}` interpolations visible, matches
   `pkgs.<name>` with an identifier boundary, refuses `stalwart_0_15`,
   `stalwart_0_16`, `stalwart-cli` and `stalwartx`, and self-tests both
   directions (10 fixture cases, 6 expected offenders) before scanning.
6. **Regression proof.** Run over the pre-fix files
   (`git show d0ae969^:...`) the checker reports exactly
   `migration.nix:64` and `stalwart-migrate-e2e.nix:60`, each with
   nixpkgs' own deprecation sentence attached. The class is now caught,
   not remembered.
7. **Wiring (both registration sites + docs).**
   `flake-modules/checks.nix` gains `deprecated-alias-lint` (runCommand,
   `python3`, self-test then scan against `${pkgs.path}` and `${../.}`);
   `tests/check-expected.json` gains it on BOTH arches; README gains the
   prose row (and the stale "pin `6774f7bc`" claim was corrected to
   `fe132422` on sight); CHANGELOG gains an Added and a Fixed entry;
   AGENTS.md gains the "deprecated attrs are a per-rebuild tax" rule.
8. **Two-site enforcement demonstrated.** With the check added but not
   registered, `nix build .#checks.x86_64-linux.check-set-lockstep`
   failed and printed both arch sets; after the JSON edit it passes.
   `scripts/check-inventory.sh` (pre-push path) EXIT 0; the CI
   README-anti-drift loop names 13/13 checks.
9. **Toolchain cleanliness of everything I touched.** ruff check +
   `ruff format --check` clean (EXE001 fixed by `chmod +x`); alejandra
   clean; `dprint check` clean on CHANGELOG/README/AGENTS; markdown pipe
   and list-marker lints clean; three full `nix flake check` runs green
   (`all checks passed!`).

## b) PARTIALLY DONE

1. **Scope of the checker.** It matches `pkgs.<name>` selections only.
   `with pkgs;`-scoped bare names, quoted selections (`pkgs."stalwart"`,
   masked as string content) and programmatic construction
   (`mkPackageOption pkgs "stalwart"`, `pkgs.${name}`) are out of scope.
   The first two are documented in the docstring; the third is the
   important one and is documented NOWHERE yet (see d/9).
2. **aarch64.** Registered for aarch64 in `check-expected.json`, but only
   the attrNames SHAPE was evaluated; CI's aarch64 step is an attrNames
   guard, so no build of the check on aarch64 has ever run.
3. **Local feedback loop.** The class is caught by `nix flake check` and
   CI, not by anything faster. `.githooks/pre-push` still only runs
   `check-inventory.sh`, and BuildFlow was not extended.
4. **Filing.** Nothing from section f) was minted as TODO rows, and no
   row records the two dprint-red files. Deliberate (the user asked for a
   report, then to wait), but it means f) has no durable home yet.
5. **Consumer-side coverage.** pbx-artmann (the victim) and SystemNix (the
   compat gate) run no equivalent lint, so the same class can still be
   introduced in their own Nix code without notice.

## c) NOT STARTED

1. Push/release of the local commits (`e6ea09e..7a94432`): explicitly
   owner-gated, nothing attempted.
2. Re-verification of the class on a pin advance: no synthetic
   "nixpkgs reformatted `aliases.nix`" scenario was exercised, and no
   `stalwart_0_15` presence entry was added to the lock-guard list.
3. The vendored module's own `package` default
   (`modules/stalwart-module/default.nix:82`,
   `lib.mkPackageOption pkgs "stalwart" {}`): identified as a latent
   same-class default for raw-module consumers, not touched.
4. Ledger currency for the deployed binary: README still carries 23
   `0.16.26` mentions while the pbx pin ships 0.16.27.

## d) TOTALLY FUCKED UP (all caught in-session; nothing broken shipped)

1. **Argued for a fix that re-creates the bug.** My first "smarter"
   proposal was `default = pkgs.stalwart_0_15 or pkgs.stalwart`. That
   keeps a live reference to the deprecated alias and protects nothing:
   `stalwart_0_16` and `stalwart_0_15` appear in the same nixpkgs era, so
   any pin that can run this 0.16 module already has both. Caught by
   reasoning before any gate ran, but it was my recommendation, and the
   lint I then wrote would have failed it - which is the correct verdict.
2. **Sequenced verification backwards.** I ran the full gate BEFORE the
   final docstring edit and the alejandra pass, so a third gate run was
   needed. Correct order is edit -> format -> gate; I burned two
   flake-check cycles learning that.
3. **Isolation lost, not restored.** My 2-line fix landed inside daemon
   commit `d0ae969`, which also contains three foreign files
   (`scripts/demo-console.sh`, `scripts/demo-smoke.py`,
   `scripts/vm-debug.sh`) from a parallel lane. Not my change to judge,
   but the fix is no longer independently bisectable, and I did not read
   those foreign edits.
4. **Shipped with a red gate line and no record.** `nix fmt -- . --check`
   fails repo-wide on two pre-existing files. Ownership made leaving them
   correct, but leaving them WITHOUT a TODO row (or a note in the report
   the owner reads) is the part I got wrong until this report.
5. **Parser without a floor - silent-green class.** The alias parser is
   line-shape based. If nixpkgs reformats `aliases.nix` (alejandra,
   reindent, a `warnAlias` call moved onto its own line), the parse can
   yield 0 aliases and the check passes VACUOUSLY. I noticed this while
   writing this report, not while writing the parser, and did not add the
   obvious `len(aliases) >= 150` assertion. This is exactly the silent
   green this repo keeps killing.
6. **Advertised aarch64 coverage I did not prove.** Registration for
   aarch64 without ever building the check there is an unverified claim,
   even though the derivation is trivial.
7. **Missed the blind spot I later found by hand.**
   `modules/stalwart-module/default.nix:82` builds the package name as a
   STRING (`mkPackageOption pkgs "stalwart"`), which no grep-style check
   can see, and which defaults raw-module consumers to the deprecated
   alias and to 0.15.5 in a 0.16-only module. I found it only when
   auditing my own scanner's limits.
8. **Instruction to the owner was thinner than warranted.** "Relock and
   the warning goes away" was true only AFTER the rev reached GitHub;
   my first message could have said "and it will be a no-op until the fix
   is pushed", and I did not verify at the time whether the push came from
   the owner or the auto-daemon.
9. **No consumer-side follow-through documented.** The user's pain was in
   pbx; I fixed the producer and left the consumer lint idea implicit in
   prose instead of writing it down.

## e) WHAT WE SHOULD IMPROVE

1. **Order of operations, mechanized.** Edit -> format -> (targeted check)
   -> full gate -> docs. Never full gate before the last write.
2. **Every parser/lint asserts its own input size.** A floor assertion
   (`>= 150` aliases, plus a printed count) turns "silent zero" into a
   loud failure; the checker already prints the count, it must also
   enforce it.
3. **Document a check's blind spots next to the check.** The programmatic
   construction hole belongs in the README row and CONTRIBUTING, not only
   in my head and a report.
4. **Fast local front-run for every new lint.** A flake-only check means
   the owner hears about it at gate speed. Pre-push or BuildFlow should
   run the cheap ones.
5. **Name the versioned attr, always.** Add the rule to CONTRIBUTING's
   wrapper-change section so it is read before a new default is written,
   not after a consumer complains.
6. **A deprecation sweep on every pin advance.** Pin advances move the
   alias set (215 -> 227 between `fe132422` and `31ecbaca`, i.e. 12 new
   retired names). The lint should be a step in the pin-advance runbook.
7. **Keep the guard's closure input narrow.** `${../.}` makes the check
   depend on the WHOLE flake source, so any commit invalidates it; a
   `lib.fileset` filter (`.nix` + the script) would keep caching honest.
8. **Audit adjacent defaults while in the file.** The raw-module
   `package` default was one line away from the bug I fixed.
9. **Report-close honesty inventory.** Before yielding, list what stayed
   red and whether it was filed or deliberately not - this session needed
   the owner's prompt to produce that list.
10. **Own the multi-agent reality.** Foreign files in a daemon commit are
    a known hazard; verify the diff I claim as mine, and never assert a
    commit contains only my fix.

## f) NEXT (ranked; none filed as TODO rows this session)

### Consumer rollout (1-6)

1. Review and (owner-gated) push `e6ea09e..7a94432` to `LarsArtmann/nix-email` master.
2. In pbx-artmann: `nix flake update nix-email`, then re-run the eval
   warning count (expect 0) and `nix build .#nixosConfigurations.pbx.config.system.build.toplevel --dry-run`.
3. Add `services.stalwart.migrateFrom015.package = pkgs.stalwart_0_15;`
   explicitly in `hosts/pbx/mail.nix`? Only if pbx wants to pin the dump
   binary independently of the module default (otherwise skip - the
   module default now suffices).
4. Land the equivalent alias lint in pbx-artmann's `flake/checks.nix`
   (its eval is the documented compat gate).
5. Land it in SystemNix's gate too (upstream-flake pattern consumers).
6. Add `stalwart_0_15` to the `/nix-email/flake-modules/lock-guards.nix`
   documented presence list (it currently names `stalwart_0_16` only).

### Guard hardening (7-20)

7. Add the alias-count floor assertion (e.g. `>= 150`) with a loud message.
8. Add a `--strict-with` opt-in that flags bare alias names inside
   `with pkgs;` scopes.
9. Handle quoted selections `pkgs."stalwart"` (unmask string content only
   in attribute-selection position).
10. Detect `pkgs.${name}` / `mkPackageOption pkgs "name"` style
    construction by also scanning string literals for exact alias names.
11. Self-test: CRLF file, unterminated string, huge file, binary-ish file.
12. Self-test: `warnAlias` moved to its own line (the reformat scenario)
    -> must fail loudly via the floor, not pass.
13. Fuzz the masker against `tests/**` and `docs/probes/**` transcripts
    for false positives (currently zero, unproven by fixtures).
14. Add a `--print-aliases` mode for pin-advance diffs
    ("which retired names are new at this pin?").
15. Optionally parse `aliases.nix` with `nix-instantiate --parse` instead
    of line shape to remove the reformat hazard entirely.
16. Wire the checker into `.githooks/pre-push` (needs the pinned path:
    `nix eval --raw --impure --expr '(builtins.getFlake ...).inputs.nixpkgs.outPath'`).
17. Wire it as a BuildFlow step (with the same pinned path) so
    `buildflow` covers it outside `nix flake check`.
18. Make the check's source input a `lib.fileset` of `*.nix` + the script
    so unrelated commits do not invalidate the derivation.
19. Prove the aarch64 build once (ARM host or remote builder) and record
    the transcript.
20. Add a CI fast-lint step that runs the script directly (seconds)
    before the heavy `nix flake check`.

### Blind spots found (21-27)

21. Decide the vendored module's `package` default
    (`default.nix:82`): upstream fidelity (`mkPackageOption pkgs
    "stalwart"`) versus correctness for raw-module consumers (0.15.5 in a
    0.16-only module + the deprecated alias).
22. If kept as-is, add a comment/prose note that the wrapper MUST override
    it (today only `mail-server.nix:945` does).
23. Add an assertion in `module-import-eval` that
    `config.services.stalwart.package.version` is `>= 0.16` whenever the
    vendored 0.16 module is in use.
24. Audit the rest of the vendored module for other unversioned package
    attrs used in defaults (`pkgs.stalwart-cli` is version-free but
    unretired; re-check on each pin advance).
25. Teach the lint the module's own package-name strings so #21-24 are
    mechanized rather than remembered.
26. Record the programmatic-construction blind spot in the README check
    row and CONTRIBUTING.
27. Re-run the whole diagnosis against a consumer that pins an OLDER
    nixpkgs (does the vendored module still eval there? probably not -
    document the minimum pin).

### Verification and gates (28-34)

28. Re-run `nix flake check` with `--rebuild` for the checks this session
    claims green, so "green" is execution, not cache hits (at minimum for
    `deprecated-alias-lint` and `check-set-lockstep`).
29. Add the two pre-existing dprint-red files to a documented repair lane
    (`TODO_LIST.md` needs `annotate.go check-rows` afterwards; the probe
    README is frozen evidence, so decide reformat vs exclude).
30. Add a dprint `--check` to the pre-push hook so markdown drift stops
    re-accumulating (the 2026-11-01 TODO row already proposes it).
31. Verify the CI "running N flake checks" line against the attrNames set
    once more now that the set is 13 (AGENTS calls the line unreliable).
32. Confirm CI run count/step names still pass with the new check
    registered (watch the first post-push run; nothing else changed).
33. Measure the check's build time and record it (expected sub-second;
    unmeasured).
34. Confirm `deprecated-alias-lint` fails on a deliberately injected
    violation inside the flake sandbox (only the out-of-sandbox trees were
    negative-tested).

### Documentation (35-42)

35. CONTRIBUTING: wrapper-change rule "never name an unversioned package
    attr in a default; use the versioned attr".
36. CONTRIBUTING: how to run the checker by hand (devShell + pinned path).
37. README: extend the check row with the blind-spot list (with-pkgs,
    quoted, programmatic).
38. README ledger: record the `warnAlias` force semantics as a verified
    fact (it is currently only in AGENTS + the script docstring).
39. CHANGELOG: verify the two new entries render correctly and cite the
    fix commit(s).
40. Reconcile the 23 `0.16.26` mentions against the deployed 0.16.27
    (pin-advance drift, not this session's scope).
41. Add the lint to the pin-advance runbook (README "Pin-advance").
42. Note in docs/MONITORING or the runbook that a switch-time warning is
    never a health signal here (the stack was fully green throughout).

### Hygiene and process (43-50)

43. Mint the f) items as `TODO_LIST.md` rows in one pass (and run
    `check-rows` + dprint afterwards).
44. Re-read `d0ae969`'s three foreign files enough to confirm they are
    another lane's intended work, then leave them strictly alone.
45. Add a session rule: `git show --stat` the daemon commit that swept my
    edits, and state in the handoff which files are mine.
46. Add a self-review checklist line: "did any lint I wrote this session
    assume its input's formatting?"
47. Add a self-review checklist line: "what did I register for an
    architecture I never built?"
48. Decide whether `scripts/check-deprecated-aliases.py` should be
    promoted into a shared linter (linter-building skill territory) once a
    second repo needs it.
49. Consider a repo-wide `scripts/nix-health-check.sh` entry so triage
    runs the cheap lints before any nix build.
50. After the next pin advance, re-read this report and strike what the
    advance made obsolete.

## g) QUESTIONS FOR THE OWNER (cannot be figured out from this repo)

1. **Push and release authority.** `e6ea09e..7a94432` are local. Should I
   push them straight to `master` (the consumer lock then moves on
   relock), or cut a release/tag first per CONTRIBUTING's release
   checklist? I never push without an explicit go-ahead, and I cannot see
   whether any release lane is currently open.
2. **Housekeeping mandate.** May I reformat the two pre-existing
   dprint-red files (`TODO_LIST.md`,
   `docs/probes/2026-11-01_demo-smoke-tooling/README.md`) and mint the f)
   items as TODO rows - or is one of those owned by a session still
   in flight? `TODO_LIST.md` needs `annotate.go check-rows` after any
   formatter pass, and the probe README is frozen evidence, so this is an
   ownership call, not a technical one.
3. **The raw-module default.** For
   `modules/stalwart-module/default.nix:82`, do you want upstream-copy
   fidelity (`mkPackageOption pkgs "stalwart"`, so the file stays
   diffable against nixpkgs PR #552103 until retirement) or correctness
   for raw-module consumers (`pkgs.stalwart_0_16`, since this module is
   0.16-only)? The two pull in opposite directions and the choice belongs
   to the retirement plan, which I do not own.

---

_Point-in-time snapshot 2026-11-01 23:38 CET. Waiting for instructions._
