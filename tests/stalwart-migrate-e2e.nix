# KNOWN-BROKEN, NOT REGISTERED as a flake check (TODO row "migrate-e2e
# repair", diagnosed 2026-10-17 over two full local runs): the mid-test
# `switch-to-configuration test` targets a toplevel from a FOREIGN
# eval-config, and switch-to-configuration STOPS backdoor.service (its
# content differs from the testers-framework-rendered unit) - the test
# driver loses its channel and the run wedges at the guard subtest.
# Repair shape: two nodes (0.15.5 phase-A node seeds a store the 0.16
# node boots with, via a shared directory) instead of an in-VM switch.
#
# 0.15 -> 0.16 store-migration e2e (the 2026-10-17 pbx outage class,
# end to end): a VM is booted on the RAW module with a 0.15.x package
# and a real principal in the store, then switched to the 0.16 wrapper
# (the exact consumer shape: httpBind 8082). The pre-0.16 store must
# FAIL the unit through the GUARD (never through the binary's exit-101
# panic - every panic poisons the store for 0.15.x, destroying the dump
# path), the migration script must refuse a poisoned live store, and
# the --backup-dir recovery must dump from a pre-0.16 copy, migrate the
# LIVE store, and leave the 0.15 password authenticating on 0.16 with
# the account id (and therefore the mail linkage) preserved.
#
# Subtests:
#   1. Phase A: 0.15.x serves the management API; domain + principal
#      created through it (the dump's data source)
#   2. The 0.16 switch trips the GUARD: journal names the migration
#      instructions; the binary NEVER ran (no panic line)
#   3. Poison simulation (the pre-guard world): one direct 0.16 boot
#      writes the webui settings key; the script REFUSES with the
#      restore-first message
#   4. --backup-dir migration: dump from the clean copy, recovery-mode
#      apply against the poisoned LIVE store, marker, DONE banner
#   5. Post-migration boot: unit active, provision plan binds 8082,
#      the 0.15 password authenticates on 0.16 (JMAP session as lars)
#   6. Restart persistence: the guard passes on the migrated store
{pkgs, ...}: let
  adminSecret = "test-admin-secret";
  larsPassword = "LarsE2EPassword123";

  # The 0.16-era config the VM switches to mid-test (the consumer
  # shape from stalwart-bind-e2e, plus the migration script on PATH).
  config016 = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = "x86_64-linux";
    modules = [
      # the same VM base the testers framework gives nodes.machine, so
      # the switched-to toplevel applies cleanly inside it
      (pkgs.path + "/nixos/modules/virtualisation/qemu-vm.nix")
      ../modules/mail-server.nix
      (
        {config, ...}: {
          system.stateVersion = "26.05";
          services.mail-server = {
            enable = true;
            hostname = "migrate.test";
            httpBind = "127.0.0.1:8082";
            admin.secretFile = "/etc/test-admin-secret";
          };
          services.stalwart.provision.singletons = {
            DnsResolver."@type" = "Cloudflare";
            SpamPyzor.enable = false;
          };
          environment.etc."test-admin-secret" = {
            mode = "0600";
            text = adminSecret;
          };
          environment.systemPackages = [
            config.services.stalwart.migrateFrom015.script
            pkgs.curl
            pkgs.iproute2
            pkgs.jq
          ];
        }
      )
    ];
  };
