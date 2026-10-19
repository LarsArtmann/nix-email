#!/usr/bin/env sh
# Prose-wrap list-marker lint (the dprint list incidents, 05-37 f/5 +
# 06-05 d/2, empirically scoped 2026-10-19): a list marker line directly
# after a column-0 PROSE line (no blank between) is the one list-adjacency
# shape dprint normalizes (it inserts the blank itself) - in a formatted
# tree it marks unfresh formatting or a wrap whose continuation was
# mistyped as a list. Wrapped-item/sibling shapes and indented nested
# lists are STABLE under dprint (verified: no restructure) and are NOT
# flagged; a wrap that lands on a nested marker inside an item is
# textually indistinguishable from a deliberate nested list and stays
# covered by the git-diff-after-every-dprint-pass doctrine (AGENTS).
# Fail-closed: prints every offender as file:line and exits nonzero.
# Argless mode lints every git-tracked *.md (no-spaces convention).
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
  FNR == 1 { prev = "" }
  /^[[:space:]]*```/ { fence = !fence; prev = ""; next }
  fence { next }
  {
    if ($0 ~ /^[[:space:]]*[-+][[:space:]]+/ && prev ~ /^[^[:space:]|>#<=*+0-9-]/) {
      printf "offender: %s:%d: list marker directly after prose (dprint inserts the blank line itself - unfresh format or mistyped wrap): %s\n", FILENAME, FNR, $0
      status = 1
    }
    prev = $0
    next
  }
  END { exit status }
' "$@"
