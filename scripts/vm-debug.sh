#!/usr/bin/env bash
# VM debug-driver wrapper: mechanizes the CONTRIBUTING "VM debug loops"
# recipe (GC root -> driver discovery -> --test-script run) so the next
# debug session gets the dance for free and keeps the baked-in rules:
#
#   (a) long machine.execute payloads die silently (status -1/28) -
#       capture via succeed("... > /tmp/f.log 2>&1") and cat the file;
#   (b) NEVER systemctl start stalwart-provision.service manually mid-test
#       - a manual RE-run's try-restart races the probe (535 on VALID
#       creds); wait for stalwart.service + wait_for_open_port;
#   (c) journal greps must quote concrete phrases (bare `over` matches
#       every "Consumed ... over Ns" line);
#   (d) let provisioning settle before probing: port-open != server-ready
#       (the ExecStartPost restart window eats connections);
#   (e) logged artifacts dump on failure by default.
#
# The generated starter test-script encodes (a), (b), (d); the driver
# itself owns (e). Driver python runs on the HOST - VM-port work must be
# packaged scripts or machine.succeed, never host socket code.
#
# Usage: scripts/vm-debug.sh [--script-only] [--check] [--self-test] [check-name] [existing-test-script]
#   check-name defaults to stalwart-e2e (must be an x86_64 VM e2e check;
#   pure-eval checks have no driver).
#   --self-test   instant, no nix eval: proves the path-like check-name
#                 guard classifies good and bad names correctly.
#   --script-only  no VM run at all: skips the GC-root build (which IS the
#                  VM test run) and does not exec the driver; prints the
#                  final command line instead (compose it into your own loop).
#   --check        lint the test script before running: python syntax
#                  (py_compile) plus the baked-in debug rules - (b) manual
#                  stalwart-provision starts, (f) the errexit
#                  `cmd; echo RC:$?` trap, host-side socket code against
#                  VM ports.
#   Scripts passed from under /tmp are COPIED into the cache dir first:
#   a /tmp sweeper broke a run mid-session once (2026-10-31) - the driver
#   reads the script at start, so the copy is what runs.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

SCRIPT_ONLY=0
LINT_ONLY=0
SELF_TEST=0
while [ "$#" -gt 0 ]; do
	case "$1" in
	--script-only) SCRIPT_ONLY=1 ;;
	--check) LINT_ONLY=1 ;;
	--self-test) SELF_TEST=1 ;;
	--)
		shift
		break
		;;
	*) break ;;
	esac
	shift
done

# True when the check name looks like a path: flags ate the positionals
# (the 02-07 report d/1 faceplant class). Single source of truth - the
# self-test calls the same function.
check_name_looks_like_path() {
	case "$1" in
	*/* | .*) return 0 ;;
	*) return 1 ;;
	esac
}

if [ "$SELF_TEST" = 1 ]; then
	for name in "./tests/foo.nix" "scripts/x.sh" ".hidden"; do
		if ! check_name_looks_like_path "$name"; then
			echo "self-test FAIL: '$name' should be flagged as path-like" >&2
			exit 1
		fi
	done
	if check_name_looks_like_path "stalwart-e2e"; then
		echo "self-test FAIL: 'stalwart-e2e' should pass the guard" >&2
		exit 1
	fi
	echo "vm-debug self-test PASS: path guard classifies 3 bad + 1 good name(s)"
	exit 0
fi

CHECK="${1:-stalwart-e2e}"
SCRIPT="${2:-}"

# Guard: a path in the CHECK slot means flags ate the positionals - fail
# fast with the fix instead of a slow "no such check" eval walk.
if check_name_looks_like_path "$CHECK"; then
	echo "error: check name '$CHECK' looks like a path - flags must come BEFORE the positionals" >&2
	echo "usage: $0 [--script-only] [--check] <check-name> [test-script]" >&2
	exit 1
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/nix-email/vm-debug"
mkdir -p "$CACHE_DIR"

if ! nix eval ".#checks.x86_64-linux.$CHECK" --apply 'd: d.outPath' >/dev/null 2>&1; then
	echo "error: no such check: checks.x86_64-linux.$CHECK" >&2
	echo "VM e2e checks: $(nix eval .#checks.x86_64-linux --json --apply 'builtins.attrNames' | jq -r 'map(select(test("e2e"))) | join(", ")')" >&2
	exit 1
fi
case "$CHECK" in
*-e2e) ;;
*)
	echo "warning: $CHECK is not a *-e2e check - if it is pure-eval it has no driver" >&2
	;;
esac

ROOT="/tmp/nix-email-vm-debug-$CHECK"
if [ "$SCRIPT_ONLY" = 1 ]; then
	echo ">>> --script-only: skipping the GC-root build (it would RUN the VM test)"
else
	echo ">>> building GC root $ROOT (instant when the check is cached)"
	# The build RUNS the VM test - a RED check fails here and, under set -e,
	# would abort before the debug script ever runs (the exact case the
	# script exists for). Survive it: debug against the store closure
	# instead; the GC root only materializes on green.
	nix build -o "$ROOT" ".#checks.x86_64-linux.$CHECK" -L ||
		echo ">>> check is RED - no GC root; continuing against the store closure" >&2
fi

# Driver discovery: a testers.runNixOSTest check output is an EMPTY dir -
# the per-test driver (which preloads the machine configs) appears in the
# check derivation's buildCommand as an absolute /nix/store path.
DRIVER="$(
	nix derivation show ".#checks.x86_64-linux.$CHECK" 2>/dev/null |
		jq -r '.derivations[].env.buildCommand' |
		grep -o '/nix/store/[a-z0-9]*-nixos-test-driver-[^/ ]*/bin/nixos-test-driver' |
		head -1
)"
if [ -z "$DRIVER" ] || [ ! -x "$DRIVER" ]; then
	echo "error: no test driver found for $CHECK (pure-eval checks have no VM to debug)" >&2
	exit 1