in
  pkgs.testers.runNixOSTest {
    name = "stalwart-migrate-e2e";

    nodes.machine = {
      # The testers framework pulls nixpkgs' own (0.15-era) stalwart
      # module through the module list; disable it for the vendored one
      # (the wrapper does this for its consumers - here the RAW module
      # is needed for the 0.15.x phase A).
      disabledModules = ["services/mail/stalwart.nix"];
      imports = [../modules/stalwart-module/default.nix ../modules/stalwart-module/provision.nix];

      system.stateVersion = "26.05";

      # PHASE A: the pre-upgrade world - raw module, 0.15.x binary,
      # provision off (JMAP apply does not exist there), one loopback
      # management listener + the fallback admin for the dump.
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
    };

    testScript = ''
      start_all()

      machine.wait_for_unit("stalwart.service", timeout=180)

      with subtest("phase A: 0.15.x serves the management API"):
          machine.wait_for_open_port(18098, timeout=120)
          machine.succeed(
              "curl -fsS -u admin:'${adminSecret}' "
              "'http://127.0.0.1:18098/api/principal?page=1&limit=1' -o /dev/null"
          )

      lars_hash = None
      with subtest("phase A: create the domain + principal the migration must carry over"):
          machine.succeed(
              "curl -fsS -u admin:'${adminSecret}' -H 'Content-Type: application/json' "
              "-X POST http://127.0.0.1:18098/api/principal "
              "-d '{\"type\": \"domain\", \"name\": \"migrate.test\"}' -o /dev/null"
          )
          lars_hash = machine.succeed(
              "openssl passwd -6 -salt e2esalt '${larsPassword}'"
          ).strip()
          machine.succeed(
              "curl -fsS -u admin:'${adminSecret}' -H 'Content-Type: application/json' "
              "-X POST http://127.0.0.1:18098/api/principal "
              "-d '{\"type\": \"individual\", \"name\": \"lars@migrate.test\", "
              "\"roles\": [\"user\"], \"secrets\": [\"" + lars_hash + "\"], "
              "\"emails\": [\"lars@migrate.test\", \"@migrate.test\"]}' -o /dev/null"
          )
          machine.succeed(
              "curl -fsS -u admin:'${adminSecret}' "
              "'http://127.0.0.1:18098/api/principal?page=1&limit=10&types=individual' "
              "| jq -e '.data.total == 1' > /dev/null"
          )

      with subtest("the 0.16 switch trips the guard, never the binary"):
          # Keep a pristine copy first - it is the --backup-dir source later.
          machine.succeed("cp -a /var/lib/stalwart /tmp/pre016-copy")
          machine.succeed("systemctl stop stalwart.service")
          # Background the switch: the guard makes stalwart restart-cycle
          # (fail-fast prestart + RestartSec), and under the default start
          # limit that job takes minutes to settle - switch-to-configuration
          # would block on it far past the test budget. The guard message in
          # the journal is the completion signal that matters.
          machine.execute(
              "${config016.config.system.build.toplevel}/bin/switch-to-configuration test"
              " > /tmp/switch.log 2>&1 &"
          )
          machine.succeed(
              "for i in $(seq 1 180); do "
              "journalctl -u stalwart --no-pager -o cat 2>/dev/null > /tmp/guard-poll.log || true; "
              "grep -q 'refusing to start - a pre-0.16 store' /tmp/guard-poll.log && exit 0; "
              "sleep 1; done; exit 1"
          )
          machine.succeed("journalctl -u stalwart --no-pager -o cat > /tmp/guard.log")
          machine.succeed("cat /tmp/guard.log >&2")
          machine.succeed("grep -q 'stalwart-migrate-from-015' /tmp/guard.log")
          # THE point of the guard: the binary never ran, so the store was
          # never poisoned (exit-101 panic class unreachable).
          machine.fail("grep -q 'Migration aborted' /tmp/guard.log")

      with subtest("poison simulation: one direct 0.16 boot, then the script refuses"):
          machine.succeed(
              "echo '{\"@type\": \"RocksDb\", \"path\": \"/var/lib/stalwart/db\"}' > /tmp/poison.json"
          )
          machine.execute(
              "${pkgs.stalwart_0_16}/bin/stalwart --config=/tmp/poison.json "
              "> /tmp/poison-boot.log 2>&1 & echo $! > /tmp/poison.pid"
          )
          machine.succeed("sleep 3; kill -9 $(cat /tmp/poison.pid) 2>/dev/null || true")
          machine.succeed("cat /tmp/poison-boot.log >&2")
          machine.fail("stalwart-migrate-from-015")
          machine.succeed(
              "stalwart-migrate-from-015 2>&1 | tee /tmp/refuse.log || true; "
              "grep -q 'POISONED for 0.15.5' /tmp/refuse.log"
          )

      with subtest("--backup-dir migration: dump from the copy, recover the live store"):
          machine.succeed(
              "stalwart-migrate-from-015 --backup-dir /tmp/pre016-copy "
              "2>&1 | tee /tmp/migrate.log"
          )
          machine.succeed("cat /tmp/migrate.log >&2")
          machine.succeed("grep -q '\\[DONE\\] migration complete' /tmp/migrate.log")
          machine.succeed("test -f /var/lib/stalwart/v016-store-migrated")

      with subtest("post-migration: the 0.15 password authenticates on 0.16"):
          machine.succeed("systemctl start stalwart.service")
          machine.wait_for_open_port(8082, timeout=240)
          machine.wait_for_open_port(25, timeout=120)
          machine.succeed(
              "curl -fsS -u 'lars@migrate.test:${larsPassword}' "
              "http://127.0.0.1:8082/.well-known/jmap -o /tmp/jmap-lars.json"
          )
          machine.succeed("cat /tmp/jmap-lars.json >&2")
          machine.succeed("jq -e '.username == \"lars@migrate.test\"' /tmp/jmap-lars.json > /dev/null")

      with subtest("restart persistence: the guard passes on the migrated store"):
          # The guard cycled LOUDLY earlier in this same (volatile-journal)
          # boot - scope the no-refusal check to since-this-restart only.
          machine.succeed("date '+%Y-%m-%d %H:%M:%S' > /tmp/restart-ts")
          machine.succeed("systemctl restart stalwart.service")
          machine.wait_for_open_port(8082, timeout=120)
          machine.fail("systemctl is-failed stalwart.service")
          machine.succeed(
              "journalctl -u stalwart --no-pager -o cat --since \"$(cat /tmp/restart-ts)\" > /tmp/restart.log; "
              "! grep -q 'refusing to start' /tmp/restart.log"
          )
    '';
  }
