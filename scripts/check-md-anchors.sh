#!/usr/bin/env sh
# Front-door integrity lint (2026-11-02, the README TOC lane):
# a markdown file that carries a `## Contents` section must keep that
# section honest, and every in-file `#anchor` must resolve.
#
# Two independent checks per file:
#   1. ANCHOR RESOLUTION - every `](#slug)` link (outside code fences and
#      inline code spans) must match a heading in the SAME file, using the
#      GitHub slugger (lowercase, strip everything but [a-z0-9 _-], spaces
#      to hyphens, duplicate headings get -1/-2 suffixes).
#   2. TOC COMPLETENESS - when the file has a `## Contents` heading, every
#      other level-2 heading must be listed EXACTLY ONCE in that section.
#      A missing row hides a section; a duplicated row is drift.
#
# Rationale: the README is 1600+ lines and 39% of it is the ledger (owner
# decision C52 keeps it there) - the TOC is the only navigation, so it is
# load-bearing and must fail a build when it rots instead of needing a
# session to notice. Before this script the audit was an ad-hoc python
# snippet run by hand, i.e. it never ran when it mattered.
#
# Fail-closed: prints every offender as file:line and exits nonzero.
# Argless mode lints every git-tracked *.md (no-spaces convention).
# `--self-test` plants a broken anchor, a missing TOC row, a duplicated
# TOC row and a clean file - a never-firing lint is a false green.
set -eu

if [ "${1:-}" = "--self-test" ]; then
	fixture="$(mktemp /tmp/md-anchors-XXXXXX.md)"
	trap 'rm -f "$fixture"' EXIT
	# 1) broken anchor -> must FAIL
	cat >"$fixture" <<'FIXTURE'
# Title

## Contents

- [Alpha](#alpha)

## Alpha

See [Beta](#beta).
FIXTURE
	if sh "$0" "$fixture" >/dev/null 2>&1; then
		echo "FATAL: lint accepted a link to a non-existent heading" >&2
		exit 1
	fi
	# 2) heading missing from Contents -> must FAIL
	cat >"$fixture" <<'FIXTURE'
# Title

## Contents

- [Alpha](#alpha)

## Alpha

body

## Beta

body
FIXTURE
	if sh "$0" "$fixture" >/dev/null 2>&1; then
		echo "FATAL: lint accepted a level-2 heading missing from Contents" >&2
		exit 1
	fi
	# 3) heading listed twice -> must FAIL
	cat >"$fixture" <<'FIXTURE'
# Title

## Contents

- [Alpha](#alpha)
- [Alpha](#alpha)

## Alpha

body
FIXTURE
	if sh "$0" "$fixture" >/dev/null 2>&1; then
		echo "FATAL: lint accepted a duplicated Contents row" >&2
		exit 1
	fi
	# 4) clean file (anchors resolve, TOC complete, links in code ignored)
	cat >"$fixture" <<'FIXTURE'
# Title

## Contents

- [Alpha](#alpha)
- [Module: `services.x`](#module-servicesx)

## Alpha

See [the module](#module-servicesx) and the literal `](#not-a-link)`.

```
[ignored](#inside-a-fence)
```

## Module: `services.x`

body
FIXTURE
	if ! sh "$0" "$fixture" >/dev/null 2>&1; then
		echo "FATAL: lint flagged a clean file" >&2
		sh "$0" "$fixture" >&2 || true
		exit 1
	fi
	echo "check-md-anchors: self-test passed (3 negative fixtures, 1 positive)"
	exit 0
fi

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
  function slug(s,   t, base) {
    t = tolower(s)
    gsub(/[^a-z0-9 _-]/, "", t)
    gsub(/ /, "-", t)
    base = t
    if (seen[base]++ > 0) t = base "-" (seen[base] - 1)
    return t
  }

  function flush(f,   i, s, a, tocstart, tocend, counts, resolved) {
    if (nline == 0) { reset(); return }
    for (i = 1; i <= nhead; i++) resolved[slugs[i]] = 1
    for (i = 1; i <= nline; i++) {
      if (infence[i]) continue
      s = L[i]
      gsub(/`[^`]*`/, "", s)
      while (match(s, /\]\(#[^)[:space:]]*\)/)) {
        a = substr(s, RSTART + 3, RLENGTH - 4)
        if (!(a in resolved)) {
          printf "offender: %s:%d: anchor #%s does not resolve to a heading\n", f, i, a
          status = 1
        }
        s = substr(s, RSTART + RLENGTH)
      }
    }
    tocstart = 0
    for (i = 1; i <= nhead; i++) {
      if (lvl[i] == 2 && txt[i] == "Contents") { tocstart = i; break }
    }
    if (tocstart > 0) {
      tocend = nline + 1
      for (i = tocstart + 1; i <= nhead; i++) {
        if (lvl[i] <= 2) { tocend = hnum[i]; break }
      }
      for (i = hnum[tocstart] + 1; i < tocend; i++) {
        if (infence[i]) continue
        if (L[i] !~ /^[[:space:]]*[-*][[:space:]]/) continue
        s = L[i]
        gsub(/`[^`]*`/, "", s)
        while (match(s, /\]\(#[^)[:space:]]*\)/)) {
          a = substr(s, RSTART + 3, RLENGTH - 4)
          counts[a]++
          s = substr(s, RSTART + RLENGTH)
        }
      }
      for (i = 1; i <= nhead; i++) {
        if (i == tocstart) continue
        if (lvl[i] != 2) continue
        if (!(slugs[i] in counts)) {
          printf "offender: %s:%d: heading \"%s\" (#%s) is missing from Contents\n", f, hnum[i], txt[i], slugs[i]
          status = 1
        } else if (counts[slugs[i]] > 1) {
          printf "offender: %s:%d: heading \"%s\" (#%s) is listed %d times in Contents\n", f, hnum[i], txt[i], slugs[i], counts[slugs[i]]
          status = 1
        }
      }
    }
    reset()
  }

  function reset(   i) {
    for (i = 1; i <= nline; i++) { L[i] = ""; infence[i] = 0 }
    for (i = 1; i <= nhead; i++) { lvl[i] = 0; txt[i] = ""; slugs[i] = ""; hnum[i] = 0 }
    for (i in seen) delete seen[i]
    nline = 0; nhead = 0; fence = 0
  }

  FNR == 1 {
    if (started) flush(curfile)
    started = 1
    curfile = FILENAME
  }

  {
    nline = FNR
    L[FNR] = $0
    if ($0 ~ /^[[:space:]]*```/) { infence[FNR] = 1; fence = !fence; next }
    if (fence) { infence[FNR] = 1; next }
    if ($0 ~ /^#+[[:space:]]/) {
      nhead++
      hnum[nhead] = FNR
      t = $0
      match(t, /^#+/)
      lvl[nhead] = RLENGTH
      sub(/^#+[[:space:]]*/, "", t)
      sub(/[[:space:]]*#+[[:space:]]*$/, "", t)
      txt[nhead] = t
      slugs[nhead] = slug(t)
    }
  }

  END {
    if (started) flush(curfile)
    exit status
  }
' "$@"
