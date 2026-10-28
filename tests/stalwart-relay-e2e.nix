# Two-node VM test for the smarthost relay path (services.mail-server.relay).
#
# WHY two nodes: Stalwart REFUSES to relay to loopback addresses (SSRF guard,
# "host resolves loopback address" - live spike, README ledger), so a
# single-node VM test can never exercise the smarthost path. Here node
# `smtp` runs Stalwart with `relay.address = "relay"` (a DNS hostname, the
# only accepted form) and node `relay` runs Mailpit as the catch-all
# smarthost.
#
# 0.16 REWORK (2026-10-16): the relay emits a MtaRoute (Relay variant) + a
# MtaOutboundStrategy route Expression (is_local_domain -> 'local', else ->
# relay NAME) instead of the 0.15 queue.route/queue.strategy.route TOML,
# and the sender account is DECLARATIVE (stalwart-provision plan) - the
# /api/principal provisioning calls are gone with the REST API. The relay
# secret still rides systemd LoadCredential -> File-secret filePath.
#
#   1. Relay generates MtaRoute "smarthost" (Relay) + the outbound strategy
#      expression with the default shape (is_local_domain -> 'local', else
#      -> relay)
#   2. Submission on 587 for a NON-local domain lands in Mailpit (relay path)
#   3. Submission for a LOCAL domain still delivers locally (strategy did not
#      break the local queue)
#
# DNS: Stalwart resolves relay targets via A lookup with its system resolver,
# which IGNORES /etc/hosts - so the smtp node runs dnsmasq on 127.0.0.1 (with
# networking.nameservers pointing at it). dnsmasq serves the test driver's
# /etc/hosts entries, bridging "relay" to the Mailpit node's IP.
#
# SASL: Mailpit runs with --smtp-auth-file (it then REQUIRES successful
# AUTH), and the wrapper sets relay.username + relay.secretFile - every
# relayed needle below is behavioral proof the SASL credentials worked
# (wrong creds = 535 = queue retry = the needle never shows up in Mailpit).
# The username==null emission shape is pinned by the eval assertions in the
# let block (this VM runs the SASL shape).
{pkgs}: let
  common = import ./common.nix;

  # 0.16 account secrets are PLAINTEXT at provision time (apply hashes
  # server-side); strength is enforced (zxcvbn), hence the length.
  testPass = "testpass-x7Kk-9mQw";
  relayNeedle = "relay-needle-9f2c1b";
  bounceNeedle = "bounce-needle-4d81ea";

  # The username==null relay emission shape (import-and-eval pattern from
  # dmarc-eval): no auth fields on the generated MtaRoute, and no credential
  # registered for it. The wrapper asserts username/secretFile pair up, so
  # this is the only legal no-credential shape. NOTE: eval-config.nix, NOT
  # nixos/default.nix - the latter only accepts {configuration, system,
  # specialArgs} in the pinned nixpkgs and rejects a modules argument.
  nullRelayConfig =
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/mail-server.nix
        {
          services.mail-server = {
            enable = true;
            hostname = "mail.example.test";
            admin.secretFile = "/run/relay-eval-admin-secret";
            relay = {
              address = "relay.example.test";
              port = 587;
              tlsImplicit = true;
            };
          };
          system.stateVersion = "26.05";
        }
      ];
    }).config;

  nullRelayRoute = nullRelayConfig.services.stalwart.provision.objects.MtaRoute.objects."smarthost";
  nullRelayAsserts = assert nullRelayRoute ? address;
  assert nullRelayRoute."@type" == "Relay";
  assert !(nullRelayRoute ? authUsername);
  assert !(nullRelayRoute ? authSecret);
  assert !(nullRelayConfig.services.stalwart.credentials ? mail-server-relay);
  assert nullRelayConfig.services.stalwart.provision.singletons.MtaOutboundStrategy.route."else" == "'smarthost'";
    nullRelayRoute.address;
