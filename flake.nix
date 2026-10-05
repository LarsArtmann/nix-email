{
  description = "nix-email: declarative mail stack (Stalwart server + DMARC report monitoring) for LarsArtmann hosts";

  inputs = {
    # Pinned to the same nixpkgs rev as SystemNix (compat doctrine):
    # services.stalwart (package pinned to 0.15.5 by nixpkgs - the 0.16.x
    # package exists as stalwart_0_16 but is NOT yet compatible with the
    # module), services.parsedmarc 11.0.1, services.mailpit, swaks
    # 20240103.0, imapsync 2.314 all verified present.
    # ADVANCED 2026-09-22 eaad0894 -> 6774f7bc to track SystemNix's lock
    # (their nixpkgs floats nixos-unstable; presence list re-verified:
    # stalwart 0.15.5, parsedmarc 11.0.1, mailpit 1.31.1, swaks 20240103.0,
    # imapsync 2.314).
    nixpkgs.url = "github:NixOS/nixpkgs/6774f7bc253789b113a4f39285dc0fa100abeacc";

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
  # Only `flake-parts` stays in the destructure since the module split
  # (2026-10-05): `self`/`nixpkgs` ride in `inputs` for the sub-modules'
  # module args, and named-but-unused patterns trip deadnix + statix.
  outputs = inputs @ {flake-parts, ...}: let
    # EVAL-TIME GUARDS (SystemNix allEvalGuards pattern) live in
    # flake-modules/lock-guards.nix. MEASURED 2026-09-22: `nix flake lock`
    # is NOT outputs-forcing - it neither runs these guards nor forces
    # check leaves; drift that moves the lock behind nix's back is caught
    # at the next outputs-forcing command (details in that file).
    allEvalGuards = import ./flake-modules/lock-guards.nix {
      lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);
    };
  in
    builtins.seq allEvalGuards
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      # flake-parts module split (2026-10-05): each file contributes
      # flake-level and/or perSystem outputs. `checks` and `demo-vm`
      # receive `inputs`/`self` as module args; perSystem files destructure
      # `pkgs` (flake-parts' built-in nixpkgs module) and use `pkgs.lib`.
      imports = [
        ./flake-modules/nixos-modules.nix
        ./flake-modules/demo-vm.nix
        ./flake-modules/checks.nix
        ./flake-modules/devshells.nix
      ];
    };
}
