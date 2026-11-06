# 0.16 -> 1.0 store-migration REHEARSAL e2e (the gold-standard gate
# before any live 1.x flip; owner decision 2026-11-05 "all latest").
# Same TWO-NODE shape as stalwart-migrate-e2e.nix (0.15 -> 0.16): no
# in-VM switch-to-configuration ever runs; the store travels through the
# testers framework's writable /tmp/shared (virtfs).
#
# The boundary under test is HARDER than 0.15 -> 0.16: Stalwart 1.0.0
# redesigned the database layout and renumbered every numeric id space
# (stalwartlabs/stalwart-migrate SCHEMA_CHANGES.md), so RAW store copies
# are unsafe - only the official stalwart-migrate tool (vendored at
# pkgs/stalwart-migrate, v1.0.6) may produce a v1 store. Verified facts
# this test is built on:
#   - the tool's exact-match schema gate (source-v016/adapter/mod.rs)
#     reads the store's DATABASE_SCHEMA_VERSION; 0.16.26 and 0.16.27 BOTH
#     ship schema 6 (stalwart crates/common/src/lib.rs at both tags), so
#     the pin's pkgs.stalwart_0_16 0.16.26 seeds a store the v1.0.6 tool
#     accepts despite the README's "v0.16.27" prose (VM-proven HERE).
#   - `prepare` is interactive by design; `prepare --non-interactive`
#     only VALIDATES an existing answers.toml. The rehearsal drives the
#     interactive prompt through a pty (util-linux `script`) feeding
#     newlines = accept the RECOMMENDED answer everywhere, then Enter on
#     the final "Write answers.toml [Y/n]".
#   - target config.json shape (tool README) == the wrapper module's own
#     0.16+ config.json shape: top-level {"@type":"RocksDb","path":...}
#     (modules/stalwart-module/default.nix settings default).
#
# Subtests:
#   1. mig016 (0.16.26, wrapper default): provision applies, a needle
#      mail is delivered to user1 and visible over IMAP (pre-state proof)
#   2. handoff: stop, tar the store to /tmp/shared
#   3. mig1x (vendored 1.0.3) baseline: virgin store + plan apply green
#      (the store-swap baseline, stalwart-e2e-v1 proves the battery)
#   4. migration: extract the 0.16 store locally, prepare (pty,
#      all-recommended), run --final --yes --owner <stalwart uid:gid>
#   5. cutover: 1.0.3 boots on the migrated store; user1's 0.16 password
#      authenticates over IMAP and the needle mail survived
{
  pkgs,
  package ? (pkgs.callPackage ../pkgs/stalwart_1_0/package.nix {}),
  migrate ? (pkgs.callPackage ../pkgs/stalwart-migrate/package.nix {}),
}: let
  common = import ./common.nix;
  testPass = "testpass-x7Kk-9mQw";
  needle = "migrate1x-needle-7f3a";

  mkUser = name: {
    "@type" = "User";
    inherit name;
    domainId = "#domain";
    roles."@type" = "User";
    credentials = [
      {
        "@type" = "Password";
        secret = testPass;
      }
    ];
  };

  # IMAP wait-probe (login + INBOX scan for a body needle). Retry loop
  # because delivery is asynchronous; TLS is self-signed by the wrapper.
  imapWait = pkgs.writers.writePython3Bin "imap-wait" {} ''
    import imaplib
    import ssl
    import sys
    import time

    user, password, needle = sys.argv[1], sys.argv[2], sys.argv[3]
    deadline = time.time() + 180
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    last_err = None
    while time.time() < deadline:
        try:
            with imaplib.IMAP4_SSL("127.0.0.1", 993, ssl_context=ctx) as imap:
                imap.login(user, password)
                status, _ = imap.select("INBOX")
                assert status == "OK"
                status, data = imap.search(None, "ALL")
                assert status == "OK"
                for num in data[0].split():
                    status, msg = imap.fetch(num, "(RFC822)")
                    body = b"".join(
                        p[1] for p in msg if isinstance(p, tuple)
                    )
                    if needle.encode() in body:
                        print(f"needle present as {num.decode()}")
                        sys.exit(0)
                last_err = "needle not in any fetched message"
        except Exception as err:
            last_err = repr(err)
        time.sleep(3)
    print(f"imap-wait failed: {last_err}", file=sys.stderr)
    sys.exit(1)
  '';

  # Minimal account plan shared by both nodes (same domain via hostname).
