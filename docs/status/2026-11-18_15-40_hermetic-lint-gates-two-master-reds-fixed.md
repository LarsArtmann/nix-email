# 2026-11-18 15:40 CET - More nix native: hermetic lint gates; two master CI reds fixed

Scope line - what this session VERIFIED and how:

- VERIFIED: statix exit semantics on the pin (probe derivation:
  errors exit 1, warnings exit 0 - "0.5.8-unstable-2026-07-17");
  the anchors selftest failure mechanism on the CI runner (log of
  run 44135583839: fixture text contained LITERAL `\xc3\xbc` - the
  runner's /bin/sh did not decode bash-only printf escapes; nixpkgs
  dash DOES decode them, so the runner shell is neither pinned bash
  nor nixpkgs dash - which is precisely the ambient-toolchain
  problem); the pipe-lint red (exact ci.yml awk over the tree flags
  tests/stalwart-migrate-1x-e2e.nix:257+317, landed 350f5d3
  2026-11-06, UNSEEN by CI because the anchors step reds first);
  every new check built individually with -L (execution, not cache),
  then the FULL `nix flake check` EXIT:0 with the changed
  migrate-1x VM rebuilt and run (13 derivations built).
- SHIPPED (all landed, tree clean, daemon split commits as usual):

  1. `statix-lint` flake check - statix from the repo's own pin over
     the flake source; self-proves it fires on a planted syntax error
     (errors-only contract, warnings exit 0). Kills the per-run
     registry eval walk of the old
     `nix run github:NixOS/nixpkgs/<rev>#statix` CI step.
  2. ``text-gates`` flake check - the four markdown/count-drift lints
     hermetically (pinned bash/gawk/python3, flake source = git-known
     files, full selftest matrix first). The four ambient CI steps
     consolidated into one fail-fast ``nix build`` of the check.
     GOTCHA recorded in-file: ``${../scripts/<file>}`` interpolates a
     LONE store copy - the selftest's $0-relative repo discovery
     found no siblings (first build failed with repo=/nix); all
     references go through `${../.}`.
  3. `vm-test-lint` flake check - the pipe-assertion ban moved OUT of
     ci.yml (a raw inline awk is untestable in place) into
     scripts/check-vm-pipe-assertions.sh with `--self-test` (the
     negative direction was previously proven only by a one-off
     2026-09-16 manual test) plus a per-line `# vm-pipe-ok: <reason>`
     exemption for in-VM shell plumbing; runs with the
     testscript-shell lint hermetically.
  4. Two pre-existing master reds FIXED: the anchors selftest
     fixtures now use POSIX OCTAL escapes (portable across every
     POSIX printf; CI had been red 2026-11-13..17 on fixture text,
     not tree content), and the two migrate-1x plumbing lines carry
     explicit vm-pipe-ok markers with reasons.
  5. Corridor truth updated: README rows for all three checks,
     AGENTS text-gates bullet, CONTRIBUTING failure-class table
     (eighth script) + the stale "--only selector per lint step"
     sentence, drift-lint pointer text now names
     tests/check-expected.json. ci.yml: 12 steps -> 9, all lint steps
     hermetic except the deliberate registry-floating actionlint and
     the pinned ruff-floor app.

- DELIBERATELY NOT DONE: ruff-floor stays a CI step (fresh measured
  decision 2026-11-01, not churned); the jq/grep in the lockstep
  steps stay ambient (stable tools, nix-eval-driven already);
  actionlint stays registry-floating (documented: newer rules are
  the point for a linter); no `apps.*` added (CI builds checks
  directly - one eval hop, cached for the final flake check).

Verdict in one line: the lint surface now runs wherever nix runs it

- same scripts, pinned toolchain, proven firing - and master's CI
  should go green for the first time since 2026-11-13.
