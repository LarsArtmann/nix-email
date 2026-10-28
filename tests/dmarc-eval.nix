# Eval-time contract test for modules/dmarc-monitor.nix: the wrapper must
# (a) flip services.parsedmarc.enable, (b) keep the heavy sinks off, and
# (c) land general.output in the rendered settings with consumer settings
# still mergeable. Pure eval - no VM, no services started. TWO evals: the
# IMAP-shape contract below, and (since the fe132422 pin) a localMail-shape
# STORAGE contract - see localMailEval.
#
# The wrapper's contract is verified against parsedmarc 11 semantics
# ([imap] connection section, `_secret` paths, no SQLite sink). Pin the
# floor here so an accidental nixpkgs pin move below 11 fails loudly
# instead of rendering a config against changed semantics.
#
# The unit-hardening readout (DynamicUser / SystemCallFilter /
# RestrictAddressFamilies) is a DROP detector for pin advances: the
# nixpkgs module owns that hardening (pin fe132422, parsedmarc.nix), and
# a pin move that silently drops it must fail HERE, not in production.
# Additions (stricter than the pin) deliberately pass - only drops fail.
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
        # Explicit stateVersion: kills the "defaulting to 26.11" eval
        # warning (fleet convention 26.05).
        system.stateVersion = "26.05";
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
  unit = cfg.systemd.services.parsedmarc.serviceConfig;

  # localMail-shape eval (fe132422+): the wrapper-vs-module STORAGE
  # contract, asserted at eval time so the OSError Errno 30 class
  # dies here in seconds instead of a 25-minute VM red. Under
  # provision.localMail the module renders settings.maildir
  # .maildir_path into postfix's spool; the wrapper must (1)
  # whitelist EXACTLY that path UNPREFIXED (a "-"/ignore-missing
  # entry is evaluated once at namespace setup - a path absent at
  # exec time is silently skipped and the spool stays read-only under
  # ProtectSystem=strict forever; the maildir only exists once
  # postfix delivers, which races unit start - two VM transcripts
  # 2026-10-28) and (2) PRE-CREATE it via a tmpfiles rule (boot time;
  # ExecStartPre is too late by construction - systemd applies the
  # namespace to every ExecStartPre command, so a "+" prepare step
  # dies at step NAMESPACE, status 226, VM transcript 2026-10-28
  # run 4).
  localMailEval = nixpkgs.lib.nixosSystem {
    inherit system;
    modules = [
      ../modules/dmarc-monitor.nix
      {
        system.stateVersion = "26.05";
        # localMail.hostname defaults to networking.fqdn - give the
        # eval a determinable one (NixOS asserts otherwise).
        networking.fqdn = "localhost";
        services.dmarc-monitor.enable = true;
        services.parsedmarc.provision.localMail.enable = true;
      }
    ];
  };

  localMailUnit = localMailEval.config.systemd.services.parsedmarc.serviceConfig;
  localMailExecStartPre = localMailUnit.ExecStartPre;
  # The module's own rendered path (its expression, quoted back): the
  # wrapper's whitelist must match it string-for-string.
  moduleMaildirPath = localMailEval.config.services.parsedmarc.settings.maildir.maildir_path;

  # Options-docs rendering drift check (never built before 2026-09-16):
  # the options doc is grepped BUILD-TIME (below) - referencing its store
  # path does not force the derivation during eval (the old readFile/
  # passAsFile shape was an IFD: eval built the doc to read it).
  inherit ((pkgs.nixosOptionsDoc {inherit (eval) options;})) optionsCommonMark;

  rendered = builtins.toJSON {
    enabled = cfg.services.parsedmarc.enable;
    settings = cfg.services.parsedmarc.settings;
    opensearch = cfg.services.parsedmarc.provision.opensearch;
    geoIp = cfg.services.parsedmarc.provision.geoIp;
    stateDirectory = unit.StateDirectory;
    execStart = unit.ExecStart;
    dynamicUser = unit.DynamicUser;
    inherit (unit) SystemCallFilter RestrictAddressFamilies;
    inherit parsedmarcVersion;
  };

  renderedLocalMail = builtins.toJSON {
    readWritePaths = lib.toList localMailUnit.ReadWritePaths;
    execStartPre = localMailExecStartPre;
    dynamicUser = localMailUnit.DynamicUser;
    user = localMailUnit.User;
    maildir = localMailEval.config.services.parsedmarc.settings.maildir;
    mailboxWatch = localMailEval.config.services.parsedmarc.settings.mailbox.watch;
    tmpfiles = localMailEval.config.systemd.tmpfiles.rules;
  };

  # Regression guard for the [opensearch]-section workaround (README
  # ledger 2026-09-15, ported 2026-10-28): the ExecStartPre list must hold the module's own
  # ini-writing step AND the wrapper's strip script, with the strip LAST -
  # the strip must therefore run AFTER the module rendered the ini. lib.last
  # is an ordering proof only while the list has both entries (on a single
  # non-list entry lib.last would return a CHARACTER), hence the length
  # assertion below. If nixpkgs changes the unit shape or the workaround is
  # removed, this fails loudly instead of crashing parsedmarc at start.
  execStartPre = unit.ExecStartPre;
  execStartPreCount = builtins.length execStartPre;
  # Store PATH (never the contents - no IFD), with the systemd privilege
  # escape prefix stripped in case a future nixpkgs adds one to ours.
  stripScript = lib.removePrefix "+" (lib.last execStartPre);

  versionOk = lib.versionAtLeast parsedmarcVersion "11";
  syscallDrops = builtins.filter (f: !builtins.elem f unit.SystemCallFilter) [
    "@system-service"
    "~@privileged"
    "~@resources"
  ];
  familyDrops = builtins.filter (f: !builtins.elem f unit.RestrictAddressFamilies) [
    "AF_UNIX"
    "AF_INET"
    "AF_INET6"
  ];
  localMailReadWriteOk = builtins.elem moduleMaildirPath (lib.toList localMailUnit.ReadWritePaths);
  localMailDashRegression = builtins.elem "-${moduleMaildirPath}" (lib.toList localMailUnit.ReadWritePaths);
  localMailHasTmpfilesRule =
    builtins.any
    (rule: lib.isString rule && lib.hasPrefix "d ${moduleMaildirPath} " rule)
    (lib.toList localMailEval.config.systemd.tmpfiles.rules);
