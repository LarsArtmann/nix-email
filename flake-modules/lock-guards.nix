# EVAL-TIME GUARDS (SystemNix flake.nix allEvalGuards pattern), extracted
# from flake.nix 2026-10-05. Parsed eagerly via builtins.seq around
# mkFlake, so every OUTPUTS-FORCING command (nix eval/check/build/
# `nix run`; CI's `nix flake check` included) fails loudly on a
# fleet-compat regression instead of shipping a silently drifted lock to
# every consumer. MEASURED 2026-09-22: `nix flake lock` is NOT
# outputs-forcing - it neither runs these guards nor forces check leaves
# (a thrown check value left lock green; an UNDEFINED VARIABLE anywhere
# in flake.nix failed lock, because that is a PARSE-time scope error,
# which also solves the 2026-09-17 "lock surfaced the broken checks"
# mystery as parse-scope, not eval). Drift that moves the lock behind
# nix's back is therefore caught at the next outputs-forcing command,
# not by lock.
{
  lockFile,
  ...
}: let
  # The fleet-verified nixpkgs pin (compat doctrine, AGENTS.md
  # Conventions). SystemNix floats `nixos-unstable`, so its lock moves
  # autonomously (auto-daemon); this constant is the rev both locks
  # shared at the last coordinated advance (2026-09-22: SystemNix lock
  # 6774f7bc, presence list re-verified: stalwart 0.15.5, parsedmarc
  # 11.0.1, mailpit 1.31.1, swaks 20240103.0, imapsync 2.314). When the
  # guard fires, the fleet has moved: diff the two flake.locks, re-run
  # the presence list, advance BOTH, then update this constant.
  fleetNixpkgsPin = "6774f7bc253789b113a4f39285dc0fa100abeacc";

  nixpkgsNode = lockFile.nodes.nixpkgs or (throw "flake.lock has no nixpkgs node");

  # Registry trap (1:1 from SystemNix): the nix global registry rewrites
  # github: URLs to tarball pointers that can be stale by months.
  nixpkgsTarballGuard = assert (nixpkgsNode.original.type or "unknown")
  == "github"
  || throw ''
    nixpkgs flake.lock regression: original type is "${nixpkgsNode.original.type or "unknown"}", expected "github".
    The nix global registry rewrote nixpkgs to a tarball which may be stale.
    Fix: manually edit flake.lock nodes.nixpkgs.original back to type "github".
  ''; true;

  nixpkgsPinGuard = let
    lockRev = nixpkgsNode.locked.rev or "unknown";
  in
    assert lockRev
    == fleetNixpkgsPin
    || throw ''
      nixpkgs pin drift vs the SystemNix fleet pin (compat doctrine):
        flake.lock rev: ${lockRev}
        fleet pin:     ${fleetNixpkgsPin}
      SystemNix floats nixos-unstable, so its lock moves autonomously.
      Fix: diff the two flake.locks, re-verify the presence list
      (stalwart/parsedmarc/mailpit/swaks/imapsync per AGENTS.md),
      advance both pins together, update fleetNixpkgsPin here.
    ''; true;

  # A dropped `follows` smuggles a second nixpkgs rev into every consumer
  # lock (flake.lock encodes follows as a node-name LIST; a real input is
  # a plain node-name STRING - the drop is exactly what this guard
  # catches: the 2026-09-22 negative test smuggled
  # nix-community/nixpkgs.lib 5bdaa90a into the lock within one
  # `nix flake lock`).
  flakePartsFollowsGuard = let
    follows = lockFile.nodes.flake-parts.inputs.nixpkgs-lib or null;
  in
    assert follows
    == ["nixpkgs"]
    || throw ''
      flake-parts input regression: nodes.flake-parts.inputs.nixpkgs-lib
      is ${builtins.toJSON follows}, expected the single follow ["nixpkgs"].
      A dropped follow smuggles a second nixpkgs rev into every consumer lock.
      Fix: restore inputs.flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs"
      in flake.nix, then `nix flake lock`.
    ''; true;
in
  builtins.seq nixpkgsTarballGuard (builtins.seq nixpkgsPinGuard flakePartsFollowsGuard)
