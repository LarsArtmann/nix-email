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
# Usage: scripts/vm-debug.sh [check-name] [existing-test-script]
#   check-name defaults to stalwart-e2e (must be an x86_64 VM e2e check;
#   pure-eval checks have no driver).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

CHECK="${1:-stalwart-e2e}"
SCRIPT="${2:-}"

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
echo ">>> building GC root $ROOT (instant when the check is cached)"
# The build RUNS the VM test - a RED check fails here and, under set -e,
# would abort before the debug script ever runs (the exact case the
# script exists for). Survive it: debug against the store closure
# instead; the GC root only materializes on green.
nix build -o "$ROOT" ".#checks.x86_64-linux.$CHECK" -L ||
	echo ">>> check is RED - no GC root; continuing against the store closure" >&2

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
	SCRIPT="/tmp/vm-debug-$CHECK.py"
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
fi

echo ">>> driver: $DRIVER"
echo ">>> script: $SCRIPT    out-dir: $OUTDIR"
echo ">>> GC root keeps the closure alive; clean up with: rm $ROOT"
echo ">>> (d) BrokenPipeError driver death = rerun; REPL: quit"
exec "$DRIVER" --test-script "$SCRIPT" -o "$OUTDIR"
