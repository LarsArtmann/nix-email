{
  description = "nix-email: declarative mail stack (Stalwart server + DMARC report monitoring) for LarsArtmann hosts";

  inputs = {
    # Pinned to the same nixpkgs rev as SystemNix (compat doctrine):
    # services.stalwart (package pinned to 0.15.5 by nixpkgs - the 0.16.x
    # package exists as stalwart_0_16 but is NOT yet compatible with the
    # module), services.parsedmarc 11.0.1, services.mailpit, swaks
    # 20240103.0, imapsync 2.314 all verified present.
    nixpkgs.url = "github:NixOS/nixpkgs/eaad089433ca2bb662274377d33df3d0e51ef28b";

    # flake-parts (SystemNix / nix-international-telephony pattern).
    # nixpkgs-lib follows OUR pinned nixpkgs, so perSystem's `lib` special
    # arg is the same lib the modules and tests evaluate against - no
    # second nixpkgs rev enters the lock.
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  # NOTE: keep the ellipsis - Nix ALWAYS passes `self` to outputs, and
  # flake-parts additionally needs the whole `inputs` set. A closed
  # pattern (the "flake lint nit" of commit a4fc343) broke evaluation:
  # "function 'outputs' called with unexpected argument 'self'".
  outputs = inputs @ {
    self,
    flake-parts,
    nixpkgs,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      flake.nixosModules = {
        # The full stack: mail-server + dmarc-monitor. Import this when wiring
        # a host; enable the pieces you need. mailpit is consumed directly
        # from nixpkgs in devshells/tests (services.mailpit.instances) - a
        # wrapper around a single-instance option adds nothing.
        default = {
          imports = [
            ./modules/mail-server.nix
            ./modules/dmarc-monitor.nix
          ];
        };
        mail-server = import ./modules/mail-server.nix;
        dmarc-monitor = import ./modules/dmarc-monitor.nix;
      };

      # Throwaway demo host for `nix run .#vm` (see apps.vm below): boots the
      # full stack with a provisioned demo account + catch-all. NOT a consumer
      # template - real hosts wire the modules in SystemNix (AGENTS.md:
      # consumer layers live there). `nix flake check` evaluates this
      # toplevel, so the demo cannot rot silently (nix-international-telephony's
      # pbx-prod pattern). Provisioning recipe mirrors tests/stalwart-e2e.nix
      # ("roles": ["user"] is REQUIRED; catch-all = the bare "@domain" address).
      flake.nixosConfigurations.demo = nixpkgs.lib.nixosSystem {
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
            imports = [
              (modulesPath + "/virtualisation/qemu-vm.nix")
            ];
            services.mail-server = {
              enable = true;
              hostname = "mail.demo.invalid";
              # The default loopback bind only serves inside the guest; the
              # demo forwards host:8080 to the web admin/JMAP/API listener.
              httpBind = "0.0.0.0:8080";
            };
            # dmarc-monitor stays OFF: parsedmarc polls a real rua mailbox,
            # which a throwaway .invalid VM cannot have (ROADMAP D1).
            services.stalwart.settings = {
              authentication.fallback-admin = {
                user = "admin";
                secret = "demo-admin";
              };
              # Tested posture from stalwart-e2e: pyzor's public host adds
              # config-error risk for zero demo value.
              spam-filter.pyzor.enable = false;
            };
            # Headless (telephony hosts/pbx): the console goes to stdio, so
            # `nix run .#vm` works from any terminal. Ports bind 127.0.0.1
            # on the host - unprivileged, no LAN clash.
            virtualisation = {
              graphics = false;
              memorySize = 2048;
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
            services.getty.autologinUser = "root";
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
                api = "curl -fsS -u admin:demo-admin -H 'Content-Type: application/json' -X POST http://127.0.0.1:8080/api/principal -d";
              in ''
                # Wait for the management API: the auth'd GET is the same
                # request stalwart-e2e asserts works before any POST.
                for i in $(seq 1 120); do
                  if curl -fsS -u admin:demo-admin \
                      http://127.0.0.1:8080/api/principal >/dev/null 2>&1; then
                    break
                  fi
                  sleep 1
                done
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

      # `pkgs` is provided by flake-parts' built-in nixpkgs module
      # (inputs'.nixpkgs.legacyPackages - the semantics the tests were
      # verified against). NOTE: inside perSystem use `pkgs.lib`, not a
      # bare `lib` - that is the shape proven in
      # nix-international-telephony; redefining _module.args.pkgs here is
      # NOT (it leaves pkgs unbound in this flake-parts rev).
      perSystem = {
        pkgs,
        system,
        ...
      }: {
        # NixOS VM tests only run reliably on x86_64-linux. MEASURED
        # 2026-09-15 (one emulated stalwart-e2e attempt on an x86 host with
        # qemu-aarch64 binfmt): the aarch64 guest BUILDS and BOOTS fine
        # (arm64 kernel + systemd reach userspace), but TCG emulation is so
        # slow that boot alone (~6 min) exceeds the test driver's
        # shell-connect timeout, and a full E2E (cert generation + the
        # ~131 s of DNS-less resolver stalls) would run well over an hour.
        # Decision: documented-manual - NOT worth CI time; anyone porting to
        # aarch64 re-runs it on real ARM hardware. The pure-eval contract
        # test below is arch-independent and runs everywhere.
        checks =
          {
            dmarc-eval = import ./tests/dmarc-eval.nix {inherit nixpkgs system;};
          }
          // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            stalwart-e2e = import ./tests/stalwart-e2e.nix {inherit pkgs;};
            stalwart-relay-e2e = import ./tests/stalwart-relay-e2e.nix {inherit pkgs;};
            parsedmarc-e2e = import ./tests/parsedmarc-e2e.nix {inherit pkgs;};
          };

        # Tool environment for `nix develop` (and the BuildFlow tool runners,
        # which execute ruff/mypy/pytest/dprint inside this shell). Minimal on
        # purpose: this repo's real gate is `nix flake check` (VM tests), not a
        # devshell toolchain.
        devShells.default = pkgs.mkShellNoCC {
          packages = [
            pkgs.alejandra
            pkgs.python3
          ];
        };

        # `nix fmt` - the one .nix formatter for this repo (dprint covers
        # json/yaml/markdown only).
        formatter = pkgs.alejandra;

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
    };
}