<<<<<<< Updated upstream
  nodeConfig = {config, ...}: {
=======
  nodeConfig = {
    config,
    ...
  }: {
>>>>>>> Stashed changes
    imports = [
      ../modules/mail-server.nix
      common.dnslessVmPatches
      common.testAdminSecretModule
    ];

    system.stateVersion = "26.05";
    services.mail-server = {
      enable = true;
      hostname = "migrate1x.test";
      admin.secretFile = "/etc/test-admin-secret";
    };

    services.stalwart.provision.objects.Account = {
      reconcile = true;
      match = ["name"];
      objects.user1 = mkUser "user1";
    };

    environment.systemPackages = [
      pkgs.jq
      pkgs.swaks
      imapWait
    ];
    virtualisation.memorySize = 2048;
  };
in
  pkgs.testers.runNixOSTest {
    name = "stalwart-migrate-1x-e2e";

    # Test-level v2 cpu for EVERY node (structurally unforgottable,
    # tests/common.nix v2CpuPatches): the 1.0.3 binary needs x86-64-v2.
    defaults = common.v2CpuPatches;

    nodes = {
      mig016 = nodeConfig;

      mig1x = {...}: {
        imports = [nodeConfig];
        # Plain list: the module system CONCATENATES this onto the
        # shared nodeConfig's packages (a config.X ++ self-reference in
        # a module that also defines X would recurse).
        services.stalwart.package = package;
        environment.systemPackages = [
          migrate
        ];
      };
    };

    testScript = ''
      start_all()

      with subtest("mig016: the 0.16.26 wrapper stack provisions and serves"):
          mig016.wait_for_unit("stalwart.service", timeout=180)
          mig016.wait_for_open_port(25, timeout=120)
          mig016.wait_for_open_port(8080, timeout=120)
          mig016.succeed(
              'test "$(systemctl show -p Result --value '
              'stalwart-provision.service)" = success'
          )
          # The provision unit's trailing reload action RESTARTS stalwart
          # after apply (the "Stopping Stalwart Server" journal line);
          # re-wait the ports or the first swaks races the restart window
          # (round-1 lesson, same discipline as stalwart-e2e's machine
          # node).
          mig016.wait_for_open_port(25, timeout=120)
          mig016.wait_for_open_port(8080, timeout=120)

      with subtest("mig016: needle mail delivered to user1 over IMAP"):
          # Authenticated submission on 587 (the e2e's proven no-stall
          # shape): a port-25 delivery from an EXTERNAL sender stalls
          # past swaks --timeout on the RCPT policy lookups (SPF/PTR/
          # DMARC for the external domain, ~30-45 s each serialized
          # behind one response in the DNS-less VM, round-2 transcript).
          # The migration proof cares about the STORE content, not the
          # ingress path.
          mig016.wait_for_open_port(587, timeout=120)
          mig016.succeed(
              "swaks --timeout 120 --server 127.0.0.1:587 --tls "
              "--auth PLAIN --auth-user user1@migrate1x.test "
              "--auth-password '${testPass}' "
              "--from user1@migrate1x.test --to user1@migrate1x.test "
              "--body ${needle} > /tmp/swaks-seed.log 2>&1"
          )
          mig016.succeed("cat /tmp/swaks-seed.log >&2")
          mig016.succeed("imap-wait user1@migrate1x.test '${testPass}' ${needle}")

      with subtest("handoff: stopped 0.16 store travels to the share"):
          mig016.succeed("systemctl stop stalwart.service")
          mig016.succeed("systemctl stop stalwart-provision.service || true")
          # tar, not cp -a: virtfs rejects chown; ownership/modes travel
          # INSIDE the archive (same lesson as stalwart-migrate-e2e).
          mig016.succeed(
              "tar -C /var/lib -cf /tmp/shared/store016.tar stalwart"
          )
          mig016.succeed("test -s /tmp/shared/store016.tar")

      with subtest("mig1x baseline: vendored 1.0.3 provisions a virgin store"):
          mig1x.wait_for_unit("stalwart.service", timeout=180)
          mig1x.wait_for_open_port(25, timeout=120)
          mig1x.wait_for_open_port(8080, timeout=120)
          mig1x.succeed(
              'test "$(systemctl show -p Result --value '
              'stalwart-provision.service)" = success'
          )
          # Same post-reload re-wait as mig016.
          mig1x.wait_for_open_port(25, timeout=120)
          mig1x.wait_for_open_port(8080, timeout=120)

      with subtest("migration: extract, prepare (pty, recommended), final run"):
          mig1x.succeed(
              "systemctl stop stalwart.service; "
              "systemctl stop stalwart-provision.service || true"
          )
          # The final target is the module's OWN live store path: empty it
          # of the virgin store first (the tool requires an empty target).
          mig1x.succeed("rm -rf /var/lib/stalwart")
          mig1x.succeed("mkdir -p /var/lib/premigrate")
          mig1x.succeed(
              "tar -C /var/lib/premigrate -xf /tmp/shared/store016.tar"
          )
          mig1x.succeed("test -d /var/lib/premigrate/stalwart/db")
          mig1x.succeed(
              "cat > /run/source-config.json <<'EOF'\n"
              '{"@type": "RocksDb", "path": "/var/lib/premigrate/stalwart/db"}\n'
              "EOF"
          )
          mig1x.succeed(
              "cat > /run/target-config.json <<'EOF'\n"
              '{"@type": "RocksDb", "path": "/var/lib/stalwart/db"}\n'
              "EOF"
          )
          mig1x.succeed("mkdir -p /var/lib/migrate-state")
          # prepare is interactive by design: drive it through a pty,
          # answering every question with Enter (= the recommended
<<<<<<< Updated upstream
          # answer) and confirming the answers.toml write. The log is
          # dumped UNCONDITIONALLY before the exit code propagates
          # (round-3 lesson: a redirected, success-only dump is a
          # dump that never runs on the round you need it).
          mig1x.succeed(
              "sh -c 'yes \"\" | head -200 | script -qec "
              '"stalwart-migrate prepare '
              "--source /run/source-config.json "
              "--state /var/lib/migrate-state\" /dev/null "
              "> /tmp/prepare.log 2>&1; "
              "rc=$?; head -c 12000 /tmp/prepare.log >&2; "
              "tail -c 8000 /tmp/prepare.log >&2; exit $rc'"
          )
=======
          # answer) and confirming the answers.toml write.
          mig1x.succeed(
              'yes "" | head -200 | script -qec '
              '"stalwart-migrate prepare '
              '--source /run/source-config.json '
              '--state /var/lib/migrate-state" /dev/null '
              "> /tmp/prepare.log 2>&1"
          )
          mig1x.succeed("cat /tmp/prepare.log >&2")
>>>>>>> Stashed changes
          mig1x.succeed("test -f /var/lib/migrate-state/answers.toml")
          owner = mig1x.succeed(
              "id -u stalwart | tr -d '\\n'; echo -n :; id -g stalwart"
          ).strip()
          mig1x.succeed(
<<<<<<< Updated upstream
              "sh -c 'stalwart-migrate run --final --yes "
              "--source /run/source-config.json "
              "--target /run/target-config.json "
              "--state /var/lib/migrate-state "
              f"--owner {owner} > /tmp/run-final.log 2>&1; "
              "rc=$?; tail -c 12000 /tmp/run-final.log >&2; exit $rc'"
          )
=======
              "stalwart-migrate run --final --yes "
              "--source /run/source-config.json "
              "--target /run/target-config.json "
              "--state /var/lib/migrate-state "
              f"--owner {owner} > /tmp/run-final.log 2>&1"
          )
          mig1x.succeed("cat /tmp/run-final.log >&2")
>>>>>>> Stashed changes
          mig1x.succeed("test -f /var/lib/migrate-state/final-report.txt")
          mig1x.succeed("test -d /var/lib/stalwart/db")

      with subtest("cutover: 1.0.3 serves the migrated store"):
<<<<<<< Updated upstream
          # The 0.16 store guard (modules/stalwart-module/default.nix) is
          # a shell heuristic: non-empty db dir + no marker = pre-0.16
          # store, refuse. The rehearsal wiped the dataDir (the tool
          # requires an empty target), taking the virgin-boot marker with
          # it; the migrate-written 1.0 store then trips the heuristic.
          # Use the guard's OWN documented escape hatch for "this store
          # was migrated by other means" - which is literally true here.
          # A live pbx flip does NOT need this (its marker survives from
          # the 0.16 era); the consumer-flip runbook owns that note.
          mig1x.succeed("touch /var/lib/stalwart/v016-store-migrated")
=======
>>>>>>> Stashed changes
          mig1x.succeed("systemctl start stalwart.service")
          mig1x.wait_for_unit("stalwart.service", timeout=180)
          mig1x.wait_for_open_port(25, timeout=120)
          mig1x.wait_for_open_port(8080, timeout=120)
          # The 0.16 password and the delivered mail both survived the
          # id-space renumbering: login + needle fetch over IMAP.
          mig1x.succeed("imap-wait user1@migrate1x.test '${testPass}' ${needle}")

      with subtest("post-cutover: the declarative plan still applies"):
          mig1x.succeed("systemctl start stalwart-provision.service")
          mig1x.succeed(
              'test "$(systemctl show -p Result --value '
              'stalwart-provision.service)" = success'
          )
    '';
  }
