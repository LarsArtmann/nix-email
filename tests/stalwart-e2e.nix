# End-to-end VM test for modules/mail-server.nix against the REAL Stalwart
# 0.15.5 binary from nixpkgs (no mocks). Pattern borrowed from
# simple-nixos-mailserver's external.nix: exercise the FULL mail path with
# real accounts, not just protocol greetings.
#
#   1. Service starts and stays up against the RocksDB store
#   2. SMTP dialogue with unknown recipient REJECTED 5xx (directory lookup)
#   3. IMAPS implicit-TLS greeting; HTTP admin answers on loopback only
#   4. Declarative admin bootstrap via `authentication.fallback-admin`
#      (verified in v0.15.5 source: works with an empty internal directory)
#   5. Accounts + domain created through the real management API
#      (POST /api/principal - payload verified against webadmin source)
#   6. Authenticated submission on 587 (STARTTLS + AUTH PLAIN)
#   7. Delivery: message lands in the recipient's INBOX, fetched via IMAPS
#   8. Nothing panics in the journal
#
# NOT covered (needs DNS + external relay creds): outbound smarthost relay,
# DKIM signing (needs generated keys), spam classification. Those stay
# live-host go-live checks - see README verified-facts ledger for the keys.
{
  pkgs,
}:
let
  # Fixed salt => deterministic hash of "testpass" (sha512-crypt $6$,
  # the exact format the webadmin hashes account passwords with).
  testHash = "$6$StalwartTestSalt$gagC41V16GV6khfXMiraIyZLKuYDgSyRzVfM0TaSFNMRqkLewQ5d/b9Ns0uc1Rr4DWD15BxHHzh2XaC4ZAS97.";
in
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

      # Headless admin: the fallback-admin exists even with an empty
      # internal directory (reference config pattern from the upstream repo).
      services.stalwart.settings.authentication.fallback-admin = {
        user = "admin";
        secret = "test-admin-secret";
      };

      environment.systemPackages = [
        pkgs.swaks
        pkgs.openssl
        pkgs.curl
        (pkgs.python3.withPackages (ps: [ ]))
      ];

      virtualisation.memorySize = 2048;
    };

  testScript = ''
    import json
    import imaplib
    import ssl
    import time

    start_all()

    machine.wait_for_unit("stalwart.service", timeout=180)
    machine.wait_for_open_port(25, timeout=60)
    machine.wait_for_open_port(8080, timeout=60)

    with subtest("SMTP: full dialogue, unknown recipient rejected 5xx"):
        # --timeout 120: the RCPT decision runs SPF/DNSBL checks whose
        # resolver calls stall ~30s each in the DNS-less VM before failing
        # (deterministic NXDOMAIN-timeout behavior, live-observed). The
        # module defaults keep the DNS checks - a real MX should do them.
        machine.succeed(
            "swaks --timeout 120 --server 127.0.0.1:25 --ehlo probe.example.test --from probe@example.test --to nobody@example.test --quit-after RCPT > /tmp/swaks.log 2>&1 || true"
        )
        machine.succeed("cat /tmp/swaks.log >&2")
        # swaks marks error-response lines with "<**" and success with "<-"
        machine.succeed("grep -E '(<-|<\\*\\*) *5[0-9][0-9]' /tmp/swaks.log")

    with subtest("IMAPS: implicit TLS with IMAP greeting"):
        machine.succeed(
            "echo | openssl s_client -connect 127.0.0.1:993 2>/dev/null | grep -q 'OK'"
        )

    with subtest("HTTP admin/JMAP answers on loopback"):
        machine.succeed(
            "curl -fsSL -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ | grep -Eq '200|30[0-9]'"
        )

    with subtest("admin API: fallback-admin works, anonymous rejected"):
        machine.succeed(
            "curl -fsS -u admin:test-admin-secret http://127.0.0.1:8080/api/principal -o /tmp/principals.json"
        )
        machine.succeed(
            "curl -fsS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/principal | grep -q 401"
        )

    def create_principal(payload):
        machine.succeed(
            "curl -fsS -u admin:test-admin-secret -H 'Content-Type: application/json' "
            "-X POST http://127.0.0.1:8080/api/principal -d '{}'".format(
                json.dumps(payload)
            )
        )

    with subtest("management API: create domain and accounts"):
        create_principal({"type": "domain", "name": "example.test"})
        create_principal({
            "type": "individual",
            "name": "user1@example.test",
            "emails": ["user1@example.test"],
            "secrets": ["${testHash}"],
        })
        create_principal({
            "type": "individual",
            "name": "user2@example.test",
            "emails": ["user2@example.test"],
            "secrets": ["${testHash}"],
        })

    with subtest("submission: authenticated SMTP on 587 delivers to INBOX"):
        machine.succeed(
            "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
            "--auth-user user1@example.test --auth-password testpass "
            "--from user1@example.test --to user2@example.test "
            "--header 'Subject: e2e-needle' --body 'needle-576a4565b70f5a4c' "
            "> /tmp/swaks-sub.log 2>&1"
        )
        machine.succeed("cat /tmp/swaks-sub.log >&2")
        machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-sub.log")

        # Delivery is async (queue -> local delivery). Poll IMAPS for the needle.
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        deadline = time.time() + 120
        found = False
        last_err = None
        while time.time() < deadline and not found:
            try:
                with imaplib.IMAP4_SSL("127.0.0.1", 993, ssl_context=ctx) as imap:
                    imap.login("user2@example.test", "testpass")
                    imap.select("INBOX")
                    status, data = imap.search(None, "ALL")
                    assert status == "OK", data
                    for num in data[0].split():
                        status, msg = imap.fetch(num, "(RFC822)")
                        body = b"".join(part[1] for part in msg if isinstance(part, tuple))
                        if b"needle-576a4565b70f5a4c" in body:
                            found = True
                            print("delivered message fetched via IMAPS")
                    imap.close()
            except Exception as err:
                last_err = err
            if not found:
                time.sleep(3)
        assert found, "message with needle never arrived in user2 INBOX (last error: {})".format(last_err)

    with subtest("no crashes"):
        machine.succeed("! journalctl -u stalwart -b 0 | grep -qiE 'panic|fatal error'")
  '';
}
