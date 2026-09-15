# End-to-end VM test for modules/dmarc-monitor.nix against the REAL
# parsedmarc 11.0.1 binary from nixpkgs (no mocks).
#
# WHY: tests/dmarc-eval.nix only proves the rendered configuration; this
# test proves the service actually COLLECTS: a real DMARC aggregate report
# is mailed into the provisioned local mailbox, parsedmarc polls it over
# IMAP (the production mechanism), and parsed JSON+CSV land in the
# wrapper's output directory - the zero-dependency file sink this wrapper
# exists to provide (no Elasticsearch, no Splunk).
#
#   1. provision.localMail wires dovecot (IMAP 143) + postfix + the dmarc
#      user with a runtime-randomized password (nixpkgs-proven path)
#   2. A real upstream sample aggregate report (.xml.zip attachment) is
#      SMTP'd to dmarc@localhost
#   3. parsedmarc (watch=true) parses it and save_output() writes
#      aggregate.json/aggregate.csv into /var/lib/parsedmarc/reports
#      (verified against 11.0.1 source: cli.py "if opts.output:" ->
#      __init__.py save_output with fixed filenames)
#   4. The StateDirectory/ReadWritePaths hardening from the wrapper is
#      what makes step 3 possible at all - the nixpkgs DynamicUser unit
#      prepares no writable state (the latent prod bug this fixes), so a
#      Permission denied here means the fix regressed.
#
# Sample report: the same upstream sample nixpkgs' own parsedmarc VM test
# uses (report_id 2940, org infonacot.gob.mx, policy domain example.com).
{pkgs}: let
  dmarcTestReport = pkgs.fetchurl {
    name = "dmarc-test-report";
    url = "https://github.com/domainaware/parsedmarc/raw/f45ab94e0608088e0433557608d9f4e9517d3afe/samples/aggregate/estadocuenta1.infonacot.gob.mx!example.com!1536853302!1536939702!2940.xml.zip";
    sha256 = "0dq64cj49711kbja27pjl2hy0d3azrjxg91kqrh40x46fkn1dwkx";
  };

  # Mails the sample report as a .xml.zip attachment (cribbed from
  # nixpkgs nixos/tests/parsedmarc: parsedmarc extracts report files by
  # attachment extension .xml/.xml.gz/.zip).
  sendEmail = pkgs.writeScriptBin "send-email" ''
    #!${pkgs.python3.interpreter}
    import smtplib
    from email import encoders
    from email.mime.base import MIMEBase
    from email.mime.multipart import MIMEMultipart
    from email.mime.text import MIMEText

    sender_email = "dmarc_tester@fake.domain"
    receiver_email = "dmarc@localhost"

    message = MIMEMultipart()
    message["From"] = sender_email
    message["To"] = receiver_email
    message["Subject"] = "DMARC test"

    message.attach(MIMEText("Testing parsedmarc", "plain"))

    attachment = MIMEBase("application", "zip")

    with open("${dmarcTestReport}", "rb") as report:
        attachment.set_payload(report.read())

    encoders.encode_base64(attachment)

    attachment.add_header(
        "Content-Disposition",
        "attachment; filename= estadocuenta1.infonacot.gob.mx!example.com!1536853302!1536939702!2940.xml.zip",
    )

    message.attach(attachment)
    text = message.as_string()

    with smtplib.SMTP('localhost') as server:
        server.sendmail(sender_email, receiver_email, text)
        server.quit()
  '';
