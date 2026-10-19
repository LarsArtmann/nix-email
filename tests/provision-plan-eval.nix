# Eval-time contract test for the provision PLAN STRUCTURE (2026-10-18,
# the V-generation fast-signal batch): `nix flake check` VM-proves the
# plan applies, but a ~10 s eval signal catches the paid-for plan-dialect
# bug classes BEFORE any VM boots:
#   - hostname vs Domain-name coherence (addresses synthesize as
#     name@<Domain(domainId).name> - a hostname/Domain split lands mail
#     outside the local namespace: auth 535, MAIL FROM 501, README ledger)
#   - match-property posture: reconcile sets MUST carry an explicit match
#     (reconcile deletes by key - a null match is a footgun); non-reconcile
#     sets without match are allowed only on the DOCUMENTED implicit-key
#     allowlist (Domain/MtaRoute/AcmeProvider - e2e-proven idempotent)
#   - the wrapper's listener plan still maps the fallback port set
#     (smtp 25, submission 587, submissions 465, imaps 993, http httpBind)
#     the bootstrap probe's built-in-endpoint fallback depends on
#   - no multi-line text inside systemd Exec* lines (the "Unbalanced
#     quoting" class that killed the first bind-e2e run)
#   - rate-limiter identity: MtaInboundThrottle matches on `description`
#     (no name field - the paid-for "match property is missing" refusal)
# Pure eval, arch-independent.
{
  system,
  nixpkgs,
}: let
  dnslessVmPatches = (import ./common.nix).dnslessVmPatches;

  mkConfig = extra:
    (import (nixpkgs + "/nixos/lib/eval-config.nix")) {
      inherit system;
      modules = [
        ../modules/mail-server.nix
        {
          system.stateVersion = "26.05";
          services.mail-server =
            {
              enable = true;
              hostname = "mail.check.test";
              httpBind = "127.0.0.1:8082";
              admin.secretFile = "/etc/check-admin-secret";
            }
            // extra;
        }
        # DNS-less-VM plan posture (DnsResolver Cloudflare + pyzor off):
        # tests/common.nix owns the canonical copy and rationale.
        dnslessVmPatches
      ];
    };

  base = mkConfig {};
  throttled = mkConfig {rateLimits.enable = true;};

  provision = base.config.services.stalwart.provision;
  inherit (provision) objects;

  hostname = base.config.services.mail-server.hostname;

  # V9.4: the provisioned Domain's name IS the wrapper hostname.
  domainName = (objects.Domain.objects.domain or {}).name or "MISSING";

  # Match-posture audit over every set the wrapper renders.
  implicitKeyAllowlist = ["Domain" "MtaRoute" "AcmeProvider"];
  setNames = builtins.attrNames objects;

  reconcileWithoutMatch =
    builtins.filter (
      name: (objects.${name}.reconcile or false) && (objects.${name}.match or null) == null
    )
    setNames;

  noMatchOutsideAllowlist =
    builtins.filter (
      name: (objects.${name}.match or null) == null && !builtins.elem name implicitKeyAllowlist
    )
    setNames;

  accountSetMatchWrong = let
    accountMatch = objects.Account.match or null;
  in
    objects ? Account && accountMatch != ["name"];

  # V10.3: the fallback listener port set.
  listeners = objects.NetworkListener.objects or {};
  # binds render as lists in the wrapper (the lua sorter normalizes them
  # to maps on the wire) - accept either shape.
  bindList = name: let
    b = listeners.${name}.bind or [];
  in
    if builtins.isList b
    then b
    else builtins.attrNames b;
  listenerBind = name: port:
    builtins.any (b: lib.hasSuffix ":${toString port}" b) (bindList name);
  httpBindStr = base.config.services.mail-server.httpBind;
  httpListenerBinds = bindList "http";

  listenerPostureOk =
    (objects.NetworkListener.reconcile or false)
    && objects.NetworkListener.match == ["name"]
    && listenerBind "smtp" 25
    && listenerBind "submission" 587
    && listenerBind "submissions" 465
    && listenerBind "imaps" 993
    && builtins.any (b: b == httpBindStr) httpListenerBinds;

  # V10.2: multi-line text in Exec* is the systemd "Unbalanced quoting"
  # class - the wrapper keeps scripts on store paths for exactly this
  # reason; lint every Exec* line of the stalwart-related services.
  execKeys = ["ExecStart" "ExecStartPre" "ExecStartPost" "ExecStop" "ExecStopPost" "ExecReload"];
  stalwartServices = builtins.filter (name: lib.hasPrefix "stalwart" name) (
    builtins.attrNames base.config.systemd.services
  );
  multilineExecs =
    builtins.filter (
      svc:
        builtins.any (
          key: let
            value = base.config.systemd.services.${svc}.serviceConfig.${key} or null;
          in
            value != null && (builtins.isString value) && lib.hasInfix "\n" value
        )
        execKeys
    )
    stalwartServices;

  # SystemSettings singleton coherence (defaultDomainId points at the
  # wrapper Domain id; defaultHostname == hostname).
  systemSettings = provision.singletons.SystemSettings or {};
  settingsCoherent =
    systemSettings ? defaultHostname
    && systemSettings.defaultHostname == hostname
    && systemSettings ? defaultDomainId
    && systemSettings.defaultDomainId == "#domain";

  # Rate-limiter identity (second config with rateLimits on; the default
  # set id is "wrapper-sustained").
  throttleSet = throttled.config.services.stalwart.provision.objects.MtaInboundThrottle or null;
  throttleOk =
    throttleSet
    != null
    && throttleSet.match == ["description"]
    && (throttleSet.objects ? "wrapper-sustained")
    && throttleSet.objects."wrapper-sustained" ? description
    && builtins.isList throttleSet.objects."wrapper-sustained".key;

  inherit (nixpkgs.legacyPackages.${system}) lib;

  renderedAttrs = {
    inherit domainName hostname;
    inherit reconcileWithoutMatch noMatchOutsideAllowlist accountSetMatchWrong;
    inherit listenerPostureOk settingsCoherent throttleOk;
    multilineExecs = builtins.length multilineExecs == 0;
    wrapperAssertionsClean = builtins.length wrapperAssertionFires == 0;
  };
  rendered = builtins.toJSON renderedAttrs;

  # NixOS base assertions (fileSystems, bootloader) fire in any partial
  # eval without a VM base - scope the cleanliness claim to the wrapper's
  # own assertion surface (mail-server/stalwart messages).
  wrapperAssertionFires =
    builtins.filter (
      a: !a.assertion && (lib.hasInfix "mail-server" a.message || lib.hasInfix "stalwart" a.message)
    )
    base.config.assertions;
