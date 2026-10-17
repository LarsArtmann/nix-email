# Dedicated-bind bootstrap e2e (nix-email#4): the management httpBind on a
# NON-default port (127.0.0.1:8082 - the pbx-artmann consumer shape) against
# a VIRGIN store. 0.16 silently ignores static server.listener keys, so
# before the first plan apply only the BUILT-IN default set is up (smtp 25 +
# http 8080); the dedicated bind can only come up through the provision
# unit's bootstrap (probe cfg.url -> fallback to the built-in 127.0.0.1:8080
# -> apply -> restart stalwart -> verify cfg.url). stalwart-e2e.nix can
# never catch this class: its httpBind is the default 8080 that coincides
# with the built-in listener, so the pre-fix deadlock was untestable there
# by construction (the pbx 43-min wedge, bounded to a visible 3-min failure
# 2026-10-17).
#
# Subtests:
#   1. Bootstrap: 8082 opens, the provision journal names the built-in 8080
#      as the endpoint the apply ran against, and the unit is not failed
#   2. The plan REPLACED the built-in listener set: 8080 gone, 8082 + 25 bound
#   3. The dedicated bind serves the REAL management API (fallback-admin
#      JMAP session authenticates on 8082; anonymous session is the empty
#      shell)
#   4. Restart persistence: a plain `systemctl restart stalwart` brings 8082
#      back without the provision unit re-running (the STORED listener binds
#      - every-boot posture for consumers)
#   5. Journal hygiene: no configuration build errors
{pkgs, ...}: let
  adminSecret = "test-admin-secret";
  # SAN-carrying self-signed pair (binary-proven 2026-10-17: the manual
  # Certificate upsert needs the SAN match key, and modern TLS validation
  # rejects CN-only certs on reload).
  testCert = pkgs.runCommand "stalwart-bind-e2e-cert" {
    nativeBuildInputs = [pkgs.openssl];
  } ''
    openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
      -days 2 -nodes -subj "/CN=bind.test" \
      -addext "subjectAltName=DNS:bind.test"
    mkdir $out; cp key.pem cert.pem $out/
  '';
  # Implicit-TLS probes (stdlib, not `openssl s_client`: its stdin/pipe
  # shapes are flaky around server-first greetings - two probe
  # iterations, 2026-10-17).
  tlsProbe = pkgs.writeText "stalwart-bind-e2e-tls-probe.py" ''
    import socket
    import ssl
    import sys

    mode = sys.argv[1]
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    if mode == "pop3":
        with socket.create_connection(("127.0.0.1", 995), 5) as raw:
            with ctx.wrap_socket(raw) as tls:
                banner = tls.recv(64)
        assert b"Stalwart POP3" in banner, banner
        print(banner.decode(errors="replace").strip())
    elif mode == "imaps-cert":
        # getpeercert() returns {} under CERT_NONE, and module-level
        # get_server_certificate() verifies against system CAs (a
        # self-signed test cert fails) - so load the test cert as its own
        # CA and read the decoded subject instead.
        ctx2 = ssl.create_default_context(
            cafile=sys.argv[2]
        )
        with socket.create_connection(("127.0.0.1", 993), 5) as raw:
            with ctx2.wrap_socket(raw, server_hostname="bind.test") as tls:
                cert = tls.getpeercert()
        cn = [
            v
            for rdn in cert.get("subject", ())
            for k, v in rdn
            if k == "commonName"
        ]
        assert "bind.test" in cn, cert
        print("imaps serves the manual cert (bind.test)")
    else:
        raise SystemExit(f"unknown mode {mode}")
  '';
