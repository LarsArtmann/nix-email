# Eval-time contract test for the throwaway demo host (`nix run .#vm`).
# `nix flake check` already forces the demo toplevel - verified 2026-10-06
# by probe (a failing assertion injected into nixosConfigurations.demo
# fails the gate) - so eval ROT is caught. What that does NOT catch is the
# demo's HUMAN contract silently regressing while still evaluating clean:
# the README "Try it in a VM" quickstart port forwards, the provisioning
# unit's roles:["user"] (README ledger: principals without it are refused
# submission), the fallback-admin login the quickstart prints, and the
# pyzor-off posture (stalwart-e2e lesson: network dependence for zero
# demo value). Pure eval, no VM - but x86_64-only, because the demo host
# itself is (flake-modules/demo-vm.nix).
{
  pkgs,
  system,
  demoConfig,
}: let
  lib = pkgs.lib;

  # hostfwd pairs exactly as the banner + README quickstart print them
  # (QEMU aborts on taken targets, and a dropped forward makes the
  # quickstart port silently dead - the "connects but never answers"
  # firewall signature, README ledger (k)).
  forwardPairs =
    map (
      p: "${p.host.address}:${toString p.host.port}->${toString p.guest.port}"
    )
    demoConfig.virtualisation.forwardPorts;

  provision = demoConfig.systemd.services.mail-demo-provision;
  provisionScript = provision.script;

  renderedAttrs = {
    mailServerEnabled = demoConfig.services.mail-server.enable;
    stalwartEnabled = demoConfig.services.stalwart.enable;
    hostname = demoConfig.services.mail-server.hostname;
    httpBind = demoConfig.services.mail-server.httpBind;
    fallbackAdminUser = demoConfig.services.stalwart.settings.authentication.fallback-admin.user;
    fallbackAdminSecret = demoConfig.services.stalwart.settings.authentication.fallback-admin.secret;
    pyzorDisabled = !demoConfig.services.stalwart.settings.spam-filter.pyzor.enable;
    forwardPairs = lib.concatStringsSep "," forwardPairs;
    # system.name drives the runner script name (run-demo-vm) that the
    # quickstart invokes via `nix run .#vm`.
    systemName = demoConfig.system.name;
    provisionType = provision.serviceConfig.Type;
    provisionAfter = lib.concatStringsSep "," provision.after;
    provisionWantedBy = lib.concatStringsSep "," provision.wantedBy;
    provisionHasRoles = lib.hasInfix ''"roles":["user"]'' provisionScript;
    provisionHasCatchall = lib.hasInfix ''"@mail.demo.invalid"'' provisionScript;
    provisionHasAbsoluteCurl = lib.hasInfix "/bin/curl" provisionScript;
    demoAssertionsClean = lib.all (a: a.assertion) demoConfig.assertions;
  };
  rendered = builtins.toJSON renderedAttrs;
in
  assert renderedAttrs.mailServerEnabled || throw "demo-eval: the demo host must enable services.mail-server.";
  assert renderedAttrs.stalwartEnabled || throw "demo-eval: the demo host must enable the wrapped stalwart service.";
  assert renderedAttrs.hostname == "mail.demo.invalid" || throw "demo-eval: demo hostname drifted from the README quickstart domain.";
  assert renderedAttrs.httpBind == "0.0.0.0:8080" || throw "demo-eval: demo httpBind must be non-loopback (0.0.0.0:8080) or the hostfwd 18080 forward hits nothing.";
  assert renderedAttrs.fallbackAdminUser == "admin" || throw "demo-eval: fallback-admin user drifted from the banner login.";
  assert renderedAttrs.fallbackAdminSecret == "demo-admin" || throw "demo-eval: fallback-admin secret drifted from the banner login.";
  assert renderedAttrs.pyzorDisabled || throw "demo-eval: pyzor must stay OFF on the demo (network dependence, zero demo value - stalwart-e2e lesson).";
  assert renderedAttrs.forwardPairs == "127.0.0.1:18080->8080,127.0.0.1:2525->25,127.0.0.1:2587->587,127.0.0.1:2593->993" || throw "demo-eval: QEMU forward pairs drifted - the README quickstart ports are the demo's contract.";
  assert renderedAttrs.systemName == "demo" || throw "demo-eval: system.name drifted - it names the run-demo-vm runner script the quickstart uses.";
  assert renderedAttrs.provisionType == "oneshot" || throw "demo-eval: provision unit must stay a oneshot.";
  assert renderedAttrs.provisionAfter == "stalwart.service" || throw "demo-eval: provision unit must start after stalwart.service.";
  assert renderedAttrs.provisionWantedBy == "multi-user.target" || throw "demo-eval: provision unit must be wanted by multi-user.target.";
  assert renderedAttrs.provisionHasRoles || throw "demo-eval: provision script lost roles:[\"user\"] - principals without it are refused submission (README ledger).";
  assert renderedAttrs.provisionHasCatchall || throw "demo-eval: provision script lost the @mail.demo.invalid catch-all principal.";
  assert renderedAttrs.provisionHasAbsoluteCurl || throw "demo-eval: provision script lost the ABSOLUTE curl path - systemd PATH does not carry environment.systemPackages (README ledger (l)).";
  assert renderedAttrs.demoAssertionsClean || throw "demo-eval: the demo host carries firing assertions.";
    builtins.derivation {
      name = "demo-eval-${system}";
      inherit system;
      PATH = "${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin";
      passAsFile = ["rendered"];
      inherit rendered;
      builder = "/bin/sh";
      args = [
        "-c"
        ''
          grep -q '"mailServerEnabled":true' "$renderedPath"
          grep -q '"stalwartEnabled":true' "$renderedPath"
          grep -q '"hostname":"mail.demo.invalid"' "$renderedPath"
          grep -q '"httpBind":"0.0.0.0:8080"' "$renderedPath"
          grep -q '"fallbackAdminUser":"admin"' "$renderedPath"
          grep -q '"fallbackAdminSecret":"demo-admin"' "$renderedPath"
          grep -q '"pyzorDisabled":true' "$renderedPath"
          grep -q '"forwardPairs":"127.0.0.1:18080->8080,127.0.0.1:2525->25,127.0.0.1:2587->587,127.0.0.1:2593->993"' "$renderedPath"
          grep -q '"systemName":"demo"' "$renderedPath"
          grep -q '"provisionType":"oneshot"' "$renderedPath"
          grep -q '"provisionAfter":"stalwart.service"' "$renderedPath"
          grep -q '"provisionWantedBy":"multi-user.target"' "$renderedPath"
          grep -q '"provisionHasRoles":true' "$renderedPath"
          grep -q '"provisionHasCatchall":true' "$renderedPath"
          grep -q '"provisionHasAbsoluteCurl":true' "$renderedPath"
          grep -q '"demoAssertionsClean":true' "$renderedPath"
          touch "$out"
        ''
      ];
    }
