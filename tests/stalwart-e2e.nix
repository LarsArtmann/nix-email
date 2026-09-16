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
#  13. Alias delivery: a second `emails` entry on a principal receives into
#      the same account's INBOX (internal directory indexes every email ->
#      EmailToId, crates/directory/src/backend/internal/lookup.rs:95)
#  14. Catch-all: a principal holding the literal email "@example.test"
#      receives mail for any unknown local part (default AddressMapping::
#      Enable retries the lookup with "@<domain>", crates/common/src/
#      addresses.rs:209)
#  15. Account quota: `quota` (bytes) on a principal makes delivery RETRY
#      forever (code-level reason "Mailbox over quota.", delivery.rs:225;
#      journal-visible signature: "Message rescheduled for delivery") -
#      message accepted at SMTP time, never ingested, and the retry IS
#      asserted in the journal
#  16. Spam classification: a GTUBE body message gets X-Spam-Status: Yes
#      and is STILL delivered to INBOX (VM-verified 2026-09-15: the default
#      filter scans authenticated submission but does NO Junk filing;
#      Junk routing is consumer sieve territory - README ledger)
#  17. Negative-cache expiry: a domain poisoned by a pre-provision probe
#      becomes deliverable locally again within the configured
#      directoryCacheTtlNegative (the 1h-trap regression guard)
#  18. Nothing panics in the journal
# 19. Native report ingestion: a DMARC aggregate mailed to a
#     report.analysis.addresses recipient with report.analysis.forward=false
#     is CONSUMED by analyze_report (no INBOX delivery) and lands parsed in
#     the report store, readable via GET /api/reports/dmarc
#
# NOT covered (needs DNS + external relay creds): outbound smarthost relay
# (see stalwart-relay-e2e). Those stay live-host go-live checks - see
# README verified-facts ledger for the keys.
{pkgs}: let
  # Fixed salt => deterministic hash of "testpass" (sha512-crypt $6$,
  # the exact format the webadmin hashes account passwords with).
  testHash = "$6$StalwartTestSalt$gagC41V16GV6khfXMiraIyZLKuYDgSyRzVfM0TaSFNMRqkLewQ5d/b9Ns0uc1Rr4DWD15BxHHzh2XaC4ZAS97.";

  # Real DMARC aggregate sample (same artifact as parsedmarc-e2e). The
  # attachment FILENAME matters: Stalwart's report detector matches
  # attachment names containing '!' or '.xml'
  # (smtp/src/reporting/analysis.rs), so the VM copy must keep a
  # report-shaped name.
  dmarcSample = pkgs.fetchurl {
    name = "dmarc-sample-aggregate";
    url = "https://github.com/domainaware/parsedmarc/raw/f45ab94e0608088e0433557608d9f4e9517d3afe/samples/aggregate/estadocuenta1.infonacot.gob.mx!example.com!1536853302!1536939702!2940.xml.zip";
    sha256 = "0dq64cj49711kbja27pjl2hy0d3azrjxg91kqrh40x46fkn1dwkx";
  };

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
  # in the account's INBOX. Delivery is async (queue -> local delivery) and
  # the self-signed cert handshake can be slow on first connect.
  # Args: needle [username [password]] (defaults to user2@example.test).
  imapProbe = pkgs.writers.writePython3Bin "imap-probe" {} ''
    import imaplib
    import ssl
    import sys
    import time

    needle = sys.argv[1].encode()
    user = sys.argv[2] if len(sys.argv) > 2 else "user2@example.test"
    password = sys.argv[3] if len(sys.argv) > 3 else "testpass"
    deadline = time.time() + 180
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    last_err = None
    while time.time() < deadline:
        try:
            with imaplib.IMAP4_SSL("127.0.0.1", 993, ssl_context=ctx) as imap:
                imap.login(user, password)
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

  # Asserts the needle NEVER lands in the account's INBOX during the
  # window (quota enforcement: the message is queue-retried forever, so
  # non-delivery is deterministic). Args: needle user password window_s.
  imapAbsentProbe = pkgs.writers.writePython3Bin "imap-absent-probe" {} ''
    import imaplib
    import ssl
    import sys
    import time

    needle = sys.argv[1].encode()
    user = sys.argv[2]
    password = sys.argv[3]
    deadline = time.time() + int(sys.argv[4])
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    while time.time() < deadline:
        try:
            with imaplib.IMAP4_SSL("127.0.0.1", 993, ssl_context=ctx) as imap:
                imap.login(user, password)
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
                        print(
                            "over-quota message WAS delivered (definitive)",
                            file=sys.stderr,
                        )
                        sys.exit(1)
                imap.close()
        except Exception as err:
            print("retry: {}".format(err), file=sys.stderr)
        time.sleep(3)
    print("needle never delivered within window")
    sys.exit(0)
  '';

  # Same polling shape, but additionally asserts that the needle message
  # carries a given header line in its header block (used for DKIM-Signature).
  # Finding the needle WITHOUT the header is definitive (headers are set at
  # queue time) - fail fast instead of polling.
  # Args: needle header [username [password]].
  imapHeaderProbe = pkgs.writers.writePython3Bin "imap-header-probe" {} ''
    import imaplib
    import ssl
    import sys
    import time

    needle = sys.argv[1].encode()
    header = sys.argv[2].encode()
    user = sys.argv[3] if len(sys.argv) > 3 else "user2@example.test"
    password = sys.argv[4] if len(sys.argv) > 4 else "testpass"
    deadline = time.time() + 180
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    last_err = None
    while time.time() < deadline:
        try:
            with imaplib.IMAP4_SSL("127.0.0.1", 993, ssl_context=ctx) as imap:
                imap.login(user, password)
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

    nodes.machine = {...}: {
      imports = [../modules/mail-server.nix];

      services.mail-server = {
        enable = true;
        hostname = "mail.example.test";
        metrics.enable = true;
        # Low negative-cache TTL so the poisoned-directory recovery subtest
        # can observe the heal inside the test run (upstream default 3600 s
        # would trap the test for an hour - that IS the documented trap).
        directoryCacheTtlNegative = 5;
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

      # Native report ingestion (subtest 19): recipients matching
      # report.analysis.addresses get inbound report messages ANALYZED into
      # the report store instead of delivered - but ONLY with
      # report.analysis.forward = false (the v0.15.5 default true merely
      # forwards; keys verified at
      # crates/common/src/config/smtp/report.rs:86,90).
      # NOTE: nested via REAL attrs (settings.report.analysis), NOT the
      # dotted-string key "report.analysis" - the latter renders as a
      # fully-quoted table header ["report.analysis"], which Stalwart's
      # TOML parser rejects ("Unexpected end of line"; binary probe
      # 2026-09-16, /tmp/st-probe). Bare-dotted and mixed headers
      # ([metrics.prometheus], [signature."rsa-example.test"]) parse fine.
      services.stalwart.settings.report.analysis = {
        addresses = ["reports@example.test"];
        forward = false;
      };

      environment.systemPackages = [
        pkgs.swaks
        pkgs.openssl
        pkgs.curl
        pkgs.jq
        imapProbe
        imapHeaderProbe
        imapAbsentProbe
      ];

      virtualisation.memorySize = 2048;
    };

    testScript = ''
      import json
      import re
      import time

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

      # PRE-PROVISION PROBE: touching example.test before the domain exists
      # poisons the directory negative cache (is_local_domain false -> the
      # domain takes the non-local path; this IS the documented provisioning
      # trap). The recovery subtest below proves the low TTL heals it.
      #
      # RUNTIME BUDGET (documented, measured per run below): the two RCPT
      # probes in this test cost ~60-70 s of pure resolver timeouts. Each
      # RCPT decision runs SPF + DNSBL lookups that stall ~30 s per lookup
      # in the DNS-less VM before failing (deterministic timeout behavior,
      # live-observed); the pre-provision poison probe and the
      # unknown-recipient probe EACH pay that once. The module defaults
      # keep the DNS checks on purpose (a real MX should do them) - the
      # cost is the DNS-less VM's fault, not a product defect.
      with subtest("pre-provision probe poisons the directory negative cache"):
          probe_t0 = time.monotonic()
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:25 --ehlo probe.example.test --from probe@example.test --to early@example.test --quit-after RCPT > /tmp/swaks-early.log 2>&1 || true"
          )
          machine.succeed("cat /tmp/swaks-early.log >&2")
          machine.succeed(
              "grep -E '(<-|<\\*\\*|<~\\*) *5[0-9][0-9]' /tmp/swaks-early.log"
          )
          machine.log(
              "negative-cache poison probe wall cost: {:.0f}s (resolver timeouts)".format(
                  time.monotonic() - probe_t0
              )
          )

      # Provisioning MUST happen BEFORE any SMTP traffic: a MAIL FROM/RCPT to
      # a not-yet-existing domain poisons the directory's is_local_domain
      # NEGATIVE CACHE (default TTL 1h, crates/directory/src/core/cache.rs),
      # and every later submission for that domain is then routed to the MX
      # path instead of local delivery (observed in VM, 2026-09-14).
      with subtest("management API: create domain and accounts"):
          create_principal({"type": "domain", "name": "example.test"})
          create_account("user1@example.test")
          create_account("user2@example.test")
          create_account("reports@example.test")
          # quota = 1 BYTE: over-quota delivery retries forever (reason
          # "Mailbox over quota." at delivery.rs:225; journal logs only
          # "Message rescheduled for delivery") - never ingested.
          create_principal({
              "type": "individual",
              "name": "user3@example.test",
              "emails": ["user3@example.test"],
              "roles": ["user"],
              "secrets": ["${testHash}"],
              "quota": 1,
          })
          # Second emails entry = alias (both map to the same account).
          create_principal({
              "type": "individual",
              "name": "user4@example.test",
              "emails": ["user4@example.test", "alias4@example.test"],
              "roles": ["user"],
              "secrets": ["${testHash}"],
          })
      with subtest("SMTP: full dialogue, unknown recipient rejected 5xx"):
          # --timeout 120: the RCPT decision runs SPF/DNSBL checks whose
          # resolver calls stall ~30s each in the DNS-less VM before failing
          # (deterministic NXDOMAIN-timeout behavior, live-observed). The
          # module defaults keep the DNS checks - a real MX should do them.
          reject_t0 = time.monotonic()
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:25 --ehlo probe.example.test --from probe@example.test --to nobody@example.test --quit-after RCPT > /tmp/swaks.log 2>&1 || true"
          )
          machine.succeed("cat /tmp/swaks.log >&2")
          # swaks marks error-response lines with "<**" and success with "<-"
          machine.succeed("grep -E '(<-|<\\*\\*) *5[0-9][0-9]' /tmp/swaks.log")
          machine.log(
              "unknown-recipient probe wall cost: {:.0f}s (resolver timeouts)".format(
                  time.monotonic() - reject_t0
              )
          )

      with subtest("IMAPS: implicit TLS with IMAP greeting"):
          # The self-signed certificate (rcgen) is generated asynchronously at
          # first start and can take tens of seconds in the entropy-poor,
          # DNS-less VM (observed >80s once) - poll instead of single-shotting.
          machine.wait_until_succeeds(
              "echo | openssl s_client -connect 127.0.0.1:993 2>/dev/null > /tmp/tls-greeting.txt "
              + "&& grep -q 'OK' /tmp/tls-greeting.txt",
              timeout=180,
          )

      with subtest("HTTP admin/JMAP answers on loopback"):
          machine.succeed(
              "curl -fsSL -o /dev/null -w '%{http_code}' "
              "http://127.0.0.1:8080/ > /tmp/http-root-code.txt"
              "&& grep -Eq '200|30[0-9]' /tmp/http-root-code.txt"
          )

      with subtest("admin API: fallback-admin works, anonymous rejected"):
          machine.succeed(
              "curl -fsS -u admin:test-admin-secret http://127.0.0.1:8080/api/principal -o /tmp/principals.json"
          )
          machine.succeed(
              "curl -sS -o /dev/null -w '%{http_code}' "
              "http://127.0.0.1:8080/api/principal > /tmp/api-anon-code.txt"
              "&& grep -q 401 /tmp/api-anon-code.txt"
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

      with subtest("negative-cache expiry: poisoned domain delivers again"):
          # The pre-provision probe poisoned is_local_domain(example.test);
          # with directoryCacheTtlNegative = 5 the entry heals within the
          # test run instead of the 1h upstream default. Under the old
          # default this submission would hang on the MX path (the trap).
          machine.succeed("sleep 7")
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password testpass "
              "--from user1@example.test --to user2@example.test "
              "--header 'Subject: recovery-needle' --body 'needle-recovery-4b9f' "
              "> /tmp/swaks-recovery.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-recovery.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-recovery.log")
          machine.succeed("imap-probe needle-recovery-4b9f")

      with subtest("metrics: /metrics/prometheus answers on the HTTP listener"):
          # metrics.prometheus.enable has no auth configured here - the loopback
          # bind is the exposure control (README doctrine); assert the endpoint
          # speaks Prometheus text format, not just any 200. File-based, never
          # `curl | grep -q`: under the test shell's pipefail, grep -q's early
          # exit EPIPEs curl - observed ONCE as exit 23 (write error) on a
          # MATCHING payload in CI (2026-09-15); the negated form would
          # phantom-green for the same reason.
          machine.succeed(
              "curl -fsS http://127.0.0.1:8080/metrics/prometheus -o /tmp/metrics.prom "
              + "&& grep -qE '^# (HELP|TYPE)' /tmp/metrics.prom"
          )

      with subtest("journal: exactly the 2 known-benign config-build errors"):
          # In the DNS-less VM exactly two "Configuration build error" lines
          # are BENIGN (details only via -o verbose): resolver.type with no
          # nameservers, and the spam-filter.pyzor.host lookup. Any NEW config
          # error (e.g. a malformed generated key) must fail this count.
          machine.succeed(
              "journalctl -u stalwart -b 0 -o cat > /tmp/journal-config.log"
              "&& test \"$(grep -c 'Configuration build error' /tmp/journal-config.log)\" -eq 2"
          )

      with subtest("alias: second emails entry delivers to the same account"):
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password testpass "
              "--from user1@example.test --to alias4@example.test "
              "--header 'Subject: alias-needle' --body 'needle-alias-2c8e' "
              "> /tmp/swaks-alias.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-alias.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-alias.log")
          machine.succeed(
              "imap-probe needle-alias-2c8e user4@example.test testpass"
          )

      with subtest("catch-all: unknown local part lands in the @domain mailbox"):
          # Literal "@example.test" address = catch-all mailbox (default
          # AddressMapping::Enable retries the lookup with "@<domain>").
          # Created HERE, not during provisioning: a live catch-all makes
          # EVERY local part deliverable, which would turn the
          # "unknown recipient rejected 5xx" assertion above into a 250.
          # The bare "@example.test" entry is what makes it the catch-all.
          # The explicit "catchall@example.test" address keeps the mailbox
          # addressable; IMAP LOGIN itself resolves by principal NAME
          # ("catchall" - VM-verified 2026-09-15, README ledger), not by
          # arbitrary email addresses of the principal.
          create_principal({
              "type": "individual",
              "name": "catchall",
              "emails": ["catchall@example.test", "@example.test"],
              "roles": ["user"],
              "secrets": ["${testHash}"],
          })
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password testpass "
              "--from user1@example.test --to stranger42@example.test "
              "--header 'Subject: catchall-needle' --body 'needle-catchall-7d1a' "
              "> /tmp/swaks-catchall.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-catchall.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-catchall.log")
          machine.succeed(
              "imap-probe needle-catchall-7d1a catchall testpass"
          )

      with subtest("quota: over-quota message accepted at SMTP, never delivered"):
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password testpass "
              "--from user1@example.test --to user3@example.test "
              "--header 'Subject: quota-needle' --body 'needle-quota-9e3b' "
              "> /tmp/swaks-quota.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-quota.log >&2")
          # Accepted at RCPT/DATA: quota is an ingest-stage check (451 +
          # queue retry), not an SMTP-stage rejection.
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-quota.log")
          machine.succeed(
              "imap-absent-probe needle-quota-9e3b user3@example.test testpass 21"
          )
          # Transcript-backed (VM debug run 2026-09-15): the journal at
          # default verbosity NEVER logs the code-level reason "Mailbox over
          # quota." (delivery.rs:225) - the observable retry signature is
          # `Message rescheduled for delivery`. Do not re-assert the reason
          # string; it was tried and the gate caught it (the source-reading
          # lesson again).
          machine.wait_until_succeeds(
              "journalctl -u stalwart.service -b 0 -o cat > /tmp/journal-quota.log "
              + "&& grep -q 'Message rescheduled for delivery' /tmp/journal-quota.log",
              timeout=60,
          )
          # A SECOND reschedule line proves the queue RETRIES (the loop),
          # not a one-off requeue - "retried forever" previously rested on
          # a single journal line. wait_until_succeeds polls, so a slow
          # retry backoff costs time, not flake. File-based count (grep -c
          # consumes its input; no EPIPE trap).
          machine.wait_until_succeeds(
              "journalctl -u stalwart.service -b 0 -o cat > /tmp/journal-quota-2.log "
              + "&& test \"$(grep -c 'Message rescheduled for delivery' /tmp/journal-quota-2.log)\" -ge 2",
              timeout=300,
          )

      with subtest("spam: GTUBE message gets X-Spam-Status (no auto-Junk filing)"):
          # GTUBE rides the BODY (the canonical vector - the rule does not
          # match subject-only text). VM-verified defaults 2026-09-15: the
          # filter scans authenticated submission too, tags X-Spam-Status,
          # and delivers to INBOX; no server-side Junk filing (README
          # ledger has the experiment - filing would be consumer sieve
          # territory).
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password testpass "
              "--from user1@example.test --to user2@example.test "
              "--header 'Subject: spamcheck-gtube' "
              "--body 'XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X needle-junk-5f7c' "
              "> /tmp/swaks-junk.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-junk.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-junk.log")
          machine.succeed("imap-header-probe needle-junk-5f7c 'X-Spam-Status'")

      with subtest("native ingestion: DMARC aggregate lands in the report store, not the INBOX"):
          # Mechanism (v0.15.5 source): recipient matches
          # report.analysis.addresses + forward=false -> inbound DATA goes to
          # analyze_report (smtp/src/inbound/data.rs:332) INSTEAD of the
          # mailbox; the parsed report is stored (analysis.rs write gated on
          # report.analysis.store, default "30d") and readable via
          # GET /api/reports/dmarc. ENDPOINT TRAP (OpenAPI-verified
          # 2026-09-16): /api/queue/reports is the OUTBOUND report queue
          # (OutgoingReportList - reports Stalwart sends), permanently empty
          # here; incoming reports live under /api/reports/{dmarc,tls,arf}.
          # Polling the queue endpoint returns total:0 forever - one VM run
          # burned on that mismatch.
          # The zip keeps its report-shaped filename - the detector matches
          # '!' / '.xml' in the ATTACHMENT NAME (analysis.rs). swaks --attach
          # needs the @-prefix to read a FILE: a bare path is attached as
          # LITERAL STRING data with no filename= header (host-verified
          # 2026-09-16) - the analysis then silently finds no report part.
          machine.succeed(
              "cp '${dmarcSample}' '/tmp/estadocuenta1.infonacot.gob.mx!example.com!1536853302!1536939702!2940.xml.zip'"
          )
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:25 "
              "--ehlo reporter.external.example "
              "--from reporter@external.example --to reports@example.test "
              "--header 'Subject: Report Domain: example.com' "
              "--body 'report-consumed-needle-9d2f' "
              "--attach-type application/zip "
              "--attach '@/tmp/estadocuenta1.infonacot.gob.mx!example.com!1536853302!1536939702!2940.xml.zip' "
              "> /tmp/swaks-report.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-report.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-report.log")
          # Parsed asynchronously (tokio::spawn in analyze_report): poll the
          # store list until the report appears, then dump the detail for
          # the transcript. Response shape (management/report.rs): items are
          # "<id>_<expires>" STRINGS, not objects - the detail URL takes the
          # item verbatim. Assert on .data.total, NEVER bare `length` (the
          # wrapper object's length is 1 even with zero items - a vacuous
          # pass burned one VM run 2026-09-16).
          machine.wait_until_succeeds(
              "curl -fsS -u admin:test-admin-secret "
              "http://127.0.0.1:8080/api/reports/dmarc -o /tmp/report-ids.json "
              "&& jq -e '.data.total >= 1' /tmp/report-ids.json",
              timeout=120,
          )
          machine.succeed("cat /tmp/report-ids.json >&2")
          machine.succeed(
              "curl -fsS -u admin:test-admin-secret "
              "http://127.0.0.1:8080/api/reports/dmarc/$(jq -r '.data.items[0]' /tmp/report-ids.json) "
              "-o /tmp/report-detail.json"
          )
          machine.succeed("cat /tmp/report-detail.json >&2")
          # Consumed, never delivered: the analysis path returns before the
          # delivery queue - non-delivery is deterministic.
          machine.succeed(
              "imap-absent-probe report-consumed-needle-9d2f reports@example.test testpass 30"
          )

      with subtest("restart persistence: INBOX survives, admin stays locked"):
          machine.succeed("systemctl restart stalwart.service")
          machine.wait_for_unit("stalwart.service", timeout=120)
          machine.wait_for_open_port(993, timeout=180)
          machine.succeed("imap-probe needle-576a4565b70f5a4c")
          machine.succeed(
              "curl -sS -o /dev/null -w '%{http_code}' "
              "http://127.0.0.1:8080/api/principal > /tmp/api-anon-code.txt"
              "&& grep -q 401 /tmp/api-anon-code.txt"
          )

      with subtest("backup/restore: export, wipe, import, message survives"):
          # `--export`/`--import` are OFFLINE ops: run instead of serving, then
          # exit (README ledger, verified against v0.15.5 source). Extract the
          # exact binary + config from the unit so the export reads the same
          # RocksDB the service wrote.
          machine.succeed("systemctl stop stalwart.service")
          machine.succeed("systemctl cat stalwart.service > /tmp/stalwart-unit.txt")
          exec_line = machine.succeed(
              "grep -oP 'ExecStart=\\K.*' /tmp/stalwart-unit.txt"
          ).strip().splitlines()[-1]
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
          machine.succeed(
              "journalctl -u stalwart -b 0 > /tmp/journal-full.log "
              + "&& ! grep -qiE 'panic|fatal error' /tmp/journal-full.log"
          )
    '';
  }
