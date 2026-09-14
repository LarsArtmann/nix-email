# Thin opinionated wrapper around the nixpkgs parsedmarc module
# (services.parsedmarc - 11.0.1).
#
# PURPOSE: close the domains-repo findings H1/H2 ("no rua anywhere - the
# reject domains enforce blindly") with a deliberately LIGHT footprint:
# parsedmarc polls the rua mailboxes over IMAP and writes parsed
# aggregate/forensic/TLS-RPT reports as JSON+CSV files. NO
# Elasticsearch/OpenSearch/Splunk - those are the heavy default sinks and
# their provision flags stay off.
#
# VERIFIED FACTS this module is built on (parsedmarc 11.0.1 source):
#   - [general] `output` is the ini key for the report output directory
#     (cli.py reads general_config["output"]).
#   - There is NO SQLite sink. JSON/CSV files are the zero-dependency
#     output. A [postgresql] sink EXISTS in v11 but requires the `psycopg`
#     extra, which the nixpkgs package does not ship - if a queryable sink
#     is ever wanted, override the package with python3Packages.psycopg
#     (3.3.4 is in nixpkgs) and set settings.postgresql.* instead.
#   - Secrets: set `password = { _secret = "/path"; }` - the nixpkgs module
#     renders the file contents into the ini at unit start.
{
  config,
  lib,
  ...
}:
let
  cfg = config.services.dmarc-monitor;
in
{
  options.services.dmarc-monitor = {
    enable = lib.mkEnableOption "DMARC/TLS-RPT report collection via parsedmarc (IMAP polling, JSON/CSV output, no search-stack dependency)";

    outputDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/parsedmarc/reports";
      description = ''
        Directory parsedmarc writes aggregate/forensic/smtp_tls JSON+CSV
        files to. Back this up (backup-coordination on the consumer host);
        a small viewer over these files is the intended read path.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        mailbox = {
          host = "mail.example.com";
          port = 993;
          ssl = true;
          user = "dmarc@example.com";
          password._secret = "/run/secrets/dmarc-imap-password";
          watch = true;
        };
      };
      description = ''
        Passthrough to services.parsedmarc.settings (parsedmarc.ini).
        At minimum set `mailbox` (host/user/password with _secret) - see
        https://domainaware.github.io/parsedmarc/#configuration-file
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.parsedmarc = {
      enable = true;
      provision = {
        # Heavy sinks stay OFF - this module's whole point is lightness.
        elasticsearch = lib.mkDefault false;
        geoIp = lib.mkDefault false;
      };
      settings = lib.mkMerge [
        cfg.settings
        {
          general.output = lib.mkDefault cfg.outputDirectory;
        }
      ];
    };
  };
}
