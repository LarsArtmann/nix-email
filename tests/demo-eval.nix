# Eval-time contract test for the throwaway demo host (`nix run .#vm`).
# `nix flake check` already forces the demo toplevel - verified 2026-10-06
# by probe (a failing assertion injected into nixosConfigurations.demo
# fails the gate) - so eval ROT is caught. What that does NOT catch is the
# demo's HUMAN contract silently regressing while still evaluating clean:
# the README "Try it in a VM" quickstart port forwards, the declarative
# demo account (0.16: roles User variant; submission is refused without
# it), the fallback-admin login the quickstart prints, and the pyzor-off
# posture (stalwart-e2e lesson: network dependence for zero demo value).
# Pure eval, no VM - but x86_64-only, because the demo host itself is
# (flake-modules/demo-vm.nix).
{
  pkgs,
  system,
  demoConfig,
}: let
  inherit (pkgs) lib;

  # hostfwd pairs exactly as the banner + README quickstart print them
  # (QEMU aborts on taken targets, and a dropped forward makes the
  # quickstart port silently dead - the "connects but never answers"
  # firewall signature, README ledger (k)).
  forwardPairs =
    map (
      p: "${p.host.address}:${toString p.host.port}->${toString p.guest.port}"
    )
    demoConfig.virtualisation.forwardPorts;

  stalwart = demoConfig.services.stalwart;
  provisionUnit = demoConfig.systemd.services.stalwart-provision;
  accounts = stalwart.provision.objects.Account.objects;
  demoAccount = accounts.demo or {};
  domainObject = stalwart.provision.objects.Domain.objects.domain or {};

  renderedAttrs = {
    mailServerEnabled = demoConfig.services.mail-server.enable;
    stalwartEnabled = stalwart.enable;
    stalwart016 = lib.versionAtLeast stalwart.package.version "0.16";
    hostname = demoConfig.services.mail-server.hostname;
    httpBind = demoConfig.services.mail-server.httpBind;
    fallbackAdminUser = stalwart.admin.username;
    fallbackAdminCred = stalwart.credentials."${stalwart.admin.username}" or "MISSING";
    pyzorDisabled = (stalwart.provision.singletons.SpinePyzor.enable or true) == false;
    forwardPairs = lib.concatStringsSep "," forwardPairs;
    # system.name drives the runner script name (run-demo-vm) that the
    # quickstart invokes via `nix run .#vm`.
    systemName = demoConfig.system.name;
    provisionType = provisionUnit.serviceConfig.Type;
    provisionAfter = lib.concatStringsSep "," provisionUnit.after;
    provisionWantedBy = lib.concatStringsSep "," provisionUnit.wantedBy;
    provisionUsesCli = lib.hasInfix "stalwart-cli apply" provisionUnit.serviceConfig.ExecStart;
    demoIsUserVariant = (demoAccount."@type" or "") == "User";
    demoEmail = demoAccount.emailAddress or "MISSING";
    demoHasPassword = demoAccount ? credentials;
    demoRolesUser = (demoAccount.roles."@type" or "") == "User";
    catchAllAddress = domainObject.catchAllAddress or "MISSING";
    demoAssertionsClean = lib.all (a: a.assertion) demoConfig.assertions;
  };
  rendered = builtins.toJSON renderedAttrs;
