# End-to-end VM test for modules/mail-server.nix against the REAL Stalwart
# 0.16.x binary from nixpkgs (stalwart_0_16, no mocks). Pattern borrowed from
# simple-nixos-mailserver's external.nix: exercise the FULL mail path with
# real accounts, not just protocol greetings.
#
# 0.16 REWORK (2026-10-16): accounts/domain/listeners/DKIM are DECLARATIVE
# now - provisioned at boot by stalwart-provision (stalwart-cli apply, the
# vendored module's typed plan). The pre-0.16 REST API (/api/principal,
# /api/dkim, /api/reload, /api/reports) is GONE upstream, so:
#   - the "pre-provision poison + negative-cache heal" subtests are dropped:
#     everything exists before the first bind, so there is nothing left to
#     poison (directoryCacheTtlNegative stays for consumers that provision
#     accounts at runtime);
#   - the "admin API" probes moved to the JMAP session endpoint (0.16 moved
#     the session off /jmap, which now answers 404);
#   - the webadmin DKIM-keygen subtest became a second DECLARATIVE signature
#     (ed25519) asserted on the wire (dual DKIM-Signature headers);
#   - the offline backup/restore subtest is dropped: 0.16 removed the
#     `--export/--import` flags (no such commands in crates/main/src/main.rs;
#     backups move to datastore-level tooling - consumer concern).
#   1.  Service starts and stays up against the RocksDB store; the
#       declarative plan applies clean (stalwart-provision oneshot)
#   2.  SMTP dialogue with unknown recipient REJECTED 5xx (directory lookup)
#   3.  IMAPS implicit-TLS greeting; HTTP answers on loopback
#   4.  JMAP session: fallback-admin authenticates via /.well-known/jmap,
#       anonymous session grants no accounts (primaryAccounts = {})
#   5.  Accounts + domain provisioned DECLARATIVELY (plan, not API calls)
#   6.  Authenticated submission on 587 (STARTTLS + AUTH PLAIN)
#   7.  Delivery: message lands in the recipient's INBOX, fetched via IMAPS
#   8.  DKIM signing: both declarative signatures (rsa + ed25519) stamp the
#       submission - one message, two DKIM-Signature headers
#   9.  Metrics: /metrics/prometheus answers 200 on the HTTP listener
#  10. Journal hygiene: no configuration build errors
#  11. Restart persistence: message survives `systemctl restart`, anonymous
#      session keeps primaryAccounts empty
#  12. Alias delivery: a provisioned EmailAlias on user4 receives into the
#      same account's INBOX
#  13. Catch-all: applied AT RUNTIME via a second `stalwart-cli apply`
#      (Domain patch BEFORE the Account - "#id" references resolve only
#      against earlier ops in the same plan) - proves apply
#      idempotency against a live server AND the ordering semantics: before
#      the catch-all exists, unknown local parts are REJECTED (subtest 2)
#  14. Account quota: quotas.maxDiskQuota = 1 makes delivery RETRY forever -
#      message accepted at SMTP time, never ingested, retry asserted in the
#      journal
#  15. Spam classification: a GTUBE body message gets X-Spam-Status: Yes
#      and is STILL delivered to INBOX (the default filter scans
#      authenticated submission but does NO Junk filing; Junk routing is
#      consumer sieve territory - README ledger)
#  16. Native report ingestion: a DMARC aggregate mailed to a
#      ReportSettings.inboundReportAddresses recipient with
#      inboundReportForwarding=false is CONSUMED (no INBOX delivery; the
#      pre-0.16 /api/reports store read is gone with the REST API)
#  17. JMAP: session, mailboxes, and the delivered needle over the API
#  18. Nothing panics in the journal
# 19. Wrapper rate limiter trips at runtime (flood node, M14 evidence)
#
# NOT covered (needs DNS + external relay creds): outbound smarthost relay
# (see stalwart-relay-e2e). Those stay live-host go-live checks - see
# README verified-facts ledger for the keys.
{pkgs}: let
  # Account identity contract (0.16 schema, apply-transcript-verified
  # 2026-10-16): User.name is the LOCAL PART (a full address fails apply
  # with "Invalid email local part | Properties: name"); the primary
  # address is synthesized as name@<Domain(domainId).name> and is the
  # unique 'email' index. Auth (SMTP AUTH, JMAP basic) resolves that
  # synthesized address - which is why the wrapper hostname below must
  # equal example.test, or every address lands in the wrong namespace
  # (auth 535s, MAIL FROM 501s). MAIL FROM outside an account's address
  # set 501s.
  testPass = "testpass-x7Kk-9mQw";

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

  # Second (ed25519) declarative signature - the 0.16 replacement of the
  # old webadmin /api/dkim keygen subtest: both signatures ride the boot
  # plan, and the wire assertion is still "one message, two
  # DKIM-Signature headers" (rsa-sha256 + ed25519-sha256).
  testDkimEd25519Key = ''
    -----BEGIN PRIVATE KEY-----
    MC4CAQAwBQYDK2VwBCIEIHrMbshXJBICmrXes9yZvgdoXWWMC61TpZ4zwH2gL+eR
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
    password = sys.argv[3] if len(sys.argv) > 3 else "${testPass}"
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
    password = sys.argv[4] if len(sys.argv) > 4 else "${testPass}"
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

      services = {
        mail-server = {
          enable = true;
          # hostname IS the provisioned mail domain (the wrapper derives
          # the Domain object + SystemSettings.defaultHostname from it, and
          # account addresses synthesize as <name>@<hostname>): it must
          # equal example.test or every account below lands outside the
          # local namespace (transcript 2026-10-16: hostname
          # mail.example.test rendered user1@mail.example.test and rejected
          # user1@example.test everywhere).
          hostname = "example.test";
          metrics.enable = true;
          # Low negative-cache TTL (upstream default 3600 s): kept from the
          # 0.15 era as a cheap canary - the declarative plan means nothing
          # SHOULD poison the cache anymore, so any stall here is a real
          # regression signal.
          directoryCacheTtlNegative = 5;
          # 0.16: the fallback admin is the provisioning CLI's only
          # credential path (systemd-creds).
          admin.secretFile = "/etc/test-admin-secret";
        };

        stalwart.provision = {
          singletons = {
            # 0.16's reload-validation READS the system resolver config and
            # fails the whole reload with "no nameservers found in config"
            # in this DNS-less VM (transcript 2026-10-16) - same patch the
            # upstream 0.16 NixOS test applies ("specific patches for the
            # test VM environment"). Lookups still stall ~30s per probe,
            # but validation passes.
            DnsResolver."@type" = "Cloudflare";

            # Pyzor OFF: its default host is unresolvable in the DNS-less
            # VM - network dependence + config-error risk for zero test
            # value (0.15-era lesson, unchanged posture).
            SpamPyzor.enable = false;

            # Native report ingestion: recipients matching
            # inboundReportAddresses get inbound report messages ANALYZED
            # into the report store instead of delivered - but ONLY with
            # inboundReportForwarding = false (the pre-0.16
            # report.analysis.{addresses,forward} pair).
            ReportSettings = {
              inboundReportAddresses = ["reports@example.test"];
              inboundReportForwarding = false;
            };
          };
          objects = {
            Account = {
              reconcile = true;
              match = ["name"];
              objects = {
                user1 = {
                  # 0.16 schema: User.name is the LOCAL PART; the primary
                  # address synthesizes as name@<Domain(domainId).name>
                  # (= user1@example.test here) and indexes uniquely as
                  # 'email'. There is no separate emailAddress field.
                  "@type" = "User";
                  name = "user1";
                  domainId = "#domain";
                  roles."@type" = "User";
                  credentials = [
                    {
                      "@type" = "Password";
                      secret = testPass;
                    }
                  ];
                };
                user2 = {
                  "@type" = "User";
                  name = "user2";
                  domainId = "#domain";
                  roles."@type" = "User";
                  credentials = [
                    {
                      "@type" = "Password";
                      secret = testPass;
                    }
                  ];
                };
                reports = {
                  "@type" = "User";
                  name = "reports";
                  domainId = "#domain";
                  roles."@type" = "User";
                  credentials = [
                    {
                      "@type" = "Password";
                      secret = testPass;
                    }
                  ];
                };
                # quota: maxDiskQuota = 1 BYTE - over-quota delivery retries
                # forever, never ingested (journal-visible via the queue
                # reschedule lines asserted below).
                user3 = {
                  "@type" = "User";
                  name = "user3";
                  domainId = "#domain";
                  roles."@type" = "User";
                  credentials = [
                    {
                      "@type" = "Password";
                      secret = testPass;
                    }
                  ];
                  quotas.maxDiskQuota = 1;
                };
                # aliases = the 0.16 replacement of the pre-0.16 second
                # `emails` entry on a principal.
                user4 = {
                  "@type" = "User";
                  name = "user4";
                  domainId = "#domain";
                  roles."@type" = "User";
                  credentials = [
                    {
                      "@type" = "Password";
                      secret = testPass;
                    }
                  ];
                  aliases = [
                    {
                      # EmailAlias.name takes the LOCAL PART only - a full
                      # address fails apply with "Invalid email local part
                      # | Properties: aliases/name" (transcript
                      # 2026-10-16); domainId carries the domain side.
                      name = "alias4";
                      domainId = "#domain";
                      enabled = true;
                    }
                  ];
                };
              };
            };
            DkimSignature = {
              reconcile = false;
              objects = {
                rsa-test = {
                  "@type" = "Dkim1RsaSha256";
                  domainId = "#domain";
                  selector = "test";
                  privateKey = {
                    "@type" = "Text";
                    secret = testDkimKey;
                  };
                  stage = "active";
                };
                ed-test = {
                  "@type" = "Dkim1Ed25519Sha256";
                  domainId = "#domain";
                  selector = "ed";
                  privateKey = {
                    "@type" = "Text";
                    secret = testDkimEd25519Key;
                  };
                  stage = "active";
                };
              };
            };
          };
        };
      };

      # Fallback-admin password (0.16 systemd-creds path).
      environment.etc."test-admin-secret" = {
        mode = "0600";
        text = "test-admin-secret";
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

    # Flood-probe node (M14 runtime evidence, 2026-09-22): one
    # wrapper-managed inbound limiter at a tight 3/1m per-remote_ip rate,
    # deliberately a SEPARATE node so its bucket cannot perturb the main
    # subtests' connections. A tripped inbound limiter is
    # CONNECTION-GATING - a pre-SMTP hangup, never a 4xx code (README
    # ledger (i) source cite + (m) live observation on the 0.15 default
    # 5/1s limiter: 12 rapid connections -> 5 banners + 7 empties; the
    # 0.16 behavior is asserted from THIS build's transcript).
    nodes.flood = {...}: {
      imports = [../modules/mail-server.nix];

      system.stateVersion = "26.05";

      services = {
        mail-server = {
          enable = true;
          hostname = "mail.flood.test";
          admin.secretFile = "/etc/test-admin-secret";
          rateLimits = {
            enable = true;
            rate = "3/1m";
          };
        };
        # Same reload-validation patches as the main node (no nameservers;
        # pyzor host unresolvable - both fail the 0.16 reload validation).
        stalwart.provision.singletons = {
          DnsResolver."@type" = "Cloudflare";
          SpamPyzor.enable = false;
        };
      };

      environment.etc."test-admin-secret" = {
        mode = "0600";
        text = "test-admin-secret";
      };

      virtualisation.memorySize = 1024;
    };

    testScript = ''
      import time

      start_all()

      machine.wait_for_unit("stalwart.service", timeout=180)
      machine.wait_for_open_port(25, timeout=60)
      machine.wait_for_open_port(8080, timeout=60)

      # The declarative plan applies via stalwart-provision (wanted by
      # multi-user.target). `systemctl restart` BLOCKS until the oneshot
      # finishes, so a failure surfaces here with the unit's exit status
      # instead of as mysterious 550s later - and the journal is dumped
      # for the transcript either way. NOTE: the vendored module's unit
      # RESTARTS stalwart after a successful apply (listener sockets do
      # not re-spawn on reload), so the mail ports flap here - re-wait
      # for them before any probe.
      machine.succeed("systemctl restart stalwart-provision.service")
      machine.succeed(
          "journalctl -u stalwart-provision -b 0 -o cat > /tmp/provision.log"
      )
      machine.succeed("cat /tmp/provision.log >&2")
      machine.wait_for_open_port(25, timeout=120)
      machine.wait_for_open_port(8080, timeout=60)

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

      # NOTE: no HTTP-root subtest - 0.16's listener root is NOT the webadmin
      # mount anymore (WebUI lives at /admin as a downloadable Application
      # bundle; a DNS-less VM cannot even fetch it) and / answers 4xx. The
      # /jmap subtests below are the loopback-HTTP contract.

      with subtest("management: fallback-admin authenticates on the session endpoint"):
          # 0.16 moved the JMAP session endpoint (demo-VM transcript,
          # 2026-10-16): GET /jmap is 404 for everyone; the session lives
          # at /.well-known/jmap (307 -> location /jmap/session). The
          # fallback admin authenticates there (vendored module admin
          # option). Anonymous gets a 200 session SHELL with EMPTY
          # primaryAccounts - the enforcement point is the API POST (401,
          # pinned with this exact body). File-based: dump to /tmp,
          # grep/jq the file (pipe-lint rule).
          machine.succeed(
              "curl -fsSL -u admin:test-admin-secret "
              "http://127.0.0.1:8080/.well-known/jmap -o /tmp/jmap-admin-session.json"
          )
          machine.succeed("cat /tmp/jmap-admin-session.json >&2")
          machine.succeed("grep -q 'capabilities' /tmp/jmap-admin-session.json")
          machine.succeed("grep -q '\"username\":\"admin\"' /tmp/jmap-admin-session.json")
          machine.succeed(
              "curl -fsS http://127.0.0.1:8080/jmap/session -o /tmp/jmap-anon-session.json"
          )
          machine.succeed(
              "jq -e '.primaryAccounts == {}' /tmp/jmap-anon-session.json > /dev/null"
          )
          machine.succeed(
              "curl -sS -o /dev/null -w '%{http_code}' "
              "-H 'Content-Type: application/json' "
              "-d '{\"using\":[\"urn:ietf:params:jmap:core\",\"urn:ietf:params:jmap:mail\"],"
              "\"methodCalls\":[[\"Mailbox/query\",{\"accountId\":\"\",\"filter\":null},\"a\"]}' "
              "http://127.0.0.1:8080/jmap/ > /tmp/jmap-anon-code.txt"
              "&& grep -q 401 /tmp/jmap-anon-code.txt"
          )

      with subtest("submission: authenticated SMTP on 587 delivers to INBOX"):
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
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

      with subtest("DKIM: BOTH declarative signatures stamp the submission"):
          # 0.16 replacement of the webadmin keygen subtest: the ed25519
          # signature is DECLARATIVE too (DkimSignature objects, stage
          # active). One message, TWO DKIM-Signature headers: rsa from
          # rsa-test, ed25519 from ed-test.
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to user2@example.test "
              "--header 'Subject: dual-sign' --body 'needle-eddsa-77aa' "
              "> /tmp/swaks-dual.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-dual.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-dual.log")
          machine.succeed("imap-probe needle-eddsa-77aa")
          machine.succeed(
              "imap-header-probe needle-eddsa-77aa 'a=rsa-sha256'"
          )
          machine.succeed(
              "imap-header-probe needle-eddsa-77aa 'a=ed25519-sha256'"
          )

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
          # Transcript-first doctrine (AGENTS.md): queue/auth/capacity alert
          # rules are written ONLY from observed series names - dump the full
          # body into the test log so series names are transcribable from
          # THIS build log (docs/MONITORING.md row 2 feeds off it).
          machine.succeed("cat /tmp/metrics.prom >&2")

      with subtest("journal: no configuration build errors"):
          # 0.16 posture: the plan typechecks at BUILD time (the vendored
          # module's Lua schema check), so any config error surviving to
          # runtime is a real defect. The 0.15 era carried exactly one
          # benign resolver line in this DNS-less VM; the 0.16 journal is
          # asserted clean after transcript inspection (VM run of this
          # file).
          machine.succeed(
              "journalctl -u stalwart -b 0 -o cat > /tmp/journal-config.log"
              "&& ! grep -q 'Configuration build error' /tmp/journal-config.log"
          )

      with subtest("alias: second emails entry delivers to the same account"):
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to alias4@example.test "
              "--header 'Subject: alias-needle' --body 'needle-alias-2c8e' "
              "> /tmp/swaks-alias.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-alias.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-alias.log")
          machine.succeed(
              "imap-probe needle-alias-2c8e user4@example.test '${testPass}'"
          )

      with subtest("catch-all: applied at runtime via a second stalwart-cli apply"):
          # 0.16 object model: Domain.catchAllAddress points at an account's
          # email address; mail for ANY unknown local part lands in that
          # account. Applied HERE, not in the boot plan, for two reasons:
          # (a) a live catch-all makes EVERY local part deliverable, which
          # would turn the "unknown recipient rejected 5xx" assertion above
          # into a 250; (b) it exercises `stalwart-cli apply` idempotency
          # against a LIVE server with an incremental plan (Domain upsert
          # patch + new Account), the exact workflow runtime account
          # provisioning uses. IMAP LOGIN is by full EMAIL ADDRESS in 0.16.
          machine.succeed("cat > /tmp/catchall-plan.ndjson <<'PLAN'\n{\"@type\":\"upsert\",\"object\":\"Domain\",\"value\":{\"domain\":{\"name\":\"example.test\",\"catchAllAddress\":\"catchall@example.test\"}}}\n{\"@type\":\"upsert\",\"object\":\"Account\",\"value\":{\"catchall\":{\"@type\":\"User\",\"name\":\"catchall\",\"domainId\":\"#domain\",\"roles\":{\"@type\":\"User\"},\"credentials\":{\"0\":{\"@type\":\"Password\",\"secret\":\"${testPass}\"}}}}}\nPLAN")
          # Plan ORDER matters: ops apply SEQUENTIALLY and "#id" references
          # resolve against EARLIER ops in the same plan only - the Domain
          # upsert (patching the wrapper's boot-time "domain" object with
          # catchAllAddress) must come BEFORE the Account whose domainId
          # references it, or apply fails with invalidResultReference:
          # 'Invalid reference to non-existing object "domain"'
          # (apply-log transcript 2026-10-16). The apply log is dumped even
          # on failure: a silent log cost one full VM run (2026-10-16).
          applyStatus = machine.execute(
              "STALWART_URL=http://127.0.0.1:8080 STALWART_USER=admin "
              "STALWART_PASSWORD=test-admin-secret "
              "stalwart-cli apply --file /tmp/catchall-plan.ndjson"
              " > /tmp/catchall-apply.log 2>&1"
          )[0]
          machine.succeed("cat /tmp/catchall-apply.log >&2")
          assert applyStatus == 0, (
              f"catch-all stalwart-cli apply failed (exit {applyStatus}) - "
              "see the /tmp/catchall-apply.log dump above"
          )
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to stranger42@example.test "
              "--header 'Subject: catchall-needle' --body 'needle-catchall-7d1a' "
              "> /tmp/swaks-catchall.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-catchall.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-catchall.log")
          machine.succeed(
              "imap-probe needle-catchall-7d1a catchall@example.test '${testPass}'"
          )

      with subtest("quota: over-quota message accepted at SMTP, never delivered"):
          machine.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to user3@example.test "
              "--header 'Subject: quota-needle' --body 'needle-quota-9e3b' "
              "> /tmp/swaks-quota.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-quota.log >&2")
          # Accepted at RCPT/DATA (0.16.22 transcript 2026-10-17: the exact
          # acceptance line is `250 2.0.0 Message queued with id <id>`):
          # quota is an ingest-stage decision, not an SMTP-stage rejection.
          machine.succeed("grep -q 'queued with id' /tmp/swaks-quota.log")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-quota.log")
          machine.succeed(
              "imap-absent-probe needle-quota-9e3b user3@example.test '${testPass}' 21"
          )
          # 0.16.22 JOURNAL SILENCE (debug-driver transcripts 2026-10-17,
          # three independent boots): the 0.15 retry signature `Message
          # rescheduled for delivery` is GONE - across 200 s of post-accept
          # polling the journal carries NO quota/retry/reschedule/4xx line
          # and never re-mentions the queue id; at default verbosity 0.16
          # logs nothing per-message. The observable contract is therefore
          # SMTP-accept + delivery-absence + journal silence; the queue's
          # long-term fate (retry-forever vs deferred) is not
          # journal-observable on 0.16 (README ledger carries the delta).
          machine.succeed(
              "journalctl -u stalwart.service -b 0 -o cat > /tmp/journal-quota.log"
              "&& ! grep -qiE 'rescheduled|over quota' /tmp/journal-quota.log"
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
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to user2@example.test "
              "--header 'Subject: spamcheck-gtube' "
              "--body 'XJS*C4JDBQADN1.NSBN3*2IDNEN*GTUBE-STANDARD-ANTI-UBE-TEST-EMAIL*C.34X needle-junk-5f7c' "
              "> /tmp/swaks-junk.log 2>&1"
          )
          machine.succeed("cat /tmp/swaks-junk.log >&2")
          machine.succeed("! grep -q '<\\*\\*' /tmp/swaks-junk.log")
          machine.succeed("imap-header-probe needle-junk-5f7c 'X-Spam-Status'")

      with subtest("native ingestion: DMARC aggregate consumed, not delivered"):
          # Mechanism: recipient matches ReportSettings.inboundReportAddresses
          # + inboundReportForwarding=false -> inbound DATA goes to the report
          # analyzer INSTEAD of the mailbox (the pre-0.16
          # report.analysis.{addresses,forward} pair). The zip keeps its
          # report-shaped filename - the detector matches '!' / '.xml' in the
          # ATTACHMENT NAME. swaks --attach needs the @-prefix to read a FILE:
          # a bare path is attached as LITERAL STRING data with no filename=
          # header (host-verified 2026-09-16) - the analysis then silently
          # finds no report part.
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
          # 0.16: the /api/reports store read is GONE (REST API removed); the
          # parsed-report evidence lives in the journal instead - dumped here
          # for transcript-first follow-ups (metrics/alert rules read from
          # observed transcripts, never expectations).
          machine.succeed(
              "journalctl -u stalwart -b 0 -o cat > /tmp/journal-report.log"
          )
          machine.succeed("cat /tmp/journal-report.log >&2")
          # Consumed, never delivered: the analysis path returns before the
          # delivery queue - non-delivery is deterministic.
          machine.succeed(
              "imap-absent-probe report-consumed-needle-9d2f reports@example.test '${testPass}' 30"
          )

      with subtest("JMAP: session, mailboxes, and the delivered needle over the API"):
          # 0.16 moved the session endpoint (demo-VM transcript,
          # 2026-10-16): GET /jmap is 404; /.well-known/jmap answers 307
          # (location: /jmap/session) and -L lands on the session doc.
          # apiUrl is an ABSOLUTE https://hostname URL (pinned:
          # https://mail.demo.test/jmap/ on the demo VM) - unusable from
          # this DNS-less VM, so assert its shape, strip scheme+authority
          # with jq, and ride the loopback listener at the extracted path.
          # user2 is a roles:["user"] principal - exactly the adapter's
          # auth shape. All assertions are file-based (dump to /tmp,
          # grep/jq the file), never from expected output.
          machine.succeed(
              "curl -sS -o /dev/null -w '%{http_code}' "
              "http://127.0.0.1:8080/jmap > /tmp/jmap-old-code.txt"
              "&& grep -q 404 /tmp/jmap-old-code.txt"
          )
          machine.succeed(
              "curl -fsSL -u user2@example.test:${testPass} "
              "http://127.0.0.1:8080/.well-known/jmap -o /tmp/jmap-session.json"
          )
          machine.succeed("cat /tmp/jmap-session.json >&2")
          machine.succeed("grep -q 'user2@example.test' /tmp/jmap-session.json")
          machine.succeed("grep -q 'urn:ietf:params:jmap:mail' /tmp/jmap-session.json")
          machine.succeed("grep -q 'eventSourceUrl' /tmp/jmap-session.json")
          machine.succeed(
              "jq -j '.apiUrl | sub(\"^https?://[^/]+\"; \"\")' "
              "/tmp/jmap-session.json > /tmp/jmap-api-path.txt"
          )
          machine.succeed("cat /tmp/jmap-api-path.txt >&2")
          machine.succeed("grep -q '^/jmap/$' /tmp/jmap-api-path.txt")
          machine.succeed(
              "jq -j '.primaryAccounts[\"urn:ietf:params:jmap:mail\"]' "
              "/tmp/jmap-session.json > /tmp/jmap-acct.txt"
          )
          machine.succeed(
              "jq -n --rawfile acct /tmp/jmap-acct.txt "
              "'{using:[\"urn:ietf:params:jmap:core\",\"urn:ietf:params:jmap:mail\"],"
              "methodCalls:[[\"Mailbox/query\",{accountId:$acct},\"a\"],"
              "[\"Mailbox/get\",{accountId:$acct,"
              "\"#ids\":{resultOf:\"a\",name:\"Mailbox/query\",path:\"/ids\"}},\"b\"]]}' "
              "> /tmp/jmap-mb-req.json"
          )
          machine.succeed(
              "curl -fsS -u user2@example.test:${testPass} "
              "-H 'Content-Type: application/json' "
              "http://127.0.0.1:8080$(cat /tmp/jmap-api-path.txt) -o /tmp/jmap-mailboxes.json "
              "-d @/tmp/jmap-mb-req.json"
          )
          machine.succeed("cat /tmp/jmap-mailboxes.json >&2")
          machine.succeed(
              "jq -e '.methodResponses[] | select(.[0] == \"Mailbox/get\") "
              "| .[1].list[] | select(.role == \"inbox\")' "
              "/tmp/jmap-mailboxes.json > /dev/null"
          )
          machine.succeed(
              "jq -e '.methodResponses[] | select(.[0] == \"Mailbox/get\") "
              "| .[1].list[] | select(.role == \"junk\")' "
              "/tmp/jmap-mailboxes.json > /dev/null"
          )
          machine.succeed(
              "jq -n --rawfile acct /tmp/jmap-acct.txt "
              "'{using:[\"urn:ietf:params:jmap:core\",\"urn:ietf:params:jmap:mail\"],"
              "methodCalls:[[\"Email/query\",{accountId:$acct,"
              "filter:{text:\"needle-576a4565b70f5a4c\"}},\"a\"],"
              "[\"Email/get\",{accountId:$acct,"
              "\"#ids\":{resultOf:\"a\",name:\"Email/query\",path:\"/ids\"},"
              "properties:[\"subject\",\"mailboxIds\"]},\"b\"]]}' "
              "> /tmp/jmap-email-req.json"
          )
          machine.succeed(
              "curl -fsS -u user2@example.test:${testPass} "
              "-H 'Content-Type: application/json' "
              "http://127.0.0.1:8080$(cat /tmp/jmap-api-path.txt) -o /tmp/jmap-email.json "
              "-d @/tmp/jmap-email-req.json"
          )
          machine.succeed("cat /tmp/jmap-email.json >&2")
          machine.succeed(
              "jq -e '.methodResponses[] | select(.[0] == \"Email/get\") "
              "| .[1].list[] | select(.subject == \"e2e-needle\")' "
              "/tmp/jmap-email.json > /dev/null"
          )

      with subtest("restart persistence: INBOX survives, admin stays locked"):
          machine.succeed("systemctl restart stalwart.service")
          machine.wait_for_unit("stalwart.service", timeout=120)
          machine.wait_for_open_port(993, timeout=180)
          machine.succeed("imap-probe needle-576a4565b70f5a4c")
          machine.succeed(
              "curl -fsS http://127.0.0.1:8080/jmap/session "
              "-o /tmp/jmap-anon-session2.json"
              "&& jq -e '.primaryAccounts == {}' /tmp/jmap-anon-session2.json > /dev/null"
          )

      with subtest("no crashes"):
          machine.succeed(
              "journalctl -u stalwart -b 0 > /tmp/journal-full.log "
              + "&& ! grep -qiE 'panic|fatal error' /tmp/journal-full.log"
          )

      with subtest("wrapper rate limiter trips at runtime (M14 evidence)"):
          flood.wait_for_unit("stalwart.service", timeout=180)
          flood.wait_for_open_port(25, timeout=60)
          # 10 rapid connections from one source IP: the wrapper's 3/1m
          # remote_ip bucket must allow exactly 3 banners; the rest are
          # pre-banner hangups (connection gating, ledger (m)). File-based
          # counting - never a producer|grep pipe (pipe-lint rule).
          flood.succeed(
              "rm -f /tmp/flood.log; for i in $(seq 1 10); do "
              "exec 3<>/dev/tcp/127.0.0.1/25; "
              "if IFS= read -r -t 10 line <&3; then echo \"$line\" >> /tmp/flood.log; "
              "else echo HANGUP >> /tmp/flood.log; fi; exec 3<&- 3>&-; done"
          )
          banners = flood.succeed("grep -c '^220' /tmp/flood.log || true").strip()
          hangups = flood.succeed("grep -c HANGUP /tmp/flood.log || true").strip()
          assert banners == "3", "expected exactly 3 banners (rate 3/1m), got " + banners
          assert hangups == "7", "expected 7 pre-banner hangups, got " + hangups
          # The 1m window must NOT refill after 2 s: a fresh connection is
          # still gated. This distinguishes the wrapper's 1m bucket from the
          # upstream default 5/1s burst limiter (which would have refilled).
          flood.succeed("sleep 2")
          flood.succeed(
              "exec 3<>/dev/tcp/127.0.0.1/25; "
              "if IFS= read -r -t 10 line <&3; then echo \"$line\" >> /tmp/flood2.log; "
              "else echo HANGUP >> /tmp/flood2.log; fi; exec 3<&- 3>&-"
          )
          flood.succeed("grep -q HANGUP /tmp/flood2.log")
    '';
  }
