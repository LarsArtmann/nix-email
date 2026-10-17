# VENDORED from NixOS/nixpkgs PR #552103 at rev 9b15e1f0c8e848e0ac11d8c0ac2f6b3d7027799c
# (see default.nix header for the retirement plan).
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.stalwart.provision;
  stalwart = config.services.stalwart;
in {
  options.services.stalwart.provision = {
    enable = lib.mkEnableOption "Stalwart Configuration Provisioning";
    package = lib.mkPackageOption pkgs "stalwart-cli" {};
    reloadSettings = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Tell Stalwart to reload its settings when complete";
    };
    url = lib.mkOption {
      type = lib.types.str;
      description = "The URL of the Stalwart instance to provision onto.";
    };

    singletons = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      description = "Singletons to configure.";
      example = {
        SystemSettings = {
          defaultHostname = "mail.example.com";
          defaultDomainId = "#mainDomain";
        };
      };
    };
    objects = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            reconcile = lib.mkOption {
              type = lib.types.bool;
              description = ''
                Whether to use the `reconcile` operation instead of `upsert`, deleting objects in this set that are not explicitly defined.
                Read the [documentation](https://stalw.art/docs/management/cli/apply/#reconciling-to-exact-state) for more information.
              '';
              default = false;
            };

            match = lib.mkOption {
              type = lib.types.nullOr (lib.types.either (lib.types.listOf lib.types.str) lib.types.str);
              description = ''
                The fields to match on, a wildcard (`"*"`), or null.
                Read the [documentation](https://stalw.art/docs/management/cli/apply/#upsert) for more information.
              '';
              example = ["name"];
              default = null;
            };

            scope = lib.mkOption {
              type = lib.types.nullOr lib.types.attrs;
              description = ''
                Optional scope to restrict which objects this operation can affect.
                Should be a partial value of the object type.
                This is especially useful when `reconcile` is `true`, only objects that match the scope will be considered for deletion.
                Read the [documentation](https://stalw.art/docs/management/cli/apply/#scoping-an-operation-with-scope) for more information.
              '';
            };

            objects = lib.mkOption {
              type = lib.types.attrsOf lib.types.attrs;
              description = "The objects in the set. Attribute names define IDs that can be referenced with `#name` elsewhere where an ID is expected.";
            };
          };
        }
      );
      description = "Objects to configure.";
      example = {
        NetworkListener = {
          reconcile = false;
          match = ["name"];
          objects = {
            nl-mgmt = {
              name = "management";
              protocol = "http";
              bind = {
                "[::]:8080" = true;
              };
            };
            nl-inc = {
              name = "incoming";
              protocol = "submissions";
              bind = {
                "[::]:465" = true;
              };
              tlsImplicit = true;
            };
          };
        };
        Domain = {
          reconcile = true;
          match = ["name"];
          objects = {
            mainDomain = {
              name = "mail.example.com";
              certificateManagement."@type" = "Manual";
              dkimManagement."@type" = "Manual";
              dnsManagement."@type" = "Manual";
              subAddressing."@type" = "Enabled";
            };
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    let
      variant = type: value: {"@type" = type;} // value;

      plans =
        lib.mapAttrsToList (
          name: value:
            variant "update" {
              object = name;
              inherit value;
            }
        )
        cfg.singletons
        ++ lib.mapAttrsToList (
          name: value:
            variant (
              if value.reconcile
              then "reconcile"
              else "upsert"
            ) {
              object = name;
              matchOn = value.match;
              inherit (value) scope;
              value = value.objects;
            }
        )
        cfg.objects;

      unsorted = lib.concatMapStringsSep "\n" builtins.toJSON plans;

      sorted =
        pkgs.runCommand "stalwart-provision.ndjson"
        {
          nativeBuildInputs = with pkgs.lua52Packages; [
            lua
            dkjson
          ];
        }
        ''
          gzip -d ${stalwart.package.src}/resources/schema/schema.json.gz -c > ./schema.json
          lua ${./provision-check-sort.lua} ${lib.escapeShellArg unsorted} $out ./schema.json ${lib.optionalString cfg.reloadSettings "--reload"}
        '';
    in {
      assertions = [
        {
          assertion = stalwart.enable;
          message = "<option>services.stalwart.provision</option> requires <option>services.stalwart.enable</option> to be true";
        }
        {
          assertion = stalwart.admin.enable;
          message = "<option>services.stalwart.provision</option> requires <option>services.stalwart.admin.enable</option> to be true";
        }
        {
          assertion = lib.versionAtLeast stalwart.package.version "0.16";
          message = "<option>services.stalwart.provision</option> requires <option>services.stalwart.package</option> to be at least version 0.16";
        }
      ];

      systemd.services.stalwart-provision = {
        description = "Stalwart Configuration Provisioning";
        wantedBy = ["multi-user.target"];
        # VENDOR PATCH (vs PR #552103): `partOf = ["stalwart.service"]`
        # removed and ExecStartPost added. On the pinned stalwart 0.16.22
        # the apply+reload Action swaps the in-memory core but does NOT
        # spawn/kill LISTENER sockets - provisioned listeners only bind on
        # a process restart (VM transcripts 2026-10-16: boot apply
        # "Done ... 0 failed" yet ss showed the DEFAULT listener set;
        # `systemctl restart stalwart` then bound the plan's listeners).
        # The unit therefore restarts stalwart AFTER a successful apply.
        # partOf MUST go with it: a stalwart restart would propagate back
        # into a provision restart (partOf semantics) and the unit would
        # restart stalwart again - an infinite loop. NixOS switch
        # semantics stay intact: a changed plan changes the unit file,
        # which restarts the provision unit on every deploy.
        after = ["stalwart.service"];
        serviceConfig = let
          shortBashScript = script: "${lib.getExe pkgs.bash} -c ${lib.escapeShellArg script}";
        in {
          Type = "oneshot";
          # Bounded wait: the ExecStartPre probe must never wedge a NixOS
          # switch forever — Type=oneshot defaults to an INFINITE start
          # timeout, so a management listener that never answers holds the
          # whole boot/switch transaction hostage (2026-10-17 pbx host
          # burn, 43-min hang). Fail visibly instead: a failed provision
          # unit is a red switch line, not a silent eternal loop.
          TimeoutStartSec = "3min";
          LoadCredential = let
            uname = stalwart.admin.username;
          in [
            "password:${stalwart.credentials.${uname} or stalwart.admin.username}"
          ];

          # stalwart does not currently notify systemd that it has started
          # see https://github.com/stalwartlabs/stalwart/pull/2383
          ExecStartPre = shortBashScript "until ${pkgs.curl}/bin/curl --fail ${lib.escapeShellArg cfg.url} &> /dev/null; do sleep 0.25; done";
          ExecStart = shortBashScript "STALWART_PASSWORD=`systemd-creds cat password` ${lib.getExe pkgs.stalwart-cli} apply --file ${sorted}";
          ExecStartPost = shortBashScript "${pkgs.systemd}/bin/systemctl try-restart stalwart.service";
          Environment = [
            "STALWART_URL=${lib.escapeShellArg cfg.url}"
            "STALWART_USER=${lib.escapeShellArg stalwart.admin.username}"
          ];
        };
      };
    }
  );
  meta = {
    maintainers = with lib.maintainers; [
      hexstella
    ];
    # meta.doc omitted, shares the main stalwart module documentation
  };
}
