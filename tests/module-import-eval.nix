# Eval-time export-surface contract (TODO_LIST 2026-09-17 sweep, C03):
# `nixosModules.default` must import cleanly via `nixosSystem` on EVERY
# architecture this flake declares - the full wrapper surface (mail-server +
# dmarc-monitor in ONE toplevel) must eval, merge, and flip both wrapped
# services. dmarc-eval covers DMARC wiring only; stalwart-e2e covers runtime
# behavior on x86_64 only. Pure eval - no VM, runs on both arches.
#
# 0.16 REWORK (2026-10-16): `services.stalwart.settings` is now the
# config.json datastore descriptor only (0.16 removed TOML config); the
# wrapper's knobs render into `services.stalwart.provision` plan objects
# (MtaInboundThrottle / SpamDnsblServer / Cache / Metrics singletons+objects,
# typed per the 0.16 schema). The absence/hardening postures assert the PLAN,
# not TOML settings.
{
  nixpkgs,
  system,
}: let
  inherit (nixpkgs) lib;
  pkgs = nixpkgs.legacyPackages.${system};

  # Shared boilerplate for the four evals below: base stateVersion +
  # the minimal mail-server config every scenario starts from. Extra
  # scenarios ride extra modules - the module system deep-merges them
  # onto the base.
  mailServerBase = {
    # Explicit stateVersion: kills the "defaulting to 26.11" eval
    # warning (fleet convention 26.05).
    system.stateVersion = "26.05";
    services.mail-server = {
      enable = true;
      hostname = "import-check.invalid";
      # REQUIRED under 0.16: the fallback admin is the provisioning
      # CLI's only credential path.
      admin.secretFile = "/run/import-check-admin-secret";
    };
  };

  mkEval = extraModules:
    nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [../modules/mail-server.nix mailServerBase] ++ extraModules;
    };

  # Both wrappers at once: the co-existence proof (an option conflict
  # or broken merge between the two modules fails HERE, on both
  # arches, before any consumer hits it).
  eval = mkEval [
    ../modules/dmarc-monitor.nix
    {services.dmarc-monitor.enable = true;}
  ];

  cfg = eval.config;
  stalwart = cfg.services.stalwart;
  inherit (stalwart) provision;

  # M14 (2026-09-22): the hardening options must be OFF by default - the
  # default PLAN carries NO throttle, NO metrics, NO cache-TTL override,
  # and the DNSBL set is EMPTY (it exists only to reconcile away the
  # broken shipped default rows - see the wrapper's SpamDnsblServer
  # comment). (Upstream ships its own conservative inbound limiters and
  # DNSBL needs real resolver DNS - README ledger.)
  defaultSingletons = provision.singletons;
  defaultObjects = provision.objects;

  # The enabled shapes must render exactly as typed in the 0.16 schema:
  # throttle rate as {count, period-ms}, keys translated to the
  # MtaInboundThrottleKey enum, dnsbl as variant objects with QUOTED
  # expression constants (unquoted zone strings die in the expression
  # tokenizer).
  evalHardened = mkEval [
    {
      services.mail-server = {
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
    }
  ];
  hardened = evalHardened.config.services.stalwart.provision;

  # Invalid inputs must trip the module's eval-time assertions. NixOS
  # assertions are enforced in toplevel (not built here), so the contract is
  # the ASSERTION LIST contents.
  evalBadKey = mkEval [
    {
      services.mail-server.rateLimits = {
        enable = true;
        # The plausible-but-wrong spelling (upstream enum: authenticatedAs).
        keys = ["auth_as"];
      };
    }
  ];
  badKeyTrips = lib.any (a: lib.hasInfix "invalid throttle key" a.message) evalBadKey.config.assertions;

  evalEmptyZone = mkEval [
    {
      services.mail-server.spamFilter.dnsbl.servers.empty = {
        scope = "ip";
        zone = "";
      };
    }
  ];
  emptyZoneTrips = lib.any (a: lib.hasInfix "non-empty DNSBL zone" a.message) evalEmptyZone.config.assertions;

  # The option surface itself: a consumer evaluating `services.mail-server.*`
  # or `services.dmarc-monitor.*` must find real options - and the vendored
  # 0.16 module must be the one defining services.stalwart (the provision
  # option only exists there; its presence proves the disabledModules swap
  # worked and nixpkgs' 0.15 stalwart.nix is NOT in this evaluation).
  servicesOptions = eval.options.services;
  hasMailServer = lib.hasAttr "mail-server" servicesOptions;
  hasDmarcMonitor = lib.hasAttr "dmarc-monitor" servicesOptions;
  vendoredModuleActive = eval.options.services.stalwart ? provision;

  throttle = hardened.objects.MtaInboundThrottle.objects."wrapper-sustained";
  dnsbl = hardened.objects.SpamDnsblServer.objects.hardcore;

  renderedAttrs = {
    stalwartEnabled = stalwart.enable;
    stalwart016 = lib.versionAtLeast stalwart.package.version "0.16";
    parsedmarcEnabled = cfg.services.parsedmarc.enable;
    hostname = cfg.services.mail-server.hostname;
    inherit hasMailServer hasDmarcMonitor vendoredModuleActive;
    inherit badKeyTrips emptyZoneTrips;
    # config.json shape: datastore descriptor only.
    settingsType = stalwart.settings."@type" or "MISSING";
    settingsHasPath = stalwart.settings ? path;
    # Default posture: wrapper-managed hardening sets absent from the plan;
    # DNSBL set present but EMPTY (reconcile-destroy of the broken shipped
    # default rows - wrapper comment owns the why).
    defaultHasThrottle = defaultObjects ? MtaInboundThrottle;
    defaultDnsblEmpty = (defaultObjects.SpamDnsblServer.objects or null) == {};
    defaultHasMetrics = defaultSingletons ? Metrics;
    defaultHasCache = defaultSingletons ? Cache;
    defaultHasRelayStrategy = defaultSingletons ? MtaOutboundStrategy;
    # Hardened shapes render into the 0.16 object model.
    throttleRateCount = throttle.rate.count or 0;
    throttleRatePeriod = throttle.rate.period or 0;
    throttleKeys = lib.concatStringsSep "," throttle.key;
    dnsblVariant = dnsbl."@type" or "MISSING";
    dnsblZone = dnsbl.zone."else" or "MISSING";
    dnsblTag = dnsbl.tag."else" or "MISSING";
  };
  rendered = builtins.toJSON renderedAttrs;
in
  assert hasMailServer || throw "module-import-eval: services.mail-server option surface missing - the export-surface contract is broken (nixosModules.default no longer carries mail-server.nix).";
  assert hasDmarcMonitor || throw "module-import-eval: services.dmarc-monitor option surface missing - the export-surface contract is broken (nixosModules.default no longer carries dmarc-monitor.nix).";
  assert renderedAttrs.vendoredModuleActive || throw "module-import-eval: services.stalwart.provision option missing - the vendored 0.16 module did not replace nixpkgs' 0.15 stalwart.nix (disabledModules swap broken).";
  assert renderedAttrs.stalwart016 || throw "module-import-eval: the wrapped stalwart package must be >= 0.16.";
  assert renderedAttrs.settingsType == "RocksDb" || throw "module-import-eval: default settings must be the 0.16 config.json datastore descriptor (RocksDb).";
  assert renderedAttrs.settingsHasPath || throw "module-import-eval: default settings must carry the datastore path.";
  assert !renderedAttrs.defaultHasThrottle || throw "module-import-eval: default plan must not carry MtaInboundThrottle - the wrapper's rateLimits default OFF posture is broken.";
  assert renderedAttrs.defaultDnsblEmpty || throw "module-import-eval: default SpamDnsblServer set must be EMPTY (reconcile-destroy of broken shipped default rows) - a configured-by-default DNSBL breaks the DNS-less posture.";
  assert !renderedAttrs.defaultHasMetrics || throw "module-import-eval: default plan must not carry the Metrics singleton - metrics.enable default OFF is broken.";
  assert !renderedAttrs.defaultHasCache || throw "module-import-eval: default plan must not carry the Cache singleton - directoryCacheTtlNegative default (upstream 3600s) is broken.";
  assert !renderedAttrs.defaultHasRelayStrategy || throw "module-import-eval: default plan must not carry MtaOutboundStrategy - direct-to-MX (relay=null) is broken.";
  assert renderedAttrs.throttleRateCount == 100 || throw "module-import-eval: rateLimits.rate did not render into the throttle x:Rate count.";
  assert renderedAttrs.throttleRatePeriod == 3600000 || throw "module-import-eval: rateLimits.period must render as integer MILLISECONDS (0.16 duration encoding) - got ${toString renderedAttrs.throttleRatePeriod}.";
  assert renderedAttrs.throttleKeys == "senderDomain,remoteIp" || throw "module-import-eval: rateLimits.keys must translate to the MtaInboundThrottleKey enum (camelCase), order preserved.";
  assert renderedAttrs.dnsblVariant == "Ip" || throw "module-import-eval: dnsbl scope must select the SpamDnsblServer variant.";
  assert renderedAttrs.dnsblZone == "'zen.spamhaus.org'" || throw "module-import-eval: dnsbl zone must render as a QUOTED expression constant - unquoted values fail the expression tokenizer.";
  assert renderedAttrs.dnsblTag == "'spamhaus-hit'" || throw "module-import-eval: dnsbl tag must render as a quoted expression constant.";
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
          grep -q '"stalwart016":true' "$renderedPath"
          grep -q '"parsedmarcEnabled":true' "$renderedPath"
          grep -q '"hostname":"import-check.invalid"' "$renderedPath"
          grep -q '"hasMailServer":true' "$renderedPath"
          grep -q '"hasDmarcMonitor":true' "$renderedPath"
          grep -q '"vendoredModuleActive":true' "$renderedPath"
          grep -q '"settingsType":"RocksDb"' "$renderedPath"
          grep -q '"settingsHasPath":true' "$renderedPath"
          grep -q '"defaultHasThrottle":false' "$renderedPath"
          grep -q '"defaultDnsblEmpty":true' "$renderedPath"
          grep -q '"defaultHasMetrics":false' "$renderedPath"
          grep -q '"defaultHasCache":false' "$renderedPath"
          grep -q '"defaultHasRelayStrategy":false' "$renderedPath"
          grep -q '"throttleRateCount":100' "$renderedPath"
          grep -q '"throttleRatePeriod":3600000' "$renderedPath"
          grep -q '"throttleKeys":"senderDomain,remoteIp"' "$renderedPath"
          grep -q '"dnsblVariant":"Ip"' "$renderedPath"
          grep -q '"dnsblZone":"'"'"'zen.spamhaus.org'"'"'"' "$renderedPath"
          grep -q '"dnsblTag":"'"'"'spamhaus-hit'"'"'"' "$renderedPath"
          grep -q '"badKeyTrips":true' "$renderedPath"
          grep -q '"emptyZoneTrips":true' "$renderedPath"
          touch "$out"
        ''
      ];
    }
