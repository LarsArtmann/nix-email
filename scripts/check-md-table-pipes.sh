#!/usr/bin/env sh
# Lint markdown tables for dprint-unsafe rows (the 2026-09-23 eaten-rows
# class): dprint re-splits table rows on UNESCAPED pipes and DROPS the
# overflow when a row has more cells than its header. Every row of a
# table must therefore carry exactly as many unescaped pipes as the
# header row; literal pipes inside a cell MUST be escaped as `\|`.
# Code fences toggle the lint off (journal transcripts quote pipes).
# Fail-closed: prints every offender as file:line and exits nonzero.
#
# Argless mode lints every git-tracked *.md (assumes no spaces in paths -
# this repo's convention). Fences are recognized INDENTED too (list-nested
# fences), matching dprint's own markdown parser.
set -eu

if [ "$#" -lt 1 ]; then
	for f in $(git ls-files -- '*.md'); do
		set -- "$@" "$f"
	done
	[ "$#" -ge 1 ] || {
		echo "no markdown files tracked - nothing to check"
		exit 0
	}
fi

awk '
  FNR == 1 { expected = 0 }
  /^[[:space:]]*```/ { fence = !fence; next }
  fence { next }
  /^[[:space:]]*\|/ {
    line = $0
    gsub(/\\\|/, "", line)
    n = gsub(/\|/, "|", line)
    if (expected == 0) {
      expected = n
    } else if (n != expected) {
      printf "offender: %s:%d: %d unescaped pipes, header has %d: %s\n", FILENAME, FNR, n, expected, $0
      status = 1
    }
    next
  }
  { expected = 0 }
  END { exit status }
' "$@"
