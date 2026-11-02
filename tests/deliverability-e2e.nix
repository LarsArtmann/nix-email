# VM e2e for the continuous deliverability checks
# (services.mail-server.deliverabilityChecks): the systemd probe unit +
# timer, the full check battery against a REAL Stalwart with REAL (local)
# DNS, the round-trip canary, and the negative paths (DNSBL listing,
# canary auth failure) - the classes a green-path-only test cannot see.
#
# DNS shape (the relay-e2e lesson, adapted): the node runs dnsmasq on
# 127.0.0.1 serving a REAL zone for the provisioned mail domain. The
# `server = ["10.0.2.3"]` entry below is a DEAD END in the test-driver
# network (the QEMU user-net resolver is instantly unreachable there -
# dig exit 9 in ~60 ms; docs/probes/2026-10-31-dnsmasq-forward/), NOT a
# working upstream - it is kept because nothing here needs it: pyzor is
# disabled (below), the probe's DNS inventory is the local zone + the
# DNSBL mock, and the `local = [...]` lines force authoritative local
# answers. Scope split: single-VM contexts DO have live slirp DNS at
# 10.0.2.3; the multi-node test-driver network does not.
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
#       transport (25 STARTTLS / 587 / 465 / 993) green, cert expiry on
#       the 993 AND the 25/587 STARTTLS legs green, the metrics endpoint
#       serves exposition format, tls-verification correctly WARNS
#       (self-signed tier, opportunistic mode - overall still pass), the
#       canary round-trip AND the unauthenticated :25 inbound canary
#       deliver to INBOX within the SLO (phase=cleanup, folder=INBOX).
#   2.  Emission contract: metrics.prom carries probe_success 1, the
#       per-check gauges, the dead-man timestamp; the timer is enabled
#       with the default cadence and Persistent.
#   3.  NEGATIVE dnsbl: manual probe run with the listed IP fails the
#       unit exit contract (non-zero) and the report names the zone.
#   4.  NEGATIVE canary-auth: wrong password fails at phase=send - the
#       send-vs-delivery distinction MONITORING.md section 6 demands.
#   5.  dmarc-sink freshness: a FRESH sink passes the check; a STALE one
#       fails the CHECK but not the run (warning severity must not page
#       at dead-MX level - the overall_status severity contract).
#   6.  Eval contract (let block below): ExecStart carries the host,
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

  # lib.toList: the wrapper sets ExecStart as ONE string (not a list) -
  # builtins.any/head on a string throw "expected a list but found a
  # string with context" (the 2026-10-30 buildflow chase).
  probeExecStart = pkgs.lib.toList probeService.serviceConfig.ExecStart;

  probeAsserts = assert probeService.serviceConfig ? LoadCredential;
  assert builtins.any (line: pkgs.lib.hasInfix "--host" line) probeExecStart;
  assert pkgs.lib.hasInfix "deliverability-probe" (builtins.head probeExecStart);
  assert !(probeService.serviceConfig ? OnFailure);
  assert probeService.serviceConfig.DynamicUser;
  assert probeTimer.wantedBy == ["timers.target"];
  assert probeTimer.timerConfig.OnCalendar == "*:0/15";
  assert probeTimer.timerConfig.Persistent; "eval-contract-ok";

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
            # The world-facing inbound path rides the battery: :25
            # unauthenticated submission -> INBOX (the recipient EXISTS
            # from provisioning - the 1 h negative-cache trap is why the
            # account is provisioned before any probe runs).
            canaryInbound = true;
            metricsUrl = "http://127.0.0.1:8080/metrics/prometheus";
          };
          metrics.enable = true;
        };

        # pyzor off (relay-e2e lesson: its host is unresolvable even with
        # the dnsmasq forward, and reload validation would starve the
        # boot). The node KEEPS the system-resolver path (no Cloudflare
        # DnsResolver pin): it runs a real local resolver, the exact
        # posture deliverabilityChecks assumes on a real host.
        stalwart.provision.singletons = {
          SpamPyzor.enable = false;
          # Stalwart's OWN resolver is NOT the system resolver by default:
          # inbound sender-auth (SPF/iprev) post-DATA lookups went to a
          # black-holed external resolver in the driver network and the
          # inbound canary died at its socket timeout (take-4 transcript:
          # EHLO/MAIL/RCPT/DATA-354 all 0.0 s, post-DATA reply > 25 s).
          # This node RUNS a real resolver (dnsmasq with the local zone);
          # point stalwart at it so its lookups are answered locally.
          DnsResolver = {
            "@type" = "Custom";
            servers = [{address = "127.0.0.1";}];
          };
        };
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
            # dig exit-9 timeout lesson, 2026-10-30). Same lesson for
            # the REVERSE zone (2026-11-02, the inbound-canary leg):
            # stalwart's inbound RCPT policy resolves the connecting
            # client's PTR; 127.in-addr.arpa forwarded upstream = the
            # dead 10.0.2.3 = a ~15 s stall that eats the probe's socket
            # timeout at RCPT time (first inbound-canary run, send-phase
            # disconnect). Every name the probe or the server resolves
            # mid-dialog must be answered LOCALLY.
            local = [
              "/mail.example.test/"
              "/dnsbl.test/"
              "/127.in-addr.arpa/"
            ];
            host-record = ["mail.example.test,127.0.0.1"];
            mx-host = ["mail.example.test,mail.example.test,10"];
            txt-record = [
              "mail.example.test,v=spf1 mx -all"
              "_dmarc.mail.example.test,v=DMARC1; p=reject"
              "rs._domainkey.mail.example.test,v=DKIM1; k=rsa; p=testpublickey"
            ];
            address = ["/2.0.0.127.dnsbl.test/127.0.0.2"];
            ptr-record = [
              "3.0.0.127.in-addr.arpa,mail.example.test"
              # the loopback client's own reverse (the probe connects to
              # the host-record 127.0.0.1): answer it authoritatively
              "1.0.0.127.in-addr.arpa,mail.example.test"
            ];
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
      # Force the eval contract (relay-e2e's smtp.log pattern): the let-
      # block asserts only fire when consumed - an unconsumed binding is
      # dead code AND a deadnix finding. The tail is a plain marker: the
      # ExecStart string itself carries derivation CONTEXT and cannot be
      # interpolated into testScript ("expected a list but found a string
      # with context", buildflow run 2026-10-30).
      machine.log("deliverability probe eval contract: ${probeAsserts}")
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
        # Cert expiry now also covers the STARTTLS legs (openssl
        # -starttls smtp): 25 + 587 carry their own warning-severity
        # checks alongside the implicit-TLS 993/465 ones.
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"tls-cert-expiry-25\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"tls-cert-expiry-587\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"metrics-endpoint\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
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
        machine.succeed("jq -e '.canary.folder == \"INBOX\"' /var/lib/mail-deliverability-probe/report.json")

      with subtest("inbound canary: :25 unauthenticated delivers to INBOX"):
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"canary-inbound\") | .status == \"pass\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.canary_inbound.phase == \"cleanup\"' /var/lib/mail-deliverability-probe/report.json"
        )
        machine.succeed(
          "jq -e '.canary_inbound.folder == \"INBOX\"' /var/lib/mail-deliverability-probe/report.json"
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
        # `systemctl show -p OnCalendar` renders EMPTY for timer units -
        # assert on the verbatim unit file instead (systemctl cat).
        timer_unit = machine.succeed("systemctl cat mail-deliverability-probe.timer")
        assert "OnCalendar=*:0/15" in timer_unit, f"unexpected timer calendar: {timer_unit}"
        assert "Persistent=true" in timer_unit, "timer must be Persistent"

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

      with subtest("dmarc-sink freshness: stale fails the check, not the run"):
        machine.succeed("mkdir -p /tmp/dmarc-sink && touch /tmp/dmarc-sink/report.json")
        machine.succeed(
          "deliverability-probe --host mail.example.test --no-dns --ports 993"
          " --dmarc-sink-dir /tmp/dmarc-sink"
          " --json-out /tmp/sink-fresh.json > /tmp/sink-fresh.log 2>&1"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dmarc-sink-freshness\") | .status == \"pass\"' /tmp/sink-fresh.json"
        )
        machine.succeed("touch -d '3 days ago' /tmp/dmarc-sink/report.json")
        # Warning severity: the CHECK fails (gauge + JSON) but overall
        # stays pass - a stalled DMARC pipeline must not page at dead-MX
        # level (the overall_status severity contract).
        machine.succeed(
          "deliverability-probe --host mail.example.test --no-dns --ports 993"
          " --dmarc-sink-dir /tmp/dmarc-sink"
          " --json-out /tmp/sink-stale.json > /tmp/sink-stale.log 2>&1"
        )
        machine.succeed(
          "jq -e '.checks[] | select(.name == \"dmarc-sink-freshness\") | .status == \"fail\"' /tmp/sink-stale.json"
        )
        machine.succeed("jq -e '.overall == \"pass\"' /tmp/sink-stale.json")

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
