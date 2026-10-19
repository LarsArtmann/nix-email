# Convert-smoke for the vendored upstream migrate_v016.py (2026-10-19,
# W10.1): the migration script's first FUNCTIONAL test. The 2026-10-18
# gate session only syntax-verified it (py_compile + --help) after the
# dead-param/stub removals; this check runs the real `convert` subcommand
# against a minimal hand-built 0.15 dump fixture (the exact key/record
# shapes the e2e's phase-A node produces) and pins the plan shape the
# migration script depends on:
#   - config.json is the DataStore descriptor (RocksDb + the live path)
#   - export.json ops create Domain + Account with the LOCAL PART name
#     and the restore-<id> account-id mechanism (mail linkage survives)
#   - the SystemSettings update op rides the plan
#   - --patch-paths rewrites emitted paths (the mechanism the migration
#     script now relies on for dump-copy -> live-store rewrites)
# Pure derivation + build-time python (no VM, no network, stdlib only).
{
  nixpkgs,
  system,
}: let
  pkgs = nixpkgs.legacyPackages.${system};
  # migrate_v016.py imports requests unconditionally (the dump side);
  # the convert path itself is stdlib-only, but the module import needs it.
  pythonWithRequests = pkgs.python3.withPackages (p: [p.requests]);

  # Minimal but faithful 0.15 dump: flat settings map (as served by
  # /api/settings/list) + principal records (as served by /api/principal).
  settings015 = pkgs.writeText "settings-015.json" (
    builtins.toJSON {
      "store.db.type" = "rocksdb";
      "store.db.path" = "/var/lib/stalwart/db";
      "store.db.compression" = "lz4";
      "storage.data" = "db";
      "storage.fts" = "db";
      "storage.lookup" = "db";
      "storage.blob" = "db";
      "directory.internal.type" = "internal";
      "directory.internal.store" = "db";
      "server.hostname" = "migrate.test";
      "server.listener.webadmin.bind" = "127.0.0.1:8080";
      "server.listener.webadmin.protocol" = "http";
      "authentication.fallback-admin.user" = "admin";
      "authentication.fallback-admin.secret" = "test-admin-secret";
      "report.submitter" = "postmaster@migrate.test";
    }
  );

  principals015 = pkgs.writeText "principals-015.json" (
    builtins.toJSON [
      {
        type = "domain";
        id = "1";
        name = "migrate.test";
      }
      {
        type = "individual";
        id = "2";
        name = "lars@migrate.test";
        emails = ["lars@migrate.test" "@migrate.test"];
        # 0.15 stores password hashes in secrets (openssl passwd -6 shape)
        secrets = ["$6$rounds=1$e2esalt$QmWJmFZOLjtFLfKCsyTJcLxQ.FBT8S0PnKzhpbn/7Phzeq1J6ZaLMSTBuuAD.BUzW2hCHvYrNkhFTsTQbQ/"];
        roles = ["user"];
      }
    ]
  );
in
  pkgs.stdenv.mkDerivation {
    name = "migrate-convert-eval";
    nativeBuildInputs = [pythonWithRequests pkgs.jq];
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild

      echo "[*] convert (no flags)"
      python3 ${../modules/stalwart-module/migrate_v016.py} convert \
        --settings ${settings015} \
        --principals ${principals015} \
        --config config.json \
        --output export.json 2>&1 | tee convert.log

      echo "[*] config.json (DataStore descriptor)"
      jq -e '."@type" == "RocksDb"' config.json > /dev/null
      jq -e '.path == "/var/lib/stalwart/db"' config.json > /dev/null

      echo "[*] export.json plan shape"
      test "$(wc -l < export.json)" -ge 2
      jq -s -e 'any(.[]; ."@type" == "create" and .object == "Domain"
        and (.value | to_entries | any(.value.name == "migrate.test")))' export.json > /dev/null
      jq -s -e 'any(.[]; ."@type" == "update" and .object == "SystemSettings"
        and .value.defaultHostname == "migrate.test")' export.json > /dev/null

      echo "[*] Account op: local-part name + restore-<id> mechanism"
      jq -s -e 'any(.[]; ."@type" == "create" and .object == "Account"
        and (.value | to_entries | any(
          .key == "restore-2"
          and .value.name == "lars"
          and (.value.domainId | startswith("#")))))' export.json > /dev/null
      grep -q 'restore-' export.json

      echo "[*] convert with --patch-paths (the dump-copy -> live rewrite)"
      python3 ${../modules/stalwart-module/migrate_v016.py} convert \
        --settings ${settings015} \
        --principals ${principals015} \
        --config config-patched.json \
        --output export-patched.json \
        --patch-paths /var/lib/stalwart=/srv/mail 2>&1 | tee convert-patched.log
      jq -e '.path == "/srv/mail/db"' config-patched.json > /dev/null
      grep -q 'patched 1 path' convert-patched.log

      runHook postBuild
    '';

    installPhase = ''
      mkdir -p "$out"
      cp config.json export.json convert.log config-patched.json convert-patched.log "$out"/
    '';
  }
