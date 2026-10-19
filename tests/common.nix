# Shared test/demo building blocks (dedup 2026-10-19): the VM test
# nodes, the demo host, and the eval contracts repeated the same three
# blocks - the DNS-less-VM provision patches, the fallback-admin
# password file, and the upstream DMARC aggregate sample - each with a
# slightly different (drifting) rationale comment. One canonical copy
# each lives HERE; consumers import the piece they need. Nodes that
# need a DIFFERENT posture (stalwart-relay-e2e runs dnsmasq, so it
# keeps only the pyzor pin inline) stay in their own files.
let
  testAdminSecret = "test-admin-secret";
in {
  inherit testAdminSecret;

  # /etc/test-admin-secret: the fallback-admin password file for the
  # 0.16 systemd-creds path (the provisioning CLI's only credential).
  # Real hosts: a sops-rendered path (README go-live runbook).
  testAdminSecretModule = {
    environment.etc."test-admin-secret" = {
      mode = "0600";
      text = testAdminSecret;
    };
  };

  # DNS-less VM provision patches - the canonical copy; e2e nodes, the
  # demo host, and the provision-plan eval contract all import THIS:
  # - 0.16's reload validation READS the system resolver config and
  #   fails the whole apply ("no nameservers found in config"; the demo
  #   2026-10-18 boot race was this class - op #7 reload failed, the
  #   apply aborted before its restart step, and stalwart kept the
  #   built-in listener set) - pin DnsResolver to Cloudflare so
  #   validation passes. Lookups still stall ~30s per probe in the
  #   DNS-less VM (deterministic NXDOMAIN-timeout behavior).
  # - SpamPyzor off: its default host is unresolvable without DNS -
  #   network dependence + config-error risk for zero test value
  #   (0.15-era lesson, unchanged posture).
  # EXCEPTION: nodes that RUN a resolver (stalwart-relay-e2e's dnsmasq,
  # forwarding to 10.0.2.3) must NOT import this - they exercise the
  # system-resolver path 0.16 actually validates against.
  dnslessVmPatches = {
    services.stalwart.provision.singletons = {
      DnsResolver."@type" = "Cloudflare";
      SpamPyzor.enable = false;
    };
  };

  # Real DMARC aggregate report sample (upstream parsedmarc, the same
  # artifact nixpkgs' own parsedmarc VM test uses - report_id 2940, org
  # infonacot.gob.mx, policy domain example.com). Shared by
  # stalwart-e2e (native report ingestion) and parsedmarc-e2e
  # (collection). The attachment FILENAME matters: Stalwart's report
  # detector matches attachment names containing '!' or '.xml'
  # (smtp/src/reporting/analysis.rs), so VM copies must keep a
  # report-shaped name.
  dmarcAggregateReport = pkgs:
    pkgs.fetchurl {
      name = "dmarc-sample-aggregate";
      url = "https://github.com/domainaware/parsedmarc/raw/f45ab94e0608088e0433557608d9f4e9517d3afe/samples/aggregate/estadocuenta1.infonacot.gob.mx!example.com!1536853302!1536939702!2940.xml.zip";
      sha256 = "0dq64cj49711kbja27pjl2hy0d3azrjxg91kqrh40x46fkn1dwkx";
    };
}
