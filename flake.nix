{
  description = "nix-email: declarative mail stack (Stalwart server + DMARC report monitoring) for LarsArtmann hosts";

  inputs = {
    # Pinned to the same nixpkgs rev as SystemNix (compat doctrine):
    # services.stalwart runs Stalwart 0.16.x via pkgs.stalwart_0_16 +
    # the VENDORED 0.16 module (modules/stalwart-module/, from nixpkgs
    # PR #552103 - nixpkgs' own stalwart.nix is still the 0.15 module at
    # this rev (pkgs.stalwart = 0.15.5, PR OPEN 2026-10-28) and is
    # disabledModules-swapped by our wrapper.
    # Verified present at this rev (nix eval 2026-10-28): stalwart_0_16
    # 0.16.26 (x86_64 needs x86-64-v2 - VMs set -cpu max, see
    # tests/common.nix v2CpuPatches), parsedmarc 11.0.2 (py3.14,
    # imapclient 4.1.0 - the starttls() pin is REVERTED), services.mailpit
    # 1.31.4, swaks 20240103.0, imapsync 2.314, stalwart-cli 1.0.13 (the
    # provision CLI - must stay >= 1.0.2). PR #566282 (parsedmarc
    # OpenSearch switch) IS in this pin: provision.elasticsearch is
    # mkRemovedOptionModule - the wrapper ports to provision.opensearch.
    # ADVANCED 2026-10-28 6774f7bc -> fe132422 to track SystemNix's lock
    # (their nixpkgs floats nixos-unstable; they moved first - their
    # follows already forced this rev onto the wrapper's contract check).
    nixpkgs.url = "github:NixOS/nixpkgs/fe13242281a67641c0102cdb1087f0ebe586c7df";

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
        ./flake-modules/probe-package.nix
      ];
    };
}
