#!/usr/bin/env sh
# Nix health-check bisect (06-12 f40 + d5): when a nix command dies with
# EMPTY output under concurrent sessions, split machine contention from a
# real failure BEFORE debugging your change. If this trivial evaluation
# answers, the daemon + eval plumbing are fine and the failure belongs to
# your command; if it dies silently too, the machine is contended (or the
# daemon is gone) - wait or free load, do not debug your diff.
set -eu

echo "[*] nix eval plumbing check (expect: 2)"
answer="$(nix-instantiate --eval -E '1+1' 2>&1)" || {
	echo "FATAL: even trivial evaluation dies: $answer" >&2
	echo "       Machine/daemon contention, not your change - wait or free load." >&2
	exit 1
}
echo "[+] plumbing OK ($answer)"