in
  assert domainName == hostname || throw "provision-plan-eval: the wrapper Domain name (${domainName}) must equal services.mail-server.hostname (${hostname}) - addresses synthesize as name@<Domain.name>, a split lands them outside the local namespace.";
  assert builtins.length reconcileWithoutMatch == 0 || throw "provision-plan-eval: reconcile sets without an explicit match property: ${toString reconcileWithoutMatch} - reconcile DELETES by key, a null match is a footgun.";
  assert builtins.length noMatchOutsideAllowlist == 0 || throw "provision-plan-eval: object sets without match outside the documented implicit-key allowlist (${toString implicitKeyAllowlist}): ${toString noMatchOutsideAllowlist}.";
  assert !accountSetMatchWrong || throw "provision-plan-eval: an Account set exists but does not match on [\"name\"] (the e2e/demo idempotence posture).";
  assert listenerPostureOk || throw "provision-plan-eval: the NetworkListener plan drifted from the fallback port set (smtp 25 / submission 587 / submissions 465 / imaps 993 / http httpBind) or lost match=[name]+reconcile.";
  assert settingsCoherent || throw "provision-plan-eval: SystemSettings.defaultHostname/defaultDomainId drifted from the wrapper hostname/Domain id.";
  assert (builtins.length multilineExecs == 0) || throw "provision-plan-eval: multi-line text found in Exec* of ${toString multilineExecs} - systemd rejects it ('Unbalanced quoting'); scripts must stay on store paths.";
  assert throttleOk || throw "provision-plan-eval: the MtaInboundThrottle set lost its description match key / body key vocabulary.";
  assert (builtins.length wrapperAssertionFires == 0) || throw "provision-plan-eval: the base config carries firing wrapper assertions: ${toString (map (a: a.message) wrapperAssertionFires)}";
    builtins.derivation {
      name = "provision-plan-eval-${system}";
      inherit system;
      PATH = "${nixpkgs.legacyPackages.${system}.coreutils}/bin:${nixpkgs.legacyPackages.${system}.gnugrep}/bin";
      passAsFile = ["rendered"];
      inherit rendered;
      builder = "/bin/sh";
      args = [
        "-c"
        ''
          grep -q '"domainName":"mail.check.test"' "$renderedPath"
          grep -q '"reconcileWithoutMatch":\[\]' "$renderedPath"
          grep -q '"noMatchOutsideAllowlist":\[\]' "$renderedPath"
          grep -q '"accountSetMatchWrong":false' "$renderedPath"
          grep -q '"listenerPostureOk":true' "$renderedPath"
          grep -q '"settingsCoherent":true' "$renderedPath"
          grep -q '"multilineExecs":true' "$renderedPath"
          grep -q '"throttleOk":true' "$renderedPath"
          grep -q '"wrapperAssertionsClean":true' "$renderedPath"
          touch "$out"
        ''
      ];
    }
