# VENDORED from NixOS/nixpkgs PR #552103 ("nixos/stalwart: update module for 0.16+")
# at rev 9b15e1f0c8e848e0ac11d8c0ac2f6b3d7027799c (0x57e11a/nixpkgs).
# Drop this directory once that PR merges into the nixpkgs rev this flake
# pins - upstream path: nixos/modules/services/mail/stalwart/.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.stalwart;

  since0_16 = lib.versionAtLeast cfg.package.version "0.16";
  configFormatName =
    if since0_16
    then "json"
    else "toml";
  configFormat = pkgs.formats.${configFormatName} {};
  configFile = configFormat.generate "stalwart.${configFormatName}" cfg.settings;
  useLegacyStorage = lib.versionOlder cfg.stateVersion "24.11";
  pre2605 = lib.versionOlder cfg.stateVersion "26.05";
  stalwartIdentifier =
    if pre2605
    then "stalwart-mail"
    else "stalwart";
  stalwartIdentifierText = ''if lib.versionOlder config.services.stalwart.stateVersion "26.05" then "stalwart-mail" else "stalwart"'';

  # 0.16 store guard (2026-10-17 pbx outage class): the 0.16 binary
  # PANICS (exit 101, migration/lib.rs:95) on a pre-0.16 store, and
  # every attempt POISONS the settings subspace for 0.15.5 before
  # panicking - a restart loop destroys the dump path of the
  # migration. Refuse loudly instead, BEFORE the binary runs. A
  # virgin (missing/empty) store self-marks so fresh installs and
  # every later boot pass; the migration script touches the same
  # marker on success. Stores already migrated BEFORE this guard
  # shipped self-mark once via the printed escape hatch.
  storeGuard =
    if since0_16
    then let
      probeDir =
        if useLegacyStorage
        then "${cfg.dataDir}/data"
        else "${cfg.dataDir}/db";
      marker = "${cfg.dataDir}/v016-store-migrated";
    in
      pkgs.writeShellScript "stalwart-v016-store-guard" ''
        set -eu
        marker=${lib.escapeShellArg marker}
        probe=${lib.escapeShellArg probeDir}
        if [ -e "$marker" ]; then exit 0; fi
        if [ ! -d "$probe" ] || [ -z "$(${lib.getExe' pkgs.coreutils "ls"} -A "$probe" 2>/dev/null)" ]; then
          # virgin store: self-mark so only pre-0.16 data ever trips
          touch "$marker"
          exit 0
        fi
        echo "stalwart: refusing to start - a pre-0.16 store exists at $probe without the v0.16 migration marker." >&2
        echo "  The 0.16 binary panics on unmigrated stores (exit 101) and EVERY attempt poisons the store for 0.15.x." >&2
        echo "  Run the migration as root: stalwart-migrate-from-015 (see the nix-email README, 'Migrating from 0.15')." >&2
        echo "  If this store was already migrated before the guard shipped: touch $marker and restart." >&2
        exit 1
      ''
    else null;
