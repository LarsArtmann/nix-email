# End-to-end VM test for modules/mail-server.nix against the REAL Stalwart
# 0.15.5 binary from nixpkgs (no mocks). Pattern borrowed from
# simple-nixos-mailserver's external.nix: exercise the FULL mail path with
# real accounts, not just protocol greetings.
#
#   1.  Service starts and stays up against the RocksDB store
#   2.  SMTP dialogue with unknown recipient REJECTED 5xx (directory lookup)
#   3.  IMAPS implicit-TLS greeting; HTTP admin answers on loopback only
#   4.  Declarative admin bootstrap via `authentication.fallback-admin`
#       (verified in v0.15.5 source: works with an empty internal directory)
#   5.  Accounts + domain created through the real management API
#       (POST /api/principal - payload verified against webadmin source)
#   6.  Authenticated submission on 587 (STARTTLS + AUTH PLAIN)
#   7.  Delivery: message lands in the recipient's INBOX, fetched via IMAPS
#   8.  DKIM signing: the declarative `signature.<id>` block signs the
#       submission (header asserted on the stored message)
#   9.  Metrics: /metrics/prometheus answers 200 on the HTTP listener
#   10. Journal hygiene: exactly the 2 known-benign "Configuration build
#       error" lines (resolver/pyzor in the DNS-less VM) - nothing else
#   11. Restart persistence: message survives `systemctl restart`, anonymous
#       admin API stays 401
#   12. Backup/restore: offline `--export`, wipe the store, `--import`,
#       message survives the roundtrip
#   13. Nothing panics in the journal
#
# NOT covered (needs DNS + external relay creds): outbound smarthost relay
# (see stalwart-relay-e2e), spam classification. Those stay live-host
# go-live checks - see README verified-facts ledger for the keys.
{pkgs}: let
  # Fixed salt => deterministic hash of "testpass" (sha512-crypt $6$,
  # the exact format the webadmin hashes account passwords with).
  testHash = "$6$StalwartTestSalt$gagC41V16GV6khfXMiraIyZLKuYDgSyRzVfM0TaSFNMRqkLewQ5d/b9Ns0uc1Rr4DWD15BxHHzh2XaC4ZAS97.";

  # Test-only RSA key (PKCS#8) for the DKIM signing subtest. Published in a
  # public repo ON PURPOSE: it signs nothing but the test domain.
  testDkimKey = ''
    -----BEGIN PRIVATE KEY-----
    MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDIqJDyBWA3cV59
    0cJRC00yhs2aLSU5a1LoDQpwIDBCCQVSI6z/Q4VJbc+Hpjccy/vrQ+DFbGT5WHoh
    LXHFC9wU5WBDOzQigLIncKpeQdBHfmY9lPeA1dvKeYzGav4dbmb4r++ZPk0rDlck
    c65lzxyuZsj5LFrRITQq8hVGOK/keIazFNqxpdJVzlV/pXRoNPQIzR4dIn6UwtX4
    YkoNfyiM6cWNXqxNrolgI+6pcpjZXjDXdtW2XPHFvVFkeMEIMhuCm+aSbxCQy5Jb
    nHOBumlddQKQMACKtnJvJHHrMOhIbv+qJc+kHAE4IGvX4dAwF9FzgvIt+Oa8LEPV
    56f9L1uZAgMBAAECggEAAZN8Yi0U+96AuRRUYy9UUNPClx+CNQS6kU7MtxCAdiMf
    87/kVrPbGHzVTI0YTmCf5t6A8pmjo4Da/CCuB14swUyQPUfAfmhiuqdUH6eP76EG
    w9Adz3kU9luBz1gTpqhhayDm2be474AeQsLc9Iw3ZXtlpvplL+xKBPyjJ0q5vyp7
    h5xBB9wuWJlvRbELqqb8j1QlXK90dmrtshrtM1UhLZk9JLlTo31FLjky3mJwXXp9
    6Q7FPIw3IoUFHSuomaALJ8XAAKNoCiw54xK5+yv78HpFhrYWJIvI+jO4j5XZcUnl
    zSdGHj0hXrf1kIYtsvBv1p2J/ISJWw6hjgmTr2q7sQKBgQDrfH2DbwHWjQsOXM8u
    vez2BnlQeCyEaTlf2cE0uZRCglYSBctroxfWVzIXhkIgGK1ufq+mXiU9+EikGS85
    QJA1BU1SpKTQ8bQAUT4aMUCGQyyi1FuBAIDAq0UqfRPr+7WM6Gt94Wvl2XwddVbE
    BEuswDBAuZ8mfSIJt1qTHgQhkQKBgQDaI2QPje04k7jvhddsnhutI8fXbPsTXBc8
    fXqgW3L+PvwD0CWUCBCqdadC0x6X/+gm6hmah5KOYBvHi0d00NLB/eUTHs6yqIuf
    xDeOlsZkUklEZyUr47XzN4JAc8oyAIrOWOiFTMC8xTvRhR8ogjYOOJ/WMITuI18c
    aJvddnCViQKBgQCtMeV6aoWWkCvGh3oV7bg/hqlpBsnvJRj+p0BTj/48IHI/VSW0
    58Ibcgw0gxlVU/ESqHh1yx5nApoinyc9W3/0jw68rr1Ns8doyFf9maXUWcmVhMw8
    B+uqSQ1Y359sW7e+iB6u+cGKzrdbTzbeei5SQxP6NsuX2kbTkJg8RcJSEQKBgQCK
    0hj8mRrNdZ0suWV2F0yPrASiwRUrpeCXu1cNtAUDbjvdhVpU0akhgcxXB5ohq1cn
    ZLW0lPCcsOcc3zMzUS2/DP/6YhGyuvZYT3v3v1Y0Q/WilW2fd8O0K7A1qjqUBapQ
    VV5sboL93xsJZImGsw8Jj9mQasI99r6xipUepCBT2QKBgCv1Ih3nvW41YxLca2gg
    xLP5uVbtiajeGgmJ+KZMjh3n/3SkA6aH8jfHSpmMbormHlCRaWzwTIUe9agjDYue
    xWBHNvRL726BfdDRf+TYc+nz4XuJ+0S0qKjPwZ1DI3n3SxbnBny8qlb+8IfXKsTN
    OmzBN6eQXVlGB7V9d4yLpNEn
    -----END PRIVATE KEY-----
  '';

  # Runs INSIDE the VM (the testScript itself runs on the driver host):
  # polls IMAPS on loopback until a message containing the needle arrives
  # in user2's INBOX. Delivery is async (queue -> local delivery) and the
  # self-signed cert handshake can be slow on first connect.
  imapProbe = pkgs.writers.writePython3Bin "imap-probe" {} ''
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

  # Same polling shape, but additionally asserts that the needle message
  # carries a given header line in its header block (used for DKIM-Signature).
  # Finding the needle WITHOUT the header is definitive (headers are set at
  # queue time) - fail fast instead of polling.
  imapHeaderProbe = pkgs.writers.writePython3Bin "imap-header-probe" {} ''
    import imaplib
    import ssl
    import sys
    import time

    needle = sys.argv[1].encode()
    header = sys.argv[2].encode()
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
                    raw = b"".join(
                        part[1] for part in msg if isinstance(part, tuple)
                    )
                    if needle in raw:
                        head = raw.split(b"\r\n\r\n", 1)[0]
                        if header in head:
                            print("header present on needle message")
                            sys.exit(0)
                        print(
                            "needle arrived but {} missing (definitive)".format(
                                header
                            ),
                            file=sys.stderr,
                        )
                        sys.exit(1)
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

    nodes.machine = {lib, ...}: {
      imports = [../modules/mail-server.nix];

      services.mail-server = {
        enable = true;
        hostname = "mail.example.test";
        metrics.enable = true;
      };

      # Headless admin: the fallback-admin exists even with an empty
      # internal directory (reference config pattern from the upstream repo).
      services.stalwart.settings.authentication.fallback-admin = {
        user = "admin";
        secret = "test-admin-secret";
      };

      # DKIM signing: the default `auth.dkim.sign` expression signs local-
      # domain mail with ids `['rsa-' + sender_domain, ...]`, so the id below
      # is exactly "rsa-" + example.test (key names verified against v0.15.5
      # source, README ledger).
      services.stalwart.settings.signature."rsa-example.test" = {
        private-key = testDkimKey;
        domain = "example.test";
        selector = "test";
        algorithm = "rsa-sha256";
      };

      environment.systemPackages = [
        pkgs.swaks
        pkgs.openssl
        pkgs.curl
        imapProbe
        imapHeaderProbe
      ];

      virtualisation.memorySize = 2048;
    };

    testScript = ''
      import json
      import re

      start_all()

      machine.wait_for_unit("stalwart.service", timeout=180)
      machine.wait_for_open_port(25, timeout=60)
      machine.wait_for_open_port(8080, timeout=60)

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

      # Provisioning MUST happen BEFORE any SMTP traffic: a MAIL FROM/RCPT to
      # a not-yet-existing domain poisons the directory's is_local_domain
      # NEGATIVE CACHE (default TTL 1h, crates/directory/src/core/cache.rs),
      # and every later submission for that domain is then routed to the MX
      # path instead of local delivery (observed in VM, 2026-09-14).
      with subtest("management API: create domain and accounts"):
          create_principal({"type": "domain", "name": "example.test"})
          create_account("user1@example.test")
          create_account("user2@example.test")

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

      with subtest("DKIM: submission is signed with the declarative signature"):
          # The same needle message was submitted by user1@example.test (a
          # local domain) - the default sign expression must have stamped a
          # DKIM-Signature header with our selector onto it.
          machine.succeed("imap-header-probe needle-576a4565b70f5a4c 'DKIM-Signature:'")
          machine.succeed(
              "imap-header-probe needle-576a4565b70f5a4c 'd=example.test'"
          )

      with subtest("metrics: /metrics/prometheus answers on the HTTP listener"):
          # metrics.prometheus.enable has no auth configured here - the loopback
          # bind is the exposure control (README doctrine); assert the endpoint
          # speaks Prometheus text format, not just any 200.
          machine.succeed(
              "curl -fsS http://127.0.0.1:8080/metrics/prometheus | grep -qE '^# (HELP|TYPE)'"
          )

      with subtest("journal: exactly the 2 known-benign config-build errors"):
          # In the DNS-less VM exactly two "Configuration build error" lines
          # are BENIGN (details only via -o verbose): resolver.type with no
          # nameservers, and the spam-filter.pyzor.host lookup. Any NEW config
          # error (e.g. a malformed generated key) must fail this count.
          machine.succeed(
              "test \"$(journalctl -u stalwart -b 0 -o cat | grep -c 'Configuration build error')\" -eq 2"
          )

      with subtest("restart persistence: INBOX survives, admin stays locked"):
          machine.succeed("systemctl restart stalwart.service")
          machine.wait_for_unit("stalwart.service", timeout=120)
          machine.wait_for_open_port(993, timeout=180)
          machine.succeed("imap-probe needle-576a4565b70f5a4c")
          machine.succeed(
              "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/api/principal | grep -q 401"
          )

      with subtest("backup/restore: export, wipe, import, message survives"):
          # `--export`/`--import` are OFFLINE ops: run instead of serving, then
          # exit (README ledger, verified against v0.15.5 source). Extract the
          # exact binary + config from the unit so the export reads the same
          # RocksDB the service wrote.
          machine.succeed("systemctl stop stalwart.service")
          exec_line = machine.succeed(
              "systemctl cat stalwart.service | grep -oP 'ExecStart=\\K.*' | tail -1"
          ).strip()
          m = re.search(r"(/nix/store/[^ ]+/bin/[^ ]+) --config=(\S+)", exec_line)
          assert m, "could not parse ExecStart line: " + exec_line
          sw_bin, sw_cfg = m.group(1), m.group(2)

          machine.succeed("mkdir -p /tmp/backup")
          machine.succeed("{} --config={} --export /tmp/backup".format(sw_bin, sw_cfg))
          # The gate must prove it measured: an EMPTY export would make the
          # later survival assertion vacuous.
          machine.succeed("test -n \"$(ls -A /tmp/backup)\"")

          machine.succeed("rm -rf /var/lib/stalwart/db")
          machine.succeed("{} --config={} --import /tmp/backup".format(sw_bin, sw_cfg))
          # import ran as root; the service account must own the store again
          machine.succeed("chown -R stalwart:stalwart /var/lib/stalwart")

          machine.succeed("systemctl start stalwart.service")
          machine.wait_for_unit("stalwart.service", timeout=120)
          machine.wait_for_open_port(993, timeout=180)
          machine.succeed("imap-probe needle-576a4565b70f5a4c")

      with subtest("no crashes"):
          machine.succeed("! journalctl -u stalwart -b 0 | grep -qiE 'panic|fatal error'")
    '';
  }
