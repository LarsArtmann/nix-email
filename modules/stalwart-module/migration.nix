# The 0.15 -> 0.16 store migration: owner-run script + dataDir marker
# consumed by the unit guard in default.nix.
#
# WHY THIS EXISTS (sandbox + host proven 2026-10-17, the pbx-artmann
# outage): the 0.16 binary REFUSES to boot against a 0.15-era store -
# exit 101, `crates/migration/src/lib.rs:95: Migration aborted:
# Upgrading to version 0.16 is a multi-step process` - and every
# attempted boot POISONS the store for 0.15.5 before panicking (the
# binary writes its webui Application defaults into the settings
# subspace first; a subsequent 0.15.5 open dies with
# `Data corruption detected (store.data-corruption)`). A unit that
# crash-loops on a 0.15 store therefore also destroys the only dump
# path (dump = 0.15.5 management API, upstream's migrate_v016.py).
#
# The sanctioned upstream flow (UPGRADING/v0_16.md) is offline and
# multi-step; this module automates it as ONE owner-run script plus a
# pre-start GUARD that fails loudly BEFORE the binary can poison
# anything:
#
#   guard   - dataDir/<store> non-empty and no marker file -> the unit
#             refuses to start with the migration instructions; a
#             virgin (empty/missing) store self-marks so fresh
#             installs never trip it (default.nix).
#   script  - `stalwart-migrate-from-015` (run as root on the host):
#             poison preflight -> backup -> boot 0.15.5 against the
#             store (or an unpacked pre-0.16 copy when the live store
#             is already poisoned) -> upstream dump+convert (paths
#             rewritten to the LIVE store: the dump serves the probe's
#             effective settings, so an unrewritten DataStore path
#             migrated the copy while the live store stayed pre-0.16 -
#             the run-6 exit-101) -> recovery-mode 0.16 on a dedicated
#             port -> stalwart-cli apply -> marker -> VERIFIED end
#             state (stable normal boot + provision apply; no [DONE]
#             before the store actually boots). Accounts keep their
#             0.15 ids (the `restore-<id>` mechanism), so mail linkage
#             survives.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.stalwart;
  mig = config.services.stalwart.migrateFrom015;

  storeDir =
    if lib.versionOlder cfg.stateVersion "24.11"
    then "${cfg.dataDir}/data"
    else "${cfg.dataDir}/db";

  adminSecretFile = let
    name = cfg.admin.username;
  in
    if cfg.admin.enable && cfg.credentials ? ${name}
    then cfg.credentials.${name}
    else null;
