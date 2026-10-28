# Thin opinionated wrapper around the nixpkgs parsedmarc module
# (services.parsedmarc - 11.0.2 at the fe132422 pin).
#
# PURPOSE: close the domains-repo findings H1/H2 ("no rua anywhere - the
# reject domains enforce blindly") with a deliberately LIGHT footprint:
# parsedmarc polls the rua mailboxes over IMAP and writes parsed
# aggregate/forensic/TLS-RPT reports as JSON+CSV files. NO
# Elasticsearch/OpenSearch/Splunk - those are the heavy default sinks and
# their provision flags stay off.
#
# VERIFIED FACTS this module is built on (parsedmarc 11.0.1 source;
# the pin ships 11.0.2 - same ini contract, fixture-verified via
# scripts/host-parse-fixture.py):
#   - [general] `output` is the ini key for the report output directory
#     (cli.py reads general_config["output"]).
#   - There is NO SQLite sink. JSON/CSV files are the zero-dependency
#     output. A [postgresql] sink EXISTS in v11 but requires the `psycopg`
#     extra, which the nixpkgs package does not ship - if a queryable sink
#     is ever wanted, override the package with python3Packages.psycopg
#     (3.3.4 is in nixpkgs) and set settings.postgresql.* instead.
#   - Secrets: set `imap.password._secret = /path;` (PATH literal, not a
#     string - the typed option is nullOr (either path (attrsOf path))). The
#     nixpkgs unit renders the file contents into the ini at unit start.
#   - parsedmarc 11 reads the CONNECTION settings from the [imap] section
#     and raises ConfigurationError if host/user/password are missing there;
#     [mailbox] carries behavior flags only (watch/delete/batch_size) -
#     verified against parsedmarc/cli.py.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.dmarc-monitor;
  # (The py3.13 parsedmarcPackage pin was REVERTED 2026-10-28: the
  # fe132422 pin ships imapclient 4.1.0 with the starttls() fix,
  # mjs/imapclient#663 - the module's own pkgs.parsedmarc ExecStart is
  # correct again. History: README ledger + "Pin-advance runbook".)
  # localMail storage path (fe132422+ shape): the exact expression the
  # nixpkgs module renders into settings.maildir.maildir_path - bound
  # once so the ReadWritePaths entry and the tmpfiles rule below stay
  # in lockstep with the module's own layout (the postfix
  # mail_spool_directory default carries a trailing slash; the kernel
  # collapses the resulting "//").
  localMailMaildirPath = "${config.services.postfix.settings.main.mail_spool_directory}/${config.services.parsedmarc.provision.localMail.recipientName}";
