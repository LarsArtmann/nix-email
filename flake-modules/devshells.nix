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
        # BuildFlow resolves its tool runners inside this shell; without a
        # pin each run falls back to `nix run nixpkgs#<tool>` and picks up
        # registry-latest versions (lint/format results drift).
        pkgs.dprint
        pkgs.lychee
        pkgs.ruff
        # The contention-vs-failure bisect (06-12 f40): when any nix
        # command dies with EMPTY output under concurrent sessions, run
        # `nix-health` BEFORE debugging your diff.
        (pkgs.writeShellScriptBin "nix-health" "exec bash ${../scripts/nix-health-check.sh}")
      ];
    };

    # `nix fmt` - the UNIFIED formatter (2026-11-01): alejandra owns .nix,
    # dprint owns json/yaml/markdown/dockerfile (dprint.json; the archived
    # corridors stay excluded there). Alejandra-only `nix fmt` let markdown
    # ship un-dprint-checked (9 files reflowed at the 11-01 closeout) even
    # though `nix fmt -- . --check` is the CI + pre-push gate line; the
    # wrapper routes each path to its toolchain so both directions of the
    # gate cover everything. Unknown flags other than --check are ignored;
    # directories and nonexistent paths go to BOTH tools (fail-closed).
    formatter = pkgs.writeShellScriptBin "fmt" ''
      set -eu
      nix_paths=""
      dprint_paths=""
      check=0
      for arg in "$@"; do
        case "$arg" in
          --check) check=1 ;;
          -*) ;;
          *)
            if [ -d "$arg" ] || [ ! -e "$arg" ]; then
              nix_paths="$nix_paths $arg"
              dprint_paths="$dprint_paths $arg"
            elif [ "''${arg%.nix}" != "$arg" ]; then
              nix_paths="$nix_paths $arg"
            else
              dprint_paths="$dprint_paths $arg"
            fi
            ;;
        esac
      done
      if [ -z "''${nix_paths# }" ] && [ -z "''${dprint_paths# }" ]; then
        nix_paths="."
        dprint_paths="."
      fi
      status=0
      if [ -n "''${nix_paths# }" ]; then
        if [ "$check" = 1 ]; then
          ${pkgs.alejandra}/bin/alejandra --check $nix_paths || status=1
        else
          ${pkgs.alejandra}/bin/alejandra $nix_paths || status=1
        fi
      fi
      # dprint finds its configuration by walking up from the CWD, so the
      # dprint half only runs where dprint.json exists - the repo root, or
      # a subdirectory of it that carries its own config. Anywhere else
      # (BuildFlow's nix-fmt roundtrip copies the .nix files into a temp
      # dir and calls `nix fmt` there) the dprint half is SKIPPED with a
      # note instead of dying on discovery: those runs are alejandra-only
      # by construction, and the repo-root gate line always has the config
      # (dprint.json is tracked, so its absence there is a broken checkout
      # that CI reports as an unformatted tree).
      if [ -n "''${dprint_paths# }" ] && [ ! -f dprint.json ]; then
        echo "fmt: no dprint.json in $PWD - checking .nix only" >&2
        dprint_paths=""
      fi
      if [ -n "''${dprint_paths# }" ]; then
        if [ "$check" = 1 ]; then
          ${pkgs.dprint}/bin/dprint check $dprint_paths || status=1
        else
          ${pkgs.dprint}/bin/dprint fmt $dprint_paths || status=1
        fi
      fi
      exit $status
    '';

    # `nix run .#ruff-floor` - the CI ruff floor without the 10 s
    # `github:NixOS/nixpkgs/<rev>#ruff` eval walk (measured at the
    # 2026-11-01 CI runner, run 41265954894: the step spent its whole
    # 10 s budget on resolving ruff from the registry ref before any
    # linting). The app pins this flake's nixpkgs ruff, so the floor is
    # one eval hop and identical to what the devShell resolves.
    apps.ruff-floor = {
      type = "app";
      program = "${pkgs.ruff}/bin/ruff";
      meta.description = "Pinned ruff for the CI error-floor lint (E4,E7,E9,F) - no registry eval walk";
    };
  };
}
