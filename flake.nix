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

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
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
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          stalwart-e2e = import ./tests/stalwart-e2e.nix { inherit pkgs; };
          dmarc-eval = import ./tests/dmarc-eval.nix { inherit nixpkgs system; };
        }
      );
    };
}