in
  pkgs.testers.runNixOSTest {
    name = "stalwart-relay-e2e";

    # Test-level v2 cpu for EVERY node (structurally unforgottable,
    # tests/common.nix v2CpuPatches; the relay/Mailpit node gets it
    # too - a harmless feature superset).
    defaults = common.v2CpuPatches;

    nodes = {
      smtp = {...}: {
        imports = [
          ../modules/mail-server.nix
          common.testAdminSecretModule
        ];

        services = {
          mail-server = {
            enable = true;
            hostname = "mail.example.test";
            admin.secretFile = "/etc/test-admin-secret";
            # Queue-state observability for the bounce subtest: exposes
            # /metrics/prometheus on the (loopback) HTTP listener.
            metrics.enable = true;
            relay = {
              address = "relay";
              port = 1025;
              # SASL smarthost (Mailpit enforces AUTH via --smtp-auth-file,
              # see the relay node): exercises the username + secretFile
              # emission path with the 0.16 File-secret filePath - the
              # same mechanism SystemNix's contract test asserts with sops.
              username = "relayuser";
              secretFile = "/etc/relay-secret";
              tlsImplicit = false;
            };
          };

          # The wrapper owns the mail.example.test domain; the SENDER needs
          # the example.test domain + account, provisioned declaratively
          # (the pre-0.16 /api/principal calls are gone with the REST API).
          # 0.16's reload-validation rejects the default-enabled pyzor host
          # in this DNS-less VM ("Invalid address: failed to lookup address
          # information", transcript 2026-10-16) - same network-dependence
          # lesson as the 0.15 era, now enforced at apply+reload time.
          stalwart.provision.singletons.SpamPyzor.enable = false;
          stalwart.provision.objects = {
            Domain.objects.example-test = {
              name = "example.test";
              dkimManagement."@type" = "Manual";
              dnsManagement."@type" = "Manual";
              certificateManagement."@type" = "Manual";
            };
            # match ["name"] is REQUIRED: without it apply matches accounts
            # BY VALUE, and the stored secret is server-hashed after the
            # first apply - a second apply then sees a "changed" object and
            # tries a fresh create, hitting the unique-email index
            # ("primaryKeyViolation | Properties: email", transcript
            # 2026-10-16).
            Account = {
              reconcile = true;
              match = ["name"];
              objects.user1 = {
                # 0.16 schema: User.name is the LOCAL PART; the primary
                # address synthesizes as name@<Domain(domainId).name>
                # (= user1@example.test via the #example-test domain
                # object above). There is no separate emailAddress field
                # (stalwart-e2e apply transcript 2026-10-16).
                "@type" = "User";
                name = "user1";
                domainId = "#example-test";
                roles."@type" = "User";
                credentials = [
                  {
                    "@type" = "Password";
                    secret = testPass;
                  }
                ];
              };
            };
          };

          # Bridge DNS for the relay hostname: stalwart's resolver is a
          # pure-DNS path that IGNORES /etc/hosts, so dnsmasq serves the
          # test driver's node names while FORWARDING everything else to
          # the QEMU user-net resolver (10.0.2.3 -> host DNS). The upstream
          # forward is REQUIRED, not cosmetic: 0.16's reload validation
          # resolves the SpamPyzor address through the system resolver, and
          # the earlier black-hole upstream (192.0.2.1) failed the whole
          # apply with "Invalid address: failed to lookup address
          # information" (transcript 2026-10-16) - listeners never spawned
          # and every subsequent subtest starved.
          dnsmasq = {
            enable = true;
            settings = {
              listen-address = "127.0.0.1";
              bind-interfaces = true;
              # resolv.conf points at dnsmasq itself - never read it back
              no-resolv = true;
              server = ["10.0.2.3"];
            };
          };
        };

        # Test-only credential files (real hosts: sops-rendered paths);
        # the fallback-admin password file rides the import above
        # (tests/common.nix).
        environment = {
          etc."relay-secret".text = "relaypass";
          systemPackages = [
            pkgs.swaks
            pkgs.curl
            pkgs.dnsutils
            pkgs.openssl
          ];
        };

        networking.nameservers = ["127.0.0.1"];

        virtualisation.memorySize = 2048;
      };

      relay = {
        # SASL-enforced smarthost: with the auth file set, Mailpit rejects
        # every session that did not AUTH successfully.
        # Freeform keys go through lib.cli.toCommandLineGNU VERBATIM - flag
        # names must be the dashed spellings, quoted as attr keys. camelCase
        # or underscored keys render unknown flags (smtpAuthFile produced
        # "--smtpAuthFile", mailpit 1.31.0 exits 1 - usage-dump verified
        # 2026-09-16). The auth file holds PLAIN user:pass lines; with no
        # TLS on the test listener Mailpit refuses to START unless insecure
        # AUTH is allowed ("authentication requires STARTTLS or TLS
        # encryption", binary probe 2026-09-16). Stalwart reaches this hop
        # with relay.tlsImplicit = false, so the pair below matches.
        environment.etc."mailpit-smtp-auth".text = "relayuser:relaypass";
        services.mailpit.instances.catchall = {
          smtp = "0.0.0.0:1025";
          listen = "0.0.0.0:8025";
          max = 0;
          "smtp-auth-file" = "/etc/mailpit-smtp-auth";
          "smtp-auth-allow-insecure" = true;
        };
        networking.firewall.allowedTCPPorts = [
          1025
          8025
        ];
      };
    };

    testScript = ''
      start_all()

      # Force the username==null emission eval asserts from the let block
      # (referencing the result guarantees evaluation).
      smtp.log("null-relay route address: ${nullRelayAsserts}")

      smtp.wait_for_unit("stalwart.service", timeout=180)
      # 587 is a PROVISIONED listener (unlike stalwart-e2e's built-in
      # 25/8080): it binds only after the boot-time stalwart-provision
      # apply + ExecStartPost restart chain, which measured ~70 s under
      # host load (run-2 transcript 2026-10-26: apply at 69.5 s, the 60 s
      # port window expired first - a timing flake, not a bind failure).
      smtp.wait_for_open_port(587, timeout=180)
      relay.wait_for_open_port(1025, timeout=120)
      relay.wait_for_open_port(8025, timeout=60)

      # The declarative plan (domain + sender account + relay objects)
      # applies via stalwart-provision; `systemctl restart` BLOCKS until
      # the oneshot finishes so a failure surfaces here, not as mystery
      # 535s downstream. Journal dumped for the transcript.
      smtp.succeed("systemctl restart stalwart-provision.service")
      smtp.succeed(
          "journalctl -u stalwart-provision -b 0 -o cat > /tmp/provision.log"
      )
      smtp.succeed("cat /tmp/provision.log >&2")

      # dnsmasq must be answering before we provision: the relay A lookup for
      # "relay" rides on it.
      # Assertions are file-based, never `producer | grep -q`: the test
      # shell runs with pipefail, and grep -q exiting at first match EPIPEs
      # the producer - the metrics curl in stalwart-e2e returned exit 23
      # (write error) on a MATCHING payload once (2026-09-15). Under pipefail
      # the negated form is worse: `! producer | grep -q` phantom-greens.
      smtp.wait_until_succeeds(
          "dig +short relay @127.0.0.1 > /tmp/dig-relay.txt && { cat /tmp/dig-relay.txt >&2; grep -q . /tmp/dig-relay.txt; }",
          timeout=120,
      )

      # The self-signed certificate is generated asynchronously at first start
      # and can take >80s in an entropy-poor VM - wait for a real TLS handshake
      # so the STARTTLS submissions below cannot flake on cert timing.
      smtp.wait_until_succeeds(
          "echo | openssl s_client -connect 127.0.0.1:993 2>/dev/null > /tmp/tls-greeting.txt "
          + "&& { cat /tmp/tls-greeting.txt >&2; grep -q 'OK' /tmp/tls-greeting.txt; }",
          timeout=180,
      )

      with subtest("relay path: SASL-authed non-local submission lands in Mailpit"):
          # Mailpit rejects unauthenticated sessions (smtpAuthFile), so the
          # needle below is proof the wrapper's SASL credentials survived
          # the whole path: secretFile -> systemd credential -> File-secret
          # filePath -> MtaRoute (Relay) -> SMTP AUTH.
          smtp.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to stranger@remote.example "
              "--header 'Subject: relay-e2e' --body '${relayNeedle}' "
              "> /tmp/swaks-relay.log 2>&1"
          )
          smtp.succeed("cat /tmp/swaks-relay.log >&2")
          smtp.succeed("! grep -q '<\\*\\*' /tmp/swaks-relay.log")

          # Queue -> strategy -> relay -> mailpit is async; poll the Mailpit
          # REST API for the needle.
          smtp.wait_until_succeeds(
              "curl -fsS http://relay:8025/api/v1/messages -o /tmp/relay-messages.json "
              + "&& grep -q '${relayNeedle}' /tmp/relay-messages.json",
              timeout=180,
          )

      with subtest("local path: strategy still routes local domains locally"):
          # nobody@example.test does NOT exist - local routing must answer with
          # a 5xx recipient lookup failure (NOT a silent relay to Mailpit, and
          # NOT an MX timeout). swaks exits non-zero on the 5xx, so run it with
          # "|| true" and assert on the transcript (swaks marks error-response
          # lines with "<**", success with "<-") - same pattern as the
          # single-node E2E.
          smtp.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to nobody@example.test "
              "--header 'Subject: local-e2e' --body 'local-needle-3a7d' "
              "> /tmp/swaks-local.log 2>&1 || true"
          )
          smtp.succeed("cat /tmp/swaks-local.log >&2")
          # Observed transcript (VM, 2026-09-15): the 550 arrives with the
          # "<~*" marker (swaks' timeout-receive variant), not "<-"/"<**" -
          # assert the marker set actually observed, never the expected one.
          smtp.succeed(
              "grep -E '(<-|<\\*\\*|<~\\*) *5[0-9][0-9]' /tmp/swaks-local.log"
          )
          smtp.succeed(
              "curl -fsS http://relay:8025/api/v1/messages -o /tmp/relay-messages2.json "
              + "&& ! grep -q 'local-needle-3a7d' /tmp/relay-messages2.json"
          )

      with subtest("bounce path: refusing smarthost defers, then drains on recovery"):
          # Kill the smarthost (TCP refusal = the production outage shape).
          # 0.16 accepts the message at SMTP (queue semantics) and must hold
          # it deferred - never drop, never bounce while retryable. The
          # assertions ride the Prometheus queue series + Mailpit only
          # (journal greps are forbidden here: 0.16 is silent on this class).
          relay.systemctl("stop mailpit-catchall.service")
          smtp.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password '${testPass}' "
              "--from user1@example.test --to stranger@remote.example "
              "--header 'Subject: bounce-e2e' --body '${bounceNeedle}' "
              "> /tmp/swaks-bounce.log 2>&1"
          )
          smtp.succeed("cat /tmp/swaks-bounce.log >&2")
          smtp.succeed("! grep -q '<\\*\\*' /tmp/swaks-bounce.log")

          # Transcript-first: dump the FULL metrics body into the test log
          # so the queue series names are transcribable from THIS run (same
          # doctrine as stalwart-e2e's metrics subtest), then assert the
          # deferred state on the observed series (file-based, never piped).
          # 0.16 exposes NO queue-depth gauge - only counters (2026-10-26
          # transcript: queue_authenticated_message_queued 2,
          # queue_rescheduled 1 at +5 s with the smarthost down). The
          # reschedule counter IS the deferred state: it ticks when the
          # first delivery attempt fails and the queue schedules a retry
          # (the 0.15 'Message rescheduled for delivery' journal line is
          # gone in 0.16 - the metric carries its HELP text verbatim).
          smtp.succeed(
              "curl -fsS http://127.0.0.1:8080/metrics/prometheus "
              "-o /tmp/metrics-bounce.prom && cat /tmp/metrics-bounce.prom >&2"
          )
          smtp.wait_until_succeeds(
              "curl -fsS http://127.0.0.1:8080/metrics/prometheus "
              "-o /tmp/metrics-bounce.prom "
              "&& grep -qE '^queue_rescheduled [1-9]' /tmp/metrics-bounce.prom",
              timeout=90,
          )

          # Smarthost recovery: the deferred message must DRAIN via the
          # queue retry into Mailpit. Observed first-retry drain ~120 s
          # (green run-3 transcript 2026-10-26) - the 300 s bound is 2.5x
          # headroom; if this flakes, read THIS subtest's log (the retry
          # window and the metrics dump are both in it) before touching
          # the timeout.
          relay.systemctl("start mailpit-catchall.service")
          relay.wait_for_open_port(1025, timeout=60)
          smtp.wait_until_succeeds(
              "curl -fsS http://relay:8025/api/v1/messages "
              "-o /tmp/relay-messages3.json "
              "&& grep -q '${bounceNeedle}' /tmp/relay-messages3.json",
              timeout=300,
          )

      with subtest("no crashes"):
          smtp.succeed(
              "journalctl -u stalwart -b 0 > /tmp/journal-full.log && { "
              "cat /tmp/journal-full.log >&2; "
              "if grep -qiE 'panic|fatal error' /tmp/journal-full.log; then exit 1; fi; }"
          )
    '';
  }