fi

OUTDIR="/tmp/nix-email-vm-debug-$CHECK-out"
mkdir -p "$OUTDIR" # the driver's -o needs an EXISTING dir

if [ -z "$SCRIPT" ]; then
	SCRIPT="$CACHE_DIR/$CHECK.py"
	if [ ! -f "$SCRIPT" ]; then
		cat >"$SCRIPT" <<'PYEOF'
# Starter debug script - rules (a)/(b)/(d) from CONTRIBUTING baked in.
# Edit for your check, then rerun scripts/vm-debug.sh with this path.
start_all()

# (b) + (d): wait for the unit, then let provisioning SETTLE before any
# probe - port-open != server-ready (the ExecStartPost restart window
# eats connections).
machine.wait_for_unit("stalwart.service")
machine.wait_for_open_port(8080)
machine.sleep(3)

# (a): capture into files, then cat - long machine.execute payloads die
# silently (status -1/28); the driver dumps logged artifacts on failure.
machine.succeed("journalctl -u stalwart.service > /tmp/stalwart-journal.log 2>&1")
print(machine.succeed("cat /tmp/stalwart-journal.log"))

# Egress forensics (pbx run 16, 2026-10-20): driver VMs have NO outbound
# - slirp DNS AND direct TCP fail instantly despite a DHCP default route.
# Read the network state before any network-dependent probe.
machine.succeed("cat /etc/resolv.conf >&2 || true")
machine.succeed("ip -br addr >&2; ip route >&2 || true")
PYEOF
		echo ">>> wrote starter script $SCRIPT (edit it for your probe)"
	fi
else
	case "$SCRIPT" in
	/tmp/* | "${TMPDIR:-/tmp}"/*)
		RELOCATED="$CACHE_DIR/$(basename "$SCRIPT")"
		cp "$SCRIPT" "$RELOCATED"
		echo ">>> NOTE: $SCRIPT lives under /tmp (a sweeper broke a run mid-session once); running the copy: $RELOCATED" >&2
		SCRIPT="$RELOCATED"
		;;
	esac
fi

echo ">>> driver: $DRIVER"
echo ">>> script: $SCRIPT    out-dir: $OUTDIR"
if [ "$SCRIPT_ONLY" = 0 ]; then
	echo ">>> GC root keeps the closure alive; clean up with: rm $ROOT"
fi
echo ">>> (d) BrokenPipeError driver death = rerun; REPL: quit"

if [ "$LINT_ONLY" = 1 ]; then
	echo ">>> --check: python syntax (py_compile)"
	python3 -m py_compile "$SCRIPT"
	echo ">>> --check: baked-in rules (b), (f), host-socket"
	if grep -n 'systemctl start stalwart-provision' "$SCRIPT"; then
		echo "error: rule (b): NEVER start stalwart-provision manually mid-test (try-restart races the probe)" >&2
		exit 1
	fi
	if grep -nE ';[[:space:]]*echo RC:' "$SCRIPT"; then
		echo "error: rule (f): errexit aborts at cmd - 'cmd; echo RC:'\$?' never captures (the A4 v1/v2 lesson)" >&2
		exit 1
	fi
	if grep -nE 'import socket|socket\.create_connection' "$SCRIPT"; then
		echo "warning: host-side socket code - VM-port work must be packaged scripts or machine.succeed, never host sockets" >&2
	fi
	echo ">>> --check: clean"
fi

if [ "$SCRIPT_ONLY" = 1 ]; then
	echo ">>> --script-only: driver NOT started; command line:"
	echo "\"$DRIVER\" --test-script \"$SCRIPT\" -o \"$OUTDIR\""
	exit 0
fi
exec "$DRIVER" --test-script "$SCRIPT" -o "$OUTDIR"
