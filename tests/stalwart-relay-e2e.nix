# Two-node VM test for the smarthost relay path (services.mail-server.relay).
#
# WHY two nodes: Stalwart REFUSES to relay to loopback addresses (SSRF guard,
# "host resolves loopback address" - live spike, README ledger), so a
# single-node VM test can never exercise the smarthost path. Here node
# `smtp` runs Stalwart with `relay.address = "relay"` (a DNS hostname, the
# only accepted form) and node `relay` runs Mailpit as the catch-all
# smarthost.
#
#   1. Relay generates queue.route."smarthost" + queue.strategy.route with
#      the default-shape IfBlock (is_local_domain -> 'local', else -> relay)
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
  testHash = "$6$StalwartTestSalt$gagC41V16GV6khfXMiraIyZLKuYDgSyRzVfM0TaSFNMRqkLewQ5d/b9Ns0uc1Rr4DWD15BxHHzh2XaC4ZAS97.";
  relayNeedle = "relay-needle-9f2c1b";

  # The username==null relay emission shape (import-and-eval pattern from
  # dmarc-eval): no auth block on the generated route, and no credential
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

  nullRelayAsserts = assert nullRelayConfig.services.stalwart.settings.queue.route ? "smarthost";
  assert !(nullRelayConfig.services.stalwart.settings.queue.route."smarthost" ? auth);
  assert !(nullRelayConfig.services.stalwart.credentials ? mail-server-relay);
    nullRelayConfig.services.stalwart.settings.queue.route."smarthost".address;
in
  pkgs.testers.runNixOSTest {
    name = "stalwart-relay-e2e";

    nodes = {
      smtp = {...}: {
        imports = [../modules/mail-server.nix];

        services = {
          mail-server = {
            enable = true;
            hostname = "mail.example.test";
            relay = {
              address = "relay";
              port = 1025;
              # SASL smarthost (Mailpit enforces AUTH via --smtp-auth-file,
              # see the relay node): exercises the username + secretFile
              # emission path with the %{file:...}% credential macro - the
              # same mechanism SystemNix's contract test asserts with sops.
              username = "relayuser";
              secretFile = "/etc/relay-secret";
              tlsImplicit = false;
            };
          };

          stalwart.settings.authentication.fallback-admin = {
            user = "admin";
            secret = "test-admin-secret";
          };

          # Bridge DNS for the relay hostname: stalwart's system resolver reads
          # /etc/resolv.conf only; dnsmasq answers from /etc/hosts (where the
          # test driver injects the node names) - networking.nameservers below
          # points the resolver at this dnsmasq.
          dnsmasq = {
            enable = true;
            settings = {
              listen-address = "127.0.0.1";
              bind-interfaces = true;
              # resolv.conf points at dnsmasq itself - never read it back
              no-resolv = true;
              server = ["192.0.2.1"];
            };
          };
        };

        # Test-only credential file (real hosts: sops-rendered path).
        environment.etc."relay-secret".text = "relaypass";

        networking.nameservers = ["127.0.0.1"];

        environment.systemPackages = [
          pkgs.swaks
          pkgs.curl
          pkgs.dnsutils
          pkgs.openssl
        ];

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
      smtp.wait_for_open_port(587, timeout=60)
      relay.wait_for_open_port(1025, timeout=120)
      relay.wait_for_open_port(8025, timeout=60)

      # dnsmasq must be answering before we provision: the relay A lookup for
      # "relay" rides on it.
      # Assertions are file-based, never `producer | grep -q`: the test
      # shell runs with pipefail, and grep -q exiting at first match EPIPEs
      # the producer - the metrics curl in stalwart-e2e returned exit 23
      # (write error) on a MATCHING payload once (2026-09-15). Under pipefail
      # the negated form is worse: `! producer | grep -q` phantom-greens.
      smtp.wait_until_succeeds(
          "dig +short relay @127.0.0.1 > /tmp/dig-relay.txt && grep -q . /tmp/dig-relay.txt",
          timeout=120,
      )

      # The self-signed certificate is generated asynchronously at first start
      # and can take >80s in an entropy-poor VM - wait for a real TLS handshake
      # so the STARTTLS submissions below cannot flake on cert timing.
      smtp.wait_until_succeeds(
          "echo | openssl s_client -connect 127.0.0.1:993 2>/dev/null > /tmp/tls-greeting.txt "
          + "&& grep -q 'OK' /tmp/tls-greeting.txt",
          timeout=180,
      )

      with subtest("provision domain and sender account before any traffic"):
          # Same negative-cache discipline as the single-node E2E: provision
          # BEFORE any SMTP touches the domain.
          smtp.succeed(
              "curl -fsS -u admin:test-admin-secret -H 'Content-Type: application/json' "
              "-X POST http://127.0.0.1:8080/api/principal "
              "-d '{\"type\": \"domain\", \"name\": \"example.test\"}'"
          )
          smtp.succeed(
              "curl -fsS -u admin:test-admin-secret -H 'Content-Type: application/json' "
              "-X POST http://127.0.0.1:8080/api/principal "
              "-d '{\"type\": \"individual\", \"name\": \"user1@example.test\", "
              "\"emails\": [\"user1@example.test\"], \"roles\": [\"user\"], "
              "\"secrets\": [\"${testHash}\"]}'"
          )

      with subtest("relay path: SASL-authed non-local submission lands in Mailpit"):
          # Mailpit rejects unauthenticated sessions (smtpAuthFile), so the
          # needle below is proof the wrapper's SASL credentials survived
          # the whole path: secretFile -> systemd credential -> %{file:...}%
          # macro -> queue.route."smarthost".auth -> SMTP AUTH.
          smtp.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
              "--auth-user user1@example.test --auth-password testpass "
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
              "--auth-user user1@example.test --auth-password testpass "
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

      with subtest("no crashes"):
          smtp.succeed(
              "journalctl -u stalwart -b 0 > /tmp/journal-full.log "
              + "&& ! grep -qiE 'panic|fatal error' /tmp/journal-full.log"
          )
    '';
  }
