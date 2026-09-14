# Eval-time contract test for modules/dmarc-monitor.nix: the wrapper must
# (a) flip services.parsedmarc.enable, (b) keep the heavy sinks off, and
# (c) land general.output in the rendered settings with consumer settings
# still mergeable. Pure eval - no VM, no services started.
{
  nixpkgs,
  system,
}:
let
  # Path literals are forbidden in pure flake eval; a store path satisfies
  # the attrsOf-path secret type the same way a sops template path would on
  # a real host.
  secretFile = nixpkgs.legacyPackages.${system}.writeText "dmarc-password" "dummy";

  cfg =
    (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../modules/dmarc-monitor.nix
        {
          services.dmarc-monitor = {
            enable = true;
            settings = {
              imap = {
                host = "mail.example.test";
                user = "dmarc@example.test";
                password._secret = secretFile;
              };
            };
          };
        }
      ];
    }).config;

  rendered = builtins.toJSON {
    enabled = cfg.services.parsedmarc.enable;
    settings = cfg.services.parsedmarc.settings;
    elasticsearch = cfg.services.parsedmarc.provision.elasticsearch;
    geoIp = cfg.services.parsedmarc.provision.geoIp;
  };
in
builtins.derivation {
  name = "dmarc-eval";
  inherit system;
  passAsFile = [ "rendered" ];
  inherit rendered;
  builder = "/bin/sh";
  args = [
    "-c"
    ''
      grep -q '"enabled":true' "$renderedPath"
      grep -q '"output":"/var/lib/parsedmarc/reports"' "$renderedPath"
      grep -q '"elasticsearch":false' "$renderedPath"
      grep -q '"geoIp":false' "$renderedPath"
      grep -q '"_secret":"/nix/store' "$renderedPath"
      touch "$out"
    ''
  ];
}
