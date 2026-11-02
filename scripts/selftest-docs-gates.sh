#!/usr/bin/env sh
# Prove the text gates can FAIL. A lint that is green is not evidence; a
# lint that is red on a planted defect is (the 2026-11-02 lesson: the
# anchor lint happily passed a correct unicode heading because nobody
# planted the adversarial case).
#
# Five gates, each with a defect it MUST reject and - where cheap - a
# clean input it MUST accept:
#
#   pipes      scripts/check-md-table-pipes.sh
#   list       scripts/check-md-list-markers.sh
#   drift      scripts/check-check-set-drift.sh
#   anchors    scripts/check-md-anchors.py
#   versions   scripts/check-readme-versions.py
#
# Usage:
#   sh scripts/selftest-docs-gates.sh                       # all five
#   sh scripts/selftest-docs-gates.sh --only anchors        # one gate
#
# ci.yml calls one selector per lint step, so the fixtures live HERE and
# not in two places. Exit 0 when every gate fires, 1 when a gate accepted
# a planted defect or rejected a clean input, 2 on usage error.
set -eu

repo="$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/docs-gates-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
status=0

must_fail() {
	gate=$1
	shift
	if "$@" >"$tmp/out" 2>&1; then
		echo "FATAL: $gate accepted a planted defect" >&2
		sed 's/^/  /' "$tmp/out" >&2
		status=1
	fi
}

must_pass() {
	gate=$1
	shift
	if ! "$@" >"$tmp/out" 2>&1; then
		echo "FATAL: $gate rejected a clean input" >&2
		sed 's/^/  /' "$tmp/out" >&2
		status=1
	fi
}

check_pipes() {
	f="$tmp/pipes.md"
	printf '| a | b | c |\n| --- | --- | --- |\n| 1 | 2 |\n' >"$f"
	must_fail "pipes (fewer cells than the header)" bash "$repo/scripts/check-md-table-pipes.sh" "$f"
	printf '| a | b | c |\n| --- | --- | --- |\n| 1 | 2 | 3 | 4 |\n' >"$f"
	must_fail "pipes (eaten overflow row)" bash "$repo/scripts/check-md-table-pipes.sh" "$f"
	printf '| a | b | c |\n| --- | --- | --- |\n| 1 \\| x | 2 | 3 |\n' >"$f"
	must_pass "pipes (escaped literal pipe)" bash "$repo/scripts/check-md-table-pipes.sh" "$f"
	cat >"$f" <<'FENCE'
text
```sh
| not | a | table |
```
| a | b | c |
| 1 | 2 | 3 |
FENCE
	must_pass "pipes (fenced transcript)" bash "$repo/scripts/check-md-table-pipes.sh" "$f"
}

check_list() {
	f="$tmp/list.md"
	printf 'prose line that wraps\n- and the wrap lands on a marker\n' >"$f"
	must_fail "list (marker directly after prose)" bash "$repo/scripts/check-md-list-markers.sh" "$f"
	printf 'prose\n\n- item\n  - nested\n- sibling after wrap\n  continues\n' >"$f"
	must_pass "list (deliberate list shape)" bash "$repo/scripts/check-md-list-markers.sh" "$f"
}

check_drift() {
	f="$tmp/drift.md"
	printf 'the 9-check set is green\n' >"$f"
	must_fail "drift (numeric check-set claim)" bash "$repo/scripts/check-check-set-drift.sh" "$f"
	printf 'the canonical check list lives in ci.yml\n' >"$f"
	must_pass "drift (clean prose)" bash "$repo/scripts/check-check-set-drift.sh" "$f"
}

check_anchors() {
	f="$tmp/anchors.md"
	must_pass "anchors (self-test matrix)" python3 "$repo/scripts/check-md-anchors.py" --self-test
	printf '# T\n\n## Contents\n\n- [Alpha](#alpha)\n\n## Alpha\n\nSee [Beta](#beta).\n' >"$f"
	must_fail "anchors (dead link)" python3 "$repo/scripts/check-md-anchors.py" --quiet "$f"
	printf '# T\n\n## Contents\n\n- [Gr\xc3\xbc\xc3\x9fe & Ma\xc3\x9f](#gr\xc3\xbc\xc3\x9fe--ma\xc3\x9f)\n\n## Gr\xc3\xbc\xc3\x9fe & Ma\xc3\x9f\n\nbody\n' >"$f"
	must_pass "anchors (unicode slug, correct)" python3 "$repo/scripts/check-md-anchors.py" --quiet "$f"
	printf '# T\n\n## Contents\n\n- [Gr\xc3\xbc\xc3\x9fe & Ma\xc3\x9f](#gre--ma)\n\n## Gr\xc3\xbc\xc3\x9fe & Ma\xc3\x9f\n\nbody\n' >"$f"
	must_fail "anchors (unicode slug, ascii-stripped)" python3 "$repo/scripts/check-md-anchors.py" --quiet "$f"
	printf '# T\n\nSee [b][b].\n\n[b]: #nope\n' >"$f"
	must_fail "anchors (reference definition)" python3 "$repo/scripts/check-md-anchors.py" --quiet "$f"
	printf '# T\n\n<a href="#nope">x</a>\n' >"$f"
	must_fail "anchors (html href)" python3 "$repo/scripts/check-md-anchors.py" --quiet "$f"
}

check_versions() {
	readme="$repo/README.md"
	must_pass "versions (self-test matrix)" python3 "$repo/scripts/check-readme-versions.py" --self-test
	stalwart="$(sed -n 's/.*Stalwart \*\*\([0-9][0-9.]*\)\*\*.*/\1/p' "$readme" | head -n 1)"
	parsedmarc="$(sed -n 's/.*parsedmarc \*\*\([0-9][0-9.]*\)\*\*.*/\1/p' "$readme" | head -n 1)"
	if [ -z "$stalwart" ] || [ -z "$parsedmarc" ]; then
		echo "FATAL: versions: cannot read the version anchors out of README.md" >&2
		status=1
		return 0
	fi
	must_pass "versions (the real README)" python3 "$repo/scripts/check-readme-versions.py" \
		--quiet --readme "$readme" --stalwart "$stalwart" --parsedmarc "$parsedmarc"
	cp "$readme" "$tmp/README.md"
	sed -i 's/Stalwart \*\*[0-9][0-9.]*\*\*/Stalwart **0.0.0**/' "$tmp/README.md"
	must_fail "versions (planted drift in a README copy)" python3 "$repo/scripts/check-readme-versions.py" \
		--quiet --readme "$tmp/README.md" --stalwart "$stalwart" --parsedmarc "$parsedmarc"
}

usage() {
	printf 'usage: %s [--only pipes|list|drift|anchors|versions]\n' "$0"
}

gate=all
if [ "$#" -gt 0 ]; then
	case "$1" in
	--only)
		gate="${2:-}"
		;;
	--only=*)
		gate="${1#--only=}"
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage >&2
		exit 2
		;;
	esac
fi

case "$gate" in
all)
	check_pipes
	check_list
	check_drift
	check_anchors
	check_versions
	;;
pipes | list | drift | anchors | versions)
	"check_$gate"
	;;
*)
	usage >&2
	exit 2
	;;
esac

if [ "$status" -ne 0 ]; then
	exit 1
fi
echo "docs gates self-test: every planted defect rejected, every clean input accepted"
