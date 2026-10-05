# Devshell + formatter, extracted from flake.nix 2026-10-05 (flake-parts
# module split).
{
  perSystem = {
    pkgs,
    ...
  }: {
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
  };
}
