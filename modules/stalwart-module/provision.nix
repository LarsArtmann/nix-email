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

      # VENDOR PATCH (bootstrap endpoint, nix-email#4): the 0.16 binary
      # ignores static server.listener keys, so on a VIRGIN store only the
      # built-in default set is up (smtp 25 + http 8080) while cfg.url (the
      # consumer's httpBind) binds only AFTER this unit applies the
      # NetworkListener plan and restarts stalwart. Probing cfg.url alone
      # self-deadlocks for every httpBind port other than 8080 (2026-10-17
      # pbx burn: 43-min host wedge, bounded to a visible failure since).
      # The probe therefore accepts EITHER endpoint, the apply runs against
      # the one that answered, and the post-restart wait verifies cfg.url
      # itself - "provisioned listeners never activate" (the apply-succeeded
      # reload-validation class) now fails the unit instead of passing
      # silently.
      #
      # A bare `curl --fail` is NOT an identity test (2026-10-23 pbx burn):
      # the built-in port is Stalwart's only on a host that leaves it free.
      # There the webphone owns 127.0.0.1:8080 and answered the fallback on
      # the probe's FIRST tick - before a just-restarted stalwart had bound
      # cfg.url - so the whole plan was applied to the webphone (schema
      # refresh 404, red switch, exit 4). An endpoint is accepted only when
      # its unauthenticated JMAP session identifies Stalwart (/jmap/session
      # carries urn:ietf:params:jmap:core on BOTH the built-in and the
      # provisioned listener set). The loop keeps waiting while neither is
      # Stalwart, so a busy built-in port can never receive the plan; the
      # unit's TimeoutStartSec bounds the wait, and a foreign responder is
      # named in the journal once so the failure is diagnosable instead of
      # a silent timeout.
      #
      # Scripts live on store PATHS (writeShellScript), not inline in the
      # unit: systemd unit files are line-based and an embedded newline in
      # ExecStart dies with "Unbalanced quoting ... unit will not be
      # started" (first bind-e2e run, 2026-10-17).
      applyScript = pkgs.writeShellScript "stalwart-provision-apply" ''
        cfg_url=${lib.escapeShellArg cfg.url}
        built_in_url='http://127.0.0.1:8080'
        is_stalwart() {
          body=$(${pkgs.curl}/bin/curl --fail --silent --max-time 2 "$1/jmap/session" 2>/dev/null) || return 1
          case "$body" in
            *'"urn:ietf:params:jmap:core"'*) return 0 ;;
          esac
          return 1
        }
        chosen=""
        ticks=0
        warned=""
        until [ -n "$chosen" ]; do
          if is_stalwart "$cfg_url"; then
            chosen="$cfg_url"
          elif is_stalwart "$built_in_url"; then
            chosen="$built_in_url"
          else
            ticks=$((ticks + 1))
            if [ "$warned" = "" ] && [ $((ticks % 40)) -eq 0 ]; then
              if ${pkgs.curl}/bin/curl --fail --silent --max-time 2 "$built_in_url" &> /dev/null; then
                warned=1
                echo "stalwart-provision: a non-Stalwart HTTP service answers on $built_in_url - refusing to apply the plan through it, still waiting for $cfg_url" >&2
              fi
            fi
            sleep 0.25
          fi
        done
        echo "stalwart-provision: management API answering at $chosen (configured: $cfg_url)"
        STALWART_PASSWORD=`systemd-creds cat password` STALWART_URL="$chosen" ${lib.getExe pkgs.stalwart-cli} apply --file ${sorted}
      '';
      restartAndVerify = pkgs.writeShellScript "stalwart-provision-restart-verify" ''
        ${pkgs.systemd}/bin/systemctl try-restart stalwart.service
        i=0
        until ${pkgs.curl}/bin/curl --fail ${lib.escapeShellArg cfg.url} &> /dev/null; do
          i=$((i + 1))
          if [ "$i" -ge 240 ]; then
            echo "stalwart-provision: ${cfg.url} never came up within 60s of the post-apply restart - the provisioned listener set did not activate" >&2
            exit 1
          fi
          sleep 0.25
        done
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
        # The unit therefore restarts stalwart AFTER a successful apply and
        # then VERIFIES cfg.url came up (restartAndVerify above).
        # partOf MUST go with it: a stalwart restart would propagate back
        # into a provision restart (partOf semantics) and the unit would
        # restart stalwart again - an infinite loop. NixOS switch
        # semantics stay intact: a changed plan changes the unit file,
        # which restarts the provision unit on every deploy.
        after = ["stalwart.service"];
        serviceConfig = {
          Type = "oneshot";
          # Bounded wait: the probe+apply in ExecStart must never wedge a
          # NixOS switch forever — Type=oneshot defaults to an INFINITE start
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
          ExecStart = "${applyScript}";
          ExecStartPost = "${restartAndVerify}";
          Environment = [
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
