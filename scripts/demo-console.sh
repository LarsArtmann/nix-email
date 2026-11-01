#!/usr/bin/env bash
# Demo-VM FIFO console: mechanizes the CONTRIBUTING "VM debug loops"
# recipe (`mkfifo in && cat in | <vm>/bin/run-demo-vm > log`, with a
# `sleep infinity > in` holder). The manual recipe is one wrong
# redirection away from a hung orphan QEMU holding the demo-disk write
# lock (~/.cache/nix-email-demo/demo.qcow2) - this wrapper owns the
# holder, a HARD timeout, and the orphan sweep, so a dead session can
# never leave the demo unbootable.
#
# Usage: scripts/demo-console.sh [timeout-seconds]
#   default timeout 1800 s; the VM is killed (TERM, then KILL) at the
#   deadline. Everything lives under one session dir; the console log
#   path is printed on start.
#
# Interact from OTHER terminals (the script's own stdin is unused):
#   echo 'root' > "$FIFO"        # send a console line
#   tail -f "$LOG"               # read the serial console
# Stop the VM: echo 'poweroff' > "$FIFO" (or wait for the timeout).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

TIMEOUT="${1:-1800}"
case "$TIMEOUT" in
'' | *[!0-9]*) echo "usage: $0 [timeout-seconds]" >&2 ; exit 2 ;;
esac

SESSION_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nix-email-demo-console.XXXXXX")"
FIFO="$SESSION_DIR/in"
LOG="$SESSION_DIR/console.log"
mkfifo "$FIFO"

echo ">>> building demo VM closure (instant when cached)"
# `nix run .#vm` is an app; the closure behind it is the demo system's
# vm build (bin/run-demo-vm) - build THAT so we can exec it directly.
VM="$(nix build --no-link --print-out-paths \
	'.#nixosConfigurations.demo.config.system.build.vm')"

HOLDER_PID=""
VM_JOB=""
# shellcheck disable=SC2329  # invoked via the EXIT/INT/TERM trap below
cleanup() {
	# Holder first: closing the FIFO's last writer lets cat drain and
	# exit instead of blocking forever.
	[ -n "$HOLDER_PID" ] && kill "$HOLDER_PID" 2>/dev/null || true
	# The VM pipeline runs under setsid, so -$VM_JOB is its process
	# group: one kill takes cat + run-demo-vm + QEMU.
	if [ -n "$VM_JOB" ]; then
		kill -- "-$VM_JOB" 2>/dev/null || true
		sleep 2
		kill -9 -- "-$VM_JOB" 2>/dev/null || true
	fi
	# Orphan sweep: any QEMU still holding the demo disk (a timed-out
	# or crashed predecessor) would keep the write lock forever.
	if pgrep -f 'qemu.*nix-email-demo' >/dev/null 2>&1; then
		echo ">>> killing orphan QEMU holding the demo disk:" >&2
		pgrep -af 'qemu.*nix-email-demo' >&2 || true
		pkill -f 'qemu.*nix-email-demo' 2>/dev/null || true
	fi
}
trap cleanup EXIT INT TERM

# Holder keeps the FIFO open so run-demo-vm never sees stdin EOF.
sleep infinity >"$FIFO" &
HOLDER_PID=$!

echo ">>> session dir: $SESSION_DIR"
echo ">>> send console input:  echo '<line>' > $FIFO"
echo ">>> read the console:    tail -f $LOG"
echo ">>> stop the VM:         echo 'poweroff' > $FIFO   (timeout ${TIMEOUT}s)"

RC=0
setsid sh -c "cat '$FIFO' | '$VM/bin/run-demo-vm' >'$LOG' 2>&1" &
VM_JOB=$!
SECONDS=0
while kill -0 "$VM_JOB" 2>/dev/null && [ "$SECONDS" -lt "$TIMEOUT" ]; do
	sleep 5
done
if kill -0 "$VM_JOB" 2>/dev/null; then
	echo ">>> timeout after ${TIMEOUT}s - killing the VM (log kept: $LOG)" >&2
	kill -- "-$VM_JOB" 2>/dev/null || true
	sleep 2
	kill -9 -- "-$VM_JOB" 2>/dev/null || true
	wait "$VM_JOB" 2>/dev/null || RC=$?
else
	wait "$VM_JOB" || RC=$?
	echo ">>> VM exited (rc=$RC); log kept: $LOG"
fi
exit "$RC"
