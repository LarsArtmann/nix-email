#!/usr/bin/env sh
# Refactor-identity proof (W18.2, mechanizing the 01-22 e/4 recipe):
# prove a "pure refactor" changed NOTHING in what the flake produces.
# Run BEFORE the refactor, save the record; run AFTER; diff. Identical
# outPath = bit-identical output (the strongest proof). A NEW outPath
# with an OLD registrationTime = cached rebuild (content moved); a new
# registrationTime = the refactor genuinely changed the build - inspect
# before claiming purity.
#
# usage: refactor-identity.sh <attr> [...] > before.json
#        refactor-identity.sh <attr> [...] > after.json
#        diff before.json after.json
set -eu

[ "$#" -ge 1 ] || {
	echo "usage: $0 <flake-attr> [...] (e.g. $0 '.#checks.x86_64-linux.demo-eval')" >&2
	exit 2
}

for attr in "$@"; do
	out="$(nix eval --raw "${attr}.outPath")"
	if [ -d "$out" ]; then
		registered="$(nix path-info --json "$out" | jq -r '.[] | .registrationTime')"
		narhash="$(nix path-info --json "$out" | jq -r '.[] | .narHash')"
	else
		registered="not-built"
		narhash="not-built"
	fi
	printf '%s\t%s\t%s\t%s\n' "$attr" "$out" "$registered" "$narhash"
done