in
  assert versionOk || throw "dmarc-monitor contract is verified against parsedmarc >= 11 (got ${parsedmarcVersion}) - re-verify the [imap]/_secret/output semantics before touching the floor.";
  assert lib.isList execStartPre || throw "dmarc-eval: parsedmarc ExecStartPre is not a list - lib.last would return a character, not the strip script; re-verify the unit shape.";
  assert execStartPreCount >= 2 || throw "dmarc-eval: ExecStartPre must hold the module's ini step plus the wrapper's strip script (>= 2 entries, strip last) - got ${toString execStartPreCount}, which makes lib.last an invalid ordering proof.";
  assert unit.DynamicUser == true || throw "dmarc-eval: the pinned parsedmarc module dropped DynamicUser hardening (got ${toString unit.DynamicUser}) - re-verify the unit sandbox before advancing the pin.";
  assert syscallDrops == [] || throw "dmarc-eval: the pinned parsedmarc module dropped SystemCallFilter entries ${toString syscallDrops} (has ${toString unit.SystemCallFilter}) - re-verify the unit sandbox before advancing the pin.";
  assert familyDrops == [] || throw "dmarc-eval: the pinned parsedmarc module dropped RestrictAddressFamilies entries ${toString familyDrops} (has ${toString unit.RestrictAddressFamilies}) - re-verify the unit sandbox before advancing the pin.";
  assert lib.isList localMailExecStartPre || throw "dmarc-eval: localMail ExecStartPre is not a list - re-verify the unit shape.";
  assert localMailReadWriteOk || throw "dmarc-eval: under provision.localMail the wrapper must whitelist the module's maildir (${moduleMaildirPath}) in ReadWritePaths - ProtectSystem=strict makes the spool read-only and parsedmarc's .Archive mkdirs die with OSError Errno 30 (VM transcripts 2026-10-28).";
  assert !localMailDashRegression || throw "dmarc-eval: the localMail ReadWritePaths entry must NOT carry the '-' ignore-missing prefix - the whitelist is evaluated once at namespace setup and the maildir (postfix creates it at first delivery) is missing at unit start, so a '-' entry silently leaves the spool read-only (two VM transcripts 2026-10-28).";
  assert localMailHasTmpfilesRule || throw "dmarc-eval: the localMail maildir tmpfiles rule (boot-time pre-creation) is missing - without it the unprefixed ReadWritePaths entry fails the unit at start (ExecStartPre cannot pre-create: systemd namespaces every ExecStartPre command, status 226/NAMESPACE).";
    builtins.derivation {
      name = "dmarc-eval";
      inherit system;
      PATH = "${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin";
      passAsFile = ["rendered" "renderedLocalMail"];
      inherit rendered renderedLocalMail stripScript optionsCommonMark;
      builder = "/bin/sh";
      args = [
        "-c"
        ''
          grep -q '"enabled":true' "$renderedPath"
          grep -q '"output":"/var/lib/parsedmarc/reports"' "$renderedPath"
          grep -q '"opensearch":false' "$renderedPath"
          grep -q '"geoIp":false' "$renderedPath"
          grep -q '"_secret":"/nix/store' "$renderedPath"
          grep -q '"offline":true' "$renderedPath"
          grep -q '"stateDirectory":"parsedmarc"' "$renderedPath"
          grep -q 'python3.14-parsedmarc' "$renderedPath"
          grep -q '"dynamicUser":true' "$renderedPath"
          grep -q '"~@privileged"' "$renderedPath"
          grep -q '"AF_INET6"' "$renderedPath"
          grep -q '\[opensearch\]' "$stripScript"
          grep -q 'keep' "$stripScript"
          # localMail storage contract greps (fixed strings: the path
          # contains a literal "//" from the postfix default's
          # trailing slash - do NOT switch to regex here).
          grep -F -- "${moduleMaildirPath}" "$renderedLocalMailPath"
          if grep -F -- "-${moduleMaildirPath}" "$renderedLocalMailPath"; then
            echo "FATAL: dashed localMail maildir whitelist regression" >&2
            exit 1
          fi
          grep -F "d ${moduleMaildirPath} 0700" "$renderedLocalMailPath"
          grep -F 'parsedmarc-strip-opensearch-section' "$renderedLocalMailPath"
          grep -q '"user":"dmarc"' "$renderedLocalMailPath"
          grep -q '"dynamicUser":false' "$renderedLocalMailPath"
          grep -q 'dmarc-monitor' "$optionsCommonMark"
          grep -q 'RETENTION' "$optionsCommonMark"
          grep -q 'parsedmarc.ini' "$optionsCommonMark"
          # Negative self-test (the CI ruff-step pattern): the hardening
          # greps must DISCRIMINATE, not match anything. Flip one key in a
          # copy; the matcher must then miss.
          sed 's/"dynamicUser":true/"dynamicUser":false/' "$renderedPath" > neg.json
          if grep -q '"dynamicUser":true' neg.json; then
            echo "FATAL: the dynamicUser matcher is vacuous" >&2
            exit 1
          fi
          touch "$out"
        ''
      ];
    }