in
  pkgs.testers.runNixOSTest {
    name = "stalwart-bind-e2e";

    nodes.machine = {...}: {
      imports = [../modules/mail-server.nix];

      system.stateVersion = "26.05";

      services = {
        mail-server = {
          enable = true;
          hostname = "bind.test";
          # THE subject under test: a dedicated non-default management
          # bind, exactly the consumer shape that wedged before the fix.
          httpBind = "127.0.0.1:8082";
          admin.secretFile = "/etc/test-admin-secret";
          # Manual certificate mode: pins the subjectAlternativeNames
          # match-key fix (upsert with matchOn null dies "match property
          # missing" on 0.16.26 - the self-signed default never renders a
          # Certificate object, so only this mode can catch it).
          certificate.mode = "manual";
          certificate.manual.certFile = "${testCert}/cert.pem";
          certificate.manual.keyFile = "${testCert}/key.pem";
        };
        # STATIC LISTENER EXTRA (the documented 0.15 extension surface):
        # 0.16 ignores config-file server.listener keys, so the wrapper
        # must merge the extra into the provision plan's reconcile set -
        # before the merge fix this listener was silently dropped.
        stalwart.settings.server.listener.pop3 = {
          bind = ["[::]:995"];
          protocol = "pop3";
          tls.implicit = true;
        };
        # Same DNS-less-VM reload-validation patches as stalwart-e2e (the
        # 0.16 reload validation reads the resolver config and fails the
        # whole apply without a nameserver; the pyzor default host is
        # unresolvable here).
        stalwart.provision.singletons = {
          DnsResolver."@type" = "Cloudflare";
          SpamPyzor.enable = false;
        };
      };

      environment.etc."test-admin-secret" = {
        mode = "0600";
        text = adminSecret;
      };

      environment.systemPackages = [
        pkgs.curl
        pkgs.iproute2
        pkgs.jq
        pkgs.openssl
        pkgs.python3
      ];

      virtualisation.memorySize = 1024;
    };

    testScript = ''
      start_all()

      machine.wait_for_unit("stalwart.service", timeout=180)

      with subtest("bootstrap: the plan applies through the built-in endpoint"):
          # The whole fix in one wait: on this virgin store only the built-in
          # 8080 is up at boot; 8082 can only open after the unit fell back
          # to 8080, applied the NetworkListener plan, and restarted
          # stalwart. The unit's own TimeoutStartSec (3min) bounds the wait
          # inside the unit; this timeout bounds the driver side.
          machine.wait_for_open_port(8082, timeout=240)

          # Transcript-first (AGENTS.md): dump the apply journal and pin the
          # endpoint line - it proves the fallback path actually ran (the
          # configured endpoint 8082 cannot answer on a virgin store).
          machine.succeed(
              "journalctl -u stalwart-provision -b 0 -o cat > /tmp/provision.log"
          )
          machine.succeed("cat /tmp/provision.log >&2")
          machine.succeed(
              "grep -q 'answering at http://127.0.0.1:8080' /tmp/provision.log"
          )
          machine.fail("systemctl is-failed stalwart-provision.service")

      with subtest("the plan replaced the built-in listener set"):
          machine.succeed("ss -tlnp > /tmp/ss-post-provision")
          machine.succeed("cat /tmp/ss-post-provision >&2")
          machine.succeed("! grep -q ':8080 ' /tmp/ss-post-provision")
          machine.succeed("grep -q ':8082 ' /tmp/ss-post-provision")
          machine.succeed("grep -q ':25 ' /tmp/ss-post-provision")

      with subtest("manual certificate + static-listener extra ride the plan"):
          # The Certificate upsert (SAN match key) succeeded...
          machine.succeed(
              "grep -q 'upserted Certificate' /tmp/provision.log"
          )
          # ...and the merged pop3 listener is bound with implicit TLS
          # answering a real POP3 greeting.
          machine.wait_for_open_port(995, timeout=60)
          machine.succeed("python3 ${tlsProbe} pop3 >&2")
          # The imaps listener serves the MANUAL certificate (subject
          # CN=bind.test), proving the File-typed PEM refs resolved.
          machine.succeed(
              "python3 ${tlsProbe} imaps-cert ${testCert}/cert.pem >&2"
          )

      with subtest("management: the dedicated bind serves the real API"):
          machine.succeed(
              "curl -fsSL -u admin:'${adminSecret}' "
              "http://127.0.0.1:8082/.well-known/jmap -o /tmp/jmap-admin-session.json"
          )
          machine.succeed("cat /tmp/jmap-admin-session.json >&2")
          machine.succeed("grep -q 'capabilities' /tmp/jmap-admin-session.json")
          machine.succeed("grep -q '\"username\":\"admin\"' /tmp/jmap-admin-session.json")
          machine.succeed(
              "curl -fsS http://127.0.0.1:8082/jmap/session -o /tmp/jmap-anon-session.json"
          )
          machine.succeed(
              "jq -e '.primaryAccounts == {}' /tmp/jmap-anon-session.json > /dev/null"
          )

      with subtest("restart: the stored listener binds without provision re-running"):
          machine.succeed("systemctl restart stalwart.service")
          machine.wait_for_open_port(8082, timeout=120)
          machine.wait_for_open_port(25, timeout=60)

      with subtest("journal: no configuration build errors"):
          machine.succeed(
              "journalctl -u stalwart -b 0 -o cat > /tmp/journal-config.log"
              "&& ! grep -q 'Configuration build error' /tmp/journal-config.log"
          )
    '';
  }
