# VM e2e for the continuous deliverability checks
# (services.mail-server.deliverabilityChecks): the systemd probe unit +
# timer, the full check battery against a REAL Stalwart with REAL (local)
# DNS, the round-trip canary, and the negative paths (DNSBL listing,
# canary auth failure) - the classes a green-path-only test cannot see.
#
# DNS shape (the relay-e2e lesson, adapted): the node runs dnsmasq on
# 127.0.0.1 forwarding upstream to the QEMU resolver (10.0.2.3 - REQUIRED:
# 0.16's reload validation resolves SpamPyzor through the system resolver,
# and pyzor is disabled anyway per the relay-e2e transcript lesson), and
# serves a REAL zone for the provisioned mail domain:
#   mail.example.test.   MX 10 mail.example.test.   (points at the host)
#   mail.example.test.   TXT "v=spf1 mx -all"
#   _dmarc.mail.example.test. TXT "v=DMARC1; p=reject"
#   rs._domainkey.mail.example.test. TXT "v=DKIM1; k=rsa; p=testkey"
#   host-record mail.example.test -> 127.0.0.1
#   ptr-record 3.0.0.127.in-addr.arpa -> mail.example.test
# DNSBL mock: address=/2.0.0.127.dnsbl.test/127.0.0.2 - the probe run
# with --ips 127.0.0.2 against zone dnsbl.test sees a LISTING (negative
# subtest); the module-configured IP 127.0.0.3 has no entry = clean.
#
#   1.  Boot: provision applies (canary account declarative); the probe
#       UNIT runs green: report.json overall=pass, every DNS check passes,
#       transport (25 STARTTLS / 587 / 465 / 993) green, tls-verification
#       correctly WARNS (self-signed tier, opportunistic mode - overall
#       still pass), canary round-trip delivers within the SLO and the
#       report shows phase=cleanup.
#   2.  Emission contract: metrics.prom carries probe_success 1, the
#       per-check gauges, the dead-man timestamp; the timer is enabled
#       with the default cadence and Persistent.
#   3.  NEGATIVE dnsbl: manual probe run with the listed IP fails the
#       unit exit contract (non-zero) and the report names the zone.
#   4.  NEGATIVE canary-auth: wrong password fails at phase=send - the
#       send-vs-delivery distinction MONITORING.md section 6 demands.
#   5.  Eval contract (let block below): ExecStart carries the host,
#       LoadCredential for the canary password, NO OnFailure in the
#       wrapper (alert routing is consumer-side doctrine), timer shape.
{pkgs}: let
  common = import ./common.nix;

  testPass = "testpass-x7Kk-9mQw";

  # Eval contract: the wrapper's emission shape, pinned the same way
  # relay-e2e pins its null-credential shape (eval-config.nix, not
  # nixos/default.nix - the pinned nixpkgs rejects a modules argument
  # there).
  probeConfig =
    (import "${pkgs.path}/nixos/lib/eval-config.nix" {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        ../modules/mail-server.nix
        {
          services.mail-server = {
            enable = true;
            hostname = "mail.example.test";
            admin.secretFile = "/run/probe-eval-admin-secret";
            deliverabilityChecks = {
              enable = true;
              canary = {
                address = "canary@mail.example.test";
                secretFile = "/run/probe-eval-canary-secret";
              };
              dnsblZones = ["zen.spamhaus.org"];
            };
          };
          system.stateVersion = "26.05";
        }
      ];
    }).config;

  probeService =
    probeConfig.systemd.services.mail-deliverability-probe;
  probeTimer =
    probeConfig.systemd.timers.mail-deliverability-probe;

  probeAsserts = assert probeService.serviceConfig ? LoadCredential;
  assert builtins.any (line: pkgs.lib.hasInfix "--host" line) probeService.serviceConfig.ExecStart;
  assert pkgs.lib.hasInfix "deliverability-probe" (builtins.head probeService.serviceConfig.ExecStart);
  assert !(probeService.serviceConfig ? OnFailure);
  assert probeService.serviceConfig.DynamicUser;
  assert probeTimer.wantedBy == ["timers.target"];
  assert probeTimer.timerConfig.OnCalendar == "*:0/15";
  assert probeTimer.timerConfig.Persistent;
    probeService.serviceConfig.ExecStart;

  # The probe derivation for manual negative runs inside the VM - the
  # SAME single-source build the unit uses (modules/deliverability-probe-bin.nix).
  probeBin = import ../modules/deliverability-probe-bin.nix {inherit pkgs;};
