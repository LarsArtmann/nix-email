# flake.nixosModules, extracted from flake.nix 2026-10-05 (flake-parts
# module split; paths are relative to THIS file, hence ../modules).
{
  flake.nixosModules = {
    # The full stack: mail-server + dmarc-monitor. Import this when wiring
    # a host; enable the pieces you need. mailpit is consumed directly
    # from nixpkgs in devshells/tests (services.mailpit.instances) - a
    # wrapper around a single-instance option adds nothing.
    default = {
      imports = [
        ../modules/mail-server.nix
        ../modules/dmarc-monitor.nix
      ];
    };
    mail-server = import ../modules/mail-server.nix;
    dmarc-monitor = import ../modules/dmarc-monitor.nix;
  };
}
