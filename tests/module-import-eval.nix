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
        # Explicit stateVersion: kills the "defaulting to 26.11" eval
        # warning (fleet convention 26.05).
        system.stateVersion = "26.05";
        # Both wrappers at once: the co-existence proof (an option conflict
        # or broken merge between the two modules fails HERE, on both
        # arches, before any consumer hits it).
        services = {
          mail-server = {
            enable = true;
            hostname = "import-check.invalid";
          };
          dmarc-monitor.enable = true;
        };
      }
    ];
  };

  cfg = eval.config;

  # M14 (2026-09-22): the hardening options must be OFF by default. v0.15.5
  # already ships two conservative inbound rate limiters (README ledger:
  # DEFAULT_SETTINGS) and DNSBL needs real resolver DNS (DNS-less E2E lesson,
  # same class as pyzor). Default posture = ZERO emitted keys for either.
  defaultSettings = cfg.services.stalwart.settings;

  # The enabled shapes must render exactly as verified against v0.15.5
  # (limiter keys/rate; dnsbl scope/zone/tag as QUOTED expression constants -
  # unquoted zone strings die in the expression tokenizer).
  evalHardened = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ../modules/mail-server.nix
      {
        system.stateVersion = "26.05";
        services = {
          mail-server = {
            enable = true;
            hostname = "import-check.invalid";
            rateLimits = {
              enable = true;
              rate = "100/1h";
              keys = ["sender_domain" "remote_ip"];
            };
            spamFilter.dnsbl.servers.hardcore = {
              scope = "ip";
              zone = "zen.spamhaus.org";
              tag = "spamhaus-hit";
            };
          };
        };
      }
    ];
  };
  hardened = evalHardened.config.services.stalwart.settings;

  # Invalid inputs must trip the module's eval-time assertions. NixOS
  # assertions are enforced in toplevel (not built here), so the contract is
  # the ASSERTION LIST contents.
  evalBadKey = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ../modules/mail-server.nix
      {
        system.stateVersion = "26.05";
        services = {
          mail-server = {
            enable = true;
            hostname = "import-check.invalid";
            rateLimits = {
              enable = true;
              # The plausible-but-wrong spelling (v0.15.5 uses authenticated_as).
              keys = ["auth_as"];
            };
          };
        };
      }
    ];
  };
  badKeyTrips = lib.any (a: lib.hasInfix "invalid throttle key" a.message) evalBadKey.config.assertions;

  evalEmptyZone = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ../modules/mail-server.nix
      {
        system.stateVersion = "26.05";
        services = {
          mail-server = {
            enable = true;
            hostname = "import-check.invalid";
            spamFilter.dnsbl.servers.empty = {
              scope = "ip";
              zone = "";
            };
          };
        };
      }
    ];
  };
  emptyZoneTrips = lib.any (a: lib.hasInfix "non-empty DNSBL zone" a.message) evalEmptyZone.config.assertions;

  # The option surface itself: a consumer evaluating `services.mail-server.*`
  # or `services.dmarc-monitor.*` must find real options (with descriptions
  # that survive the docs pipeline - dmarc-eval already proves that side).
  servicesOptions = eval.options.services;
  hasMailServer = lib.hasAttr "mail-server" servicesOptions;
  hasDmarcMonitor = lib.hasAttr "dmarc-monitor" servicesOptions;

  renderedAttrs = {
    stalwartEnabled = cfg.services.stalwart.enable;
    parsedmarcEnabled = cfg.services.parsedmarc.enable;
    hostname = cfg.services.mail-server.hostname;
    inherit hasMailServer hasDmarcMonitor;
    inherit badKeyTrips emptyZoneTrips;
    defaultHasQueue = defaultSettings ? queue;
    # NOTE: settings DOES carry spam-filter.resource by default (the nixpkgs
    # module's external-rules pointer) - the absence contract is scoped to
    # the DNSBL subtree this wrapper owns.
    defaultHasDnsbl = (defaultSettings."spam-filter" or {}) ? dnsbl;
    limiterRate = hardened.queue.limiter.inbound.wrapper-sustained.rate;
    limiterKeys = hardened.queue.limiter.inbound.wrapper-sustained.key;
    dnsblScope = hardened.spam-filter.dnsbl.server.hardcore.scope;
  };
  rendered = builtins.toJSON renderedAttrs;
in
  assert hasMailServer || throw "module-import-eval: services.mail-server option surface missing - the export-surface contract is broken (nixosModules.default no longer carries mail-server.nix).";
  assert hasDmarcMonitor || throw "module-import-eval: services.dmarc-monitor option surface missing - the export-surface contract is broken (nixosModules.default no longer carries dmarc-monitor.nix).";
  assert !renderedAttrs.defaultHasQueue || throw "module-import-eval: default settings must not contain queue.* keys - the wrapper's rateLimits default OFF posture is broken and consumers silently diverge from upstream DEFAULT_SETTINGS.";
  assert !renderedAttrs.defaultHasDnsbl || throw "module-import-eval: default settings must not contain spam-filter.dnsbl.* keys - the DNSBL default OFF posture (DNS-less E2E lesson) is broken.";
  assert hardened.queue.limiter.inbound.wrapper-sustained.rate == "100/1h" || throw "module-import-eval: rateLimits.rate did not render into queue.limiter.inbound.<id>.rate.";
  assert hardened.queue.limiter.inbound.wrapper-sustained.key == ["sender_domain" "remote_ip"] || throw "module-import-eval: rateLimits.keys did not render into queue.limiter.inbound.<id>.key.";
  assert hardened.spam-filter.dnsbl.server.hardcore.scope == "ip" || throw "module-import-eval: dnsbl scope did not render.";
  assert hardened.spam-filter.dnsbl.server.hardcore.zone == "'zen.spamhaus.org'" || throw "module-import-eval: dnsbl zone must render as a QUOTED expression constant ('zone') - unquoted values fail the v0.15.5 expression tokenizer.";
  assert hardened.spam-filter.dnsbl.server.hardcore.tag == "'spamhaus-hit'" || throw "module-import-eval: dnsbl tag must render as a quoted expression constant.";
  assert renderedAttrs.badKeyTrips || throw "module-import-eval: an invalid rateLimits key (auth_as) did not trip the throttle-key assertion.";
  assert renderedAttrs.emptyZoneTrips || throw "module-import-eval: an empty dnsbl zone did not trip the zone assertion.";
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
          grep -q '"defaultHasQueue":false' "$renderedPath"
          grep -q '"defaultHasDnsbl":false' "$renderedPath"
          grep -q '"limiterRate":"100/1h"' "$renderedPath"
          grep -q '"limiterKeys":["sender_domain","remote_ip"]' "$renderedPath"
          grep -q '"dnsblScope":"ip"' "$renderedPath"
          grep -q '"badKeyTrips":true' "$renderedPath"
          grep -q '"emptyZoneTrips":true' "$renderedPath"
          touch "$out"
        ''
      ];
    }