in
  assert renderedAttrs.mailServerEnabled || throw "demo-eval: the demo host must enable services.mail-server.";
  assert renderedAttrs.stalwartEnabled || throw "demo-eval: the demo host must enable the wrapped stalwart service.";
  assert renderedAttrs.stalwart016 || throw "demo-eval: the demo must run Stalwart >= 0.16 (the declarative provision surface).";
  assert renderedAttrs.hostname == "mail.demo.invalid" || throw "demo-eval: demo hostname drifted from the README quickstart domain.";
  assert renderedAttrs.httpBind == "0.0.0.0:8080" || throw "demo-eval: demo httpBind must be non-loopback (0.0.0.0:8080) or the hostfwd 18080 forward hits nothing.";
  assert renderedAttrs.fallbackAdminUser == "admin" || throw "demo-eval: fallback-admin user drifted from the banner login.";
  assert lib.hasSuffix "/etc/demo-admin-secret" renderedAttrs.fallbackAdminCred || throw "demo-eval: fallback-admin password must ride the /etc/demo-admin-secret credential file (0.16 systemd-creds path), not an inline secret.";
  assert renderedAttrs.pyzorDisabled || throw "demo-eval: pyzor must stay OFF on the demo (network dependence, zero demo value - stalwart-e2e lesson).";
  assert renderedAttrs.forwardPairs == "127.0.0.1:18080->8080,127.0.0.1:2525->25,127.0.0.1:2587->587,127.0.0.1:2593->993" || throw "demo-eval: QEMU forward pairs drifted - the README quickstart ports are the demo's contract.";
  assert renderedAttrs.systemName == "demo" || throw "demo-eval: system.name drifted - it names the run-demo-vm runner script the quickstart uses.";
  assert renderedAttrs.provisionType == "oneshot" || throw "demo-eval: provision unit must stay a oneshot.";
  assert renderedAttrs.provisionAfter == "stalwart.service" || throw "demo-eval: provision unit must start after stalwart.service.";
  assert renderedAttrs.provisionWantedBy == "multi-user.target" || throw "demo-eval: provision unit must be wanted by multi-user.target.";
  assert renderedAttrs.provisionUsesCli || throw "demo-eval: provision unit must apply the plan via stalwart-cli (the 0.16 management surface - /api/principal is gone).";
  assert renderedAttrs.demoIsUserVariant || throw "demo-eval: the demo account must be an Account User variant (0.16 object model).";
  assert renderedAttrs.demoEmail == "demo@mail.demo.invalid" || throw "demo-eval: demo account email drifted from the README quickstart login.";
  assert renderedAttrs.demoHasPassword || throw "demo-eval: the demo account lost its password credential - the quickstart login would not work.";
  assert renderedAttrs.demoRolesUser || throw "demo-eval: the demo account must carry the User role - accounts without it are refused submission (README ledger).";
  assert renderedAttrs.catchAllAddress == "catchall@mail.demo.invalid" || throw "demo-eval: the demo lost its @mail.demo.invalid catch-all (Domain.catchAllAddress -> catchall account).";
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
          grep -q '"stalwart016":true' "$renderedPath"
          grep -q '"hostname":"mail.demo.invalid"' "$renderedPath"
          grep -q '"httpBind":"0.0.0.0:8080"' "$renderedPath"
          grep -q '"fallbackAdminUser":"admin"' "$renderedPath"
          grep -q 'demo-admin-secret' "$renderedPath"
          grep -q '"pyzorDisabled":true' "$renderedPath"
          grep -q '"forwardPairs":"127.0.0.1:18080->8080,127.0.0.1:2525->25,127.0.0.1:2587->587,127.0.0.1:2593->993"' "$renderedPath"
          grep -q '"systemName":"demo"' "$renderedPath"
          grep -q '"provisionType":"oneshot"' "$renderedPath"
          grep -q '"provisionAfter":"stalwart.service"' "$renderedPath"
          grep -q '"provisionWantedBy":"multi-user.target"' "$renderedPath"
          grep -q '"provisionUsesCli":true' "$renderedPath"
          grep -q '"demoIsUserVariant":true' "$renderedPath"
          grep -q '"demoEmail":"demo@mail.demo.invalid"' "$renderedPath"
          grep -q '"demoHasPassword":true' "$renderedPath"
          grep -q '"demoRolesUser":true' "$renderedPath"
          grep -q '"catchAllAddress":"catchall@mail.demo.invalid"' "$renderedPath"
          grep -q '"demoAssertionsClean":true' "$renderedPath"
          touch "$out"
        ''
      ];
    }