in {
  options.services.stalwart.migrateFrom015 = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.stalwart;
      description = ''
        The 0.15.x server binary used for the dump leg of the migration
        (opens the old store and serves the management API the vendored
        upstream migrate_v016.py dumps through). Must be >= 0.15, < 0.16.
      '';
    };

    pythonEnv = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3.withPackages (p: [p.requests]);
      readOnly = true;
      internal = true;
      description = "Python env for the vendored migrate_v016.py.";
    };

    probePort = lib.mkOption {
      type = lib.types.port;
      default = 18081;
      description = "Loopback port the 0.15.5 dump probe listens on.";
    };

    recoveryPort = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = ''
        Loopback port the 0.16 recovery-mode boot listens on. Deliberately
        NOT the built-in 8080: the recovery default collides with real
        services on consumer hosts (the pbx webphone owns 8080).
      '';
    };

    script = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      description = "The owner-run migration script; add to environment.systemPackages.";
    };
  };

  config = let
    # bash parameter expansions are escaped (''${) - everything ${} here is
    # nix interpolation of eval-time values only.
    migrateScript = pkgs.writeShellScriptBin "stalwart-migrate-from-015" ''
      set -euo pipefail

      usage() {
        echo "usage: stalwart-migrate-from-015 [--backup-dir PATH]" >&2
        echo "  --backup-dir PATH  a pre-0.16 store directory (the db/ or data/ dir" >&2
        echo "                      itself, or an unpacked backup root containing it)" >&2
        echo "                      to dump from when the live store is already" >&2
        echo "                      poisoned by a 0.16 boot attempt" >&2
      }

      [ "$(id -u)" = 0 ] || { echo "FATAL: run as root (needs systemctl + the admin secret)" >&2; exit 1; }

      backup_dir=""
      while [ $# -gt 0 ]; do
        case "$1" in
          --backup-dir) backup_dir="''${2-}"; shift 2 ;;
          *) usage; exit 64 ;;
        esac
      done

      data_dir=${lib.escapeShellArg cfg.dataDir}
      store_dir=${lib.escapeShellArg storeDir}
      marker="''${data_dir%/}/v016-store-migrated"

      [ -e "$marker" ] && { echo "[=] $marker exists - nothing to migrate"; exit 0; }

      secret_file=${lib.escapeShellArg (toString adminSecretFile)}
      if [ ! -f "$secret_file" ]; then
        echo "FATAL: admin secret file $secret_file missing (services.stalwart credentials)" >&2
        exit 1
      fi
      secret="$(tr -d '\n' < "$secret_file")"

      work="''${data_dir%/}/migration-v016"
      mkdir -p "$work"

      echo "[*] stopping stalwart (and the provision oneshot, if queued)"
      systemctl stop stalwart-provision.service 2>/dev/null || true
      systemctl stop stalwart.service 2>/dev/null || true
      systemctl reset-failed stalwart.service 2>/dev/null || true

      dump_store="$store_dir"
      if [ -n "$backup_dir" ]; then
        # accept either the db dir itself or a root containing db/ or data/
        if [ -d "''${backup_dir%/}/db" ]; then
          dump_store="''${backup_dir%/}/db"
        elif [ -d "''${backup_dir%/}/data" ]; then
          dump_store="''${backup_dir%/}/data"
        else
          dump_store="''${backup_dir%/}"
        fi
      fi

      probe_toml="$work/probe.toml"
      {
        printf '[store.db]\ntype = "rocksdb"\npath = "%s"\ncompression = "lz4"\n\n' "$dump_store"
        printf '[storage]\ndata = "db"\nfts = "db"\nlookup = "db"\nblob = "db"\ndirectory = "internal"\n\n'
        printf '[directory.internal]\ntype = "internal"\nstore = "db"\n\n'
        printf '[resolver]\ntype = "system"\n\n'
        printf '[server]\nhostname = "migrate.internal"\n\n'
        printf '[server.listener.migrate-http]\nbind = ["127.0.0.1:${toString mig.probePort}"]\nprotocol = "http"\n\n'
        printf '[authentication.fallback-admin]\nuser = "${cfg.admin.username}"\nsecret = "%s"\n' "$secret"
      } > "$probe_toml"
      chmod 600 "$probe_toml"
      # The probe and the recovery boot run as the SERVICE USER (upstream
      # doctrine: root-run boots litter the store with root-owned RocksDB
      # files the unit cannot always rewrite). The toml carries the admin
      # secret, so it stays 0600 - just owned by the service user.
      chown ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} "$probe_toml"
      as_service_user="${lib.getExe' pkgs.util-linux "setpriv"} --reuid=${lib.escapeShellArg cfg.user} --regid=${lib.escapeShellArg cfg.group} --init-groups"
      if [ "$dump_store" != "$store_dir" ]; then
        # A root-unpacked backup copy is root-owned; the 0.15.5 probe needs
        # to WRITE (RocksDB lock + WAL) as the service user.
        echo "[*] normalizing dump-copy ownership for the 0.15.x probe"
        chown -R ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} "$dump_store"
      fi

      echo "[*] preflight: opening the dump store with ${mig.package.version}"
      $as_service_user ${lib.getExe mig.package} --config="$probe_toml" > "$work/preflight.log" 2>&1 &
      preflight_pid=$!
      preflight_verdict=""
      for _ in $(seq 1 40); do
        if ! kill -0 "$preflight_pid" 2>/dev/null; then preflight_verdict="exited"; break; fi
        if grep -q 'Housekeeper process started' "$work/preflight.log" 2>/dev/null; then preflight_verdict="healthy"; break; fi
        sleep 0.5
      done
      if [ "$preflight_verdict" != "healthy" ]; then
        kill "$preflight_pid" 2>/dev/null || true
        wait "$preflight_pid" 2>/dev/null || true
        if grep -q 'Data corruption detected' "$work/preflight.log" 2>/dev/null; then
          echo "FATAL: the dump store is POISONED for 0.15.5 (a 0.16 binary wrote settings into it)." >&2
          echo "       Restore a pre-0.16 store copy and pass --backup-dir, e.g.:" >&2
          echo "         mkdir -p /var/lib/stalwart-migration-source" >&2
          echo "         tar -xf <newest pre-0.16 stalwart staging tar> -C /var/lib/stalwart-migration-source" >&2
          echo "         stalwart-migrate-from-015 --backup-dir /var/lib/stalwart-migration-source" >&2
          exit 2
        fi
        echo "FATAL: 0.15.x did not come up against the dump store:" >&2
        tail -5 "$work/preflight.log" >&2
        exit 2
      fi
      echo "[+] store opens with 0.15.x (housekeeper running)"

      backup_dst="''${data_dir%/}.v015-premigrate"
      if [ -e "$backup_dst" ]; then
        echo "[=] $backup_dst already exists - keeping it"
      else
        echo "[*] backing up the live store -> $backup_dst (mail data survives poisoning)"
        cp -a "$data_dir" "$backup_dst"
      fi

      echo "[*] dumping settings + principals through the 0.15.x management API"
      ${lib.getExe mig.pythonEnv} ${./migrate_v016.py} dump \
        --url "http://127.0.0.1:${toString mig.probePort}" \
        --username "${cfg.admin.username}" --password "$secret" \
        --settings "$work/settings.json" --principals "$work/principals.json"
      echo "[*] converting to the 0.16 plan"
      # The dump captured the PROBE's EFFECTIVE settings: every path the
      # 0.15 API served - including store.<id>.path, which the probe toml
      # pointed at the DUMP store - lands in convert's output verbatim.
      # Rewrite dump-store paths to their live equivalents everywhere.
      patch_args=()
      if [ "$dump_store" != "$store_dir" ]; then
        patch_args=(--patch-paths "$dump_store=$store_dir")
      fi
      ${lib.getExe mig.pythonEnv} ${./migrate_v016.py} convert \
        --settings "$work/settings.json" \
        --principals "$work/principals.json" \
        --config "$work/config.json" \
        --output "$work/export.json" \
        ''${patch_args[@]}
      # Belt and braces: whatever convert emitted, the recovery boot MUST
      # target the LIVE store - migrating any other path is worthless.
      ${lib.getExe mig.pythonEnv} ${./rewrite-datastore-path.py} "$work/config.json" "$store_dir"

      echo "[*] stopping the 0.15.x probe"
      kill -INT "$preflight_pid" 2>/dev/null || true
      for _ in $(seq 1 20); do kill -0 "$preflight_pid" 2>/dev/null || break; sleep 0.5; done
      kill -9 "$preflight_pid" 2>/dev/null || true
      wait "$preflight_pid" 2>/dev/null || true

      # The recovery boot uses convert's own config.json - it describes the
      # SAME datastore the dump read (path carried from the old settings),
      # so no module-internal configFile exposure is needed.
      echo "[*] booting ${cfg.package.version} in recovery mode (port ${toString mig.recoveryPort})"
      # A root-run 0.16 boot attempt (the poison class) leaves root-owned
      # RocksDB files (MANIFEST/WAL/OPTIONS) the service-user recovery
      # cannot append to - mid-apply writes then fail with jmap 503
      # serverUnavailable (migrate-e2e run 8, 2026-10-19). Normalize BEFORE
      # the boot; upstream's Docker flow does the same chown on import.
      chown -R ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} "$store_dir"
      recovery_password="$(head -c 32 /dev/urandom | base64 | tr -d '=+/' | cut -c1-24)"
      STALWART_RECOVERY_MODE=1 \
      STALWART_RECOVERY_ADMIN="${cfg.admin.username}:$recovery_password" \
      STALWART_RECOVERY_MODE_PORT=${toString mig.recoveryPort} \
        $as_service_user ${lib.getExe cfg.package} --config="$work/config.json" \
        > "$work/recovery.log" 2>&1 &
      recovery_pid=$!
      recovery_up=0
      for _ in $(seq 1 60); do
        if ! kill -0 "$recovery_pid" 2>/dev/null; then break; fi
        if ${lib.getExe' pkgs.curl "curl"} -sf -o /dev/null "http://127.0.0.1:${toString mig.recoveryPort}/"; then recovery_up=1; break; fi
        sleep 0.5
      done
      if [ "$recovery_up" != 1 ]; then
        echo "FATAL: recovery mode never came up:" >&2
        tail -10 "$work/recovery.log" >&2
        kill -INT "$recovery_pid" 2>/dev/null || true
        exit 3
      fi
      echo "[+] recovery mode is up"
      # The one-shot migration path (subspace wipe + spam-model migration)
      # keeps running briefly after the HTTP endpoint answers; let it
      # settle before driving the apply through the same store.
      sleep 5

      echo "[*] applying the converted plan (accounts keep their 0.15 ids)"
      if ! STALWART_URL="http://127.0.0.1:${toString mig.recoveryPort}" \
      STALWART_USER="${cfg.admin.username}" \
      STALWART_PASSWORD="$recovery_password" \
        ${lib.getExe cfg.provision.package} apply --file "$work/export.json"; then
        echo "FATAL: the plan apply failed - recovery.log tail:" >&2
        tail -40 "$work/recovery.log" >&2 || true
        exit 4
      fi

      echo "[*] stopping recovery mode"
      kill -INT "$recovery_pid" 2>/dev/null || true
      for _ in $(seq 1 20); do kill -0 "$recovery_pid" 2>/dev/null || break; sleep 0.5; done
      kill -9 "$recovery_pid" 2>/dev/null || true
      wait "$recovery_pid" 2>/dev/null || true

      touch "$marker"
      chown ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} "$marker"

      # The marker is a STORE-FORMAT claim; [DONE] is an END-STATE claim.
      # Verify the end state before claiming it: boot the unit (the guard
      # passes on the marker) and require STABLE active - Restart=on-failure
      # cycles a panicking binary through brief active windows, so settle
      # and check the restart counter too - then run the provision apply,
      # whose own ExecStartPost restarts stalwart and verifies cfg.url.
      echo "[*] verifying the end state: normal boot + provision apply"
      systemctl reset-failed stalwart.service 2>/dev/null || true
      systemctl start stalwart.service
      boot_ok=0
      for _ in $(seq 1 60); do
        [ "$(systemctl is-active stalwart.service)" = "active" ] && { boot_ok=1; break; }
        sleep 2
      done
      if [ "$boot_ok" = 1 ]; then
        sleep 8
        [ "$(systemctl is-active stalwart.service)" = "active" ] || boot_ok=0
        [ "$(systemctl show -p NRestarts --value stalwart.service)" = "0" ] || boot_ok=0
      fi
      if [ "$boot_ok" != 1 ]; then
        echo "FATAL: the migrated store did not boot cleanly." >&2
        echo "       Removing $marker so the unit guard refuses further boots (no crash-looping a half-migrated store)." >&2
        rm -f "$marker"
        journalctl -u stalwart --no-pager -n 40 >&2 || true
        echo "       Forensics: $work (recovery.log, config.json, export.json)" >&2
        exit 5
      fi
      echo "[+] stalwart.service is stable on the migrated store"

      if ! systemctl start stalwart-provision.service; then
        echo "FATAL: stalwart-provision failed on the migrated store (the server is up; the listener plan did not apply)." >&2
        journalctl -u stalwart-provision --no-pager -n 40 >&2 || true
        echo "       Forensics: $work" >&2
        exit 6
      fi

      echo ""
      echo "[DONE] migration complete and verified:"
      echo "  - the live store boots ${cfg.package.version} (stalwart.service stable)"
      echo "  - the provision plan applied (stalwart-provision.service = success)"
      echo "  - accounts keep their 0.15 ids and passwords"
      echo "  Next steps:"
      echo "  1. Recalculate disk quotas (webadmin -> Tasks) - the migration resets them"
      echo "  2. Artifacts kept for forensics: $work"
    '';
  in {
    services.stalwart.migrateFrom015.script = migrateScript;

    # Only meaningful (and only safe to assert) on 0.16 consumers - the raw
    # module still serves 0.15.x packages, and nothing below runs for them.
    assertions = lib.optionals (lib.versionAtLeast cfg.package.version "0.16") [
      {
        assertion = lib.versionAtLeast mig.package.version "0.15" && lib.versionOlder mig.package.version "0.16";
        message = "services.stalwart.migrateFrom015.package must be a 0.15.x stalwart (got ${mig.package.version})";
      }
    ];
  };
}
