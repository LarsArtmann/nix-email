#!/usr/bin/env sh
# Ban piped grep/tail/head assertions inside VM tests (the exit-23
# lesson, mechanized 2026-09-15, made hermetic + self-tested
# 2026-11-18): in-VM assertions must be dump-to-file + grep-the-file,
# never `producer | grep -q`. Under the test shell's pipefail, grep -q's
# early exit EPIPEs the producer (observed ONCE in CI as curl exit 23 on
# a MATCHING payload); the negated form `! p | grep -q` can
# phantom-green. `| tail`/`| head` are the same class (exit-code eating
# / early close). Comment lines (nix or embedded python) are exempt so
# the doctrine can be stated in comments.
#
# The word boundary in the regex is ([^[:alnum:]]|$), NOT \b - gawk 5.x
# regex constants treat \b as backspace, which makes the lint a
# never-firing false green (caught by the 2026-09-16 local negative
# test; now replayed by --self-test on every invocation).
#
# Line-level exemption (2026-11-18): append `# vm-pipe-ok: <reason>` to
# a line whose pipe is INSIDE an in-VM shell string as plumbing (a pty
# feeder, a data pump with explicit rc propagation) - NOT a driver-side
# assertion pipe. The marker is per-line, must carry a reason, and is
# itself covered by --self-test (a marked offender line MUST pass).
#
# Argless mode lints every git-tracked tests/*.nix. Fail-closed:
# prints every offender as file:line and exits nonzero.
set -eu

lint() {
	awk '
	  match($0, /\|[[:space:]]*!?[[:space:]]*(grep|tail|head)([^[:alnum:]]|$)/) && $0 !~ /^[[:space:]]*#/ && $0 !~ /#[[:space:]]*vm-pipe-ok/ {printf "offender: %s:%d: %s\n", FILENAME, FNR, $0; bad=1} END {exit bad}
	' "$@"
}

case "${1:-}" in
--self-test)
	tmp="$(mktemp -d "${TMPDIR:-/tmp}/vm-pipe-lint-XXXXXX")"
	trap 'rm -rf "$tmp"' EXIT
	# The 2026-09-16 negative test, mechanized: the planted piped
	# assertion MUST fail, the dump-to-file form MUST pass, and a
	# comment carrying the pipe shape MUST stay exempt.
	printf 'machine.succeed("curl http://x | grep -q needle")\n' >"$tmp/bad.nix"
	if lint "$tmp/bad.nix" >"$tmp/out" 2>&1; then
		echo "FATAL: vm pipe-assertion lint accepted a planted \`cmd | grep -q\`" >&2
		exit 1
	fi
	printf 'machine.succeed("curl http://x > out; grep -q needle out")\n' >"$tmp/good.nix"
	lint "$tmp/good.nix"
	printf '# doctrine comment: never producer | grep -q\n' >"$tmp/comment.nix"
	lint "$tmp/comment.nix"
	printf 'machine.succeed("feed | head -200 | script -qec x") # vm-pipe-ok: pty feeder, rc propagated\n' >"$tmp/marked.nix"
	lint "$tmp/marked.nix"
	echo "vm pipe-assertion lint self-test: planted pipe rejected, dump-to-file/comment/vm-pipe-ok forms accepted"
	exit 0
	;;
-h | --help)
	echo "usage: check-vm-pipe-assertions.sh [--self-test] [tests/*.nix ...]"
	exit 0
	;;
-*)
	echo "unknown flag: $1" >&2
	exit 2
	;;
esac

if [ "$#" -lt 1 ]; then
	set -- $(git ls-files -- 'tests/*.nix')
	[ "$#" -ge 1 ] || {
		echo "no tests/*.nix tracked - nothing to check"
		exit 0
	}
fi

lint "$@"
