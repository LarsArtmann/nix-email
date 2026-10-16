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
}: {
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
          stalwart.provision = {
            singletons = {
              # Tested posture from stalwart-e2e: pyzor's public host adds
              # network dependence + config-error risk for zero demo value.
              SpamPyzor.enable = false;
            };
            objects = {
              Account = {
                reconcile = true;
                match = ["name"];
                objects = {
                  demo = {
                    # 0.16 schema: User.name IS the primary address - the
                    # quickstart login demo@mail.demo.test is the account
                    # NAME, not a separate emailAddress field.
                    "@type" = "User";
                    name = "demo@mail.demo.test";
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
                    name = "catchall@mail.demo.test";
                    domainId = "#domain";
                    roles."@type" = "User";
                  };
                };
              };
              Domain.objects.domain.catchAllAddress = "catchall@mail.demo.test";
            };
          };
          getty.autologinUser = "root";
        };
        environment.etc."demo-admin-secret" = {
          mode = "0600";
          text = "demo-admin";
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
        environment.systemPackages = [pkgs.swaks pkgs.curl];
        # Printed by every root login shell (the autologin getty shows it).
        environment.etc."profile.d/mail-demo-banner.sh".text = ''
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
             Unauthenticated inbound lands in Junk Mail (spam filter);
             authenticated submission lands in INBOX - both verified.
          ==================================================================
          BANNER
        '';
      })
    ];
  };

  perSystem = {
    pkgs,
    system,
    ...
  }: {
    # Throwaway demo VM: `nix run .#vm` (x86_64-linux only - same
    # constraint as the VM tests above).
    apps = pkgs.lib.optionalAttrs (system == "x86_64-linux") {
      vm = {
        type = "app";
        program = "${self.nixosConfigurations.demo.config.system.build.vm}/bin/run-demo-vm";
        meta.description = "Boot the demo mail stack as a throwaway QEMU VM";
      };
    };
  };
}
