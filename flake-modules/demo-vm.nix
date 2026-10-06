# The throwaway demo host (`nix run .#vm`) and its app, extracted from
# flake.nix 2026-10-05 (flake-parts module split).
{
  inputs,
  self,
  ...
}: {
  # Throwaway demo host for `nix run .#vm` (see apps.vm below): boots the
  # full stack with a provisioned demo account + catch-all. NOT a consumer
  # template - real hosts wire the modules in SystemNix (AGENTS.md:
  # consumer layers live there). `nix flake check` evaluates this
  # toplevel, so the demo cannot rot silently (nix-international-telephony's
  # pbx-prod pattern). Provisioning recipe mirrors tests/stalwart-e2e.nix
  # ("roles": ["user"] is REQUIRED; catch-all = the bare "@domain"
  # address, created AFTER any rejection probe by nature - the demo
  # has none, README "Per-account semantics" ordering footgun).
  flake.nixosConfigurations.demo = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    modules = [
      self.nixosModules.default
      ({
        modulesPath,
        pkgs,
        ...
      }: let
        # sha512-crypt of "demo" (fixed salt => deterministic; the exact
        # hash format the webadmin uses for principal secrets).
        demoHash = "$6$nixemaildemo$oK4UNSKSdI4Ye5sGdvn8ZYPOFQ1e8rNpbn5w8cZ0Qiu6s1gkcSP.x7PGE67K.iPdJeRb6o3d8zoj9crztuLon0";
      in {
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
            hostname = "mail.demo.invalid";
            # The default loopback bind only serves inside the guest; the
            # demo forwards host:8080 to the web admin/JMAP/API listener.
            httpBind = "0.0.0.0:8080";
          };
          # dmarc-monitor stays OFF: parsedmarc polls a real rua mailbox,
          # which a throwaway .invalid VM cannot have (ROADMAP D1).
          stalwart.settings = {
            authentication.fallback-admin = {
              user = "admin";
              secret = "demo-admin";
            };
            # Tested posture from stalwart-e2e: pyzor's public host adds
            # network dependence + config-error risk for zero demo value.
            spam-filter.pyzor.enable = false;
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
        environment.systemPackages = [pkgs.swaks pkgs.curl];
        # Printed by every root login shell (the autologin getty shows it).
        environment.etc."profile.d/mail-demo-banner.sh".text = ''
          cat <<'BANNER'
          ==================================================================
           nix-email demo VM - throwaway, all state dies with the process

             web admin / JMAP / API : http://localhost:18080  (admin / demo-admin)
             SMTP                   : swaks --server localhost:2525 \\
                                      --to anyone@mail.demo.invalid \\
                                      --from you@example.com
             submission (STARTTLS)  : localhost:2587  (demo@mail.demo.invalid / demo)
             IMAPS                  : localhost:2593  (demo@mail.demo.invalid / demo)

             The catch-all accepts mail for ANY local part; provisioned
             by mail-demo-provision.service (journal: systemctl status).
             Unauthenticated inbound lands in Junk Mail (spam filter);
             authenticated submission lands in INBOX - both verified.
          ==================================================================
          BANNER
        '';
        systemd.services.mail-demo-provision = {
          description = "Provision the nix-email demo domain, account, and catch-all";
          wantedBy = ["multi-user.target"];
          after = ["stalwart.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = let
            # ABSOLUTE curl path + --max-time: systemd services run with
            # a minimal PATH (NOT environment.systemPackages), so a bare
            # `curl` is "command not found" and the || true's below
            # masked it - the oneshot exited SUCCESS having provisioned
            # NOTHING, and the 120s wait-loop burned on instant
            # command-not-found failures (transcript 2026-09-22,
            # unit-log lines 15-17). --max-time keeps a pre-ready API
            # (listener bound, requests held) from hanging a probe.
            api = "${pkgs.curl}/bin/curl -fsS --max-time 5 -u admin:demo-admin -H 'Content-Type: application/json' -X POST http://127.0.0.1:8080/api/principal -d";
            ready = "${pkgs.curl}/bin/curl -fsS --max-time 5 -u admin:demo-admin http://127.0.0.1:8080/api/principal";
          in ''
            # Wait for the management API: the auth'd GET is the same
            # request stalwart-e2e asserts works before any POST.
            ready=0
            for i in $(seq 1 120); do
              if ${ready} >/dev/null 2>&1; then
                ready=1
                break
              fi
              sleep 1
            done
            # Fail loudly rather than lie: a green unit that provisioned
            # nothing hid exactly this class of bug for five days.
            if [ "$ready" != "1" ]; then
              echo "management API not ready after 120s - demo NOT provisioned" >&2
              exit 1
            fi
            # Reboot-tolerant: conflicts from already-provisioned
            # principals are non-fatal; readiness is gated above.
            ${api} '{"type":"domain","name":"mail.demo.invalid"}' || true
            ${api} '{"type":"individual","name":"demo@mail.demo.invalid","emails":["demo@mail.demo.invalid"],"roles":["user"],"secrets":["${demoHash}"]}' || true
            ${api} '{"type":"individual","name":"catchall","emails":["catchall@mail.demo.invalid","@mail.demo.invalid"],"roles":["user"]}' || true
            echo "demo ready: SMTP/IMAP demo@mail.demo.invalid / demo (web admin on :8080, admin / demo-admin)"
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
