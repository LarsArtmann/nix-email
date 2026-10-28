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
#   6b. --backup-dir-FREE migration: a CLEAN live store dumps in place
#      (the happy path) and the script makes its own .v015-premigrate
#      copy; the store is then reset to re-run the poisoned-path legs
#   7. Post-migration: stalwart + provision units re-run, the plan's
#      8082 listener binds, the 0.15 password authenticates on 0.16
#   8. Restart persistence: the guard passes on the migrated store
{pkgs, ...}: let
  common = import ./common.nix;
  adminSecret = common.testAdminSecret;
  larsPassword = "LarsE2EPassword123";
in
  pkgs.testers.runNixOSTest {
    name = "stalwart-migrate-e2e";

    # Test-level v2 cpu for EVERY node (structurally unforgottable,
    # tests/common.nix v2CpuPatches). mig015 (0.15.5) gets it too -
    # a harmless feature superset, it does not REQUIRE v2.
    defaults = common.v2CpuPatches;

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
            # A REALISTIC 0.15 install shape: webadmin on the default
            # 8080 PLUS the dedicated api listener. Post-migration, the
            # converted store binds these listener objects - the 0.16
            # provision unit's probe (cfg.url, then the built-in 8080)
            # can then reach the migrated server and apply the consumer
            # plan. A store whose ONLY management listener was
            # nonstandard leaves provision unreachable (run-5 lesson,
            # 2026-10-18) - documented in the README migration section.
            server.listener.api = {
              bind = ["127.0.0.1:18098"];
              protocol = "http";
            };
            server.listener.webadmin = {
              bind = ["127.0.0.1:8080"];
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
      };

      # The 0.16 consumer (the pbx shape from stalwart-bind-e2e: a
      # dedicated httpBind the built-in 8080 cannot shadow) plus the
      # migration script on PATH.
      mig016 = {config, ...}: {
        imports = [
          ../modules/mail-server.nix
          common.dnslessVmPatches
          common.testAdminSecretModule
        ];

        system.stateVersion = "26.05";
        services.mail-server = {
          enable = true;
          hostname = "migrate.test";
          httpBind = "127.0.0.1:8082";
          admin.secretFile = "/etc/test-admin-secret";
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
      };
    };

    testScript = ''
      # The store travels between nodes through the testers framework's
      # built-in WRITABLE shared directory (/tmp/shared, virtfs to the
      # driver's xchg dir) - no custom share, no in-VM switch.
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
          # tar, not cp -a: virtfs rejects chown ("failed to preserve
          # ownership ... Invalid argument") - ownership and modes travel
          # INSIDE the archive and are restored at extraction time.
          mig015.succeed("tar -C /var/lib -cf /tmp/shared/pre016-store.tar stalwart")
          mig015.succeed("test -s /tmp/shared/pre016-store.tar")

      with subtest("mig016 baseline: the consumer shape provisions its own virgin store"):
          # A COMPLETED oneshot reads "inactive" - wait_for_unit races it;
          # house pattern: stalwart.service + port + the unit's Result.
          mig016.wait_for_unit("stalwart.service", timeout=180)
          mig016.wait_for_open_port(8082, timeout=240)
          mig016.succeed('test "$(systemctl show -p Result --value stalwart-provision.service)" = success')

      with subtest("the 0.15 store swap trips the guard, never the binary"):
          mig016.succeed(
              "systemctl stop stalwart-provision.service 2>/dev/null || true; "
              "systemctl stop stalwart.service"
          )
          # Replace the WHOLE dataDir: the baseline boot self-marked the
          # virgin store, and a leftover marker would wrongly pass the
          # guard on top of 0.15 data (the poison class).
          mig016.succeed(
              "rm -rf /var/lib/stalwart && tar -C /var/lib -xf /tmp/shared/pre016-store.tar"
          )
          # The guard fails ExecStartPre, the unit cycles under its
          # restart policy - never let that block the driver.
          mig016.execute("systemctl start stalwart.service > /dev/null 2>&1 || true")
          mig016.succeed(
              "for i in $(seq 1 180); do "
              "journalctl -u stalwart --no-pager -o cat 2>/dev/null > /tmp/guard-poll.log || true; "
              "grep -q 'refusing to start - a pre-0.16 store' /tmp/guard-poll.log && exit 0; "
              "sleep 1; done; cat /tmp/guard-poll.log >&2; exit 1"
          )
          mig016.succeed("journalctl -u stalwart --no-pager -o cat > /tmp/guard.log")
          mig016.succeed("cat /tmp/guard.log >&2")
          mig016.succeed("grep -q 'stalwart-migrate-from-015' /tmp/guard.log")
          # THE point of the guard: the binary never ran, so the store was
          # never poisoned by the UNIT (exit-101 panic class unreachable).
          mig016.fail("grep -q 'Migration aborted' /tmp/guard.log")

      with subtest("no-backup-dir migration: a CLEAN live store migrates in place"):
          # The other leg always passes --backup-dir (the poisoned-store
          # shape). This covers the happy path: a pre-0.16 store that no
          # 0.16 binary ever touched is dumped from the LIVE directory, and
          # the script takes its own .v015-premigrate copy before touching
          # anything.
          mig016.succeed(
              "stalwart-migrate-from-015 2>&1 | tee /tmp/migrate-clean.log"
          )
          mig016.succeed("cat /tmp/migrate-clean.log >&2")
          mig016.succeed("grep -q '\\[DONE\\] migration complete' /tmp/migrate-clean.log")
          mig016.succeed("test -f /var/lib/stalwart/v016-store-migrated")
          # The pre-migration copy is the rollback artifact: it must exist
          # and contain the RocksDB dir, because a later 0.16 poisoning of
          # the live store is exactly what it protects against.
          mig016.succeed("test -d /var/lib/stalwart.v015-premigrate/db")
          mig016.succeed("ls -la /var/lib/stalwart/db /var/lib/stalwart.v015-premigrate/db >&2")
          # Reset to a pristine pre-0.16 store for the poisoned-path legs
          # below. The re-extract also drops the migration marker, which the
          # guard and the script both key on.
          mig016.succeed(
              "rm -rf /var/lib/stalwart /var/lib/stalwart.v015-premigrate && "
              "tar -C /var/lib -xf /tmp/shared/pre016-store.tar"
          )

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
          # Extract a LOCAL pre-0.16 copy for the dump leg (never run the
          # 0.15.5 probe against the virtfs share itself - RocksDB over
          # 9p is neither fast nor trustworthy).
          mig016.succeed("mkdir -p /tmp/pre016-copy")
          mig016.succeed("tar -C /tmp/pre016-copy -xf /tmp/shared/pre016-store.tar")
          mig016.succeed(
              "stalwart-migrate-from-015 --backup-dir /tmp/pre016-copy/stalwart "
              "2>&1 | tee /tmp/migrate.log"
          )
          mig016.succeed("cat /tmp/migrate.log >&2")
          mig016.succeed("grep -q '\\[DONE\\] migration complete' /tmp/migrate.log")
          mig016.succeed("test -f /var/lib/stalwart/v016-store-migrated")
          # Artifacts on stdout: the datastore path inside convert's
          # config.json decides WHICH store recovery mode wiped - the
          # post-migration boot panic ("multi-step process", run 6,
          # 2026-10-18) means the live store was not the one migrated.
          mig016.succeed("cat /var/lib/stalwart/migration-v016/config.json >&2")
          mig016.succeed("cat /var/lib/stalwart/migration-v016/recovery.log >&2")
          mig016.succeed("ls -la /var/lib/stalwart/db /var/lib/stalwart.v015-premigrate/db >&2")

      with subtest("post-migration: the 0.15 password authenticates on 0.16"):
          # The provision oneshot has not run since the store swap: start
          # BOTH units (the script's own next-steps banner) and let the
          # apply + restartAndVerify path bind the plan's 8082 listener.
          mig016.succeed("systemctl start stalwart.service")
          mig016.succeed("systemctl start stalwart-provision.service")
          mig016.wait_for_unit("stalwart.service", timeout=180)
          mig016.wait_for_open_port(8082, timeout=240)
          mig016.succeed('test "$(systemctl show -p Result --value stalwart-provision.service)" = success')
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
              "journalctl -u stalwart --no-pager -o cat --since \"$(cat /tmp/restart-ts)\" > /tmp/restart.log && { "
              "cat /tmp/restart.log >&2; "
              "if grep -q 'refusing to start' /tmp/restart.log; then exit 1; fi; }"
          )
    '';
  }
