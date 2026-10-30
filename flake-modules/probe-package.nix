# perSystem package + app: the deliverability probe for VANTAGE runs
# (MONITORING.md row 10 - the outside view a host-local probe can never
# give). evo-x2 / SystemNix / any fleet host runs, on a systemd timer or
# cron:
#
#   nix run github:LarsArtmann/nix-email#deliverability-probe -- \
#     --host mail.example.com --domains example.com \
#     --dnsbl-zones zen.spamhaus.org \
#     --canary-address canary@example.com \
#     --canary-password-file /run/secrets/mail-canary-password \
#     --json-out /var/lib/mail-canary/report.json \
#     --prom-out /var/lib/mail-canary/metrics.prom
#
# The derivation is single-sourced in modules/deliverability-probe-bin.nix
# - the SAME one the wrapper's mail-deliverability-probe.service unit runs
# in host mode, so vantage and host probes cannot drift apart.
{
  perSystem = {pkgs, ...}: let
    probe = import ../modules/deliverability-probe-bin.nix {inherit pkgs;};
  in {
    packages.deliverability-probe = probe;
    apps.deliverability-probe = {
      type = "app";
      program = pkgs.lib.getExe probe;
    };
  };
}
