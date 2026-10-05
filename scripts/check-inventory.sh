#!/usr/bin/env bash
# Check-inventory guard: the flake's declared checks must match CI's
# expected list EXACTLY (x86_64 lockstep + aarch64 shape), mirroring the
# two ci.yml guard steps. CI owns the truth on the runner; this hook
# front-runs it locally so a drift commit fails BEFORE the push ships a
# red master run (the 2026-09-23 class: a missing list entry shipped
# three unnoticed master reds).
#
# Exit 0 when the flake check inventory matches the expectations below;
# nonzero otherwise (hook fails the push). Update BOTH this script and
# the ci.yml lists in the same commit that adds/removes a check.
set -eu
cd "$(git rev-parse --show-toplevel)"

nix eval .#checks.x86_64-linux --json --apply 'builtins.attrNames' > /tmp/hook-actual-checks.json
expected='["dmarc-eval","module-import-eval","parsedmarc-e2e","stalwart-e2e","stalwart-relay-e2e"]'
if ! jq -e --argjson expected "$expected" 'sort == ($expected | sort)' /tmp/hook-actual-checks.json > /dev/null; then
  echo "pre-push: flake checks and the expected list diverged."
  echo "--- flake declares: $(cat /tmp/hook-actual-checks.json)"
  echo "--- expected:       $expected"
  echo "--- update scripts/check-inventory.sh AND .github/workflows/ci.yml in the same commit"
  exit 1
fi

aarch64="$(nix eval .#checks.aarch64-linux --apply 'builtins.attrNames')"
if [ "$aarch64" != '[ "dmarc-eval" "module-import-eval" ]' ]; then
  echo "pre-push: aarch64 check set drifted: $aarch64"
  echo "--- update scripts/check-inventory.sh AND .github/workflows/ci.yml in the same commit"
  exit 1
fi

echo "pre-push: check inventory matches CI expectations"
