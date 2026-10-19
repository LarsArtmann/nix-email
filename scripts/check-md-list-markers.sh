#!/usr/bin/env sh
# Prose-wrap list-marker lint (three shipped dprint incidents, e.g.
# 05-37 f/5 + 06-05 d/2): dprint parses a wrapped line that STARTS with
# "- "/"+ " as a nested list item and then rewraps everything under it.
# In a dprint-normalized tree a list following prose ALWAYS has a blank
# line before it, so a marker line DIRECTLY after a prose line is either
# a rewrap trap or a formatting deviation - flag it. Deliberate lists are
# NOT flagged: a marker after a blank line, a heading, a fence, a table,
# or another list item (sibling/nested) is legitimate structure.
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
    if ($0 ~ /^[[:space:]]*[-+][[:space:]]+/ && prev !~ /^[[:space:]]*$/) {
      prev_is_prose = (prev !~ /^[[:space:]]*#/ && prev !~ /^[[:space:]]*\|/ && prev !~ /^[[:space:]]*([-*+][[:space:]]|[0-9]+[.)][[:space:]]|<[!\/])/)
      if (prev_is_prose) {
        printf "offender: %s:%d: list marker directly after prose - dprint reparses this as a nested list and rewraps the block: %s\n", FILENAME, FNR, $0
        status = 1
      }
    }
    prev = $0
    next
  }
  END { exit status }
' "$@"
