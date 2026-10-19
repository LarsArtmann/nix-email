# The throwaway demo host (`nix run .#vm`) and its app, extracted from
# flake.nix 2026-10-05 (flake-parts module split).
#
# 0.16 REWORK (2026-10-16): provisioning is DECLARATIVE now - the domain,
# demo account, and catch-all ride services.stalwart.provision (the
# vendored module's stalwart-cli apply unit), replacing the old
# mail-demo-provision curl oneshot (POST /api/principal died with the 0.16
# REST API). Account passwords go through stalwart's set-time strength
# check (zxcvbn), so the demo secret is a long passphrase, and they live
# in the (throwaway) Nix store plan - the fallback ADMIN password is the
# only one routed through a systemd credential file.
{
  inputs,
  self,
  ...
}: let
  common = import ../tests/common.nix;
in {
  # Throwaway demo host for `nix run .#vm` (see apps.vm below): boots the
  # full stack with a provisioned demo account + catch-all. NOT a consumer
  # template - real hosts wire the modules in SystemNix (AGENTS.md:
  # consumer layers live there). The catch-all = Domain.catchAllAddress
  # pointing at the catchall account's address (0.16 object model; the
  # pre-0.16 "@domain literal email" trick is gone).
  flake.nixosConfigurations.demo = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.default
      ({
        modulesPath,
        pkgs,
        ...
      }: {
        # The demo IS a VM (telephony hosts/pbx pattern): importing
        # qemu-vm.nix defines the virtualisation.* options below and
        # shapes the toplevel for `system.build.vm`. hostName also names
        # the runner script (run-demo-vm, via system.name).
        networking.hostName = "demo";
        # Explicit NixOS stateVersion: kills the "not set, defaulting
        # to 26.11" eval warning (fleet convention 26.05, matching the
        # e2e relay node).
        system.stateVersion = "26.05";
        imports = [
          (modulesPath + "/virtualisation/qemu-vm.nix")
          # DNS-less-VM provision patches (DnsResolver Cloudflare + pyzor
          # off, with the 2026-10-18 demo boot-race rationale): the
          # canonical copy lives in tests/common.nix.
          common.dnslessVmPatches
        ];
        services = {
          mail-server = {
            enable = true;
            hostname = "mail.demo.test";
            # The default loopback bind only serves inside the guest; the
            # demo forwards host:8080 to the web admin/JMAP/API listener.
            httpBind = "0.0.0.0:8080";
            # Throwaway VM: the fallback-admin password is a plain file
            # (real hosts: sops template, README go-live runbook).
            admin.secretFile = "/etc/demo-admin-secret";
            # The catch-all address belongs to the account provisioned
            # below (stalwart apply patches the wrapper Domain object).
            # Set via the provision extension, not a wrapper option:
            # extending a wrapper-owned object id MERGES (types.attrs),
            # it does not replace.
          };

          # dmarc-monitor stays OFF: parsedmarc polls a real rua mailbox,
          # which a throwaway .invalid VM cannot have (ROADMAP D1).
          stalwart.provision.objects = {
            Account = {
              reconcile = true;
              match = ["name"];
              objects = {
                demo = {
                  # 0.16 schema: User.name is the LOCAL PART; the quickstart
                  # login demo@mail.demo.test synthesizes as
                  # name@<Domain(domain).name> (hostname = mail.demo.test).
                  "@type" = "User";
                  name = "demo";
                  domainId = "#domain";
                  roles."@type" = "User";
                  # Strength-checked by stalwart at apply time (zxcvbn):
                  # a bare "demo" is rejected - keep the passphrase long.
                  credentials = [
                    {
                      "@type" = "Password";
                      secret = "demo-nixemail-2026";
                    }
                  ];
                };
                catchall = {
                  "@type" = "User";
                  name = "catchall";
                  domainId = "#domain";
                  roles."@type" = "User";
                };
              };
            };
            Domain.objects.domain.catchAllAddress = "catchall@mail.demo.test";
          };
          getty.autologinUser = "root";
        };
        # Headless (telephony hosts/pbx): the console goes to stdio, so
        # `nix run .#vm` works from any terminal. Ports bind 127.0.0.1
        # on the host - unprivileged, no LAN clash.
        virtualisation = {
          graphics = false;
          memorySize = 2048;
          # (The old pin needed `qemu.enableSharedMemory = true` as a
          # workaround: its qemu-vm.nix defaulted it to false, dropping
          # the guest into emergency mode via vhost-user-fs EIO. The
          # 2026-09-22 pin advance to 6774f7bc retires it - that pin
          # defaults enableSharedMemory = useVirtiofs = true on linux,
          # verified by grep of the pin's qemu-vm.nix:756.)
          forwardPorts = [
            {
              from = "host";
              host.address = "127.0.0.1";
              # Host side is 18080, not 8080: dev servers squat on 8080,
              # and QEMU aborts loudly when a forward target is taken.
              host.port = 18080;
              guest.port = 8080;
            }
            {
              from = "host";
              host.address = "127.0.0.1";
              host.port = 2525;
              guest.port = 25;
            }
            {
              from = "host";
              host.address = "127.0.0.1";
              host.port = 2587;
              guest.port = 587;
            }
            {
              from = "host";
              host.address = "127.0.0.1";
              host.port = 2593;
              guest.port = 993;
            }
          ];
        };
        environment = {
          etc."demo-admin-secret" = {
            mode = "0600";
            text = "demo-admin";
          };
          systemPackages = [pkgs.swaks pkgs.curl];
          # Printed by every root login shell (the autologin getty shows it).
          etc."profile.d/mail-demo-banner.sh".text = ''
            cat <<'BANNER'
            ==================================================================
             nix-email demo VM - throwaway, all state dies with the process

               web admin / JMAP : http://localhost:18080  (admin / demo-admin)
               SMTP             : swaks --server localhost:2525 \\
                                    --to anyone@mail.demo.test \\
                                    --from you@example.com
               submission (STARTTLS) : localhost:2587  (demo@mail.demo.test / demo-nixemail-2026)
               IMAPS                 : localhost:2593  (demo@mail.demo.test / demo-nixemail-2026)

               Provisioned declaratively by stalwart-provision.service
               (stalwart-cli apply; journal: systemctl status). The catch-all
               accepts mail for ANY local part.
               Unauthenticated inbound MAY land in Junk Mail (spam scoring
               is score-based on 0.16, not a fixed rule - both INBOX and
               Junk landings observed 2026-10-18); authenticated
               submission lands in INBOX - both verified.
            ==================================================================
            BANNER
          '';
        };
      })
    ];
  };

  perSystem = {
    pkgs,
    system,
    ...
  }: {
    # Throwaway demo VM: `nix run .#vm` (x86_64-linux only - same
    # constraint as the VM tests above). The disk is NOT CWD-relative
    # anymore (2026-10-18, the demo.qcow2-in-git-status footgun): the
    # wrapper pins NIX_DISK_IMAGE to a per-user cache path so boots are
    # stable across runs and never pollute the working directory. The
    # runner's own NIX_DISK_IMAGE override (qemu-vm.nix) carries it.
    apps = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
      vm = {
        type = "app";
        program = "${pkgs.writeShellScript "run-demo-vm-app" ''
          set -eu
          if [ -z "''${HOME:-}" ]; then
            echo "nix-email demo: HOME unset - falling back to the CWD-relative disk" >&2
            exec ${self.nixosConfigurations.demo.config.system.build.vm}/bin/run-demo-vm
          fi
          disk_dir="''${XDG_CACHE_HOME:-$HOME/.cache}/nix-email-demo"
          mkdir -p "$disk_dir"
          export NIX_DISK_IMAGE="$disk_dir/demo.qcow2"
          exec ${self.nixosConfigurations.demo.config.system.build.vm}/bin/run-demo-vm
        ''}";
        meta.description = "Boot the demo mail stack as a throwaway QEMU VM (disk: ~/.cache/nix-email-demo/)";
      };
      # Host-side parsedmarc dry-run (V25): the script walks the check
      # closure itself, so the app only supplies the interpreter - the
      # nix CLI must come from the caller's PATH (it is what ran `nix
      # run` in the first place).
      host-parse-fixture = {
        type = "app";
        program = "${pkgs.writeShellScript "host-parse-fixture-app" ''
          exec ${pkgs.python3}/bin/python3 ${../scripts/host-parse-fixture.py} "$@"
        ''}";
        meta.description = "Run the PINNED parsedmarc parser on a fixture file (~30 s host-side dry-run; --check parsedmarc-e2e)";
      };
    };
  };
}
