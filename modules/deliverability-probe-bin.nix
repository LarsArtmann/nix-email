# The deliverability probe as ONE runnable derivation - the single source
# shared by three consumers (the dedup rule):
#   1. the wrapper's systemd unit (host mode, modules/mail-server.nix),
#   2. the flake package/app (vantage mode - evo-x2 / SystemNix run it
#      against the PUBLIC hostname; MONITORING.md row 10's outside view),
#   3. the deliverability-e2e VM test's manual negative runs.
# Takes {pkgs} deliberately (not a NixOS module): it is a package, not
# configuration. Absolute store paths only - a unit's ExecStart PATH is
# NOT the console PATH (CONTRIBUTING "unit-script PATH trap"), so dig
# and openssl are baked in here rather than hoped for.
{pkgs}:
pkgs.writeShellScriptBin "deliverability-probe" ''
  export PATH="${pkgs.dnsutils}/bin:${pkgs.openssl}/bin:$PATH"
  exec ${pkgs.python3}/bin/python3 ${./deliverability-probe.py} "$@"
''
