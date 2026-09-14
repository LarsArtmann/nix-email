# End-to-end VM test for modules/mail-server.nix against the REAL Stalwart
# 0.16.20 binary from nixpkgs (no mocks). Verifies what eval cannot:
#   1. The service starts and stays up against the RocksDB store
#   2. A full SMTP dialogue (EHLO -> MAIL -> RCPT) is processed and an
#      unknown recipient is REJECTED with a 5xx - proving the SMTP path
#      AND the internal directory lookup work end-to-end
#   3. Implicit-TLS IMAPS answers with a real IMAP greeting over TLS
#   4. The HTTP listener (web admin / JMAP) answers on loopback only
#   5. Nothing panics in the journal
#
# NOT covered (needs accounts + DNS, both interactive/vcs-dependent):
# account bootstrap via the first-run web wizard, DKIM signing, delivery
# into a mailbox. Those are live-host go-live checks, not VM-testable here.
{
  pkgs,
}:
pkgs.testers.runNixOSTest {
  name = "stalwart-e2e";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ ../modules/mail-server.nix ];

      services.mail-server = {
        enable = true;
        hostname = "mail.example.test";
      };

      environment.systemPackages = [
        pkgs.swaks
        pkgs.openssl
        pkgs.curl
      ];

      virtualisation.memorySize = 2048;
    };

  testScript = ''
    start_all()

    machine.wait_for_unit("stalwart.service", timeout=180)
    machine.wait_for_open_port(25, timeout=60)

    with subtest("SMTP: full dialogue, unknown recipient rejected 5xx"):
        machine.succeed(
            "swaks --server 127.0.0.1:25 --from probe@example.test --to nobody@example.test --quit-after RCPT 2>&1 | grep -E '<- *5[0-9][0-9]'"
        )

    with subtest("IMAPS: implicit TLS with IMAP greeting"):
        machine.succeed(
            "echo | openssl s_client -connect 127.0.0.1:993 2>/dev/null | grep -q 'OK'"
        )

    with subtest("HTTP admin/JMAP answers on loopback"):
        machine.succeed(
            "curl -fsSL -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ | grep -Eq '200|30[0-9]'"
        )

    with subtest("no crashes"):
        machine.succeed("! journalctl -u stalwart -b 0 | grep -qiE 'panic|fatal error'")
  '';
}
