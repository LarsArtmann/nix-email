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
  inherit (nixpkgs) lib;

  parsedmarcVersion = pkgs.parsedmarc.version;

  # The nixpkgs parsedmarc module's _secret handling REQUIRES a string
  # (isString gate in its ini generator; a path VALUE throws at unit
  # generation, parsedmarc.nix:12). An absolute path STRING passes
  # types.path and satisfies the generator - on a real host that is the
  # sops template path. Forcing the rendered unit below also forces
  # ini.generate, so this file genuinely exercises the secret-replacement
  # contract, not just the settings shape.
  secretFile = toString (pkgs.writeText "dmarc-password" "dummy");

  eval = nixpkgs.lib.nixosSystem {
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
            # Passthrough proof beyond the wrapper's own general.output
            # mkDefault: a consumer general.* key must survive mkMerge
            # verbatim (the thin-wrapper settings contract).
            general.offline = true;
          };
        };
      }
    ];
  };

  cfg = eval.config;

  # Options-docs rendering drift check (never built before 2026-09-16):
  # forcing the full CommonMark options render proves every wrapper option
  # description survives the NixOS docs pipeline instead of breaking it
  # (unbalanced code fences etc. fail HERE, not in a manual build), and the
  # greps below prove the wrapper's own docs content actually rendered.
  inherit ((pkgs.nixosOptionsDoc {inherit (eval) options;})) optionsCommonMark;

  rendered = builtins.toJSON {
    enabled = cfg.services.parsedmarc.enable;
    settings = cfg.services.parsedmarc.settings;
    elasticsearch = cfg.services.parsedmarc.provision.elasticsearch;
    geoIp = cfg.services.parsedmarc.provision.geoIp;
    stateDirectory = cfg.systemd.services.parsedmarc.serviceConfig.StateDirectory;
    execStart = cfg.systemd.services.parsedmarc.serviceConfig.ExecStart;
    inherit parsedmarcVersion;
  };

  # Regression guard for the [elasticsearch]-section workaround (README
  # ledger 2026-09-15): the ExecStartPre list must hold the module's own
  # ini-writing step AND the wrapper's strip script, with the strip LAST -
  # the strip must therefore run AFTER the module rendered the ini. lib.last
  # is an ordering proof only while the list has both entries (on a single
  # non-list entry lib.last would return a CHARACTER), hence the length
  # assertion below. If nixpkgs changes the unit shape or the workaround is
  # removed, this fails loudly instead of crashing parsedmarc at start.
  execStartPre = cfg.systemd.services.parsedmarc.serviceConfig.ExecStartPre;
  execStartPreCount = builtins.length execStartPre;
  stripScript = builtins.readFile (lib.last execStartPre);

  versionOk = lib.versionAtLeast parsedmarcVersion "11";
in
  assert versionOk || throw "dmarc-monitor contract is verified against parsedmarc >= 11 (got ${parsedmarcVersion}) - re-verify the [imap]/_secret/output semantics before touching the floor.";
  assert lib.isList execStartPre || throw "dmarc-eval: parsedmarc ExecStartPre is not a list - lib.last would return a character, not the strip script; re-verify the unit shape.";
  assert execStartPreCount >= 2 || throw "dmarc-eval: ExecStartPre must hold the module's ini step plus the wrapper's strip script (>= 2 entries, strip last) - got ${toString execStartPreCount}, which makes lib.last an invalid ordering proof.";
    builtins.derivation {
      name = "dmarc-eval";
      inherit system;
      PATH = "${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin";
      passAsFile = ["rendered" "stripScript" "optionsCommonMark"];
      inherit rendered stripScript optionsCommonMark;
      builder = "/bin/sh";
      args = [
        "-c"
        ''
          grep -q '"enabled":true' "$renderedPath"
          grep -q '"output":"/var/lib/parsedmarc/reports"' "$renderedPath"
          grep -q '"elasticsearch":false' "$renderedPath"
          grep -q '"geoIp":false' "$renderedPath"
          grep -q '"_secret":"/nix/store' "$renderedPath"
          grep -q '"offline":true' "$renderedPath"
          grep -q '"stateDirectory":"parsedmarc"' "$renderedPath"
          grep -q 'python3.13-parsedmarc' "$renderedPath"
          grep -q '"\\[elasticsearch\\]"' "$stripScriptPath"
          grep -q 'keep' "$stripScriptPath"
          grep -q 'dmarc-monitor' "$optionsCommonMarkPath"
          grep -q 'RETENTION' "$optionsCommonMarkPath"
          grep -q 'parsedmarc.ini' "$optionsCommonMarkPath"
          touch "$out"
        ''
      ];
    }
