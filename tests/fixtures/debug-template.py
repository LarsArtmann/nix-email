# VM debug template - run an ad-hoc script against the stalwart-e2e VM
# without editing the committed test (pattern distilled 2026-09-15; the
# working script lived in /tmp and was lost twice before this).
#
# Usage (see AGENTS.md "VM debug loop" for the full procedure):
#   OUT=$(mktemp -d)   # -o requires an EXISTING directory
#   nix-store -r $(nix-store -q --references \
#     $(nix eval --raw .#checks.x86_64-linux.stalwart-e2e.drvPath) \
#     | grep nixos-test-driver) -o $OUT/driver
#   $OUT/driver/bin/nixos-test-driver --test-script $(pwd)/tests/fixtures/debug-template.py \
#     $(nix eval --raw .#checks.x86_64-linux.stalwart-e2e.drvPath)^out \
#     > /tmp/debug-transcript.log 2>&1
#
# Rules encoded here (each one cost a debugging session):
#   - This python runs on the DRIVER HOST. Anything touching VM ports must be
#     a packaged script or a machine.succeed("...") command - never host-side
#     socket code.
#   - wait_for_open_port for EVERY listener before probing (the self-signed
#     cert is generated asynchronously and can take >80 s: POLL, don't
#     single-shot TLS handshakes).
#   - Provision domain/accounts BEFORE any SMTP probe (a RCPT/MAIL FROM probe
#     poisons the directory negative cache for 1 h - see README ledger).
#   - Use file-based greps, not `cmd | grep -q` (EPIPE under pipefail).
#   - swaks needs --timeout 120 in the DNS-less VM (RCPT policy checks stall
#     ~30 s per lookup) and its error markers are <-, <**, AND <~*.

start_all()

machine.wait_for_unit("stalwart.service", timeout=180)
for port in (25, 587, 465, 993, 8080):
    machine.wait_for_open_port(port, timeout=180)

# One submission, then per-variant probes:
machine.succeed(
    "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
    "--auth-user user1@example.test --auth-password testpass "
    "--from user1@example.test --to user2@example.test "
    "--header 'Subject: debug' --body 'debug-needle' "
    "> /tmp/swaks-debug.log 2>&1"
)
machine.succeed("cat /tmp/swaks-debug.log >&2")

# IMAPS probe (packaged script from the committed test's environment):
machine.succeed("imap-probe debug-needle")

# Journal dump for offline reading:
machine.succeed("journalctl -u stalwart -b 0 > /tmp/journal-debug.log")
print(machine.succeed("cat /tmp/journal-debug.log"))