in {
  imports = [
    # since 0.12.0 (2025-05-26) release, upstream re-branded project to 'stalwart' due to inclusion of collaboration features (CalDAV, CardDAV, and WebDAV)
    #  https://github.com/stalwartlabs/stalwart/releases/tag/v0.12.0
    (lib.mkRenamedOptionModule ["services" "stalwart-mail"] ["services" "stalwart"])
    ./migration.nix
  ];
  options.services.stalwart = {
    enable = lib.mkEnableOption "the all-in-one collaboration and mail server, Stalwart";

    stateVersion = lib.mkOption {
      type = lib.types.str;
      description = ''
        The version of this module (=version of NixOS) when this module was first enabled on this particular machine, used to maintain compatibility with application data created on older versions of this module.

        See {option}`system.stateVersion` for details on the NixOS-global equivalent to this option.
      '';
    };

    package = lib.mkPackageOption pkgs "stalwart" {};

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to open TCP firewall ports on all interfaces, which are specified in:
        - {option}`services.stalwart.settings.server.listener` in v0.15
        - {option}`services.stalwart.recovery.port` in v0.16+ if {option}`services.stalwart.recovery.enable`
        - {option}`services.stalwart.provision.objects.NetworkListener.objects` in v0.16+ if {option}`services.stalwart.provision.enable`
      '';
    };

    settings = lib.mkOption {
      # previously this was `inherit (configFormat) type;`, however now the config format is dependent on the package version,
      # choosing toml <0.16 and json >=0.16. thankfully, the `type` of the `json` format is identical to `toml` except the base value type is nullable
      inherit ((pkgs.formats.json {})) type;
      default = {};
      description = ''
        Configuration options for the Stalwart server.
        See <https://stalw.art/docs/configuration> for available options.

        By default, the module is configured to store everything locally.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/${stalwartIdentifier}";
      defaultText = lib.literalExpression "/var/lib/\${${stalwartIdentifierText}}";
      description = ''
        Data directory for stalwart
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = stalwartIdentifier;
      defaultText = lib.literalExpression stalwartIdentifierText;
      description = ''
        User ownership of service
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = stalwartIdentifier;
      defaultText = lib.literalExpression stalwartIdentifierText;
      description = ''
        Group ownership of service
      '';
    };

    url = lib.mkOption {
      type = lib.types.str;
      description = ''
        The public URL of the instance.
      '';
    };

    recovery = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to run in recovery mode, serving the web UI on `services.stalwart.recovery.port`.

          See the Stalwart documentation section "[Recovery mode](https://stalw.art/docs/configuration/recovery-mode/)"
          for details.
        '';
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = ''
          The port to serve the web UI on in bootstrap/recovery mode.
        '';
      };
      logLevel = lib.mkOption {
        type = lib.types.enum [
          "error"
          "warn"
          "info"
          "debug"
          "trace"
        ];
        default = "info";
        description = ''
          The log level to be used in recovery mode.

          See the Stalwart documentation on "[TracingLevel](https://stalw.art/docs/ref/object/log/#tracinglevel)" for details.
        '';
      };
    };

    admin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable the fallback administrator.

          This user is available in both recovery and production modes.
        '';
      };
      username = lib.mkOption {
        type = lib.types.str;
        description = ''
          The username of the fallback administrator used with {option}`admin.enable`.

          For providing the user's password, a credential with an identifier matching the value of {option}`admin.username`
          is required.

          For it to be automatically used, it can be provided through one of systemd's lookup locations for systemd-credentials,
          e.g. by creating the file `/run/credstore/fallback_admin`, containing the user's plain-text password.
          See {manpage}`systemd.exec(5)` (section "CREDENTIALS") and {option}`credentials` for details.
          Alternatively, configure the corresponding credential with a custom source path explicitly via {option}`credentials`
          and ensure its key matches {option}`username`.
        '';
        example = "fallback_admin";
      };
    };

    environmentFile = lib.mkOption {
      description = ''
        Path to a file containing extra Stalwart environment variables in the systemd `EnvironmentFile` format.
        Refer to the [documentation](https://stalw.art/docs/configuration/environment-variables/) for config options.

        This can be used to pass basic config data to Stalwart without putting them in the Nix store.
      '';
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/temporary-troubleshooting/stalwart-env";
    };

    credentials = lib.mkOption {
      description = ''
        Systemd credentials used to configure Stalwart secrets.

        These secrets can be accessed in configuration values with
        macros such as `%{file:/run/credentials/stalwart.service/VAR_NAME}%` on 0.15.x,
        or `filePath` in `"@type" = "File"` secrets on 0.16+.

        See {manpage}`systemd.exec(5)` (section "CREDENTIALS") for details.
      '';
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {
        fallback_admin = "/run/credstore/stalwart.fallback_admin_password";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.recovery.enable -> since0_16;
        message = "<option>services.stalwart.recovery.enable</option> requires <option>services.stalwart.package</option> to be at least version 0.16";
      }
      {
        assertion = cfg.admin.enable -> since0_16;
        message = "<option>services.stalwart.admin.enable</option> requires <option>services.stalwart.package</option> to be at least version 0.16";
      }
      {
        assertion =
          since0_16
          || !(
            (lib.hasAttrByPath ["settings" "queue"] cfg)
            && (builtins.any (lib.hasAttrByPath [
              "value"
              "next-hop"
            ]) (lib.attrsToList cfg.settings.queue))
          );
        message = ''
          Stalwart deprecated `next-hop` in favor of "virtual queues" `queue.strategy.route` \
          with v0.13.0 see [Outbound Strategy](https://stalw.art/docs/mta/outbound/strategy/#configuration) \
          and [release announcement](https://github.com/stalwartlabs/stalwart/blob/main/UPGRADING.md#upgrading-from-v012x-and-v011x-to-v013x).
        '';
      }
    ];

    # Default config: all local
    services.stalwart.settings =
      if since0_16
      then {
        "@type" = lib.mkDefault "RocksDb";
        path = lib.mkDefault "${cfg.dataDir}/db";
      }
      else {
        tracer =
          if pre2605
          then {
            stdout = {
              type = lib.mkDefault "stdout";
              level = lib.mkDefault "info";
              ansi = lib.mkDefault false; # no colour markers to journald
              enable = lib.mkDefault true;
            };
          }
          else {
            journal = {
              type = lib.mkDefault "journal";
              level = lib.mkDefault "info";
              enable = lib.mkDefault true;
            };
          };
        store =
          if useLegacyStorage
          then {
            # structured data in SQLite, blobs on filesystem
            db = {
              type = lib.mkDefault "sqlite";
              path = lib.mkDefault "${cfg.dataDir}/data/index.sqlite3";
            };
            fs = {
              type = lib.mkDefault "fs";
              path = lib.mkDefault "${cfg.dataDir}/data/blobs";
            };
          }
          else {
            # everything in RocksDB
            db = {
              type = lib.mkDefault "rocksdb";
              path = lib.mkDefault "${cfg.dataDir}/db";
              compression = lib.mkDefault "lz4";
            };
          };
        storage = {
          data = lib.mkDefault "db";
          fts = lib.mkDefault "db";
          lookup = lib.mkDefault "db";
          blob = lib.mkDefault (
            if useLegacyStorage
            then "fs"
            else "db"
          );
          directory = lib.mkDefault "internal";
        };
        directory.internal = {
          type = lib.mkDefault "internal";
          store = lib.mkDefault "db";
        };
        resolver = {
          type = lib.mkDefault "system";
          public-suffix = lib.mkDefault [
            "file://${pkgs.publicsuffix-list}/share/publicsuffix/public_suffix_list.dat"
          ];
        };
        spam-filter.resource = lib.mkDefault "file://${cfg.package.spam-filter}/spam-filter.toml";
        webadmin = let
          hasHttpListener = builtins.any (listener: listener.protocol == "http") (
            lib.attrValues (cfg.settings.server.listener or {})
          );
        in {
          path = "/var/cache/${stalwartIdentifier}";
          # SEMANTICS (source-proven, stalwart v0.15.5 boot.rs): the
          # webadmin zip is fetched from `resource` ONLY when the blob
          # store has none — the pin silently no-ops after the first
          # boot, so a changed package pin does NOT converge the served
          # bundle. Convergence = "Update WebAdmin" in the admin UI, or
          # delete the stored webadmin blob host-side and restart. (A
          # bundle-hash mismatch alone does NOT prove a version skew:
          # JS chunk hashes vary per toolchain build.)
          # Version-aware: the 0.16 package line (stalwart_0_16) exposes the
          # bundle as passthru.webui (webui-1.0.10 containing webui.zip);
          # the 0.15 line exposes webadmin/webadmin.zip. Pinned-rev
          # verified 2026-10-26; a bare cfg.package.webadmin threw
          # "attribute 'webadmin' missing" for any 0.16 consumer with an
          # http settings listener (eval transcript 2026-10-23).
          resource =
            lib.mkIf hasHttpListener
            (lib.mkDefault (
              if cfg.package ? webui
              then "file://${cfg.package.webui}/webui.zip"
              else "file://${cfg.package.webadmin}/webadmin.zip"
            ));
        };
      };

    # This service stores a potentially large amount of data.
    # Running it as a dynamic user would force chown to be run everytime the
    # service is restarted on a potentially large number of files.
    # That would cause unnecessary and unwanted delays.
    users = {
      groups = lib.mkIf (cfg.group == stalwartIdentifier) {
        ${cfg.group} = {};
      };
      users = lib.mkIf (cfg.user == stalwartIdentifier) {
        ${cfg.user} = {
          isSystemUser = true;
          inherit (cfg) group;
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' - '${cfg.user}' '${cfg.group}' - -"
    ];

    systemd = {
      services.stalwart = {
        description = "Stalwart Server";
        wantedBy = ["multi-user.target"];
        after = [
          "local-fs.target"
          "network.target"
        ];

        serviceConfig = {
          # Upstream service config
          Type = "simple";
          LimitNOFILE = 65536;
          KillMode = "process";
          KillSignal = "SIGINT";
          Restart = "on-failure";
          RestartSec = 5;
          SyslogIdentifier = stalwartIdentifier;

          ExecStartPre =
            (
              if useLegacyStorage
              then [
                "${lib.getExe' pkgs.coreutils "mkdir"} -p ${cfg.dataDir}/data/blobs"
              ]
              else [
                "${lib.getExe' pkgs.coreutils "mkdir"} -p ${cfg.dataDir}/db"
              ]
            )
            ++ (lib.optional (storeGuard != null) "${storeGuard}");
          ExecStart = let
            env = lib.optionalString cfg.admin.enable "STALWART_RECOVERY_ADMIN=${lib.escapeShellArg cfg.admin.username}:`systemd-creds cat ${lib.escapeShellArg cfg.admin.username}`";
            cmd = "${lib.getExe cfg.package} --config=${configFile}";
          in
            if since0_16 && cfg.admin.enable
            then "${lib.getExe pkgs.bash} -c ${lib.escapeShellArg "${env} ${cmd}"}"
            else cmd;
          Environment =
            lib.optionals since0_16 [
              "STALWART_PUBLIC_URL=${cfg.url}"
            ]
            ++ lib.optionals cfg.recovery.enable [
              "STALWART_RECOVERY_MODE=${toString cfg.recovery.enable}"
              "STALWART_RECOVERY_MODE_PORT=${toString cfg.recovery.port}"
              "STALWART_RECOVERY_MODE_LOG_LEVEL=${cfg.recovery.logLevel}"
            ];
          EnvironmentFile = lib.optional (cfg.environmentFile != null) cfg.environmentFile;
          LoadCredential = let
            # default credentials for the admin user, might be overridden by an explicitly configured cred in cfg.credentials
            adminCreds = lib.optionalAttrs cfg.admin.enable {"${cfg.admin.username}" = cfg.admin.username;};
          in
            lib.mapAttrsToList (key: value: "${key}:${value}") (adminCreds // cfg.credentials);

          ReadWritePaths = [
            cfg.dataDir
          ];
          CacheDirectory = stalwartIdentifier;
          StateDirectory = stalwartIdentifier;

          # Upstream uses "stalwart" as the username since 0.12.0
          User = cfg.user;
          Group = cfg.group;

          # Bind standard privileged ports
          AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
          CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];

          # Hardening
          DeviceAllow = [""];
          LockPersonality = true;
          MemoryDenyWriteExecute = true;
          PrivateDevices = true;
          PrivateUsers = false; # incompatible with CAP_NET_BIND_SERVICE
          ProcSubset = "pid";
          PrivateTmp = true;
          ProtectClock = true;
          ProtectControlGroups = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          RestrictAddressFamilies = [
            "AF_INET"
            "AF_INET6"
            "AF_UNIX"
          ];
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          SystemCallArchitectures = "native";
          SystemCallFilter = [
            "@system-service"
            "~@privileged"
          ];
          UMask = "0077";
        };
        unitConfig.ConditionPathExists = [
          "${configFile}"
        ];
      };
    };

    # Make admin commands available in the shell
    environment.systemPackages = [cfg.package] ++ (lib.optional since0_16 pkgs.stalwart-cli);

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = let
        parsePorts = listeners: let
          parseAddresses = listeners: lib.flatten (lib.mapAttrsToList (_name: value: value.bind) listeners);
          splitAddress = addr: lib.splitString ":" addr;
          extractPort = addr: lib.toInt (builtins.foldl' (_a: b: b) "" (splitAddress addr));
        in
          map extractPort (parseAddresses listeners);
      in
        if since0_16
        then
          if cfg.recovery.enable
          then [cfg.recovery.port]
          else if cfg.provision.enable
          then parsePorts (cfg.provision.objects.NetworkListener.objects or [])
          else
            builtins.warn ''
              <option>services.stalwart.openFirewall</option> is true, but Stalwart is neither:
              - in recovery mode <option>services.stalwart.recovery.enable</option>.
              - being provisioned by <option>services.stalwart.provision.enable</option>.
              Ports cannot be automatically detected, so none will be opened.
            '' []
        else parsePorts (cfg.settings.server.listener or []);
    };
  };

  meta = {
    maintainers = with lib.maintainers; [
      happysalada
      onny
      norpol
      hexstella
    ];
    # VENDOR PATCH (vs PR #552103): `doc = ./stalwart.md` removed. The doc's
    # section anchors (module-services-stalwart-provision etc.) must have
    # matching entries in nixpkgs' nixos/doc/manual/redirects.json - the PR
    # adds them THERE, which a vendored module cannot ship. With meta.doc
    # set, every nixosSystem toplevel fails in nixos-manual
    # ("Identifiers present in the source must have a mapping in the
    # redirects file"). stalwart.md stays in-tree as reference reading.
    # Restore `doc = ./stalwart.md;` verbatim when un-vendoring.
  };
}