in {
  options.services.dmarc-monitor = {
    enable = lib.mkEnableOption "DMARC/TLS-RPT report collection via parsedmarc (IMAP polling, JSON/CSV output, no search-stack dependency)";

    outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/parsedmarc/reports";
      description = ''
        Directory parsedmarc writes aggregate/forensic/smtp_tls JSON+CSV
        files to. Back this up (backup-coordination on the consumer host);
        a small viewer over these files is the intended read path.

        RETENTION (disk-growth policy): parsedmarc 11 itself has NO
        retention/pruning option - the JSON/CSV sink grows monotonically
        (roughly one file set per report received, per rua mailbox poll).
        Size it before enablement and prune on the consumer host (a
        systemd-timer `find <dir> -mtime +N -delete`, or backup rotation
        if the backup tool owns expiry). A busy domain's rua traffic is
        small (KBs/day), but an unbounded forever-directory on a mail
        host is still a disk-fill risk.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      example = lib.literalExpression ''
        {
          imap = {
            host = "mail.example.com";
            port = 993;
            ssl = true;
            # Stalwart GOTCHA (README ledger): IMAP LOGIN resolves by the
            # principal NAME, NOT by the principal's email addresses -
            # a principal named `dmarc` with email `dmarc@example.com`
            # logs in as `dmarc`, not as the address. Name the account
            # after its address (or set user = the principal NAME).
            user = "dmarc@example.com";
            # NOTE: _secret must be an absolute path STRING - the nixpkgs
            # ini generator throws on path VALUES (isString gate).
            password._secret = "/run/secrets/dmarc-imap-password";
          };
          mailbox.watch = true;
        }
      '';
      description = ''
        Passthrough to services.parsedmarc.settings (parsedmarc.ini).
        At minimum set `imap` (host/user/password with _secret) - see
        https://domainaware.github.io/parsedmarc/#configuration-file

        Stalwart-specific: IMAP LOGIN resolves by principal NAME, not by
        the principal's email addresses (README ledger, VM-verified) - if
        login fails with correct credentials, `imap.user` may need the
        principal NAME rather than the address.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.parsedmarc = {
      enable = true;
      provision = {
        # Heavy sinks stay OFF - this module's whole point is lightness.
        # (opensearch since the fe132422 pin: nixpkgs PR #566282 renamed
        # provision.elasticsearch away with mkRemovedOptionModule.)
        opensearch = lib.mkDefault false;
        geoIp = lib.mkDefault false;
      };
      settings = lib.mkMerge [
        cfg.settings
        {
          general.output = lib.mkDefault cfg.outputDirectory;
        }
      ];
    };

    # The nixpkgs unit runs as a DynamicUser and prepares NO writable state,
    # while parsedmarc 11.0.1 os.makedirs()es the output directory on first
    # write - as the dynamic user that hits "Permission denied" on the
    # root-owned /var/lib. StateDirectory makes systemd create and chown
    # /var/lib/parsedmarc on every start; custom outputDirectories outside
    # it must exist already and are explicitly whitelisted here.
    # The nixpkgs unit is already heavily sandboxed (DynamicUser,
    # CapabilityBoundingSet="", PrivateDevices/Users/Mounts, Protect* for
    # clock/hostname/kernel/control-groups/home, SystemCallFilter,
    # RestrictAddressFamilies) - deliberately NOT duplicated here. The
    # wrapper adds exactly what is missing on top; all mkDefault so a
    # stricter consumer policy wins.
    systemd.services.parsedmarc.serviceConfig = {
      StateDirectory = lib.mkDefault "parsedmarc";
      ReadWritePaths =
        # "-" prefix: the output directory may not exist until
        # parsedmarc's first makedirs() - and its parent
        # /var/lib/parsedmarc is writable anyway via the
        # StateDirectory auto-whitelist, so a missing path must not
        # fail the unit at start.
        ["-${cfg.outputDirectory}"]
        ++ lib.optionals config.services.parsedmarc.provision.localMail.enable [
          # localMail (fe132422+ shape, PR #566282): the provision
          # watches a MAILDIR inside postfix's spool, and parsedmarc's
          # maildir source CREATES .Archive/.Invalid/... folders there
          # at connect time (mailbox.Maildir -> mailsuite) - the
          # provision's own storage must be whitelisted, mirroring the
          # module's settings.maildir.maildir_path expression exactly.
          #
          # NO "-" prefix here - deliberately. The whitelist is
          # evaluated ONCE at namespace setup: a "-"-prefixed path
          # that is missing AT EXEC TIME is silently skipped and the
          # spool stays read-only under ProtectSystem=strict FOREVER -
          # and this maildir only appears when postfix delivers the
          # first mail, typically AFTER unit start (OSError Errno 30
          # on '/var/spool/mail/<user>/.Archive', two VM transcripts
          # 2026-10-28). The tmpfiles rule below pre-creates the
          # maildir at BOOT (ExecStartPre CANNOT do it: systemd applies
          # the mount namespace to EVERY ExecStartPre command - the
          # "+" prefix exempts only user/group/credential settings,
          # not namespace options - so a "+" prepare step died at
          # step NAMESPACE, status 226, before its command even ran,
          # VM transcript 2026-10-28 run 4). Keeping the prefix off
          # means a future regression fails the unit loudly at start
          # instead of surfacing as a read-only filesystem in
          # production.
          localMailMaildirPath
        ];
      # parsedmarc writes reports and nothing else: a read-only FS (with the
      # StateDirectory auto-whitelisted by systemd) plus the remaining
      # namespace/privilege restrictions the upstream unit omits.
      ProtectSystem = lib.mkDefault "strict";
      PrivateTmp = lib.mkDefault true;
      NoNewPrivileges = lib.mkDefault true;
      RestrictNamespaces = lib.mkDefault true;
      RestrictRealtime = lib.mkDefault true;
      RestrictSUIDSGID = lib.mkDefault true;
      SystemCallArchitectures = lib.mkDefault "native";
      # WORKAROUND (nixpkgs bug, README ledger 2026-09-15; retirement
      # procedure: README "Pin-advance runbook"): with
      # provision.opensearch = false the module's settings submodule
      # still materializes opensearch.cert_path (types.path, defaults
      # to the CA bundle) and .ssl (types.bool, false); both survive
      # the module's null/[]/{} filter, so the rendered ini carries an
      # [opensearch] section WITHOUT hosts and parsedmarc 11 refuses to
      # start (ConfigurationError, "hosts setting missing" - the
      # elasticsearch-era message shape). Neither key can be nulled
      # through the option types, so strip the section from the RENDERED
      # ini after the module's own ExecStartPre. Guarded: a real
      # [opensearch] (OpenSearch provisioned) must survive.
      # PORTED 2026-10-28 at the fe132422 pin advance (PR #566282
      # renamed the option; the host-less-section bug persists as
      # [opensearch], nixpkgs #563651 still open).
      ExecStartPre = lib.mkIf (!config.services.parsedmarc.provision.opensearch) (
        lib.mkAfter [
          (pkgs.writeShellScript "parsedmarc-strip-opensearch-section" ''
            set -eu
            ${pkgs.gawk}/bin/awk '/^\[/{keep = ($0 != "[opensearch]")} keep' \
              /run/parsedmarc/parsedmarc.ini > /run/parsedmarc/parsedmarc.ini.tmp
            ${pkgs.coreutils}/bin/mv /run/parsedmarc/parsedmarc.ini.tmp \
              /run/parsedmarc/parsedmarc.ini
          '')
        ]
      );
    };

    # localMail: materialize the provisioned maildir (owned by the
    # recipient, mode 0700) at BOOT, before ANY unit start - the
    # unprefixed ReadWritePaths entry above then binds it writable.
    # postfix only creates the maildir at first delivery, which races
    # (and loses against) unit start; tmpfiles is the one mechanism
    # that runs early enough (NixOS activation creates the user before
    # tmpfiles-setup; ExecStartPre is too late by construction - see
    # the ReadWritePaths comment). "d" = mkdir -p + owner/mode,
    # idempotent, never touches delivered mail; group stays root,
    # irrelevant at mode 0700.
    systemd.tmpfiles.rules = lib.optionals config.services.parsedmarc.provision.localMail.enable [
      "d ${localMailMaildirPath} 0700 ${config.services.parsedmarc.provision.localMail.recipientName} - -"
    ];
  };
}
