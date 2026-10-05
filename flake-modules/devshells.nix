# Devshell + formatter, extracted from flake.nix 2026-10-05 (flake-parts
# module split).
{
  perSystem = {pkgs, ...}: {
    # Tool environment for `nix develop` (and the BuildFlow tool runners,
    # which execute ruff/mypy/pytest/dprint inside this shell). Minimal on
    # purpose: this repo's real gate is `nix flake check` (VM tests), not a
    # devshell toolchain. actionlint + shellcheck are CI-parity tooling:
    # CI's actionlint runs WITH shellcheck, so a shellcheck-less local
    # machine shipped SC2016/SC2064 reds CI saw and buildflow could not
    # (2026-10-05); both live here so local actionlint is never blind.
    devShells.default = pkgs.mkShellNoCC {
      packages = [
        pkgs.alejandra
        pkgs.actionlint
        pkgs.python3
        pkgs.shellcheck
      ];
    };

    # `nix fmt` - the one .nix formatter for this repo (dprint covers
    # json/yaml/markdown only).
    formatter = pkgs.alejandra;
  };
}
