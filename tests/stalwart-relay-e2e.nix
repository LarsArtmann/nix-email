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
{
  pkgs,
}:
let
  testHash = "$6$StalwartTestSalt$gagC41V16GV6khfXMiraIyZLKuYDgSyRzVfM0TaSFNMRqkLewQ5d/b9Ns0uc1Rr4DWD15BxHHzh2XaC4ZAS97.";
  relayNeedle = "relay-needle-9f2c1b";
in
pkgs.testers.runNixOSTest {
  name = "stalwart-relay-e2e";

  nodes = {
    smtp =
      { lib, ... }:
      {
        imports = [ ../modules/mail-server.nix ];

        services.mail-server = {
          enable = true;
          hostname = "mail.example.test";
          relay = {
            address = "relay";
            port = 1025;
            # Unauthenticated smarthost (Mailpit): exercises the username ==
            # null emission path. Resend on a real host sets username +
            # secretFile; the %{file:...}% macro mechanism is the same one
            # the fallback-admin path already exercises.
            tlsImplicit = false;
          };
        };

        services.stalwart.settings.authentication.fallback-admin = {
          user = "admin";
          secret = "test-admin-secret";
        };

        # Bridge DNS for the relay hostname: stalwart's system resolver reads
        # /etc/resolv.conf only; dnsmasq answers from /etc/hosts (where the
        # test driver injects the node names).
        networking.nameservers = [ "127.0.0.1" ];
        services.dnsmasq = {
          enable = true;
          settings = {
            listen-address = "127.0.0.1";
            bind-interfaces = true;
            # resolv.conf points at dnsmasq itself - never read it back
            no-resolv = true;
            server = [ "192.0.2.1" ];
          };
        };

        environment.systemPackages = [
          pkgs.swaks
          pkgs.curl
          pkgs.dnsutils
          pkgs.openssl
        ];

        virtualisation.memorySize = 2048;
      };

    relay = {
      services.mailpit.instances.catchall = {
        smtp = "0.0.0.0:1025";
        listen = "0.0.0.0:8025";
        max = 0;
      };
      networking.firewall.allowedTCPPorts = [
        1025
        8025
      ];
    };
  };

  testScript = ''
    start_all()

    smtp.wait_for_unit("stalwart.service", timeout=180)
    smtp.wait_for_open_port(587, timeout=60)
    relay.wait_for_open_port(1025, timeout=120)
    relay.wait_for_open_port(8025, timeout=60)

    # dnsmasq must be answering before we provision: the relay A lookup for
    # "relay" rides on it.
    smtp.wait_until_succeeds("dig +short relay @127.0.0.1 | grep -q .", timeout=120)

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

    with subtest("relay path: non-local submission lands in Mailpit"):
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
            "curl -fsS http://relay:8025/api/v1/messages | grep -q '${relayNeedle}'",
            timeout=180,
        )

    with subtest("local path: strategy still routes local domains locally"):
        smtp.succeed(
            "swaks --timeout 120 --server 127.0.0.1:587 --tls --auth PLAIN "
            "--auth-user user1@example.test --auth-password testpass "
            "--from user1@example.test --to nobody@example.test "
            "--header 'Subject: local-e2e' --body 'local-needle-3a7d' "
            "> /tmp/swaks-local.log 2>&1"
        )
        smtp.succeed("cat /tmp/swaks-local.log >&2")
        # nobody@example.test does NOT exist - local routing must answer with
        # a 5xx recipient lookup failure (NOT a silent relay to Mailpit, and
        # NOT an MX timeout).
        smtp.succeed("grep -E '(<-|<\\*\\*) *5[0-9][0-9]' /tmp/swaks-local.log")
        smtp.succeed(
            "! curl -fsS http://relay:8025/api/v1/messages | grep -q 'local-needle-3a7d'"
        )

    with subtest("no crashes"):
        smtp.succeed("! journalctl -u stalwart -b 0 | grep -qiE 'panic|fatal error'")
  '';
}
