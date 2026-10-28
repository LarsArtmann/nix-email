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
# Both endpoints are accepted only when their unauthenticated JMAP session
# identifies Stalwart (2026-10-23 pbx burn: the webphone owned the built-in
# 8080 and received the plan from a blind `curl --fail` probe).
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
#   6. Guard (second node `guarded`): a FOREIGN HTTP service owns the built-in
#      8080 and the configured bind cannot come up on a virgin store -> the
#      unit refuses to apply through the stranger, names it in the journal,
#      and fails at its (shortened) start timeout with no plan sent anywhere
{pkgs, ...}: let
  common = import ./common.nix;
  adminSecret = common.testAdminSecret;
  # SAN-carrying self-signed pair (binary-proven 2026-10-17: the manual
  # Certificate upsert needs the SAN match key, and modern TLS validation
  # rejects CN-only certs on reload). Long validity is LOAD-BEARING: the
  # runCommand output is store-cached (inputs never change -> never
  # rebuilds), so a short -days is a time bomb - the -days 2 pair expired
  # 2026-10-19, stalwart silently fell back to its rcgen runtime cert,
  # and imaps-cert verification failed with a served-vs-pinned mismatch
  # (bind-tls debug transcript 2026-10-20).
  testCert =
    pkgs.runCommand "stalwart-bind-e2e-cert" {
      nativeBuildInputs = [pkgs.openssl];
    } ''
      openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem \
        -days 3650 -nodes -subj "/CN=bind.test" \
        -addext "subjectAltName=DNS:bind.test"
      mkdir $out; cp key.pem cert.pem $out/
    '';
  # Implicit-TLS probes (stdlib, not `openssl s_client`: its stdin/pipe
  # shapes are flaky around server-first greetings - two probe
  # iterations, 2026-10-17). The `cafile=` argument trusts testCert and
  # `server_hostname="bind.test"` forces the hostname half of validation,
  # so the probe succeeds only when the SERVED SAN matches the
  # `DNS:bind.test` value the Certificate upsert matches on - that link is
  # what makes the probe a SAN assertion, not just a handshake.
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
      imports = [
        ../modules/mail-server.nix
        common.dnslessVmPatches
        common.testAdminSecretModule
        # 0.16.26 needs x86-64-v2 (tests/common.nix v2CpuPatches)
        common.v2CpuPatches
      ];

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
          certificate.manual = {
            certFile = "${testCert}/cert.pem";
            keyFile = "${testCert}/key.pem";
          };
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
        # DNS-less-VM reload-validation patches (DnsResolver Cloudflare +
        # pyzor off) and the fallback-admin password file ride the
        # imports above (tests/common.nix).
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

    # The 2026-10-23 pbx shape: something OTHER than Stalwart owns the
    # built-in bootstrap port (there the webphone on 127.0.0.1:8080). The
    # provision unit must refuse to apply the plan through a responder that
    # is not Stalwart's JMAP server - the blind `curl --fail` probe sent the
    # whole plan to the webphone (schema refresh 404, red switch). A short
    # unit timeout keeps the refusal leg cheap; the journal warning fires at
    # ~10s, well inside it.
    nodes.guarded = {
      lib,
      pkgs,
      ...
    }: {
      imports = [
        ../modules/mail-server.nix
        common.dnslessVmPatches
        common.testAdminSecretModule
        # 0.16.26 needs x86-64-v2 (tests/common.nix v2CpuPatches)
        common.v2CpuPatches
      ];

      system.stateVersion = "26.05";

      services = {
        mail-server = {
          enable = true;
          hostname = "guard.test";
          httpBind = "127.0.0.1:8082";
          admin.secretFile = "/etc/test-admin-secret";
          certificate.mode = "manual";
          certificate.manual = {
            certFile = "${testCert}/cert.pem";
            keyFile = "${testCert}/key.pem";
          };
        };
        stalwart.provision.singletons = {
          DnsResolver."@type" = "Cloudflare";
          SpamPyzor.enable = false;
        };
      };

      # Foreign occupant FIRST, exactly like the webphone on the pbx host
      # (empirically: python's 0.0.0.0:8080 also blocks stalwart's
      # dual-stack built-in bind, and stalwart stays up on its remaining
      # listeners). It serves 200 on `/` (so a blind probe would accept
      # it) and 404 on /jmap/session (so the identity check refuses it).
      systemd.services.fake-builtin-http = {
        wantedBy = ["multi-user.target"];
        before = ["stalwart.service" "stalwart-provision.service"];
        serviceConfig = {
          ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8080 --bind 0.0.0.0";
          Restart = "always";
        };
      };

      systemd.services.stalwart-provision.serviceConfig.TimeoutStartSec =
        lib.mkForce "20s";

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
              "journalctl -u stalwart -b 0 -o cat > /tmp/journal-config.log && { "
              "cat /tmp/journal-config.log >&2; "
              "if grep -q 'Configuration build error' /tmp/journal-config.log; then exit 1; fi; }"
          )

      with subtest("guard: a foreign built-in-port responder never gets the plan"):
          # The 2026-10-23 pbx burn, replayed: the built-in port is owned by
          # another HTTP service and the configured endpoint cannot bind on a
          # virgin store. The old blind probe applied the whole plan through
          # that stranger; the identity check must keep waiting instead and
          # the unit must fail (bounded by TimeoutStartSec, shortened here).
          guarded.wait_for_unit("fake-builtin-http.service")
          guarded.wait_for_unit("stalwart.service", timeout=180)
          guarded.wait_until_succeeds(
              "systemctl is-failed stalwart-provision.service", timeout=120
          )
          guarded.succeed(
              "journalctl -u stalwart-provision -b 0 -o cat > /tmp/guard.log"
          )
          guarded.succeed("cat /tmp/guard.log >&2")
          # The refusal is NAMED, with the foreign responder's URL ...
          guarded.succeed(
              "grep -q 'a non-Stalwart HTTP service answers on http://127.0.0.1:8080' /tmp/guard.log"
          )
          # ... and the plan was never sent anywhere (no endpoint line).
          guarded.fail(
              "grep -q 'answering at http://127.0.0.1:8080' /tmp/guard.log"
          )
          guarded.fail(
              "grep -q 'answering at http://127.0.0.1:8082' /tmp/guard.log"
          )
    '';
  }
