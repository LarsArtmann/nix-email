# Eval-time contract test for modules/dmarc-monitor.nix: the wrapper must
# (a) flip services.parsedmarc.enable, (b) keep the heavy sinks off, and
# (c) land general.output in the rendered settings with consumer settings
# still mergeable. Pure eval - no VM, no services started.
#
# The wrapper's contract is verified against parsedmarc 11 semantics
# ([imap] connection section, `_secret` paths, no SQLite sink). Pin the
# floor here so an accidental nixpkgs pin move below 11 fails loudly
# instead of rendering a config against changed semantics.
{
  nixpkgs,
  system,
}: let
  pkgs = nixpkgs.legacyPackages.${system};
  lib = nixpkgs.lib;

  parsedmarcVersion = pkgs.parsedmarc.version;

  # The nixpkgs parsedmarc module's _secret handling REQUIRES a string
  # (isString gate in its ini generator; a path VALUE throws at unit
  # generation, parsedmarc.nix:12). An absolute path STRING passes
  # types.path and satisfies the generator - on a real host that is the
  # sops template path. Forcing the rendered unit below also forces
  # ini.generate, so this file genuinely exercises the secret-replacement
  # contract, not just the settings shape.
  secretFile = toString (pkgs.writeText "dmarc-password" "dummy");

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
    stateDirectory = cfg.systemd.services.parsedmarc.serviceConfig.StateDirectory;
    inherit parsedmarcVersion;
  };

  versionOk = lib.versionAtLeast parsedmarcVersion "11";
in
  assert versionOk || throw "dmarc-monitor contract is verified against parsedmarc >= 11 (got ${parsedmarcVersion}) - re-verify the [imap]/_secret/output semantics before touching the floor.";
    builtins.derivation {
      name = "dmarc-eval";
      system = system;
      PATH = "${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin";
      passAsFile = ["rendered"];
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
          grep -q '"stateDirectory":"parsedmarc"' "$renderedPath"
          touch "$out"
        ''
      ];
    }
