# Eval-time export-surface contract (TODO_LIST 2026-09-17 sweep, C03):
# `nixosModules.default` must import cleanly via `nixosSystem` on EVERY
# architecture this flake declares - the full wrapper surface (mail-server +
# dmarc-monitor in ONE toplevel) must eval, merge, and flip both wrapped
# services. dmarc-eval covers DMARC wiring only; stalwart-e2e covers runtime
# behavior on x86_64 only. Pure eval - no VM, runs on both arches.
{
  nixpkgs,
  system,
}: let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};

  eval = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ../modules/mail-server.nix
      ../modules/dmarc-monitor.nix
      {
        # Both wrappers at once: the co-existence proof (an option conflict
        # or broken merge between the two modules fails HERE, on both
        # arches, before any consumer hits it).
        services.mail-server = {
          enable = true;
          hostname = "import-check.invalid";
        };
        services.dmarc-monitor.enable = true;
      }
    ];
  };

  cfg = eval.config;

  # The option surface itself: a consumer evaluating `services.mail-server.*`
  # or `services.dmarc-monitor.*` must find real options (with descriptions
  # that survive the docs pipeline - dmarc-eval already proves that side).
  servicesOptions = eval.options.services;
  hasMailServer = lib.hasAttr "mail-server" servicesOptions;
  hasDmarcMonitor = lib.hasAttr "dmarc-monitor" servicesOptions;

  rendered = builtins.toJSON {
    stalwartEnabled = cfg.services.stalwart.enable;
    parsedmarcEnabled = cfg.services.parsedmarc.enable;
    hostname = cfg.services.mail-server.hostname;
    inherit hasMailServer hasDmarcMonitor;
  };
in
  assert hasMailServer || throw "module-import-eval: services.mail-server option surface missing - the export-surface contract is broken (nixosModules.default no longer carries mail-server.nix).";
  assert hasDmarcMonitor || throw "module-import-eval: services.dmarc-monitor option surface missing - the export-surface contract is broken (nixosModules.default no longer carries dmarc-monitor.nix).";
    builtins.derivation {
      name = "module-import-eval-${system}";
      inherit system;
      PATH = "${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin";
      passAsFile = ["rendered"];
      inherit rendered;
      builder = "/bin/sh";
      args = [
        "-c"
        ''
          grep -q '"stalwartEnabled":true' "$renderedPath"
          grep -q '"parsedmarcEnabled":true' "$renderedPath"
          grep -q '"hostname":"import-check.invalid"' "$renderedPath"
          grep -q '"hasMailServer":true' "$renderedPath"
          grep -q '"hasDmarcMonitor":true' "$renderedPath"
          touch "$out"
        ''
      ];
    }
