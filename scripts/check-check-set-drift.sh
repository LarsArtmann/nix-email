#!/usr/bin/env sh
# Check-set drift alarm: AGENTS.md and README.md must not carry NUMERIC
# check-set claims ("9-check set", "the 7 checks", "4 flake checks") -
# counts rot within hours (the 6->7 drift shipped once, AGENTS rule:
# the check set is SINGLE-SOURCED). The canonical set lives in the ci.yml
# lockstep lists + scripts/check-inventory.sh; README "What is built and
# verified" names checks individually, never by count.
# Fail-closed: prints every offender as file:line and exits nonzero.
set -eu

if [ "$#" -lt 1 ]; then
	set -- AGENTS.md README.md
fi

awk '
  $0 ~ /[0-9]+([[:space:]]|-)+(flake[[:space:]]+)?checks?([^[:alnum:]]|$)/ {
    printf "offender: %s:%d: numeric check-set claim rots - point at the ci.yml lockstep list instead: %s\n", FILENAME, FNR, $0
    status = 1
  }
  END { exit status }
' "$@"
