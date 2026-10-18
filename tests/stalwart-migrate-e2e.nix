# 0.15 -> 0.16 store-migration e2e, TWO-NODE shape (2026-10-18 repair of
# the 2026-10-17 wedge): the original single-node design switched the VM
# mid-test to a FOREIGN eval-config toplevel; switch-to-configuration
# stopped backdoor.service and the driver lost its channel. Here the 0.15
# world and the 0.16 consumer world are two SEPARATE nodes, and the store
# travels between them through a shared (virtfs) directory - no in-VM
# switch ever runs.
#
# Subtests:
#   1. Phase A on mig015: 0.15.5 serves the management API; domain +
#      lars principal created through it (the dump's data source)
#   2. Handoff: stop, copy the 0.15 store to the share
#   3. mig016 sanity: the consumer shape (httpBind 8082) provisions its
#      own virgin store at boot - the pre-migration baseline
#   4. Store swap: replace mig016's store with the 0.15 store (no
#      marker); `systemctl start stalwart` trips the GUARD - journal
#      names the migration instructions, the binary NEVER ran
#   5. Poison simulation (the pre-guard world): one direct 0.16 boot
#      poisons the LIVE store; the script REFUSES (restore-first)
#   6. --backup-dir migration: dump from the clean share copy,
#      recovery-mode apply, marker, DONE banner
#   7. Post-migration: stalwart + provision units re-run, the plan's
#      8082 listener binds, the 0.15 password authenticates on 0.16
#   8. Restart persistence: the guard passes on the migrated store
{pkgs, ...}: let
  adminSecret = "test-admin-secret";
  larsPassword = "LarsE2EPassword123";
