#!/usr/bin/env bash
# Check-inventory guard: the flake's declared checks must match
# tests/check-expected.json EXACTLY (x86_64 lockstep + aarch64 shape),
# mirroring the two ci.yml guard steps. The JSON is the SINGLE canonical
# list - this script, ci.yml, and the check-set-lockstep flake check all
# read it, so a check add/remove edits one list (+ the README prose row).
# CI owns the truth on the runner; this hook front-runs it locally so a
# drift commit fails BEFORE the push ships a red master run (the
# 2026-09-23 class: a missing list entry shipped three unnoticed master
# reds).
#
# Exit 0 when the flake check inventory matches the expectations;
# nonzero otherwise (hook fails the push).
set -eu
cd "$(git rev-parse --show-toplevel)"

nix eval .#checks.x86_64-linux --json --apply 'builtins.attrNames' >/tmp/hook-actual-checks.json
expected="$(jq -c '.["x86_64-linux"]' tests/check-expected.json)"
if ! jq -e --argjson expected "$expected" 'sort == ($expected | sort)' /tmp/hook-actual-checks.json >/dev/null; then
	echo "pre-push: flake checks and tests/check-expected.json diverged."
	echo "--- flake declares: $(cat /tmp/hook-actual-checks.json)"
	echo "--- expected:       $expected"
	echo "--- update tests/check-expected.json in the same commit as the check change"
	exit 1
fi

nix eval .#checks.aarch64-linux --json --apply 'builtins.attrNames' >/tmp/hook-actual-aarch64.json
if ! jq -e --slurpfile expected tests/check-expected.json 'sort == ($expected[0]["aarch64-linux"] | sort)' /tmp/hook-actual-aarch64.json >/dev/null; then
	echo "pre-push: aarch64 check set drifted: $(cat /tmp/hook-actual-aarch64.json)"
	echo "--- expected: $(jq -c '.["aarch64-linux"]' tests/check-expected.json)"
	echo "--- update tests/check-expected.json in the same commit as the check change"
	exit 1
fi

echo "pre-push: check inventory matches the canonical expected list"