in
  pkgs.testers.runNixOSTest {
    name = "deliverability-e2e";

    defaults = common.v2CpuPatches;

    nodes.machine = {...}: {
      imports = [
        ../modules/mail-server.nix
        common.testAdminSecretModule
      ];

      services = {
        mail-server = {
          enable = true;
          hostname = "mail.example.test";
          admin.secretFile = "/etc/test-admin-secret";
          deliverabilityChecks = {
            enable = true;
            # SLO kept small so a regression surfaces fast; production
            # keeps the 600 s default.
            sloSeconds = 120;
            dkimSelectors = ["rs"];
            dnsblZones = ["dnsbl.test"];
            # 127.0.0.3 has NO dnsbl address entry = clean; 127.0.0.2 is
            # the listed one used by the negative subtest.
            ipAddresses = ["127.0.0.3"];
            canary = {
              address = "canary@mail.example.test";
              secretFile = "/etc/canary-secret";
            };
          };
        };

        # pyzor off (relay-e2e lesson: its host is unresolvable even with
        # the dnsmasq forward, and reload validation would starve the
        # boot). The node KEEPS the system-resolver path (no Cloudflare
        # DnsResolver pin): it runs a real local resolver, the exact
        # posture deliverabilityChecks assumes on a real host.
        stalwart.provision.singletons.SpamPyzor.enable = false;
        stalwart.provision.objects = {
          # match ["name"]: without it a re-apply value-matches the
          # server-hashed secret and trips the unique-email index (the
          # relay-e2e 2026-10-16 transcript lesson).
          Account = {
            reconcile = true;
            match = ["name"];
            objects.canary = {
              "@type" = "User";
              name = "canary";
              domainId = "#domain";
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

        # The DNS the probe (and 0.16 reload validation) sees: a real
        # local zone for the mail domain + the DNSBL mock + upstream
        # forward (see the header comment for the record inventory).
        dnsmasq = {
          enable = true;
          settings = {
            listen-address = "127.0.0.1";
            bind-interfaces = true;
            no-resolv = true;
            server = ["10.0.2.3"];
            # dnsbl.test is LOCAL too: an unlisted IP must get an
            # authoritative NXDOMAIN from dnsmasq, never a forwarded
            # query into the QEMU resolver's black hole (the first run's
            # dig exit-9 timeout lesson, 2026-10-30).
            local = ["/mail.example.test/" "/dnsbl.test/"];
            host-record = ["mail.example.test,127.0.0.1"];
            mx-host = ["mail.example.test,mail.example.test,10"];
            txt-record = [
              "mail.example.test,v=spf1 mx -all"
              "_dmarc.mail.example.test,v=DMARC1; p=reject"
              "rs._domainkey.mail.example.test,v=DKIM1; k=rsa; p=testpublickey"
            ];
            address = ["/2.0.0.127.dnsbl.test/127.0.0.2"];
            ptr-record = ["3.0.0.127.in-addr.arpa,mail.example.test"];
          };
        };
      };

      environment = {
        etc."canary-secret".text = testPass;
        systemPackages = [
          probeBin
          pkgs.jq
        ];
      };

      networking.nameservers = ["127.0.0.1"];

      virtualisation.memorySize = 2048;
    };

    testScript = ''
      machine.wait_for_unit("stalwart.service", timeout=180)
      # Provision BEFORE any SMTP probe (the 1 h directory negative-cache
      # trap): the canary account must exist before the probe submits.
      machine.wait_for_unit("stalwart-provision.service", timeout=180)
      machine.wait_for_open_port(25, timeout=120)
      machine.wait_for_open_port(993, timeout=120)

      with subtest("probe unit: full battery green incl. round-trip canary"):
        machine.succeed(
          "systemctl start mail-deliverability-probe.service"
          " > /tmp/probe-run.log 2>&1"
        )
        result = machine.succeed(
          "systemctl show -p Result --value mail-deliverability-probe.service"
        ).strip()
        assert result == "success", f"probe unit Result={result}, journal tail: {machine.succeed('journalctl -u mail-deliverability-probe -b 0 --no-pager -n 40')}"
        machine.succeed("jq -e '.overall == \"pass\"' /var/lib/mail-deliverability-probe/report.json")
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dns-mx:mail.example.test\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dns-spf:mail.example.test\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dns-dmarc:mail.example.test\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dns-dkim:rs.mail.example.test\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dnsbl:dnsbl.test:127.0.0.3\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"smtp-starttls-25\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"submission-587\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"submissions-465\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"imaps-993\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        # Self-signed tier + opportunistic mode: the WARN verdict is the
        # doctrine pin - degraded, never failed.
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"tls-verification\") | .status == \"warn\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"canary-roundtrip\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed("jq -e '.canary.phase == \"cleanup\"' /var/lib/mail-deliverability-probe/report.json")
        machine.succeed(
          "jq -e '.canary.elapsed_s < 120' /var/lib/mail-deliverability-probe/report.json"
        )

      with subtest("emission contract: prometheus textfile + timer"):
        metrics = machine.succeed("cat /var/lib/mail-deliverability-probe/metrics.prom")
        assert "mail_deliverability_probe_success 1" in metrics, "probe_success gauge must be 1"
        assert 'mail_deliverability_check_success{check="canary-roundtrip"} 1' in metrics
        assert "mail_deliverability_probe_timestamp_seconds " in metrics, "dead-man timestamp gauge missing"
        assert "mail_deliverability_check_warn{check=\"tls-verification\"} 1" in metrics
        assert (
            'mail_deliverability_dnsbl_listed{zone="dnsbl.test",ip="127.0.0.3"} 0' in metrics
        ), "clean DNSBL gauges must be emitted as 0, not absent"
        machine.succeed("ls /var/lib/mail-deliverability-probe/history/*.json")
        machine.succeed("systemctl is-enabled mail-deliverability-probe.timer")
        timer_calendar = machine.succeed("systemctl show -p OnCalendar --value mail-deliverability-probe.timer")
        assert "*:0/15" in timer_calendar, f"unexpected timer calendar: {timer_calendar}"
        persistent = machine.succeed("systemctl show -p Persistent --value mail-deliverability-probe.timer")
        assert persistent.strip() == "yes", "timer must be Persistent"

      with subtest("negative: DNSBL listing fails the probe and names the zone"):
        machine.fail(
          "deliverability-probe --host mail.example.test"
          " --ports 993 --ips 127.0.0.2 --dnsbl-zones dnsbl.test"
          " --json-out /tmp/dnsbl-report.json > /tmp/dnsbl-probe.log 2>&1"
        )
        machine.succeed(
          "jq -e '.overall == \"fail\"' /tmp/dnsbl-report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dnsbl:dnsbl.test:127.0.0.2\") | .status == \"fail\"' /tmp/dnsbl-report.json"
        )
        dnsbl_log = machine.succeed("cat /tmp/dnsbl-probe.log")
        assert "LISTED" in dnsbl_log, "the listed verdict must be human-greppable in the journal path"

      with subtest("negative: canary auth failure fails at the send phase"):
        machine.succeed("printf wrong-password > /tmp/wrong-canary-secret")
        machine.fail(
          "deliverability-probe --host mail.example.test"
          " --ports 993 --slo-seconds 30"
          " --canary-address canary@mail.example.test"
          " --canary-password-file /tmp/wrong-canary-secret"
          " --json-out /tmp/canary-report.json > /tmp/canary-probe.log 2>&1"
        )
        machine.succeed("jq -e '.canary.phase == \"send\"' /tmp/canary-report.json")
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"canary-roundtrip\") | .status == \"fail\"' /tmp/canary-report.json"
        )

      with subtest("timer cadence: a second run stays green (idempotent)"):
        machine.succeed(
          "systemctl start mail-deliverability-probe.service"
          " > /tmp/probe-run2.log 2>&1"
        )
        result2 = machine.succeed(
          "systemctl show -p Result --value mail-deliverability-probe.service"
        ).strip()
        assert result2 == "success", f"second probe run Result={result2}"
    '';
  }