in
  pkgs.testers.runNixOSTest {
    name = "stalwart-migrate-e2e";

    nodes = {
      # PHASE A: the pre-upgrade world - raw module, 0.15.5 binary,
      # provision off (JMAP apply does not exist there), one loopback
      # management listener + the fallback admin for the dump.
      mig015 = {
        # The testers framework pulls nixpkgs' own (0.15-era) stalwart
        # module through the module list; disable it for the vendored one
        # (the wrapper does this for its consumers - here the RAW module
        # is needed for the 0.15.x phase A).
        disabledModules = ["services/mail/stalwart.nix"];
        imports = [
          ../modules/stalwart-module/default.nix
          ../modules/stalwart-module/provision.nix
        ];

        system.stateVersion = "26.05";

        services.stalwart = {
          enable = true;
          package = pkgs.stalwart;
          stateVersion = "26.05";
          provision.enable = false;
          settings = {
            server.listener.api = {
              bind = ["127.0.0.1:18098"];
              protocol = "http";
            };
            authentication.fallback-admin = {
              user = "admin";
              secret = adminSecret;
            };
          };
        };

        environment.systemPackages = [
          pkgs.curl
          pkgs.jq
          pkgs.openssl
        ];

        virtualisation.memorySize = 1536;
        virtualisation.sharedDirectories.share = {
          source = "/tmp/migrate-e2e-share";
          target = "/mnt/share";
        };
      };

      # The 0.16 consumer (the pbx shape from stalwart-bind-e2e: a
      # dedicated httpBind the built-in 8080 cannot shadow) plus the
      # migration script on PATH.
      mig016 = {config, ...}: {
        imports = [../modules/mail-server.nix];

        system.stateVersion = "26.05";
        services.mail-server = {
          enable = true;
          hostname = "migrate.test";
          httpBind = "127.0.0.1:8082";
          admin.secretFile = "/etc/test-admin-secret";
        };
        services.stalwart.provision.singletons = {
          # 0.16 reload-validation reads the system resolver config and
          # fails the apply in DNS-less VMs (see the demo boot race,
          # 2026-10-18) - same pin the other e2e nodes use.
          DnsResolver."@type" = "Cloudflare";
          SpamPyzor.enable = false;
        };

        environment.etc."test-admin-secret" = {
          mode = "0600";
          text = adminSecret;
        };
        environment.systemPackages = [
          # the migration script is per-config; pull it from THIS node's
          # eval so its embedded paths (dataDir, ports, package) match
          config.services.stalwart.migrateFrom015.script
          pkgs.curl
          pkgs.iproute2
          pkgs.jq
        ];

        virtualisation.memorySize = 1536;
        virtualisation.sharedDirectories.share = {
          source = "/tmp/migrate-e2e-share";
          target = "/mnt/share";
        };
      };
    };

    testScript = ''
      import os

      os.makedirs("/tmp/migrate-e2e-share", exist_ok=True)

      start_all()

      mig015.wait_for_unit("stalwart.service", timeout=180)

      with subtest("phase A: 0.15.x serves the management API"):
          mig015.wait_for_open_port(18098, timeout=120)
          mig015.succeed(
              "curl -fsS -u admin:'${adminSecret}' "
              "'http://127.0.0.1:18098/api/principal?page=1&limit=1' -o /dev/null"
          )

      with subtest("phase A: create the domain + principal the migration must carry over"):
          mig015.succeed(
              "curl -fsS -u admin:'${adminSecret}' -H 'Content-Type: application/json' "
              "-X POST http://127.0.0.1:18098/api/principal "
              "-d '{\"type\": \"domain\", \"name\": \"migrate.test\"}' -o /dev/null"
          )
          lars_hash = mig015.succeed(
              "openssl passwd -6 -salt e2esalt '${larsPassword}'"
          ).strip()
          mig015.succeed(
              "curl -fsS -u admin:'${adminSecret}' -H 'Content-Type: application/json' "
              "-X POST http://127.0.0.1:18098/api/principal "
              "-d '{\"type\": \"individual\", \"name\": \"lars@migrate.test\", "
              "\"roles\": [\"user\"], \"secrets\": [\"" + lars_hash + "\"], "
              "\"emails\": [\"lars@migrate.test\", \"@migrate.test\"]}' -o /dev/null"
          )
          mig015.succeed(
              "curl -fsS -u admin:'${adminSecret}' "
              "'http://127.0.0.1:18098/api/principal?page=1&limit=10&types=individual' "
              "-o /tmp/principals.json"
          )
          mig015.succeed("jq -e '.data.total == 1' /tmp/principals.json > /dev/null")

      with subtest("handoff: the 0.15 store lands on the shared directory"):
          mig015.succeed("systemctl stop stalwart.service")
          mig015.succeed("cp -a /var/lib/stalwart /mnt/share/pre016-store")
          mig015.succeed("test -d /mnt/share/pre016-store/db")

      with subtest("mig016 baseline: the consumer shape provisions its own virgin store"):
          mig016.wait_for_unit("stalwart-provision.service", timeout=300)
          mig016.wait_for_open_port(8082, timeout=120)

      with subtest("the 0.15 store swap trips the guard, never the binary"):
          mig016.succeed(
              "systemctl stop stalwart-provision.service 2>/dev/null || true; "
              "systemctl stop stalwart.service"
          )
          # Replace the WHOLE dataDir: the baseline boot self-marked the
          # virgin store, and a leftover marker would wrongly pass the
          # guard on top of 0.15 data (the poison class).
          mig016.succeed(
              "rm -rf /var/lib/stalwart && cp -a /mnt/share/pre016-store /var/lib/stalwart"
          )
          # The guard fails ExecStartPre, the unit cycles under its
          # restart policy - never let that block the driver.
          mig016.execute("systemctl start stalwart.service > /dev/null 2>&1 || true")
          mig016.succeed(
              "for i in $(seq 1 180); do "
              "journalctl -u stalwart --no-pager -o cat 2>/dev/null > /tmp/guard-poll.log || true; "
              "grep -q 'refusing to start - a pre-0.16 store' /tmp/guard-poll.log && exit 0; "
              "sleep 1; done; exit 1"
          )
          mig016.succeed("journalctl -u stalwart --no-pager -o cat > /tmp/guard.log")
          mig016.succeed("cat /tmp/guard.log >&2")
          mig016.succeed("grep -q 'stalwart-migrate-from-015' /tmp/guard.log")
          # THE point of the guard: the binary never ran, so the store was
          # never poisoned by the UNIT (exit-101 panic class unreachable).
          mig016.fail("grep -q 'Migration aborted' /tmp/guard.log")

      with subtest("poison simulation: one direct 0.16 boot, then the script refuses"):
          # Settle the restart cycling first so the store is at rest.
          mig016.succeed(
              "systemctl stop stalwart.service 2>/dev/null || true; "
              "systemctl reset-failed stalwart.service 2>/dev/null || true"
          )
          mig016.succeed(
              "echo '{\"@type\": \"RocksDb\", \"path\": \"/var/lib/stalwart/db\"}' > /tmp/poison.json"
          )
          mig016.execute(
              "${pkgs.stalwart_0_16}/bin/stalwart --config=/tmp/poison.json "
              "> /tmp/poison-boot.log 2>&1 & echo $! > /tmp/poison.pid"
          )
          mig016.succeed("sleep 3; kill -9 $(cat /tmp/poison.pid) 2>/dev/null || true")
          mig016.succeed("cat /tmp/poison-boot.log >&2")
          mig016.fail("stalwart-migrate-from-015 > /tmp/refuse.log 2>&1")
          mig016.succeed("cat /tmp/refuse.log >&2")
          mig016.succeed("grep -q 'POISONED for 0.15.5' /tmp/refuse.log")

      with subtest("--backup-dir migration: dump from the copy, recover the live store"):
          mig016.succeed(
              "stalwart-migrate-from-015 --backup-dir /mnt/share/pre016-store "
              "2>&1 | tee /tmp/migrate.log"
          )
          mig016.succeed("cat /tmp/migrate.log >&2")
          mig016.succeed("grep -q '\\[DONE\\] migration complete' /tmp/migrate.log")
          mig016.succeed("test -f /var/lib/stalwart/v016-store-migrated")

      with subtest("post-migration: the 0.15 password authenticates on 0.16"):
          # The provision oneshot has not run since the store swap: start
          # BOTH units (the script's own next-steps banner) and let the
          # apply + restartAndVerify path bind the plan's 8082 listener.
          mig016.succeed("systemctl start stalwart.service")
          mig016.succeed("systemctl start stalwart-provision.service")
          mig016.wait_for_unit("stalwart-provision.service", timeout=300)
          mig016.wait_for_open_port(8082, timeout=240)
          mig016.wait_for_open_port(25, timeout=120)
          # 0.16 session path (probe-verified 2026-10-18: the 0.15
          # /.well-known/jmap document fetch is now a 307).
          mig016.succeed(
              "curl -fsS -u 'lars@migrate.test:${larsPassword}' "
              "http://127.0.0.1:8082/jmap/session -o /tmp/jmap-lars.json"
          )
          mig016.succeed("cat /tmp/jmap-lars.json >&2")
          mig016.succeed("jq -e '.username == \"lars@migrate.test\"' /tmp/jmap-lars.json > /dev/null")

      with subtest("restart persistence: the guard passes on the migrated store"):
          # The guard refused LOUDLY earlier in this same (volatile-journal)
          # boot - scope the no-refusal check to since-this-restart only.
          mig016.succeed("date '+%Y-%m-%d %H:%M:%S' > /tmp/restart-ts")
          mig016.succeed("systemctl restart stalwart.service")
          mig016.wait_for_open_port(8082, timeout=120)
          mig016.fail("systemctl is-failed stalwart.service")
          mig016.succeed(
              "journalctl -u stalwart --no-pager -o cat --since \"$(cat /tmp/restart-ts)\" > /tmp/restart.log; "
              "! grep -q 'refusing to start' /tmp/restart.log"
          )
    '';
  }