in
  pkgs.testers.runNixOSTest {
    name = "parsedmarc-e2e";

    nodes.machine = {config, ...}: {
      imports = [../modules/dmarc-monitor.nix];

      virtualisation.memorySize = 2048;

      services.dovecot2 = {
        # nixpkgs' localMail provision ships no auth config: on this pin
        # (dovecot 2.4) enablePAM defaults FALSE, so the auth service
        # crash-loops with "No passdbs specified ... PLAIN mechanism needs
        # one" and IMAP login is impossible (observed in this test,
        # 2026-09-15). enablePAM adds the passdb/userdb blocks + PAM
        # service; the dmarc system user authenticates via PAM unix auth.
        enablePAM = true;
        settings = {
          # Dovecot 2.4 on this nixpkgs pin REQUIRES explicit version pins
          # (base-module assertions), but nixpkgs' parsedmarc localMail
          # provision enables dovecot2 without setting them - any localMail
          # consumer hits the assertion (upstream gap, verified in the
          # pinned module source). The VM's storage is ephemeral, so pin
          # both to the shipped package version (the auto-update variant).
          dovecot_config_version = config.services.dovecot2.package.version;
          dovecot_storage_version = config.services.dovecot2.package.version;
          # 2.4 needs explicit storage; must match postfix's home_mailbox
          # below so the IMAP INBOX is exactly the Maildir postfix writes.
          mail_driver = "maildir";
          mail_path = "~/Maildir";
          # VM fixture: no TLS material, so dovecot would advertise
          # STARTTLS it cannot complete - mailsuite auto-activates STARTTLS
          # whenever the capability is advertised (mailsuite/imap.py) and
          # the handshake dies with WRONG_VERSION_NUMBER. plaintext IMAP
          # inside the VM loop; production rua mailboxes use real TLS.
          ssl = "no";
        };
      };

      # Deliver INTO the Maildir dovecot serves (postfix local(8) default
      # is the mbox in /var/mail, which dovecot's maildir INBOX would
      # never see - observed as "empty INBOX forever" in testing).

      services.dmarc-monitor = {
        enable = true;
        # parsedmarc 11 does DNS at PARSE time (reverse-DNS map, geolocation)
        # against Cloudflare/Google by default (constants.py
        # RECOMMENDED_DNS_NAMESERVERS = 1.1.1.1, 8.8.8.8) - in the DNS-less
        # VM every lookup stalls and parsing never completes. offline=true
        # skips all online enrichment ([general] offline, cli.py:778).
        settings.general.offline = true;
      };

      # The nixpkgs parsedmarc module's localMail provision: dovecot + postfix
      # + dmarc system user + runtime-randomized IMAP password, and the
      # [imap]/[mailbox] settings (localhost:143, ssl=false, watch=true)
      # merged into services.parsedmarc.settings. The wrapper's own
      # contributions stay in force: general.output=/var/lib/parsedmarc/reports,
      # heavy sinks off, StateDirectory/ReadWritePaths on the unit.
      services.parsedmarc.provision = {
        geoIp = false;
        localMail = {
          enable = true;
          hostname = "localhost";
        };
      };

      services.postfix.settings.main.home_mailbox = "Maildir/";

      environment.systemPackages = [
        (sendEmail)
        pkgs.jq
      ];
    };

    testScript = ''
      start_all()

      machine.wait_for_unit("postfix.service")
      # The 2.4 module renamed the unit: systemd.services.dovecot (was
      # dovecot2.service on 2.3-era nixpkgs).
      machine.wait_for_unit("dovecot.service")
      machine.wait_for_unit("parsedmarc.service")
      machine.wait_for_open_port(25, timeout=60)
      machine.wait_for_open_port(143, timeout=60)

      # The wrapper must render a clean unit BEFORE any report exists:
      # the ini secret replacement ran (no @imap-password@ placeholder
      # left in /run) and the heavy sinks stayed out of the config.
      machine.succeed(
          "! grep -q '@imap-password@' /run/parsedmarc/parsedmarc.ini"
      )
      machine.succeed(
          # The WRAPPER's contract is that no sink TARGET is configured:
          # no splunk_hec section, no hosts line anywhere in the ini.
          "! grep -qiE '^\\[splunk_hec\\]' /run/parsedmarc/parsedmarc.ini"
      )
      machine.succeed(
          "! grep -qiE '^hosts' /run/parsedmarc/parsedmarc.ini"
      )
      machine.succeed(
          # The strip workaround's OWN contract, asserted directly: with
          # Elasticsearch off, nixpkgs still renders an inert host-less
          # [elasticsearch] section (cert_path/ssl are typed and survive
          # the module's null/[]/{} filter) - it must be provably GONE
          # from the runtime ini. parsedmarc merely STARTING is necessary
          # but not sufficient: cli.py only refuses a section that is
          # present AND hosts-less.
          "! grep -qiE '^\\[elasticsearch\\]' /run/parsedmarc/parsedmarc.ini"
      )
      machine.succeed(
          # ini renders key=value with NO spaces (parsedmarc.nix flips
          # mkKeyValueDefault "=") - verified against the rendered file.
          "grep -q '^output=/var/lib/parsedmarc/reports$' /run/parsedmarc/parsedmarc.ini"
      )

      with subtest("aggregate report mailed into the local mailbox is parsed"):
          machine.succeed("send-email >&2")
          # IMAP IDLE/watch -> parse -> save_output is async; poll for the
          # fixed filenames (save_output writes aggregate.json/csv, verified
          # against parsedmarc 11.0.1 __init__.py save_output).
          machine.wait_until_succeeds(
              # Healthy parse is ~9 s; 120 s bounds a hang 13x over
              # without making a slow-but-working parse flaky.
              "test -s /var/lib/parsedmarc/reports/aggregate.json",
              timeout=120,
          )

      with subtest("parsed aggregate JSON carries the report's identity"):
          # report_id 2940, org "XYZ Corporation", policy domain example.com
          # - the parsed XML's OWN metadata: the sample FILENAME says
          # infonacot.gob.mx but the XML body's org_name is XYZ Corporation
          # (verified by parsing the fixture with the pinned parsedmarc).
          # Plain `jq -e '.[] | select(...)': NO -s slurp (it would wrap the
          # array and make select test the inner array instead of reports).
          machine.succeed(
              "jq -e '.[] | select(.report_metadata.report_id == \"2940\")' "
              "/var/lib/parsedmarc/reports/aggregate.json"
          )
          machine.succeed(
              "jq -e '.[] | select(.report_metadata.org_name == \"XYZ Corporation\")' "
              "/var/lib/parsedmarc/reports/aggregate.json"
          )
          machine.succeed(
              "jq -e '.[] | select(.policy_published.domain == \"example.com\")' "
              "/var/lib/parsedmarc/reports/aggregate.json"
          )

      with subtest("CSV sink carries the same report"):
          machine.succeed(
              "test -s /var/lib/parsedmarc/reports/aggregate.csv"
          )
          machine.succeed(
              "grep -q 'example.com' /var/lib/parsedmarc/reports/aggregate.csv"
          )

      with subtest("no file-output errors: StateDirectory fix holds"):
          # A "File output Error" in the journal is the exact symptom of the
          # DynamicUser-writes-to-root-owned-path bug the wrapper's
          # StateDirectory/ReadWritePaths addition fixes.
          machine.succeed(
              "! journalctl -u parsedmarc -b 0 -o cat | grep -qi 'File output Error'"
          )
          machine.succeed(
              "! journalctl -u parsedmarc -b 0 -o cat | grep -qi 'Permission denied'"
          )
    '';
  }
