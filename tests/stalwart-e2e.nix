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

  # Runs INSIDE the VM (the testScript itself runs on the driver host):
  # polls IMAPS on loopback until a message containing the needle arrives
  # in user2's INBOX. Delivery is async (queue -> local delivery) and the
  # self-signed cert handshake can be slow on first connect.
  imapProbe = pkgs.writers.writePython3Bin "imap-probe" { } ''
    import imaplib
    import ssl
    import sys
    import time

    needle = sys.argv[1].encode()
    deadline = time.time() + 180
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    last_err = None
    while time.time() < deadline:
        try:
            with imaplib.IMAP4_SSL("127.0.0.1", 993, ssl_context=ctx) as imap:
                imap.login("user2@example.test", "testpass")
                status, _ = imap.select("INBOX")
                assert status == "OK"
                status, data = imap.search(None, "ALL")
                assert status == "OK"
                for num in data[0].split():
                    status, msg = imap.fetch(num, "(RFC822)")
                    body = b"".join(
                        part[1] for part in msg if isinstance(part, tuple)
                    )
                    if needle in body:
                        print("needle found in INBOX")
                        sys.exit(0)
                imap.close()
        except Exception as err:
            last_err = err
            print("retry: {}".format(err), file=sys.stderr)
        time.sleep(3)
    msg = "needle never arrived (last error: {})".format(last_err)
    print(msg, file=sys.stderr)
    sys.exit(1)
  '';
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
        imapProbe
      ];

      virtualisation.memorySize = 2048;
    };

  testScript = ''
    import json

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
        # The self-signed certificate (rcgen) is generated asynchronously at
        # first start and can take tens of seconds in the entropy-poor,
        # DNS-less VM (observed >80s once) - poll instead of single-shotting.
        machine.wait_until_succeeds(
            "echo | openssl s_client -connect 127.0.0.1:993 2>/dev/null | grep -q 'OK'",
            timeout=180,
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
            "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/principal | grep -q 401"
        )

    def create_principal(payload):
        machine.succeed(
            "curl -fsS -u admin:test-admin-secret -H 'Content-Type: application/json' "
            "-X POST http://127.0.0.1:8080/api/principal -d '{}'".format(
                json.dumps(payload)
            )
        )

    def create_account(name):
        # "roles": ["user"] is REQUIRED - without it the account authenticates
        # but submission is refused with 550 5.7.1 "not authorized to use
        # this service" (the webadmin adds it silently; observed live in VM).
        create_principal({
            "type": "individual",
            "name": name,
            "emails": [name],
            "roles": ["user"],
            "secrets": ["${testHash}"],
        })

    with subtest("management API: create domain and accounts"):
        create_principal({"type": "domain", "name": "example.test"})
        create_account("user1@example.test")
        create_account("user2@example.test")

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

        # Delivery is async (queue -> local delivery); probe IMAPS until the
        # needle message appears in user2's INBOX (script runs in the VM).
        machine.succeed("imap-probe needle-576a4565b70f5a4c")

    with subtest("no crashes"):
        machine.succeed("! journalctl -u stalwart -b 0 | grep -qiE 'panic|fatal error'")
  '';
}
