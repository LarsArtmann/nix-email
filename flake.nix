{
  description = "nix-email: declarative mail stack (Stalwart server + DMARC report monitoring) for LarsArtmann hosts";

  inputs = {
    # Pinned to the same nixpkgs rev as SystemNix (compat doctrine):
    # services.stalwart (package pinned to 0.15.5 by nixpkgs - the 0.16.x
    # package exists as stalwart_0_16 but is NOT yet compatible with the
    # module), services.parsedmarc 11.0.1, services.mailpit, swaks
    # 20240103.0, imapsync 2.314 all verified present.
    nixpkgs.url = "github:NixOS/nixpkgs/eaad089433ca2bb662274377d33df3d0e51ef28b";
  };

  # NOTE: no bare `self` in the pattern - Nix ALWAYS passes `self` to
  # outputs, so the signature must stay open (ellipsis) or keep self used.
  # A closed pattern without self ("flake lint nit" from commit a4fc343)
  # broke evaluation: "function 'outputs' called with unexpected argument
  # 'self'" - and deadnix would re-remove an unused self on every --fix.
  outputs = {nixpkgs, ...}: let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    nixosModules = {
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

    checks = forAllSystems (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
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
          // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
            stalwart-e2e = import ./tests/stalwart-e2e.nix {inherit pkgs;};
            stalwart-relay-e2e = import ./tests/stalwart-relay-e2e.nix {inherit pkgs;};
            parsedmarc-e2e = import ./tests/parsedmarc-e2e.nix {inherit pkgs;};
          };
      in
        checks
    );

    # Tool environment for `nix develop` (and the BuildFlow tool runners,
    # which execute ruff/mypy/pytest/dprint inside this shell). Minimal on
    # purpose: this repo's real gate is `nix flake check` (VM tests), not a
    # devshell toolchain.
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShellNoCC {
        packages = [
          pkgs.alejandra
          pkgs.python3
        ];
      };
    });

    # `nix fmt` - the one .nix formatter for this repo (dprint covers
    # json/yaml/markdown only).
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
  };
}
