#!/usr/bin/env sh
# Lint markdown tables for dprint-unsafe rows (the 2026-09-23 eaten-rows
# class): dprint re-splits table rows on UNESCAPED pipes and DROPS the
# overflow when a row has more cells than its header. Every row of a
# table must therefore carry exactly as many unescaped pipes as the
# header row; literal pipes inside a cell MUST be escaped as `\|`.
# Code fences toggle the lint off (journal transcripts quote pipes).
# Fail-closed: prints every offender as file:line and exits nonzero.
#
# Limitations (deliberate): fences are recognized only at column 0
# (backtick form) - this repo's markdown keeps fences at column 0.
set -eu

[ "$#" -ge 1 ] || {
	echo "usage: $0 <markdown-file>..." >&2
	exit 2
}

awk '
  FNR == 1 { expected = 0 }
  /^```/ { fence = !fence; next }
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
