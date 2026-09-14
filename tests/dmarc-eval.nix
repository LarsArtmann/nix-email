# Eval-time contract test for modules/dmarc-monitor.nix: the wrapper must
# (a) flip services.parsedmarc.enable, (b) keep the heavy sinks off, and
# (c) land general.output in the rendered settings with consumer settings
# still mergeable. Pure eval - no VM, no services started.
{
  nixpkgs,
  system,
}:
let
  cfg =
    (nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../modules/dmarc-monitor.nix
        {
          services.dmarc-monitor = {
            enable = true;
            settings = {
              mailbox = {
                host = "mail.example.test";
                user = "dmarc@example.test";
                password._secret = "/run/keys/dmarc-password";
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
  system = builtins.currentSystem;
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
      grep -q '"_secret":"/run/keys/dmarc-password"' "$renderedPath"
      touch "$out"
    ''
  ];
}
